@tool
extends RefCounted

const U = preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
	registry.add_command(
		"godot.get_status",
		"Return the connected Godot editor status and version.",
		{"type": "object", "properties": {}, "additionalProperties": false},
		func(_args: Dictionary) -> Dictionary:
			return _ok({
				"godot_version": Engine.get_version_info().get("string", "unknown"),
				"editor": Engine.is_editor_hint(),
				"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
			}),
		{"readOnlyHint": true, "destructiveHint": false}
	)

	registry.add_command(
		"project.get_info",
		"Return basic information about the currently open Godot project.",
		{"type": "object", "properties": {}, "additionalProperties": false},
		func(_args: Dictionary) -> Dictionary:
			var root := plugin.get_editor_interface().get_edited_scene_root()
			return _ok({
				"name": str(ProjectSettings.get_setting("application/config/name", "")),
				"project_file": ProjectSettings.globalize_path("res://project.godot"),
				"edited_scene": root.scene_file_path if root != null else "",
			}),
		{"readOnlyHint": true, "destructiveHint": false}
	)

	registry.add_command(
		"scene.get_tree",
		"Return the edited scene tree with node names and classes.",
		{
			"type": "object",
			"properties": {"max_depth": {"type": "integer", "minimum": 0, "maximum": 32}},
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _scene_get_tree(plugin, args),
		{"readOnlyHint": true, "destructiveHint": false}
	)

	registry.add_command(
		"scene.create",
		"Create a new .tscn scene, save it under res://, and open it in the editor.",
		{
			"type": "object",
			"properties": {
				"path": {"type": "string"},
				"root_type": {"type": "string"},
				"root_name": {"type": "string"},
				"overwrite": {"type": "boolean"},
			},
			"required": ["path"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return await _scene_create(plugin, args),
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false}
	)

	registry.add_command(
		"scene.save",
		"Save the currently edited scene. Optionally save to a new res:// .tscn path.",
		{
			"type": "object",
			"properties": {"path": {"type": "string"}},
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _scene_save(plugin, args),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true}
	)

	registry.add_command(
		"node.create",
		"Create a Godot node under a parent in the currently edited scene.",
		{
			"type": "object",
			"properties": {
				"parent_path": {"type": "string", "description": "Path relative to the edited-scene root. Use . for the scene root; do not use the root node name."},
				"type": {"type": "string", "description": "Instantiable Godot Node class name, for example CharacterBody3D."},
				"name": {"type": "string", "description": "Optional node name."},
			},
			"required": ["type"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _node_create(plugin, args),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false}
	)

	registry.add_command(
		"node.set_property",
		"Set a property on a node in the currently edited scene.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"property": {"type": "string"},
				"value": {},
			},
			"required": ["node_path", "property", "value"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _node_set_property(plugin, args),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true}
	)

	registry.add_command(
		"node.delete",
		"Delete a non-root node from the currently edited scene.",
		{
			"type": "object",
			"properties": {"node_path": {"type": "string"}},
			"required": ["node_path"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _node_delete(plugin, args),
		{"readOnlyHint": false, "destructiveHint": true, "idempotentHint": false}
	)

	registry.add_command(
		"script.read",
		"Read a UTF-8 script or text file inside res://.",
		{
			"type": "object",
			"properties": {"path": {"type": "string"}},
			"required": ["path"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _script_read(args),
		{"readOnlyHint": true, "destructiveHint": false}
	)

	registry.add_command(
		"script.write",
		"Write UTF-8 GDScript or text content to a file inside res://.",
		{
			"type": "object",
			"properties": {
				"path": {"type": "string"},
				"content": {"type": "string"},
			},
			"required": ["path", "content"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _script_write(plugin, args),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true}
	)

	registry.add_command(
		"script.attach",
		"Attach a res:// GDScript resource to a node in the edited scene.",
		{
			"type": "object",
			"properties": {
				"node_path": {"type": "string"},
				"script_path": {"type": "string"},
			},
			"required": ["node_path", "script_path"],
			"additionalProperties": false,
		},
		func(args: Dictionary) -> Dictionary:
			return _script_attach(plugin, args),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true}
	)

	registry.add_command(
		"editor.run_project",
		"Run the project's main scene from the Godot editor.",
		{"type": "object", "properties": {}, "additionalProperties": false},
		func(_args: Dictionary) -> Dictionary:
			var editor := plugin.get_editor_interface()
			if editor.has_method("play_main_scene"):
				editor.call("play_main_scene")
				return _ok({"started": true})
			return _error("UNSUPPORTED", "EditorInterface.play_main_scene is unavailable"),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": false}
	)

	registry.add_command(
		"editor.stop",
		"Stop the currently running project or scene.",
		{"type": "object", "properties": {}, "additionalProperties": false},
		func(_args: Dictionary) -> Dictionary:
			var editor := plugin.get_editor_interface()
			if editor.has_method("stop_playing"):
				editor.call("stop_playing")
				return _ok({"stopped": true})
			return _error("UNSUPPORTED", "EditorInterface.stop_playing is unavailable"),
		{"readOnlyHint": false, "destructiveHint": false, "idempotentHint": true}
	)


static func _scene_get_tree(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return _error("NO_SCENE", "No scene is currently open")
	var max_depth := clampi(int(args.get("max_depth", 8)), 0, 32)
	return _ok({
		"scene_file": root.scene_file_path,
		"root": _serialize_node(root, root, 0, max_depth),
	})


static func _scene_create(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var path := str(args.get("path", "")).strip_edges()
	if not _valid_res_path(path) or not path.ends_with(".tscn"):
		return _error("INVALID_PATH", "Scene path must be a res:// .tscn path without '..'")
	var overwrite := bool(args.get("overwrite", false))
	if ResourceLoader.exists(path) and not overwrite:
		return _error("FILE_EXISTS", "Scene already exists; pass overwrite=true to replace it: %s" % path)
	if overwrite:
		var close_result := await _close_scene_if_open(plugin, path)
		if not bool(close_result.get("ok", false)):
			return close_result
	var root_type := str(args.get("root_type", "Node3D")).strip_edges()
	if root_type.is_empty():
		root_type = "Node3D"
	var instance = ClassDB.instantiate(root_type)
	if not instance is Node:
		if instance is Object:
			instance.free()
		return _error("INVALID_NODE_TYPE", "Class is not an instantiable Node: %s" % root_type)
	var root: Node = instance
	root.name = str(args.get("root_name", "Main")).strip_edges()
	if root.name.is_empty():
		root.name = "Main"
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		root.free()
		return _error("PACK_FAILED", "Unable to pack scene: %s" % error_string(pack_err))
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		root.free()
		return _error("DIRECTORY_FAILED", "Unable to create scene directory: %s" % error_string(dir_err))
	var save_err := ResourceSaver.save(packed, path)
	root.free()
	if save_err != OK:
		return _error("SAVE_FAILED", "Unable to save scene: %s" % error_string(save_err))
	plugin.get_editor_interface().open_scene_from_path.call_deferred(path)
	await plugin.get_tree().process_frame
	return _ok({"path": path, "root_type": root_type, "overwritten": overwrite})


static func _close_scene_if_open(plugin: EditorPlugin, path: String) -> Dictionary:
	var editor := plugin.get_editor_interface()
	if not editor.get_open_scenes().has(path):
		return _ok({"closed": false})
	if not editor.has_method("close_scene"):
		return _error("UNSUPPORTED", "Godot editor cannot close an already-open scene on this version")
	var current := editor.get_edited_scene_root()
	if current == null or current.scene_file_path != path:
		editor.open_scene_from_path.call_deferred(path)
		await plugin.get_tree().process_frame
	editor.call_deferred("close_scene")
	await plugin.get_tree().process_frame
	return _ok({"closed": true})


static func _scene_save(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return _error("NO_SCENE", "No scene is currently open")
	var path := str(args.get("path", root.scene_file_path)).strip_edges()
	if path.is_empty():
		return _error("PATH_REQUIRED", "Current scene has no path; provide res://...tscn")
	if not _valid_res_path(path) or not path.ends_with(".tscn"):
		return _error("INVALID_PATH", "Scene path must be a res:// .tscn path without '..'")
	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		return _error("PACK_FAILED", "Unable to pack scene: %s" % error_string(pack_err))
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return _error("DIRECTORY_FAILED", "Unable to create scene directory: %s" % error_string(dir_err))
	var save_err := ResourceSaver.save(packed, path)
	if save_err != OK:
		return _error("SAVE_FAILED", "Unable to save scene: %s" % error_string(save_err))
	return _ok({"path": path})


static func _node_create(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return _error("NO_SCENE", "No scene is currently open")
	var parent_path := str(args.get("parent_path", "."))
	var parent := _resolve_node(root, parent_path)
	if parent == null:
		return _error("NODE_NOT_FOUND", "Parent node not found: %s" % parent_path)
	var type_name := str(args.get("type", "")).strip_edges()
	var instance = ClassDB.instantiate(type_name)
	if not instance is Node:
		if instance is Object: instance.free()
		return _error("INVALID_NODE_TYPE", "Class is not an instantiable Node: %s" % type_name)
	var node: Node = instance
	var requested_name := str(args.get("name", "")).strip_edges()
	if not requested_name.is_empty(): node.name = requested_name
	var undo := plugin.get_undo_redo()
	undo.create_action("MCP Create Node", UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(parent, "add_child", node)
	undo.add_do_method(node, "set_owner", root)
	undo.add_undo_method(parent, "remove_child", node)
	undo.add_do_reference(node)
	undo.commit_action()
	return _ok({"node_path": str(root.get_path_to(node)), "name": node.name, "type": node.get_class(), "undoable": true})

static func _node_set_property(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null: return _error("NO_SCENE", "No scene is currently open")
	var node_path := str(args.get("node_path", ""))
	var node := _resolve_node(root, node_path)
	if node == null: return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	var property_name := str(args.get("property", "")).strip_edges()
	if property_name.is_empty(): return _error("PROPERTY_REQUIRED", "property is required")
	if not _has_property(node, property_name): return _error("PROPERTY_NOT_FOUND", "Property '%s' does not exist on %s" % [property_name, node.get_class()])
	var decoded = U.decode_value(args.get("value"))
	var old_value = node.get(property_name)
	var undo := plugin.get_undo_redo()
	undo.create_action("MCP Set %s" % property_name, UndoRedo.MERGE_DISABLE, node)
	undo.add_do_property(node, property_name, decoded)
	undo.add_undo_property(node, property_name, old_value)
	undo.commit_action()
	return _ok({"node_path": node_path, "property": property_name, "value": U.encode_value(node.get(property_name)), "undoable": true})

static func _node_delete(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null: return _error("NO_SCENE", "No scene is currently open")
	var node_path := str(args.get("node_path", ""))
	var node := _resolve_node(root, node_path)
	if node == null: return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	if node == root: return _error("ROOT_DELETE_DENIED", "The edited scene root cannot be deleted with node.delete")
	var deleted_name := node.name
	var parent := node.get_parent()
	if parent == null: return _error("NO_PARENT", "Node has no parent")
	var old_owner := node.owner
	var undo := plugin.get_undo_redo()
	undo.create_action("MCP Delete Node", UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(parent, "remove_child", node)
	undo.add_undo_method(parent, "add_child", node)
	if old_owner != null: undo.add_undo_method(node, "set_owner", old_owner)
	undo.add_undo_reference(node)
	undo.commit_action()
	return _ok({"deleted": true, "name": deleted_name, "undoable": true})

static func _script_read(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", "")).strip_edges()
	if not _valid_res_path(path):
		return _error("INVALID_PATH", "Path must stay inside res:// and must not contain '..'")
	if not FileAccess.file_exists(path):
		return _error("FILE_NOT_FOUND", "File not found: %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("OPEN_FAILED", "Unable to open file: %s" % path)
	var content := file.get_as_text()
	file.close()
	return _ok({"path": path, "content": content})


static func _script_write(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var path := str(args.get("path", "")).strip_edges()
	if not _valid_res_path(path): return _error("INVALID_PATH", "Path must stay inside res:// and must not contain '..'")
	var content := str(args.get("content", ""))
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS: return _error("DIRECTORY_FAILED", "Unable to create file directory: %s" % error_string(dir_err))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _error("OPEN_FAILED", "Unable to write file: %s" % path)
	file.store_string(content); file.close()
	var diagnostics := {"valid": true, "error_code": 0, "error": "", "methods": []}
	if path.get_extension().to_lower() == "gd":
		var script := GDScript.new(); script.source_code = content
		var parse_error := script.reload(true)
		diagnostics.valid = parse_error == OK
		diagnostics.error_code = int(parse_error)
		diagnostics.error = error_string(parse_error) if parse_error != OK else ""
		if parse_error == OK:
			for method in script.get_script_method_list(): diagnostics.methods.append(str(method.get("name", "")))
	var fs := plugin.get_editor_interface().get_resource_filesystem()
	if fs != null: fs.scan_sources()
	return _ok({"path": path, "bytes": content.to_utf8_buffer().size(), "written": true, "valid": diagnostics.valid, "diagnostics": diagnostics})

static func _script_attach(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root := plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return _error("NO_SCENE", "No scene is currently open")
	var node_path := str(args.get("node_path", ""))
	var node := _resolve_node(root, node_path)
	if node == null:
		return _error("NODE_NOT_FOUND", "Node not found: %s" % node_path)
	var script_path := str(args.get("script_path", "")).strip_edges()
	if not _valid_res_path(script_path):
		return _error("INVALID_PATH", "Script path must stay inside res:// and must not contain '..'")
	var script = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
	if script == null or not script is Script:
		return _error("SCRIPT_LOAD_FAILED", "Unable to load script: %s" % script_path)
	node.set_script(script)
	_mark_unsaved(plugin)
	return _ok({"node_path": node_path, "script_path": script_path})


static func _resolve_node(root: Node, path_text: String) -> Node:
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


static func _serialize_node(node: Node, root: Node, depth: int, max_depth: int) -> Dictionary:
	var item := {
		"name": node.name,
		"type": node.get_class(),
		"path": "." if node == root else str(root.get_path_to(node)),
		"children": [],
	}
	if depth >= max_depth:
		return item
	var children: Array = []
	for child in node.get_children():
		if child is Node:
			children.append(_serialize_node(child, root, depth + 1, max_depth))
	item["children"] = children
	return item


static func _has_property(node: Object, property_name: String) -> bool:
	for property_info in node.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


static func _decode_value(value):
	if not value is Dictionary:
		return value
	var data: Dictionary = value
	var kind := str(data.get("__godot_type", ""))
	match kind:
		"Vector2":
			return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		"Vector3":
			return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))
		"Color":
			return Color(float(data.get("r", 0.0)), float(data.get("g", 0.0)), float(data.get("b", 0.0)), float(data.get("a", 1.0)))
		"NodePath":
			return NodePath(str(data.get("value", "")))
		_:
			return value


static func _encode_value(value):
	if value is Vector2:
		return {"__godot_type": "Vector2", "x": value.x, "y": value.y}
	if value is Vector3:
		return {"__godot_type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
	if value is Color:
		return {"__godot_type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is NodePath:
		return {"__godot_type": "NodePath", "value": str(value)}
	if typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_ARRAY, TYPE_DICTIONARY]:
		return value
	return str(value)


static func _valid_res_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	var relative := path.trim_prefix("res://").replace("\\", "/")
	for segment in relative.split("/", false):
		if segment == "..":
			return false
	return not relative.is_empty()


static func _mark_unsaved(plugin: EditorPlugin) -> void:
	var editor := plugin.get_editor_interface()
	if editor.has_method("mark_scene_as_unsaved"):
		editor.call("mark_scene_as_unsaved")


static func _ok(result) -> Dictionary:
	return {"ok": true, "result": result}


static func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
