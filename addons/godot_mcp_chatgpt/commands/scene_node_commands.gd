@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
	_add(registry, "scene.get_current", "Return the currently edited scene.", {}, func(_a): return _scene_current(plugin), true)
	_add(registry, "scene.list_open", "List open editor scenes and roots.", {}, func(_a): return _scene_list(plugin), true)
	_add(registry, "scene.get_unsaved", "List scenes with unsaved changes.", {}, func(_a): return U.ok(plugin.get_editor_interface().get_unsaved_scenes()), true)
	_add(registry, "scene.open", "Open an existing .tscn scene in the editor.", {"path":{"type":"string"}}, func(a): return await _scene_open(plugin, a), false, ["path"])
	_add(registry, "scene.close", "Close the current edited scene.", {}, func(_a): return _scene_close(plugin), false, [], true)
	_add(registry, "scene.reload", "Reload an open scene from disk.", {"path":{"type":"string"}}, func(a): return await _scene_reload(plugin, a), false)
	_add(registry, "scene.save_all", "Save all open scenes.", {}, func(_a): return _scene_save_all(plugin), false)
	_add(registry, "scene.inspect", "Inspect scene structure with scripts, groups, metadata, signals and property summaries.", {"max_depth":{"type":"integer"},"property_mode":{"type":"string","enum":["none","storage","editor","all"]},"max_properties":{"type":"integer"},"include_methods":{"type":"boolean"}}, func(a): return _scene_inspect(plugin, a), true)
	_add(registry, "scene.instantiate", "Instantiate a PackedScene into the current scene.", {"scene_path":{"type":"string"},"parent_path":{"type":"string"},"name":{"type":"string"}}, func(a): return _scene_instantiate(plugin, a), false, ["scene_path"])

	_add(registry, "node.inspect", "Return rich information about one node.", {"node_path":{"type":"string"},"property_mode":{"type":"string","enum":["none","storage","editor","all"]},"max_properties":{"type":"integer"},"include_methods":{"type":"boolean"}}, func(a): return _node_inspect(plugin, a), true)
	_add(registry, "node.get_property", "Read one node property.", {"node_path":{"type":"string"},"property":{"type":"string"}}, func(a): return _node_get_property(plugin, a), true, ["node_path","property"])
	_add(registry, "node.get_properties", "Read node property metadata and values with filtering.", {"node_path":{"type":"string"},"mode":{"type":"string","enum":["storage","editor","all"]},"name_contains":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _node_get_properties(plugin, a), true, ["node_path"])
	_add(registry, "node.get_methods", "List methods available on a node.", {"node_path":{"type":"string"},"name_contains":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _node_methods(plugin, a), true, ["node_path"])
	_add(registry, "node.call_method", "Call a method on a node with JSON-encoded arguments.", {"node_path":{"type":"string"},"method":{"type":"string"},"arguments":{"type":"array"}}, func(a): return _node_call(plugin, a), false, ["node_path","method"], true)
	_add(registry, "node.find", "Find nodes by name substring, class, group or script path.", {"name_contains":{"type":"string"},"class":{"type":"string"},"group":{"type":"string"},"script_path":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _node_find(plugin, a), true)
	_add(registry, "node.rename", "Rename a node.", {"node_path":{"type":"string"},"name":{"type":"string"}}, func(a): return _node_rename(plugin, a), false, ["node_path","name"])
	_add(registry, "node.reparent", "Move a node under a new parent.", {"node_path":{"type":"string"},"new_parent_path":{"type":"string"},"keep_global_transform":{"type":"boolean"}}, func(a): return _node_reparent(plugin, a), false, ["node_path","new_parent_path"])
	_add(registry, "node.duplicate", "Duplicate a node in the edited scene.", {"node_path":{"type":"string"},"name":{"type":"string"}}, func(a): return _node_duplicate(plugin, a), false, ["node_path"])
	_add(registry, "node.move_child", "Change a child node's order under its parent.", {"node_path":{"type":"string"},"index":{"type":"integer"}}, func(a): return _node_move_child(plugin, a), false, ["node_path","index"])
	_add(registry, "node.get_groups", "List groups for a node.", {"node_path":{"type":"string"}}, func(a): return _node_groups(plugin, a), true, ["node_path"])
	_add(registry, "node.add_to_group", "Add a node to a group.", {"node_path":{"type":"string"},"group":{"type":"string"},"persistent":{"type":"boolean"}}, func(a): return _node_add_group(plugin, a), false, ["node_path","group"])
	_add(registry, "node.remove_from_group", "Remove a node from a group.", {"node_path":{"type":"string"},"group":{"type":"string"}}, func(a): return _node_remove_group(plugin, a), false, ["node_path","group"])
	_add(registry, "node.get_signals", "List signals exposed by a node.", {"node_path":{"type":"string"}}, func(a): return _node_signals(plugin, a), true, ["node_path"])
	_add(registry, "node.get_signal_connections", "List outgoing connections for one or all node signals.", {"node_path":{"type":"string"},"signal":{"type":"string"}}, func(a): return _node_connections(plugin, a), true, ["node_path"])
	_add(registry, "node.connect_signal", "Connect a source node signal to a target node method.", {"node_path":{"type":"string"},"signal":{"type":"string"},"target_path":{"type":"string"},"method":{"type":"string"},"flags":{"type":"integer"}}, func(a): return _node_connect_signal(plugin, a), false, ["node_path","signal","target_path","method"])
	_add(registry, "node.disconnect_signal", "Disconnect a source node signal from a target node method.", {"node_path":{"type":"string"},"signal":{"type":"string"},"target_path":{"type":"string"},"method":{"type":"string"}}, func(a): return _node_disconnect_signal(plugin, a), false, ["node_path","signal","target_path","method"])
	_add(registry, "node.get_metadata", "List or read metadata from a node.", {"node_path":{"type":"string"},"key":{"type":"string"}}, func(a): return _node_get_metadata(plugin, a), true, ["node_path"])
	_add(registry, "node.set_metadata", "Set node metadata.", {"node_path":{"type":"string"},"key":{"type":"string"},"value":{}}, func(a): return _node_set_metadata(plugin, a), false, ["node_path","key","value"])
	_add(registry, "node.remove_metadata", "Remove node metadata.", {"node_path":{"type":"string"},"key":{"type":"string"}}, func(a): return _node_remove_metadata(plugin, a), false, ["node_path","key"])

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = [], destructive: bool = false) -> void:
	registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":destructive})

static func _scene_current(plugin: EditorPlugin) -> Dictionary:
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	return U.ok({"open":root != null,"path":root.scene_file_path if root != null else "","root":U.object_summary(root) if root != null else {}})

static func _scene_list(plugin: EditorPlugin) -> Dictionary:
	var editor := plugin.get_editor_interface()
	var roots: Array = []
	for root_value in editor.get_open_scene_roots():
		var root: Node = root_value as Node
		if root != null:
			roots.append(U.object_summary(root))
	var current: Node = editor.get_edited_scene_root()
	return U.ok({"paths":editor.get_open_scenes(),"roots":roots,"current":current.scene_file_path if current != null else ""})

static func _scene_open(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path) or not path.ends_with(".tscn"):
		return U.error("INVALID_PATH", "path must be a res:// .tscn file")
	if not FileAccess.file_exists(path):
		return U.error("NOT_FOUND", "Scene file not found: " + path)
	plugin.get_editor_interface().open_scene_from_path(path)
	await plugin.get_tree().process_frame
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	return U.ok({"path":path,"opened":root != null,"root":U.object_summary(root) if root != null else {}})

static func _scene_close(plugin: EditorPlugin) -> Dictionary:
	var editor := plugin.get_editor_interface()
	var root: Node = editor.get_edited_scene_root()
	if root == null:
		return U.ok({"closed":false,"reason":"no current scene"})
	var path := root.scene_file_path
	var err: Error = editor.close_scene()
	if err != OK:
		return U.error("CLOSE_FAILED", error_string(err))
	return U.ok({"closed":true,"path":path})

static func _scene_reload(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var editor := plugin.get_editor_interface()
	var path := str(args.get("path", ""))
	if path.is_empty():
		var root: Node = editor.get_edited_scene_root()
		if root == null:
			return U.error("NO_SCENE", "No current scene")
		path = root.scene_file_path
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	editor.reload_scene_from_path(path)
	await plugin.get_tree().process_frame
	return U.ok({"reloaded":true,"path":path})

static func _scene_save_all(plugin: EditorPlugin) -> Dictionary:
	plugin.get_editor_interface().save_all_scenes()
	return U.ok({"saved":true,"open_scenes":plugin.get_editor_interface().get_open_scenes()})

static func _scene_inspect(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return U.error("NO_SCENE", "No scene is currently open")
	var depth := clampi(int(args.get("max_depth", 8)), 0, 32)
	var mode := str(args.get("property_mode", "storage"))
	var max_props := clampi(int(args.get("max_properties", 24)), 0, 200)
	var include_methods := bool(args.get("include_methods", false))
	return U.ok({"scene_file":root.scene_file_path,"unsaved":plugin.get_editor_interface().get_unsaved_scenes().has(root.scene_file_path),"root":_inspect_node(root, root, 0, depth, mode, max_props, include_methods)})

static func _inspect_node(node: Node, root: Node, depth: int, max_depth: int, mode: String, max_props: int, include_methods: bool) -> Dictionary:
	var script: Script = node.get_script() as Script
	var metadata := {}
	for key in node.get_meta_list():
		metadata[str(key)] = U.encode_value(node.get_meta(key))
	var owner_path := ""
	if node.owner != null:
		owner_path = U.node_path_relative(root, node.owner)
	var item := {
		"name":node.name,
		"class":node.get_class(),
		"path":U.node_path_relative(root,node),
		"owner":owner_path,
		"groups":_groups(node),
		"script":script.resource_path if script != null else "",
		"metadata":metadata,
		"properties":_properties(node,mode,"",max_props),
		"signals":_signal_summary(node),
		"children":[],
	}
	if include_methods:
		item["methods"] = _method_list(node, "", 80)
	if depth < max_depth:
		var children: Array = []
		for child_value in node.get_children():
			var child: Node = child_value as Node
			if child != null:
				children.append(_inspect_node(child, root, depth + 1, max_depth, mode, max_props, false))
		item["children"] = children
	return item

static func _scene_instantiate(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var path := str(args.get("scene_path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "scene_path must stay inside res://")
	var loaded: Resource = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	var packed: PackedScene = loaded as PackedScene
	if packed == null:
		return U.error("LOAD_FAILED", "Unable to load PackedScene: " + path)
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return U.error("NO_SCENE", "No edited scene")
	var parent: Node = U.resolve_node_from_root(root, str(args.get("parent_path", ".")))
	if parent == null:
		return U.error("NODE_NOT_FOUND", "Parent node not found")
	var instance: Node = packed.instantiate()
	var requested_name := str(args.get("name", ""))
	if not requested_name.is_empty():
		instance.name = requested_name
	parent.add_child(instance)
	_assign_owner_recursive(instance, root)
	U.mark_unsaved(plugin)
	return U.ok({"path":U.node_path_relative(root,instance),"class":instance.get_class(),"scene_path":path})

static func _get_node(plugin: EditorPlugin, args: Dictionary) -> Node:
	return U.resolve_node(plugin, str(args.get("node_path", "")))

static func _node_inspect(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	var mode := str(args.get("property_mode", "storage"))
	var max_props := clampi(int(args.get("max_properties", 80)), 0, 500)
	var include_methods := bool(args.get("include_methods", false))
	var script: Script = node.get_script() as Script
	var metadata := {}
	for key in node.get_meta_list():
		metadata[str(key)] = U.encode_value(node.get_meta(key))
	var child_summaries: Array = []
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child != null:
			child_summaries.append({"name":child.name,"class":child.get_class(),"path":U.node_path_relative(root,child)})
	var result := {
		"node":U.object_summary(node),
		"relative_path":U.node_path_relative(root,node),
		"parent":U.node_path_relative(root,node.get_parent()) if node.get_parent() is Node else "",
		"owner":U.node_path_relative(root,node.owner) if node.owner != null else "",
		"groups":_groups(node),
		"script":script.resource_path if script != null else "",
		"metadata":metadata,
		"properties":_properties(node,mode,"",max_props),
		"signals":_signal_summary(node),
		"children":child_summaries,
	}
	if include_methods:
		result["methods"] = _method_list(node, "", 250)
	return U.ok(result)

static func _node_get_property(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var property := str(args.get("property", ""))
	if not U.property_exists(node, property):
		return U.error("PROPERTY_NOT_FOUND", "Property not found: " + property)
	return U.ok({"node":U.object_summary(node),"property":property,"info":U.property_info(node,property),"value":U.encode_value(node.get(property))})

static func _node_get_properties(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var mode := str(args.get("mode", "storage"))
	var contains := str(args.get("name_contains", "")).to_lower()
	var limit := clampi(int(args.get("limit", 200)), 1, 1000)
	return U.ok({"node":U.object_summary(node),"properties":_properties(node,mode,contains,limit)})

static func _properties(object: Object, mode: String, contains: String, limit: int) -> Array:
	if mode == "none":
		return []
	var result: Array = []
	for info_value in object.get_property_list():
		var info: Dictionary = info_value
		var name := str(info.get("name", ""))
		if not contains.is_empty() and not name.to_lower().contains(contains):
			continue
		var usage := int(info.get("usage", 0))
		if mode == "storage" and (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if mode == "editor" and (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var item := U.encode_property_info(info)
		item["value"] = U.encode_value(object.get(name))
		result.append(item)
		if result.size() >= limit:
			break
	return result

static func _node_methods(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var contains := str(args.get("name_contains", ""))
	var limit := clampi(int(args.get("limit", 300)), 1, 1000)
	return U.ok({"node":U.object_summary(node),"methods":_method_list(node,contains,limit)})

static func _method_list(object: Object, contains: String, limit: int) -> Array:
	var result: Array = []
	var needle := contains.to_lower()
	for info_value in object.get_method_list():
		var info: Dictionary = info_value
		if not needle.is_empty() and not str(info.get("name", "")).to_lower().contains(needle):
			continue
		result.append(U.encode_method_info(info))
		if result.size() >= limit:
			break
	return result

static func _node_call(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var method := str(args.get("method", ""))
	if not node.has_method(method):
		return U.error("METHOD_NOT_FOUND", "Method not found: " + method)
	var call_args: Array = []
	for value in args.get("arguments", []):
		call_args.append(U.decode_value(value))
	var call_result = node.callv(method, call_args)
	U.mark_unsaved(plugin)
	return U.ok({"node":U.object_summary(node),"method":method,"result":U.encode_value(call_result)})

static func _node_find(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	if root == null:
		return U.error("NO_SCENE", "No edited scene")
	var result: Array = []
	_find_recursive(root, root, args, result, clampi(int(args.get("limit", 200)), 1, 1000))
	return U.ok({"nodes":result,"count":result.size()})

static func _find_recursive(node: Node, root: Node, args: Dictionary, out: Array, limit: int) -> void:
	if out.size() >= limit:
		return
	var name_contains := str(args.get("name_contains", "")).to_lower()
	var requested_class := str(args.get("class", ""))
	var group := str(args.get("group", ""))
	var script_path := str(args.get("script_path", ""))
	var script: Script = node.get_script() as Script
	var matched: bool = name_contains.is_empty() or str(node.name).to_lower().contains(name_contains)
	matched = matched and (requested_class.is_empty() or node.is_class(requested_class))
	matched = matched and (group.is_empty() or node.is_in_group(group))
	matched = matched and (script_path.is_empty() or (script != null and script.resource_path == script_path))
	if matched:
		out.append({"name":node.name,"class":node.get_class(),"path":U.node_path_relative(root,node),"script":script.resource_path if script != null else "","groups":_groups(node)})
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child != null:
			_find_recursive(child, root, args, out, limit)

static func _node_rename(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var name := str(args.get("name", "")).strip_edges()
	if name.is_empty():
		return U.error("INVALID_NAME", "name is required")
	node.name = name
	U.mark_unsaved(plugin)
	return U.ok(U.object_summary(node))

static func _node_reparent(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	if node == root:
		return U.error("ROOT_REPARENT_DENIED", "Cannot reparent scene root")
	var parent: Node = U.resolve_node_from_root(root, str(args.get("new_parent_path", "")))
	if parent == null:
		return U.error("NODE_NOT_FOUND", "New parent not found")
	if parent == node or node.is_ancestor_of(parent):
		return U.error("INVALID_PARENT", "Cannot create a node cycle")
	node.reparent(parent, bool(args.get("keep_global_transform", true)))
	_assign_owner_recursive(node, root)
	U.mark_unsaved(plugin)
	return U.ok(U.object_summary(node))

static func _node_duplicate(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	if node == root:
		return U.error("ROOT_DUPLICATE_DENIED", "Use scene tools for root duplication")
	var copy: Node = node.duplicate()
	if copy == null:
		return U.error("DUPLICATE_FAILED", "Node duplicate returned null")
	var requested_name := str(args.get("name", ""))
	if not requested_name.is_empty():
		copy.name = requested_name
	var parent: Node = node.get_parent()
	parent.add_child(copy)
	_assign_owner_recursive(copy, root)
	U.mark_unsaved(plugin)
	return U.ok(U.object_summary(copy))

static func _node_move_child(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var parent: Node = node.get_parent()
	if parent == null:
		return U.error("NO_PARENT", "Node has no parent")
	parent.move_child(node, int(args.get("index", 0)))
	U.mark_unsaved(plugin)
	return U.ok({"path":U.node_path_relative(plugin.get_editor_interface().get_edited_scene_root(),node),"index":node.get_index()})

static func _node_groups(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	return U.ok({"node":U.object_summary(node),"groups":_groups(node)})

static func _groups(node: Node) -> Array:
	var groups: Array = []
	for group in node.get_groups():
		groups.append(str(group))
	return groups

static func _node_add_group(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var group := str(args.get("group", ""))
	if group.is_empty():
		return U.error("GROUP_REQUIRED", "group is required")
	node.add_to_group(group, bool(args.get("persistent", true)))
	U.mark_unsaved(plugin)
	return U.ok({"groups":_groups(node)})

static func _node_remove_group(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	node.remove_from_group(str(args.get("group", "")))
	U.mark_unsaved(plugin)
	return U.ok({"groups":_groups(node)})

static func _node_signals(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var signals: Array = []
	for info_value in node.get_signal_list():
		signals.append(U.encode_signal_info(info_value))
	return U.ok({"signals":signals})

static func _signal_summary(node: Node) -> Array:
	var result: Array = []
	for info_value in node.get_signal_list():
		var info: Dictionary = info_value
		var signal_name := str(info.get("name", ""))
		var connections: Array = node.get_signal_connection_list(signal_name)
		if not connections.is_empty():
			result.append({"name":signal_name,"connections":_encode_connections(connections)})
	return result

static func _node_connections(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var signal_name := str(args.get("signal", ""))
	var result: Array = []
	if not signal_name.is_empty():
		result = _encode_connections(node.get_signal_connection_list(signal_name))
	else:
		for info_value in node.get_signal_list():
			var info: Dictionary = info_value
			var current_signal := str(info.get("name", ""))
			var connections: Array = node.get_signal_connection_list(current_signal)
			if not connections.is_empty():
				result.append({"signal":current_signal,"connections":_encode_connections(connections)})
	return U.ok({"connections":result})

static func _encode_connections(connections: Array) -> Array:
	var out: Array = []
	for connection_value in connections:
		if not connection_value is Dictionary:
			continue
		var connection: Dictionary = connection_value
		var callable: Callable = connection.get("callable", Callable())
		var target: Object = callable.get_object() if callable.is_valid() else null
		out.append({"signal":str(connection.get("signal", "")),"target":U.object_summary(target) if target != null else {},"method":str(callable.get_method()) if callable.is_valid() else "","flags":int(connection.get("flags", 0))})
	return out

static func _node_connect_signal(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var source: Node = _get_node(plugin, args)
	if source == null:
		return U.error("NODE_NOT_FOUND", "Source node not found")
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	var target: Node = U.resolve_node_from_root(root, str(args.get("target_path", "")))
	if target == null:
		return U.error("NODE_NOT_FOUND", "Target node not found")
	var signal_name := str(args.get("signal", ""))
	var method := str(args.get("method", ""))
	if not source.has_signal(signal_name):
		return U.error("SIGNAL_NOT_FOUND", "Signal not found: " + signal_name)
	if not target.has_method(method):
		return U.error("METHOD_NOT_FOUND", "Target method not found: " + method)
	var callable := Callable(target, method)
	if source.is_connected(signal_name, callable):
		return U.ok({"already_connected":true})
	var err: Error = source.connect(signal_name, callable, int(args.get("flags", 0)))
	if err != OK:
		return U.error("CONNECT_FAILED", error_string(err))
	U.mark_unsaved(plugin)
	return U.ok({"connected":true})

static func _node_disconnect_signal(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var source: Node = _get_node(plugin, args)
	if source == null:
		return U.error("NODE_NOT_FOUND", "Source node not found")
	var root: Node = plugin.get_editor_interface().get_edited_scene_root()
	var target: Node = U.resolve_node_from_root(root, str(args.get("target_path", "")))
	if target == null:
		return U.error("NODE_NOT_FOUND", "Target node not found")
	var signal_name := str(args.get("signal", ""))
	var callable := Callable(target, str(args.get("method", "")))
	if source.is_connected(signal_name, callable):
		source.disconnect(signal_name, callable)
	U.mark_unsaved(plugin)
	return U.ok({"connected":false})

static func _node_get_metadata(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var key := str(args.get("key", ""))
	if not key.is_empty():
		return U.ok({"key":key,"exists":node.has_meta(key),"value":U.encode_value(node.get_meta(key)) if node.has_meta(key) else null})
	var result := {}
	for metadata_key in node.get_meta_list():
		result[str(metadata_key)] = U.encode_value(node.get_meta(metadata_key))
	return U.ok(result)

static func _node_set_metadata(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var key := str(args.get("key", ""))
	if key.is_empty():
		return U.error("KEY_REQUIRED", "key is required")
	node.set_meta(key, U.decode_value(args.get("value")))
	U.mark_unsaved(plugin)
	return U.ok({"key":key,"value":U.encode_value(node.get_meta(key))})

static func _node_remove_metadata(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = _get_node(plugin, args)
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	var key := str(args.get("key", ""))
	if node.has_meta(key):
		node.remove_meta(key)
	U.mark_unsaved(plugin)
	return U.ok({"key":key,"removed":true})

static func _assign_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child_value in node.get_children():
		var child: Node = child_value as Node
		if child != null:
			_assign_owner_recursive(child, owner)