@tool
extends RefCounted

const MAX_COLLECTION_ITEMS := 256
const MAX_ENCODE_DEPTH := 6

static func ok(result) -> Dictionary:
	return {"ok": true, "result": result}

static func error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}

static func valid_res_path(path: String, allow_root: bool = false) -> bool:
	if not path.begins_with("res://"):
		return false
	var relative := path.trim_prefix("res://").replace("\\", "/")
	for segment in relative.split("/", false):
		if segment == "..":
			return false
	return allow_root or not relative.is_empty()

static func resolve_node(plugin: EditorPlugin, path_text: String) -> Node:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	return resolve_node_from_root(root, path_text)

static func resolve_node_from_root(root: Node, path_text: String) -> Node:
	var value := path_text.strip_edges()
	if value.is_empty() or value == "." or value == root.name or value == str(root.get_path()):
		return root
	if value.begins_with("/"):
		var absolute := root.get_node_or_null(NodePath(value))
		if absolute != null:
			return absolute
	var root_prefix := root.name + "/"
	if value.begins_with(root_prefix):
		value = value.substr(root_prefix.length())
	return root.get_node_or_null(NodePath(value))

static func node_path_relative(root: Node, node: Node) -> String:
	return "." if node == root else str(root.get_path_to(node))

static func property_exists(object: Object, property_name: String) -> bool:
	for info in object.get_property_list():
		if str(info.get("name", "")) == property_name:
			return true
	return false

static func property_info(object: Object, property_name: String) -> Dictionary:
	for info in object.get_property_list():
		if str(info.get("name", "")) == property_name:
			return encode_property_info(info)
	return {}

static func encode_property_info(info: Dictionary) -> Dictionary:
	var type_id := int(info.get("type", TYPE_NIL))
	return {
		"name": str(info.get("name", "")),
		"type": type_id,
		"type_name": type_string(type_id),
		"class_name": str(info.get("class_name", "")),
		"hint": int(info.get("hint", 0)),
		"hint_string": str(info.get("hint_string", "")),
		"usage": int(info.get("usage", 0)),
	}

static func encode_method_info(info: Dictionary) -> Dictionary:
	var args: Array = []
	for arg in info.get("args", []):
		if arg is Dictionary:
			args.append(encode_property_info(arg))
	var defaults: Array = []
	for value in info.get("default_args", []):
		defaults.append(encode_value(value))
	var return_info := info.get("return", {})
	return {
		"name": str(info.get("name", "")),
		"args": args,
		"default_args": defaults,
		"flags": int(info.get("flags", 0)),
		"return": encode_property_info(return_info) if return_info is Dictionary else {},
	}

static func encode_signal_info(info: Dictionary) -> Dictionary:
	var args: Array = []
	for arg in info.get("args", []):
		if arg is Dictionary:
			args.append(encode_property_info(arg))
	return {"name": str(info.get("name", "")), "args": args}

static func encode_value(value, depth: int = 0):
	if depth > MAX_ENCODE_DEPTH:
		return {"__godot_type": "DepthLimit", "summary": str(value)}
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_VECTOR2:
			return {"__godot_type": "Vector2", "x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"__godot_type": "Vector2i", "x": value.x, "y": value.y}
		TYPE_RECT2:
			return {"__godot_type": "Rect2", "position": encode_value(value.position, depth + 1), "size": encode_value(value.size, depth + 1)}
		TYPE_RECT2I:
			return {"__godot_type": "Rect2i", "position": encode_value(value.position, depth + 1), "size": encode_value(value.size, depth + 1)}
		TYPE_VECTOR3:
			return {"__godot_type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR3I:
			return {"__godot_type": "Vector3i", "x": value.x, "y": value.y, "z": value.z}
		TYPE_TRANSFORM2D:
			return {"__godot_type": "Transform2D", "x": encode_value(value.x, depth + 1), "y": encode_value(value.y, depth + 1), "origin": encode_value(value.origin, depth + 1)}
		TYPE_VECTOR4:
			return {"__godot_type": "Vector4", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_VECTOR4I:
			return {"__godot_type": "Vector4i", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_PLANE:
			return {"__godot_type": "Plane", "normal": encode_value(value.normal, depth + 1), "d": value.d}
		TYPE_QUATERNION:
			return {"__godot_type": "Quaternion", "x": value.x, "y": value.y, "z": value.z, "w": value.w}
		TYPE_AABB:
			return {"__godot_type": "AABB", "position": encode_value(value.position, depth + 1), "size": encode_value(value.size, depth + 1)}
		TYPE_BASIS:
			return {"__godot_type": "Basis", "x": encode_value(value.x, depth + 1), "y": encode_value(value.y, depth + 1), "z": encode_value(value.z, depth + 1)}
		TYPE_TRANSFORM3D:
			return {"__godot_type": "Transform3D", "basis": encode_value(value.basis, depth + 1), "origin": encode_value(value.origin, depth + 1)}
		TYPE_PROJECTION:
			return {"__godot_type": "Projection", "x": encode_value(value.x, depth + 1), "y": encode_value(value.y, depth + 1), "z": encode_value(value.z, depth + 1), "w": encode_value(value.w, depth + 1)}
		TYPE_COLOR:
			return {"__godot_type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NODE_PATH:
			return {"__godot_type": "NodePath", "value": str(value)}
		TYPE_RID:
			return {"__godot_type": "RID", "id": value.get_id()}
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			var output: Array = []
			var count := mini(value.size(), MAX_COLLECTION_ITEMS)
			for i in count:
				output.append(encode_value(value[i], depth + 1))
			if value.size() > MAX_COLLECTION_ITEMS:
				output.append({"__truncated__": value.size() - MAX_COLLECTION_ITEMS})
			return output
		TYPE_DICTIONARY:
			var output := {}
			var count := 0
			for key in value.keys():
				if count >= MAX_COLLECTION_ITEMS:
					output["__truncated__"] = value.size() - MAX_COLLECTION_ITEMS
					break
				output[str(key)] = encode_value(value[key], depth + 1)
				count += 1
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Node:
				return {"__godot_type": "Node", "class": value.get_class(), "name": value.name, "path": str(value.get_path()), "instance_id": value.get_instance_id()}
			if value is Resource:
				return {"__godot_type": "Resource", "class": value.get_class(), "path": value.resource_path, "name": value.resource_name, "instance_id": value.get_instance_id()}
			return {"__godot_type": "Object", "class": value.get_class(), "instance_id": value.get_instance_id()}
		_:
			return {"__godot_type": type_string(typeof(value)), "value": str(value)}
	return value

static func decode_value(value):
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(decode_value(item))
		return result
	if not value is Dictionary:
		return value
	var data: Dictionary = value
	var kind := str(data.get("__godot_type", ""))
	if kind.is_empty():
		var result := {}
		for key in data.keys():
			result[key] = decode_value(data[key])
		return result
	match kind:
		"Vector2": return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		"Vector2i": return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
		"Vector3": return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
		"Vector3i": return Vector3i(int(data.get("x", 0)), int(data.get("y", 0)), int(data.get("z", 0)))
		"Vector4": return Vector4(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)), float(data.get("w", 0.0)))
		"Vector4i": return Vector4i(int(data.get("x", 0)), int(data.get("y", 0)), int(data.get("z", 0)), int(data.get("w", 0)))
		"Color": return Color(float(data.get("r", 0.0)), float(data.get("g", 0.0)), float(data.get("b", 0.0)), float(data.get("a", 1.0)))
		"NodePath": return NodePath(str(data.get("value", "")))
		"Quaternion": return Quaternion(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)), float(data.get("w", 1.0)))
		"Plane": return Plane(decode_value(data.get("normal", {})), float(data.get("d", 0.0)))
		"AABB": return AABB(decode_value(data.get("position", {})), decode_value(data.get("size", {})))
		"Rect2": return Rect2(decode_value(data.get("position", {})), decode_value(data.get("size", {})))
		"Rect2i": return Rect2i(decode_value(data.get("position", {})), decode_value(data.get("size", {})))
		"Basis": return Basis(decode_value(data.get("x", {})), decode_value(data.get("y", {})), decode_value(data.get("z", {})))
		"Transform3D": return Transform3D(decode_value(data.get("basis", {})), decode_value(data.get("origin", {})))
		"Transform2D": return Transform2D(decode_value(data.get("x", {})), decode_value(data.get("y", {})), decode_value(data.get("origin", {})))
		"Resource":
			var path := str(data.get("path", ""))
			return ResourceLoader.load(path) if valid_res_path(path) else null
		_:
			return value

static func mark_unsaved(plugin: EditorPlugin) -> void:
	var editor := plugin.get_editor_interface()
	if editor.has_method("mark_scene_as_unsaved"):
		editor.mark_scene_as_unsaved()

static func object_summary(object: Object) -> Dictionary:
	if object == null:
		return {}
	var result := {"class": object.get_class(), "instance_id": object.get_instance_id()}
	if object is Resource:
		result["resource_path"] = object.resource_path
		result["resource_name"] = object.resource_name
	if object is Node:
		result["name"] = object.name
		result["path"] = str(object.get_path()) if object.is_inside_tree() else ""
		if not object.scene_file_path.is_empty():
			result["scene_file_path"] = object.scene_file_path
	return result