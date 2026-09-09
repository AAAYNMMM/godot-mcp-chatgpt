@tool
extends Node

const DebuggerBridge := preload("res://addons/godot_mcp_chatgpt/debug/editor_debugger_bridge.gd")
const RUNTIME_AUTOLOAD_NAME := "GodotMCPChatGPTRuntime"
const RUNTIME_SCRIPT := "res://addons/godot_mcp_chatgpt/runtime/runtime_bridge.gd"

var _editor_plugin: EditorPlugin
var _debugger: EditorDebuggerPlugin
var _responses: Dictionary = {}
var _sequence := 0

func setup(editor_plugin: EditorPlugin) -> Dictionary:
    _editor_plugin = editor_plugin
    var autoload_key := "autoload/" + RUNTIME_AUTOLOAD_NAME
    if ProjectSettings.has_setting(autoload_key):
        var existing := str(ProjectSettings.get_setting(autoload_key, ""))
        if not _autoload_matches_runtime(existing):
            _editor_plugin = null
            return {"ok": false, "error": "RUNTIME_AUTOLOAD_CONFLICT", "existing": existing}
    _debugger = DebuggerBridge.new()
    _debugger.response_received.connect(_on_response)
    _editor_plugin.add_debugger_plugin(_debugger)
    if not ProjectSettings.has_setting(autoload_key):
        _editor_plugin.add_autoload_singleton(RUNTIME_AUTOLOAD_NAME, RUNTIME_SCRIPT)
        var save_error: Error = ProjectSettings.save()
        if save_error != OK:
            _editor_plugin.remove_autoload_singleton(RUNTIME_AUTOLOAD_NAME)
            _editor_plugin.remove_debugger_plugin(_debugger)
            _debugger = null
            _editor_plugin = null
            return {"ok": false, "error": "RUNTIME_AUTOLOAD_SAVE_FAILED", "message": error_string(save_error)}
    return {"ok": true}

func shutdown() -> void:
    if _editor_plugin != null and _debugger != null:
        _editor_plugin.remove_debugger_plugin(_debugger)
    _debugger = null
    _editor_plugin = null
    _responses.clear()

func remove_runtime_autoload() -> Dictionary:
    if _editor_plugin == null:
        return {"ok": true, "removed": false}
    var autoload_key := "autoload/" + RUNTIME_AUTOLOAD_NAME
    if not ProjectSettings.has_setting(autoload_key):
        return {"ok": true, "removed": false}
    var existing := str(ProjectSettings.get_setting(autoload_key, ""))
    if not _autoload_matches_runtime(existing):
        return {"ok": false, "error": "RUNTIME_AUTOLOAD_CONFLICT", "existing": existing}
    _editor_plugin.remove_autoload_singleton(RUNTIME_AUTOLOAD_NAME)
    var save_error: Error = ProjectSettings.save()
    if save_error != OK:
        return {"ok": false, "error": "RUNTIME_AUTOLOAD_SAVE_FAILED", "message": error_string(save_error)}
    return {"ok": true, "removed": true}

func _autoload_matches_runtime(value: String) -> bool:
    var reference := value.trim_prefix("*")
    if reference == RUNTIME_SCRIPT:
        return true
    if reference.begins_with("uid://"):
        var uid := ResourceUID.text_to_id(reference)
        return ResourceUID.get_id_path(uid) == RUNTIME_SCRIPT
    return false

func request(command: String, arguments: Dictionary = {}, timeout_ms: int = 4000, session_id: int = -1) -> Dictionary:
    if _debugger == null:
        return _error("DEBUGGER_UNAVAILABLE", "Runtime debugger bridge is unavailable")
    _sequence += 1
    var request_id := "%s-%s-%s" % [Time.get_ticks_msec(), _sequence, randi()]
    var sent: Dictionary = _debugger.send_request({"request_id":request_id,"command":command,"arguments":arguments}, session_id)
    if not bool(sent.get("ok", false)):
        return _error(str(sent.get("error", "RUNTIME_NOT_RUNNING")), "No active Godot runtime debugger session")
    var deadline := Time.get_ticks_msec() + clampi(timeout_ms, 100, 30000)
    while not _responses.has(request_id):
        if Time.get_ticks_msec() >= deadline:
            return _error("RUNTIME_REQUEST_TIMEOUT", "Runtime debugger request timed out: " + command)
        await get_tree().create_timer(0.01).timeout
    var payload: Dictionary = _responses[request_id]
    _responses.erase(request_id)
    if bool(payload.get("ok", false)):
        return {"ok": true, "result": payload.get("result")}
    var error_value = payload.get("error", {})
    if error_value is Dictionary:
        return {"ok": false, "error": error_value}
    return _error("RUNTIME_ERROR", str(error_value))

func session_summaries() -> Array:
    return [] if _debugger == null else _debugger.session_summaries()

func set_breakpoint(path: String, line: int, enabled: bool, session_id: int = -1) -> Dictionary:
    if _debugger == null:
        return _error("DEBUGGER_UNAVAILABLE", "Runtime debugger bridge is unavailable")
    var result: Dictionary = _debugger.set_breakpoint(path, line, enabled, session_id)
    if not bool(result.get("ok", false)):
        return _error(str(result.get("error", "RUNTIME_NOT_RUNNING")), "No active debugger session")
    return {"ok": true, "result": {"path":path,"line":line,"enabled":enabled,"session_id":result.get("session_id",-1)}}

func toggle_profiler(profiler: String, enabled: bool, data: Array = [], session_id: int = -1) -> Dictionary:
    if _debugger == null:
        return _error("DEBUGGER_UNAVAILABLE", "Runtime debugger bridge is unavailable")
    var result: Dictionary = _debugger.toggle_profiler(StringName(profiler), enabled, data, session_id)
    if not bool(result.get("ok", false)):
        return _error(str(result.get("error", "RUNTIME_NOT_RUNNING")), "No active debugger session")
    return {"ok": true, "result": {"profiler":profiler,"enabled":enabled,"session_id":result.get("session_id",-1)}}

func _on_response(request_id: String, payload: Dictionary) -> void:
    if not request_id.is_empty():
        _responses[request_id] = payload

func _error(code: String, message: String) -> Dictionary:
    return {"ok": false, "error": {"code":code,"message":message}}