@tool
extends EditorDebuggerPlugin

signal response_received(request_id: String, payload: Dictionary)
signal runtime_event(session_id: int, event_name: String, payload: Dictionary)

const PREFIX := "godot_mcp"
var _sessions: Dictionary = {}

func _setup_session(session_id: int) -> void:
    var session := get_session(session_id)
    if session != null:
        _sessions[session_id] = session
        session.started.connect(_on_session_started.bind(session_id))
        session.stopped.connect(_on_session_stopped.bind(session_id))

func _has_capture(capture: String) -> bool:
    return capture == PREFIX

func _capture(message: String, data: Array, session_id: int) -> bool:
    var action := message
    if action.begins_with(PREFIX + ":"):
        action = action.substr(PREFIX.length() + 1)
    var payload: Dictionary = {}
    if not data.is_empty() and data[0] is Dictionary:
        payload = data[0]
    match action:
        "response":
            response_received.emit(str(payload.get("request_id", "")), payload)
        "ready":
            runtime_event.emit(session_id, "ready", payload)
        "event":
            runtime_event.emit(session_id, str(payload.get("event", "runtime")), payload)
        _:
            runtime_event.emit(session_id, action, payload)
    return true

func send_request(payload: Dictionary, preferred_session_id: int = -1) -> Dictionary:
    var chosen_id := _choose_session(preferred_session_id)
    if chosen_id < 0:
        return {"ok": false, "error": "RUNTIME_NOT_RUNNING"}
    var session := get_session(chosen_id)
    if session == null or not session.is_active():
        return {"ok": false, "error": "RUNTIME_SESSION_INACTIVE"}
    session.send_message(PREFIX + ":request", [payload])
    return {"ok": true, "session_id": chosen_id}

func session_summaries() -> Array:
    var result: Array = []
    var sessions := get_sessions()
    for i in sessions.size():
        var session := sessions[i] as EditorDebuggerSession
        if session == null:
            continue
        result.append({
            "session_id": i,
            "active": session.is_active(),
            "debuggable": session.is_debuggable(),
            "breaked": session.is_breaked(),
        })
    return result

func set_breakpoint(path: String, line: int, enabled: bool, preferred_session_id: int = -1) -> Dictionary:
    var chosen_id := _choose_session(preferred_session_id)
    if chosen_id < 0:
        return {"ok": false, "error": "RUNTIME_NOT_RUNNING"}
    var session := get_session(chosen_id)
    if session == null:
        return {"ok": false, "error": "RUNTIME_SESSION_INACTIVE"}
    session.set_breakpoint(path, line, enabled)
    return {"ok": true, "session_id": chosen_id}

func toggle_profiler(profiler: StringName, enabled: bool, data: Array = [], preferred_session_id: int = -1) -> Dictionary:
    var chosen_id := _choose_session(preferred_session_id)
    if chosen_id < 0:
        return {"ok": false, "error": "RUNTIME_NOT_RUNNING"}
    var session := get_session(chosen_id)
    if session == null:
        return {"ok": false, "error": "RUNTIME_SESSION_INACTIVE"}
    session.toggle_profiler(profiler, enabled, data)
    return {"ok": true, "session_id": chosen_id}

func _choose_session(preferred_session_id: int) -> int:
    if preferred_session_id >= 0:
        var preferred := get_session(preferred_session_id)
        if preferred != null and preferred.is_active():
            return preferred_session_id
    var sessions := get_sessions()
    for offset in sessions.size():
        var i := sessions.size() - 1 - offset
        var session := sessions[i] as EditorDebuggerSession
        if session != null and session.is_active():
            return i
    return -1

func _on_session_started(session_id: int) -> void:
    runtime_event.emit(session_id, "session_started", {})

func _on_session_stopped(session_id: int) -> void:
    runtime_event.emit(session_id, "session_stopped", {})