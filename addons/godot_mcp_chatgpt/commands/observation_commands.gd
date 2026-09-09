@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const ImageUtils := preload("res://addons/godot_mcp_chatgpt/core/image_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin, manager: Node, editor_logger: Logger) -> void:
    _add(registry, "editor.take_screenshot", "Capture the Godot editor 3D/2D viewport, a cinematic Camera3D view, or the running game as MCP image content.", {
        "source":{"type":"string","enum":["viewport_3d","viewport_2d","cinematic","game"]},
        "max_resolution":{"type":"integer","minimum":64,"maximum":2048},
        "session_id":{"type":"integer"},"timeout_ms":{"type":"integer","minimum":100,"maximum":30000}
    }, func(a): return await _screenshot(plugin, manager, a), true)
    _add(registry, "editor.get_performance", "Return editor-process performance monitor values.", {"monitors":{"type":"array","items":{"type":"string"}}}, func(a): return _editor_performance(a), true)
    _add(registry, "editor.get_play_status", "Return structured play/debugger/runtime liveness for the current project run.", {}, func(_a): return await _play_status(plugin, manager, editor_logger), true)
    _add(registry, "editor.reload_plugin", "Safely refresh addon scripts/filesystem state. Full self-disable/re-enable is intentionally not performed because it would tear down the active MCP response path.", {"scan":{"type":"boolean"}}, func(a): return _reload_plugin(plugin, a), false)
    _add(registry, "editor.quit", "Schedule Godot editor shutdown. Requires confirm=true; optionally saves all scenes/scripts first.", {"confirm":{"type":"boolean"},"save_before":{"type":"boolean"}}, func(a): return _quit_editor(plugin, a), false, ["confirm"], true)

    _add(registry, "logs.read", "Read bounded editor/game logs with cursors and per-run identity.", {
        "source":{"type":"string","enum":["editor","game","all"]},"cursor":{"type":"integer","minimum":0},"limit":{"type":"integer","minimum":1,"maximum":500},"level":{"type":"string","enum":["","info","warning","error"]},"session_id":{"type":"integer"},"timeout_ms":{"type":"integer","minimum":100,"maximum":30000}
    }, func(a): return await _logs_read(manager, editor_logger, a), true)
    _add(registry, "logs.clear", "Clear the editor and/or running-game log ring buffers.", {
        "source":{"type":"string","enum":["editor","game","all"]},"session_id":{"type":"integer"},"timeout_ms":{"type":"integer","minimum":100,"maximum":30000}
    }, func(a): return await _logs_clear(manager, editor_logger, a), false)

    _runtime(registry, "runtime.get_ui_elements", "List visible live Control nodes with bounded layout/text state.", "ui_elements", {"limit":{"type":"integer","minimum":1,"maximum":500},"include_hidden":{"type":"boolean"}}, manager, true)
    _runtime(registry, "runtime.input_action", "Press or release an InputMap action in the running game.", "input_action", {"action":{"type":"string"},"pressed":{"type":"boolean"},"strength":{"type":"number","minimum":0,"maximum":1}}, manager, false, ["action"])
    _runtime(registry, "runtime.input_key", "Inject a keyboard event into the running game.", "input_key", {"keycode":{"type":"integer"},"physical_keycode":{"type":"integer"},"pressed":{"type":"boolean"},"echo":{"type":"boolean"},"ctrl":{"type":"boolean"},"alt":{"type":"boolean"},"shift":{"type":"boolean"},"meta":{"type":"boolean"}}, manager, false)
    _runtime(registry, "runtime.input_mouse", "Inject mouse button or motion input into the running game.", "input_mouse", {"kind":{"type":"string","enum":["button","motion"]},"button":{"type":"integer"},"pressed":{"type":"boolean"},"x":{"type":"number"},"y":{"type":"number"},"dx":{"type":"number"},"dy":{"type":"number"},"vx":{"type":"number"},"vy":{"type":"number"},"factor":{"type":"number"}}, manager, false)
    _runtime(registry, "runtime.input_gamepad", "Inject joypad button or axis input into the running game.", "input_gamepad", {"kind":{"type":"string","enum":["button","axis"]},"device":{"type":"integer"},"button":{"type":"integer"},"pressed":{"type":"boolean"},"pressure":{"type":"number","minimum":0,"maximum":1},"axis":{"type":"integer"},"value":{"type":"number","minimum":-1,"maximum":1}}, manager, false)
    _runtime(registry, "runtime.get_input_state", "Read InputMap action state and runtime mouse position.", "input_state", {"actions":{"type":"array","items":{"type":"string"},"maxItems":128}}, manager, true)
    _runtime(registry, "runtime.input_sequence", "Execute frame-timed input steps inside the running Godot process, independent of tunnel latency.", "input_sequence", {
        "steps":{"type":"array","minItems":1,"maxItems":128,"items":{"type":"object","properties":{"at_frame":{"type":"integer","minimum":0,"maximum":600},"event":{"type":"object"}},"required":["at_frame","event"],"additionalProperties":false}},"release_actions":{"type":"boolean"}
    }, manager, false, ["steps"], 30000)
    _runtime(registry, "runtime.get_debug_status", "Return game-loop/debugger-suspension status from inside the running process.", "debug_status", {}, manager, true)
    _runtime(registry, "runtime.evaluate", "Evaluate a bounded Godot Expression against one live runtime node. This does not expose an OS shell or project-external process execution.", "evaluate", {"node_path":{"type":"string"},"expression":{"type":"string","maxLength":4096},"variables":{"type":"object","maxProperties":32}}, manager, true, ["expression"])

    _add(registry, "debugger.suspend", "Suspend the running game through Godot's native debugger session.", {"session_id":{"type":"integer"}}, func(a): return manager.native_control("suspend", int(a.get("session_id",-1))), false)
    _add(registry, "debugger.resume", "Resume a debugger-suspended game through Godot's native debugger session.", {"session_id":{"type":"integer"}}, func(a): return manager.native_control("resume", int(a.get("session_id",-1))), false)
    _add(registry, "debugger.next_frame", "Advance one frame through Godot's native debugger path. The game should be debugger-suspended first.", {"session_id":{"type":"integer"}}, func(a): return manager.native_control("next_frame", int(a.get("session_id",-1))), false)
    _add(registry, "debugger.get_status", "Return native debugger session active/debuggable/breaked state.", {"session_id":{"type":"integer"}}, func(a): return manager.native_status(int(a.get("session_id",-1))), true)

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = [], destructive: bool = false) -> void:
    registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":destructive})

static func _runtime(registry: RefCounted, name: String, description: String, runtime_command: String, properties: Dictionary, manager: Node, read_only: bool, required: Array = [], default_timeout_ms: int = 6000) -> void:
    var schema := properties.duplicate(true)
    schema["session_id"] = {"type":"integer"}
    schema["timeout_ms"] = {"type":"integer","minimum":100,"maximum":30000}
    _add(registry, name, description, schema, func(a): return await manager.request(runtime_command, a, int(a.get("timeout_ms",default_timeout_ms)), int(a.get("session_id",-1))), read_only, required)

static func _screenshot(plugin: EditorPlugin, manager: Node, args: Dictionary) -> Dictionary:
    var source := str(args.get("source", "viewport_3d"))
    if source == "game":
        return await manager.request("screenshot", {"max_resolution":int(args.get("max_resolution",1280))}, int(args.get("timeout_ms",8000)), int(args.get("session_id",-1)))
    var viewport: Viewport = null
    if source == "viewport_2d":
        viewport = plugin.get_editor_interface().get_editor_viewport_2d()
    elif source == "viewport_3d":
        viewport = plugin.get_editor_interface().get_editor_viewport_3d()
    elif source == "cinematic":
        return _cinematic_screenshot(plugin, int(args.get("max_resolution",1280)))
    if viewport == null:
        return U.error("VIEWPORT_UNAVAILABLE", "Requested editor viewport is unavailable")
    RenderingServer.force_draw(false)
    var image := viewport.get_texture().get_image()
    return _image_result(image, source, int(args.get("max_resolution",1280)))

static func _cinematic_screenshot(plugin: EditorPlugin, max_resolution: int) -> Dictionary:
    var root := plugin.get_editor_interface().get_edited_scene_root()
    if root == null:
        return U.error("NO_SCENE", "No edited scene is open")
    var camera := _find_camera3d(root)
    if camera == null:
        return U.error("CAMERA_NOT_FOUND", "No current Camera3D exists in the edited scene")
    var edit_view := plugin.get_editor_interface().get_editor_viewport_3d()
    var size := Vector2i(1280,720)
    if edit_view != null:
        var visible := edit_view.get_visible_rect().size
        if visible.x >= 64 and visible.y >= 64:
            size = Vector2i(int(visible.x),int(visible.y))
    var sub := SubViewport.new()
    sub.size = size
    sub.own_world_3d = false
    sub.render_target_update_mode = SubViewport.UPDATE_ONCE
    var cam := Camera3D.new()
    cam.fov = camera.fov
    cam.near = camera.near
    cam.far = camera.far
    cam.projection = camera.projection
    cam.size = camera.size
    cam.keep_aspect = camera.keep_aspect
    cam.cull_mask = camera.cull_mask
    cam.environment = camera.environment
    cam.attributes = camera.attributes
    cam.current = true
    sub.add_child(cam)
    root.add_child(sub)
    cam.global_transform = camera.global_transform
    cam.force_update_transform()
    RenderingServer.force_draw(false)
    var image := sub.get_texture().get_image()
    root.remove_child(sub)
    sub.free()
    var result := _image_result(image, "cinematic", max_resolution)
    if bool(result.get("ok",false)):
        result["result"]["camera_path"] = str(root.get_path_to(camera))
    return result

static func _find_camera3d(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera3d(child)
        if found != null:
            return found
    return null

static func _image_result(image: Image, source: String, max_resolution: int) -> Dictionary:
    var encoded := ImageUtils.encode_png(image, max_resolution)
    if not bool(encoded.get("ok",false)):
        return encoded
    return U.ok({"source":source,"width":encoded.width,"height":encoded.height,"original_width":encoded.original_width,"original_height":encoded.original_height,"bytes":encoded.bytes,"__mcp_image":{"data":encoded.data,"mime_type":encoded.mime_type}})

static func _editor_performance(args: Dictionary) -> Dictionary:
    var monitor_names := {
        "fps":Performance.TIME_FPS,"process":Performance.TIME_PROCESS,"physics_process":Performance.TIME_PHYSICS_PROCESS,
        "memory_static":Performance.MEMORY_STATIC,"objects":Performance.OBJECT_COUNT,"nodes":Performance.OBJECT_NODE_COUNT,
        "resources":Performance.OBJECT_RESOURCE_COUNT,"orphan_nodes":Performance.OBJECT_ORPHAN_NODE_COUNT,
        "draw_calls":Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,"primitives":Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
    }
    var requested: Array = args.get("monitors",[])
    var values := {}
    for key in monitor_names.keys():
        if requested.is_empty() or requested.has(key):
            values[key] = Performance.get_monitor(monitor_names[key])
    return U.ok({"monitors":values,"count":values.size()})

static func _play_status(plugin: EditorPlugin, manager: Node, editor_logger: Logger) -> Dictionary:
    var playing := plugin.get_editor_interface().is_playing_scene()
    var runtime: Dictionary = {}
    if playing:
        var response: Dictionary = await manager.request("status", {}, 1000, -1)
        runtime = response.get("result", {}) if bool(response.get("ok",false)) else {"ready":false,"error":response.get("error")}
    var logs: Dictionary = editor_logger.recent(20) if editor_logger != null and editor_logger.has_method("recent") else {}
    var recent_errors: Array = []
    for entry in logs.get("entries",[]):
        if entry is Dictionary and str(entry.get("level","")) == "error":
            recent_errors.append(entry)
    return U.ok({"playing":playing,"playing_scene":plugin.get_editor_interface().get_playing_scene(),"sessions":manager.session_summaries(),"runtime":runtime,"recent_errors":recent_errors.slice(maxi(0,recent_errors.size()-5))})

static func _reload_plugin(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    plugin.get_editor_interface().get_script_editor().reload_open_files()
    var fs := plugin.get_editor_interface().get_resource_filesystem()
    if fs != null and bool(args.get("scan",true)):
        fs.scan()
    return U.ok({"refreshed":true,"full_self_reload":false,"reason":"A full disable/re-enable would tear down the active MCP request; scripts/filesystem were refreshed in-process."})

static func _quit_editor(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    if not bool(args.get("confirm",false)):
        return U.error("CONFIRM_REQUIRED", "editor.quit requires confirm=true")
    if bool(args.get("save_before",false)):
        plugin.get_editor_interface().save_all_scenes()
        plugin.get_editor_interface().get_script_editor().save_all_scripts()
    var tree := plugin.get_tree()
    if tree == null:
        return U.error("EDITOR_TREE_UNAVAILABLE", "Editor SceneTree is unavailable")
    tree.create_timer(0.25).timeout.connect(func(): tree.quit())
    return U.ok({"scheduled":true,"delay_ms":250})

static func _logs_read(manager: Node, editor_logger: Logger, args: Dictionary) -> Dictionary:
    var source := str(args.get("source","all"))
    var cursor := int(args.get("cursor",0))
    var limit := clampi(int(args.get("limit",200)),1,500)
    var level := str(args.get("level",""))
    var result := {"source":source,"entries":[]}
    if source in ["editor","all"]:
        var editor_result: Dictionary = editor_logger.read_since(cursor,limit,level) if editor_logger != null and editor_logger.has_method("read_since") else {"entries":[],"cursor":0}
        result["editor"] = editor_result
        result["entries"].append_array(editor_result.get("entries",[]))
    if source in ["game","all"]:
        var game_response: Dictionary = await manager.request("logs_read", {"cursor":cursor,"limit":limit,"level":level}, int(args.get("timeout_ms",3000)), int(args.get("session_id",-1)))
        if bool(game_response.get("ok",false)):
            var game_result: Dictionary = game_response.get("result",{})
            result["game"] = game_result
            result["entries"].append_array(game_result.get("entries",[]))
        else:
            result["game"] = {"entries":[],"unavailable":true,"error":game_response.get("error")}
    result["entries"] = result["entries"].slice(0,limit)
    return U.ok(result)

static func _logs_clear(manager: Node, editor_logger: Logger, args: Dictionary) -> Dictionary:
    var source := str(args.get("source","all"))
    var result := {"source":source}
    if source in ["editor","all"]:
        result["editor"] = editor_logger.clear() if editor_logger != null and editor_logger.has_method("clear") else {"cleared":0}
    if source in ["game","all"]:
        var game_response: Dictionary = await manager.request("logs_clear", {}, int(args.get("timeout_ms",3000)), int(args.get("session_id",-1)))
        result["game"] = game_response.get("result",{}) if bool(game_response.get("ok",false)) else {"unavailable":true,"error":game_response.get("error")}
    return U.ok(result)