@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin, manager: Node) -> void:
    _add(registry, "debugger.get_sessions", "Return active Godot debugger sessions and break/debuggable state.", {}, func(_a): return U.ok({"sessions":manager.session_summaries()}), true)
    _add(registry, "debugger.get_breakpoints", "Return breakpoints currently known by the Godot Script editor.", {}, func(_a): return _breakpoints(plugin), true)
    _add(registry, "debugger.set_breakpoint", "Enable or disable a breakpoint in an active debugger session.", {"path":{"type":"string"},"line":{"type":"integer"},"enabled":{"type":"boolean"},"session_id":{"type":"integer"}}, func(a): return manager.set_breakpoint(str(a.get("path","")),int(a.get("line",1)),bool(a.get("enabled",true)),int(a.get("session_id",-1))), false, ["path","line"])
    _add(registry, "debugger.toggle_profiler", "Enable or disable a named Godot debugger profiler in an active session.", {"profiler":{"type":"string"},"enabled":{"type":"boolean"},"data":{"type":"array"},"session_id":{"type":"integer"}}, func(a): return manager.toggle_profiler(str(a.get("profiler","")),bool(a.get("enabled",true)),Array(a.get("data",[])),int(a.get("session_id",-1))), false, ["profiler"])
    _runtime(registry, "runtime.status", "Inspect the connected running game's status.", "status", {}, manager, true)
    _runtime(registry, "runtime.get_tree", "Return the live runtime SceneTree under current_scene.", "get_tree", {"max_depth":{"type":"integer"},"include_properties":{"type":"boolean"}}, manager, true)
    _runtime(registry, "runtime.inspect", "Inspect one live runtime node, including properties/groups/script.", "inspect", {"node_path":{"type":"string"},"property_mode":{"type":"string"},"limit":{"type":"integer"}}, manager, true)
    _runtime(registry, "runtime.find", "Find live runtime nodes by name substring, class, or group.", "find", {"name_contains":{"type":"string"},"class":{"type":"string"},"group":{"type":"string"},"limit":{"type":"integer"}}, manager, true)
    _runtime(registry, "runtime.get_property", "Read one property from a live runtime node.", "get_property", {"node_path":{"type":"string"},"property":{"type":"string"}}, manager, true, ["node_path","property"])
    _runtime(registry, "runtime.set_property", "Set one property on a live runtime node. This affects the running instance, not the saved scene.", "set_property", {"node_path":{"type":"string"},"property":{"type":"string"},"value":{}}, manager, false, ["node_path","property","value"])
    _runtime(registry, "runtime.call_method", "Call a method on a live runtime node with structured arguments.", "call_method", {"node_path":{"type":"string"},"method":{"type":"string"},"arguments":{"type":"array"}}, manager, false, ["node_path","method"])
    _runtime(registry, "runtime.get_groups", "Return groups for a live runtime node.", "get_groups", {"node_path":{"type":"string"}}, manager, true, ["node_path"])
    _runtime(registry, "runtime.get_performance", "Return selected live Godot Performance monitors.", "performance", {}, manager, true)
    _runtime(registry, "runtime.pause", "Pause the running SceneTree.", "pause", {}, manager, false)
    _runtime(registry, "runtime.resume", "Resume a paused running SceneTree.", "resume", {}, manager, false)

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = []) -> void:
    registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":false})

static func _runtime(registry: RefCounted, name: String, description: String, runtime_command: String, properties: Dictionary, manager: Node, read_only: bool, required: Array = []) -> void:
    var schema_properties := properties.duplicate(true)
    schema_properties["session_id"] = {"type":"integer","description":"Optional debugger session id; defaults to the newest active session."}
    schema_properties["timeout_ms"] = {"type":"integer","minimum":100,"maximum":30000,"description":"Runtime response timeout in milliseconds."}
    _add(registry,name,description,schema_properties,func(a): return await manager.request(runtime_command,a,int(a.get("timeout_ms",4000)),int(a.get("session_id",-1))),read_only,required)

static func _breakpoints(plugin: EditorPlugin) -> Dictionary:
    var values := plugin.get_editor_interface().get_script_editor().get_breakpoints()
    var result: Array = []
    for value in values:
        result.append(str(value))
    return U.ok({"breakpoints":result})