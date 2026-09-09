extends Node

const PREFIX := "godot_mcp"
const MAX_ITEMS := 256
const MAX_DEPTH := 8
const MAX_SEQUENCE_STEPS := 128
const MAX_SEQUENCE_FRAMES := 600
const ImageUtils := preload("res://addons/godot_mcp_chatgpt/core/image_utils.gd")
const LogCapture := preload("res://addons/godot_mcp_chatgpt/debug/log_capture.gd")

var _game_logger: Logger
var _run_id := ""
var _process_ticks := 0
var _sequence_state: Dictionary = {}
var _held_actions: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _run_id = "%s-%s" % [Time.get_unix_time_from_system(), OS.get_process_id()]
    _game_logger = LogCapture.new()
    OS.add_logger(_game_logger)
    if EngineDebugger.is_active():
        EngineDebugger.register_message_capture(PREFIX, Callable(self, "_capture_debugger_message"))
        EngineDebugger.send_message(PREFIX + ":ready", [{"scene":_current_scene_path(),"pid":OS.get_process_id()}])

func _process(_delta: float) -> void:
    _process_ticks += 1
    if not _sequence_state.is_empty():
        _advance_input_sequence()

func _exit_tree() -> void:
    if _game_logger != null:
        OS.remove_logger(_game_logger)
        _game_logger = null
    if EngineDebugger.is_active() and EngineDebugger.has_capture(PREFIX):
        EngineDebugger.unregister_message_capture(PREFIX)

func _capture_debugger_message(message: String, data: Array) -> bool:
    var action := message
    if action.begins_with(PREFIX + ":"):
        action = action.substr(PREFIX.length() + 1)
    if action != "request":
        return false
    if data.is_empty() or not data[0] is Dictionary:
        return true
    var request: Dictionary = data[0]
    var request_id := str(request.get("request_id", ""))
    var command := str(request.get("command", ""))
    var arguments_value = request.get("arguments", {})
    var arguments: Dictionary = arguments_value if arguments_value is Dictionary else {}
    var response := _dispatch(command, arguments, request_id)
    if bool(response.get("__deferred", false)):
        return true
    response["request_id"] = request_id
    EngineDebugger.send_message(PREFIX + ":response", [response])
    return true

func _dispatch(command: String, args: Dictionary, request_id: String = "") -> Dictionary:
    match command:
        "status":
            return _ok(_status())
        "get_tree":
            return _get_tree(args)
        "inspect":
            return _inspect(args)
        "find":
            return _find(args)
        "get_property":
            return _get_property(args)
        "set_property":
            return _set_property(args)
        "call_method":
            return _call_method(args)
        "get_groups":
            return _get_groups(args)
        "performance":
            return _ok(_performance())
        "screenshot":
            return _runtime_screenshot(args)
        "ui_elements":
            return _runtime_ui_elements(args)
        "input_action":
            return _input_action(args)
        "input_key":
            return _input_key(args)
        "input_mouse":
            return _input_mouse(args)
        "input_gamepad":
            return _input_gamepad(args)
        "input_state":
            return _input_state(args)
        "input_sequence":
            return _start_input_sequence(args, request_id)
        "logs_read":
            return _runtime_logs_read(args)
        "logs_clear":
            return _runtime_logs_clear()
        "debug_status":
            return _ok(_debug_status())
        "evaluate":
            return _runtime_evaluate(args)
        "pause":
            get_tree().paused = true
            return _ok({"paused":true})
        "resume":
            get_tree().paused = false
            return _ok({"paused":false})
        _:
            return _error("RUNTIME_COMMAND_NOT_FOUND", "Unknown runtime command: " + command)

func _status() -> Dictionary:
    var scene := get_tree().current_scene
    return {
        "pid": OS.get_process_id(),
        "paused": get_tree().paused,
        "current_scene": _current_scene_path(),
        "root_name": str(scene.name) if scene != null else "",
        "node_count": _count_nodes(scene) if scene != null else 0,
        "fps": Performance.get_monitor(Performance.TIME_FPS),
        "engine_version": Engine.get_version_info(),
        "run_id": _run_id,
        "process_ticks": _process_ticks,
        "debugger_suspended": is_inside_tree() and not can_process(),
    }

func _get_tree(args: Dictionary) -> Dictionary:
    var root := get_tree().current_scene
    if root == null:
        return _error("RUNTIME_NO_SCENE", "Runtime has no current scene")
    var max_depth := clampi(int(args.get("max_depth", 6)), 0, MAX_DEPTH)
    var include_properties := bool(args.get("include_properties", false))
    return _ok({"scene":_current_scene_path(),"root":_serialize_node(root,root,0,max_depth,include_properties)})

func _inspect(args: Dictionary) -> Dictionary:
    var node := _resolve_node(str(args.get("node_path", ".")))
    if node == null:
        return _error("RUNTIME_NODE_NOT_FOUND", "Runtime node not found")
    var mode := str(args.get("property_mode", "storage"))
    var limit := clampi(int(args.get("limit", 160)), 1, 1000)
    var properties: Array = []
    for info_value in node.get_property_list():
        if not info_value is Dictionary:
            continue
        var info: Dictionary = info_value
        var usage := int(info.get("usage", 0))
        if mode == "storage" and (usage & PROPERTY_USAGE_STORAGE) == 0:
            continue
        if mode == "editor" and (usage & PROPERTY_USAGE_EDITOR) == 0:
            continue
        var name := str(info.get("name", ""))
        properties.append({"name":name,"type":int(info.get("type",TYPE_NIL)),"type_name":type_string(int(info.get("type",TYPE_NIL))),"value":_encode(node.get(name))})
        if properties.size() >= limit:
            break
    var script := node.get_script() as Script
    return _ok({
        "node": _node_summary(node),
        "groups": Array(node.get_groups()),
        "script": script.resource_path if script != null else "",
        "properties": properties,
        "child_count": node.get_child_count(),
    })

func _find(args: Dictionary) -> Dictionary:
    var root := get_tree().current_scene
    if root == null:
        return _error("RUNTIME_NO_SCENE", "Runtime has no current scene")
    var name_contains := str(args.get("name_contains", "")).to_lower()
    var class_filter := str(args.get("class", ""))
    var group := str(args.get("group", ""))
    var limit := clampi(int(args.get("limit", 200)), 1, 1000)
    var result: Array = []
    _find_recursive(root, root, name_contains, class_filter, group, result, limit)
    return _ok({"nodes":result,"count":result.size(),"truncated":result.size()>=limit})

func _find_recursive(node: Node, root: Node, name_contains: String, class_filter: String, group: String, out: Array, limit: int) -> void:
    if out.size() >= limit:
        return
    var matched := name_contains.is_empty() or str(node.name).to_lower().contains(name_contains)
    matched = matched and (class_filter.is_empty() or node.is_class(class_filter))
    matched = matched and (group.is_empty() or node.is_in_group(group))
    if matched:
        out.append(_node_summary_relative(root,node))
    for child_value in node.get_children():
        var child := child_value as Node
        if child != null:
            _find_recursive(child,root,name_contains,class_filter,group,out,limit)
            if out.size() >= limit:
                return

func _get_property(args: Dictionary) -> Dictionary:
    var node := _resolve_node(str(args.get("node_path", ".")))
    if node == null:
        return _error("RUNTIME_NODE_NOT_FOUND", "Runtime node not found")
    var property_name := str(args.get("property", ""))
    if not _has_property(node, property_name):
        return _error("RUNTIME_PROPERTY_NOT_FOUND", "Property not found: " + property_name)
    return _ok({"node":_node_summary(node),"property":property_name,"value":_encode(node.get(property_name))})

func _set_property(args: Dictionary) -> Dictionary:
    var node := _resolve_node(str(args.get("node_path", ".")))
    if node == null:
        return _error("RUNTIME_NODE_NOT_FOUND", "Runtime node not found")
    var property_name := str(args.get("property", ""))
    if not _has_property(node, property_name):
        return _error("RUNTIME_PROPERTY_NOT_FOUND", "Property not found: " + property_name)
    node.set(property_name, _decode(args.get("value")))
    return _ok({"node":_node_summary(node),"property":property_name,"value":_encode(node.get(property_name))})

func _call_method(args: Dictionary) -> Dictionary:
    var node := _resolve_node(str(args.get("node_path", ".")))
    if node == null:
        return _error("RUNTIME_NODE_NOT_FOUND", "Runtime node not found")
    var method := str(args.get("method", ""))
    if not node.has_method(method):
        return _error("RUNTIME_METHOD_NOT_FOUND", "Method not found: " + method)
    var call_args: Array = []
    for value in args.get("arguments", []):
        call_args.append(_decode(value))
    var result = node.callv(method, call_args)
    return _ok({"node":_node_summary(node),"method":method,"result":_encode(result)})

func _get_groups(args: Dictionary) -> Dictionary:
    var node := _resolve_node(str(args.get("node_path", ".")))
    if node == null:
        return _error("RUNTIME_NODE_NOT_FOUND", "Runtime node not found")
    return _ok({"node":_node_summary(node),"groups":Array(node.get_groups())})

func _performance() -> Dictionary:
    return {
        "fps": Performance.get_monitor(Performance.TIME_FPS),
        "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "physics_process_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
        "memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
        "memory_static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
        "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
        "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
        "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
        "orphan_nodes": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
    }

func _runtime_screenshot(args: Dictionary) -> Dictionary:
    var viewport := get_viewport()
    if viewport == null:
        return _error("RUNTIME_VIEWPORT_UNAVAILABLE", "Runtime viewport is unavailable")
    RenderingServer.force_draw(false)
    var image := viewport.get_texture().get_image()
    var encoded := ImageUtils.encode_png(image, int(args.get("max_resolution", 1280)))
    if not bool(encoded.get("ok", false)):
        return encoded
    return _ok({
        "source": "game",
        "width": encoded.get("width", 0),
        "height": encoded.get("height", 0),
        "original_width": encoded.get("original_width", 0),
        "original_height": encoded.get("original_height", 0),
        "bytes": encoded.get("bytes", 0),
        "__mcp_image": {"data": encoded.get("data", ""), "mime_type": encoded.get("mime_type", "image/png")},
    })

func _runtime_ui_elements(args: Dictionary) -> Dictionary:
    var root := get_tree().current_scene
    if root == null:
        return _error("RUNTIME_NO_SCENE", "Runtime has no current scene")
    var limit := clampi(int(args.get("limit", 200)), 1, 500)
    var include_hidden := bool(args.get("include_hidden", false))
    var items: Array = []
    _collect_runtime_controls(root, root, items, limit, include_hidden)
    return _ok({"elements": items, "count": items.size(), "truncated": items.size() >= limit})

func _collect_runtime_controls(node: Node, root: Node, out: Array, limit: int, include_hidden: bool) -> void:
    if out.size() >= limit:
        return
    if node is Control:
        var control := node as Control
        if include_hidden or control.is_visible_in_tree():
            var item := {
                "path": "." if node == root else str(root.get_path_to(node)),
                "name": str(node.name),
                "class": node.get_class(),
                "visible": control.visible,
                "position": _encode(control.position),
                "size": _encode(control.size),
                "focus_mode": int(control.focus_mode),
            }
            if _has_property(control, "text"):
                item["text"] = str(control.get("text"))
            if _has_property(control, "disabled"):
                item["disabled"] = bool(control.get("disabled"))
            out.append(item)
    for child_value in node.get_children():
        var child := child_value as Node
        if child != null:
            _collect_runtime_controls(child, root, out, limit, include_hidden)
            if out.size() >= limit:
                return

func _input_action(args: Dictionary) -> Dictionary:
    var action := StringName(str(args.get("action", "")))
    if str(action).is_empty():
        return _error("ACTION_REQUIRED", "action is required")
    var pressed := bool(args.get("pressed", true))
    var strength := clampf(float(args.get("strength", 1.0)), 0.0, 1.0)
    if pressed:
        Input.action_press(action, strength)
        _held_actions[str(action)] = true
    else:
        Input.action_release(action)
        _held_actions.erase(str(action))
    return _ok({"action": str(action), "pressed": Input.is_action_pressed(action), "strength": Input.get_action_strength(action)})

func _input_key(args: Dictionary) -> Dictionary:
    var event := InputEventKey.new()
    event.keycode = int(args.get("keycode", 0)) as Key
    event.physical_keycode = int(args.get("physical_keycode", 0)) as Key
    event.pressed = bool(args.get("pressed", true))
    event.echo = bool(args.get("echo", false))
    event.ctrl_pressed = bool(args.get("ctrl", false))
    event.alt_pressed = bool(args.get("alt", false))
    event.shift_pressed = bool(args.get("shift", false))
    event.meta_pressed = bool(args.get("meta", false))
    Input.parse_input_event(event)
    return _ok({"pressed": event.pressed, "keycode": int(event.keycode), "physical_keycode": int(event.physical_keycode)})

func _input_mouse(args: Dictionary) -> Dictionary:
    var kind := str(args.get("kind", "button"))
    if kind == "motion":
        var motion := InputEventMouseMotion.new()
        motion.position = Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0)))
        motion.relative = Vector2(float(args.get("dx", 0.0)), float(args.get("dy", 0.0)))
        motion.velocity = Vector2(float(args.get("vx", 0.0)), float(args.get("vy", 0.0)))
        Input.parse_input_event(motion)
        return _ok({"kind": "motion", "position": _encode(motion.position), "relative": _encode(motion.relative)})
    var button := InputEventMouseButton.new()
    button.button_index = int(args.get("button", MOUSE_BUTTON_LEFT)) as MouseButton
    button.pressed = bool(args.get("pressed", true))
    button.position = Vector2(float(args.get("x", 0.0)), float(args.get("y", 0.0)))
    button.factor = float(args.get("factor", 1.0))
    Input.parse_input_event(button)
    return _ok({"kind": "button", "button": int(button.button_index), "pressed": button.pressed, "position": _encode(button.position)})

func _input_gamepad(args: Dictionary) -> Dictionary:
    var kind := str(args.get("kind", "button"))
    var device := int(args.get("device", 0))
    if kind == "axis":
        var axis := InputEventJoypadMotion.new()
        axis.device = device
        axis.axis = int(args.get("axis", 0)) as JoyAxis
        axis.axis_value = clampf(float(args.get("value", 0.0)), -1.0, 1.0)
        Input.parse_input_event(axis)
        return _ok({"kind": "axis", "device": device, "axis": int(axis.axis), "value": axis.axis_value})
    var button := InputEventJoypadButton.new()
    button.device = device
    button.button_index = int(args.get("button", 0)) as JoyButton
    button.pressed = bool(args.get("pressed", true))
    button.pressure = clampf(float(args.get("pressure", 1.0)), 0.0, 1.0)
    Input.parse_input_event(button)
    return _ok({"kind": "button", "device": device, "button": int(button.button_index), "pressed": button.pressed})

func _input_state(args: Dictionary) -> Dictionary:
    var requested: Array = args.get("actions", [])
    var actions: Array = []
    if requested.is_empty():
        for action_value in InputMap.get_actions():
            actions.append(str(action_value))
            if actions.size() >= 128:
                break
    else:
        for value in requested:
            actions.append(str(value))
            if actions.size() >= 128:
                break
    var state := {}
    for action in actions:
        var key := StringName(action)
        state[action] = {"pressed": Input.is_action_pressed(key), "strength": Input.get_action_strength(key), "raw_strength": Input.get_action_raw_strength(key)}
    return _ok({"actions": state, "mouse_position": _encode(get_viewport().get_mouse_position())})

func _start_input_sequence(args: Dictionary, request_id: String) -> Dictionary:
    if request_id.is_empty():
        return _error("REQUEST_ID_REQUIRED", "input_sequence requires a debugger request id")
    if not _sequence_state.is_empty():
        return _error("INPUT_SEQUENCE_BUSY", "Another input sequence is already running")
    var steps_value = args.get("steps", [])
    if not steps_value is Array or steps_value.is_empty():
        return _error("SEQUENCE_STEPS_REQUIRED", "steps must contain at least one input step")
    if steps_value.size() > MAX_SEQUENCE_STEPS:
        return _error("INPUT_SEQUENCE_TOO_LARGE", "steps is limited to %d" % MAX_SEQUENCE_STEPS)
    var steps: Array = []
    var max_frame := 0
    for raw in steps_value:
        if not raw is Dictionary:
            return _error("INVALID_SEQUENCE_STEP", "Each sequence step must be an object")
        var step: Dictionary = raw.duplicate(true)
        var frame := int(step.get("at_frame", 0))
        if frame < 0 or frame > MAX_SEQUENCE_FRAMES:
            return _error("INVALID_SEQUENCE_FRAME", "at_frame must be between 0 and %d" % MAX_SEQUENCE_FRAMES)
        step["at_frame"] = frame
        max_frame = maxi(max_frame, frame)
        steps.append(step)
    steps.sort_custom(func(a, b): return int(a.get("at_frame", 0)) < int(b.get("at_frame", 0)))
    _sequence_state = {"request_id": request_id, "frame": 0, "index": 0, "steps": steps, "max_frame": max_frame, "release_actions": bool(args.get("release_actions", true)), "started_ticks": Time.get_ticks_msec()}
    return {"__deferred": true}

func _advance_input_sequence() -> void:
    var frame := int(_sequence_state.get("frame", 0))
    var index := int(_sequence_state.get("index", 0))
    var steps: Array = _sequence_state.get("steps", [])
    while index < steps.size() and int(steps[index].get("at_frame", 0)) <= frame:
        var step: Dictionary = steps[index]
        var event_value = step.get("event", {})
        var outcome := _apply_sequence_event(event_value if event_value is Dictionary else {})
        if not bool(outcome.get("ok", false)):
            _finish_input_sequence(outcome)
            return
        index += 1
    _sequence_state["index"] = index
    if frame >= int(_sequence_state.get("max_frame", 0)) and index >= steps.size():
        if bool(_sequence_state.get("release_actions", true)):
            _release_held_actions()
        _finish_input_sequence(_ok({"completed": true, "frames": frame + 1, "steps": steps.size(), "duration_ms": Time.get_ticks_msec() - int(_sequence_state.get("started_ticks", Time.get_ticks_msec()))}))
        return
    _sequence_state["frame"] = frame + 1

func _apply_sequence_event(event: Dictionary) -> Dictionary:
    match str(event.get("type", "action")):
        "action": return _input_action(event)
        "key": return _input_key(event)
        "mouse", "mouse_button", "mouse_motion": return _input_mouse(event)
        "gamepad", "gamepad_button", "gamepad_axis": return _input_gamepad(event)
        _: return _error("INVALID_SEQUENCE_EVENT", "Unsupported sequence event type: " + str(event.get("type", "")))

func _release_held_actions() -> void:
    for action in _held_actions.keys():
        Input.action_release(StringName(str(action)))
    _held_actions.clear()

func _finish_input_sequence(response: Dictionary) -> void:
    var request_id := str(_sequence_state.get("request_id", ""))
    _sequence_state.clear()
    if request_id.is_empty() or not EngineDebugger.is_active():
        return
    var payload := response.duplicate(true)
    payload["request_id"] = request_id
    EngineDebugger.send_message(PREFIX + ":response", [payload])

func _runtime_logs_read(args: Dictionary) -> Dictionary:
    if _game_logger == null or not _game_logger.has_method("read_since"):
        return _ok({"source": "game", "run_id": _run_id, "entries": [], "cursor": 0, "available": 0})
    var result: Dictionary = _game_logger.read_since(int(args.get("cursor", 0)), int(args.get("limit", 200)), str(args.get("level", "")))
    result["source"] = "game"
    result["run_id"] = _run_id
    return _ok(result)

func _runtime_logs_clear() -> Dictionary:
    var result := {"cleared": 0, "cursor": 0}
    if _game_logger != null and _game_logger.has_method("clear"):
        result = _game_logger.clear()
    result["source"] = "game"
    result["run_id"] = _run_id
    return _ok(result)

func _runtime_evaluate(args: Dictionary) -> Dictionary:
    var expression_text := str(args.get("expression", "")).strip_edges()
    if expression_text.is_empty():
        return _error("EXPRESSION_REQUIRED", "expression is required")
    if expression_text.length() > 4096:
        return _error("EXPRESSION_TOO_LARGE", "expression is limited to 4096 characters")
    var node := _resolve_node(str(args.get("node_path", ".")))
    if node == null:
        return _error("RUNTIME_NODE_NOT_FOUND", "Runtime evaluation base node was not found")
    var names: PackedStringArray = []
    var values: Array = []
    var variables_value = args.get("variables", {})
    if variables_value is Dictionary:
        if variables_value.size() > 32:
            return _error("TOO_MANY_VARIABLES", "runtime.evaluate supports at most 32 variables")
        for key in variables_value.keys():
            names.append(str(key))
            values.append(_decode(variables_value[key]))
    var expression := Expression.new()
    var parse_error := expression.parse(expression_text, names)
    if parse_error != OK:
        return _error("EXPRESSION_PARSE_FAILED", expression.get_error_text())
    var value = expression.execute(values, node, false)
    if expression.has_execute_failed():
        return _error("EXPRESSION_EXECUTE_FAILED", expression.get_error_text())
    return _ok({"node": _node_summary(node), "expression": expression_text, "value": _encode(value)})

func _debug_status() -> Dictionary:
    return {
        "suspended": is_inside_tree() and not can_process(),
        "tree_paused": get_tree().paused,
        "process_ticks": _process_ticks,
        "process_frames": Engine.get_process_frames(),
        "physics_frames": Engine.get_physics_frames(),
        "frames_drawn": Engine.get_frames_drawn(),
        "time_scale": Engine.time_scale,
        "run_id": _run_id,
    }

func _serialize_node(node: Node, root: Node, depth: int, max_depth: int, include_properties: bool) -> Dictionary:
    var item := _node_summary_relative(root,node)
    item["groups"] = Array(node.get_groups())
    var script := node.get_script() as Script
    item["script"] = script.resource_path if script != null else ""
    if include_properties:
        var props := {}
        for info_value in node.get_property_list():
            if not info_value is Dictionary:
                continue
            var info: Dictionary = info_value
            if (int(info.get("usage",0)) & PROPERTY_USAGE_STORAGE) == 0:
                continue
            var name := str(info.get("name",""))
            props[name] = _encode(node.get(name))
            if props.size() >= 80:
                break
        item["properties"] = props
    var children: Array = []
    if depth < max_depth:
        for child_value in node.get_children():
            var child := child_value as Node
            if child != null:
                children.append(_serialize_node(child,root,depth+1,max_depth,include_properties))
                if children.size() >= MAX_ITEMS:
                    break
    item["children"] = children
    return item

func _resolve_node(path_text: String) -> Node:
    var root := get_tree().current_scene
    if root == null:
        return null
    var value := path_text.strip_edges()
    if value.is_empty() or value == "." or value == root.name or value == str(root.get_path()):
        return root
    if value.begins_with("/"):
        return get_tree().root.get_node_or_null(NodePath(value))
    if value.begins_with(root.name + "/"):
        value = value.substr(root.name.length()+1)
    return root.get_node_or_null(NodePath(value))

func _node_summary(node: Node) -> Dictionary:
    return {"name":str(node.name),"class":node.get_class(),"path":str(node.get_path()),"instance_id":node.get_instance_id()}

func _node_summary_relative(root: Node, node: Node) -> Dictionary:
    return {"name":str(node.name),"class":node.get_class(),"path":"." if node==root else str(root.get_path_to(node)),"instance_id":node.get_instance_id()}

func _current_scene_path() -> String:
    var scene := get_tree().current_scene
    return scene.scene_file_path if scene != null else ""

func _count_nodes(root: Node) -> int:
    if root == null:
        return 0
    var count := 1
    for child_value in root.get_children():
        var child := child_value as Node
        if child != null:
            count += _count_nodes(child)
    return count

func _has_property(object: Object, property_name: String) -> bool:
    for info_value in object.get_property_list():
        if info_value is Dictionary and str(info_value.get("name","")) == property_name:
            return true
    return false

func _encode(value, depth: int = 0):
    if depth > 5:
        return str(value)
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
            return value
        TYPE_STRING_NAME:
            return str(value)
        TYPE_VECTOR2:
            return {"__godot_type":"Vector2","x":value.x,"y":value.y}
        TYPE_VECTOR2I:
            return {"__godot_type":"Vector2i","x":value.x,"y":value.y}
        TYPE_VECTOR3:
            return {"__godot_type":"Vector3","x":value.x,"y":value.y,"z":value.z}
        TYPE_VECTOR3I:
            return {"__godot_type":"Vector3i","x":value.x,"y":value.y,"z":value.z}
        TYPE_VECTOR4:
            return {"__godot_type":"Vector4","x":value.x,"y":value.y,"z":value.z,"w":value.w}
        TYPE_VECTOR4I:
            return {"__godot_type":"Vector4i","x":value.x,"y":value.y,"z":value.z,"w":value.w}
        TYPE_COLOR:
            return {"__godot_type":"Color","r":value.r,"g":value.g,"b":value.b,"a":value.a}
        TYPE_NODE_PATH:
            return {"__godot_type":"NodePath","value":str(value)}
        TYPE_ARRAY:
            var arr: Array = []
            for i in mini(value.size(),MAX_ITEMS):
                arr.append(_encode(value[i],depth+1))
            return arr
        TYPE_DICTIONARY:
            var out := {}
            var count := 0
            for key in value.keys():
                if count >= MAX_ITEMS:
                    break
                out[str(key)] = _encode(value[key],depth+1)
                count += 1
            return out
        TYPE_OBJECT:
            if value == null:
                return null
            if value is Node:
                return _node_summary(value)
            if value is Resource:
                return {"__godot_type":"Resource","class":value.get_class(),"path":value.resource_path,"name":value.resource_name}
            return {"__godot_type":"Object","class":value.get_class(),"instance_id":value.get_instance_id()}
        _:
            return {"__godot_type":type_string(typeof(value)),"value":str(value)}

func _decode(value):
    if value is Array:
        var arr: Array = []
        for item in value:
            arr.append(_decode(item))
        return arr
    if not value is Dictionary:
        return value
    var data: Dictionary = value
    var kind := str(data.get("__godot_type", ""))
    match kind:
        "Vector2": return Vector2(float(data.get("x",0.0)),float(data.get("y",0.0)))
        "Vector2i": return Vector2i(int(data.get("x",0)),int(data.get("y",0)))
        "Vector3": return Vector3(float(data.get("x",0.0)),float(data.get("y",0.0)),float(data.get("z",0.0)))
        "Vector3i": return Vector3i(int(data.get("x",0)),int(data.get("y",0)),int(data.get("z",0)))
        "Vector4": return Vector4(float(data.get("x",0.0)),float(data.get("y",0.0)),float(data.get("z",0.0)),float(data.get("w",0.0)))
        "Vector4i": return Vector4i(int(data.get("x",0)),int(data.get("y",0)),int(data.get("z",0)),int(data.get("w",0)))
        "Color": return Color(float(data.get("r",0.0)),float(data.get("g",0.0)),float(data.get("b",0.0)),float(data.get("a",1.0)))
        "NodePath": return NodePath(str(data.get("value","")))
        "Resource":
            var path := str(data.get("path",""))
            return ResourceLoader.load(path) if path.begins_with("res://") else null
        "":
            var out := {}
            for key in data.keys():
                out[key] = _decode(data[key])
            return out
        _:
            return value

func _ok(result) -> Dictionary:
    return {"ok":true,"result":result}

func _error(code: String, message: String) -> Dictionary:
    return {"ok":false,"error":{"code":code,"message":message}}