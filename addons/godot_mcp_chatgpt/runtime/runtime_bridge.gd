extends Node

const PREFIX := "godot_mcp"
const MAX_ITEMS := 256
const MAX_DEPTH := 8

func _ready() -> void:
    if EngineDebugger.is_active():
        EngineDebugger.register_message_capture(PREFIX, Callable(self, "_capture_debugger_message"))
        EngineDebugger.send_message(PREFIX + ":ready", [{"scene":_current_scene_path(),"pid":OS.get_process_id()}])

func _exit_tree() -> void:
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
    var response := _dispatch(command, arguments)
    response["request_id"] = request_id
    EngineDebugger.send_message(PREFIX + ":response", [response])
    return true

func _dispatch(command: String, args: Dictionary) -> Dictionary:
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