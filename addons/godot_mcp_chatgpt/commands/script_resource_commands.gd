@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
	_add(registry, "script.get_info", "Inspect a script's base type, class name, properties, methods, signals and constants.", {"path":{"type":"string"},"include_source":{"type":"boolean"}}, func(a): return _script_info(a), true, ["path"])
	_add(registry, "script.validate", "Parse/compile GDScript source without attaching it to a node.", {"path":{"type":"string"},"source":{"type":"string"}}, func(a): return _script_validate(a), true)
	_add(registry, "script.list_open", "List scripts currently open in the Godot script editor.", {}, func(_a): return _script_open(plugin), true)
	_add(registry, "script.get_unsaved", "List unsaved script-editor files.", {}, func(_a): return U.ok(plugin.get_editor_interface().get_script_editor().get_unsaved_files()), true)
	_add(registry, "script.reload_open", "Reload open scripts from disk.", {}, func(_a): return _script_reload_open(plugin), false)
	_add(registry, "script.save_all", "Save all open scripts.", {}, func(_a): return _script_save_all(plugin), false)
	_add(registry, "script.detach", "Detach the script from a node.", {"node_path":{"type":"string"}}, func(a): return _script_detach(plugin, a), false, ["node_path"])

	_add(registry, "resource.inspect", "Inspect a Resource, including properties, methods and signals.", {"path":{"type":"string"},"property_mode":{"type":"string","enum":["storage","editor","all"]},"include_methods":{"type":"boolean"},"limit":{"type":"integer"}}, func(a): return _resource_inspect(a), true, ["path"])
	_add(registry, "resource.get_property", "Read one property from a Resource.", {"path":{"type":"string"},"property":{"type":"string"}}, func(a): return _resource_get(a), true, ["path","property"])
	_add(registry, "resource.set_property", "Set and save one Resource property.", {"path":{"type":"string"},"property":{"type":"string"},"value":{}}, func(a): return _resource_set(a), false, ["path","property","value"])
	_add(registry, "resource.create", "Create a Resource class, set initial properties and save it.", {"class":{"type":"string"},"path":{"type":"string"},"properties":{"type":"object"}}, func(a): return _resource_create(a), false, ["class","path"])
	_add(registry, "resource.save", "Save a loaded Resource, optionally to a new path.", {"path":{"type":"string"},"target_path":{"type":"string"}}, func(a): return _resource_save(a), false, ["path"])
	_add(registry, "resource.duplicate", "Duplicate a Resource to another path.", {"path":{"type":"string"},"target_path":{"type":"string"},"deep":{"type":"boolean"}}, func(a): return _resource_duplicate(a), false, ["path","target_path"])
	_add(registry, "resource.get_dependencies", "List ResourceLoader dependencies and UID information.", {"path":{"type":"string"}}, func(a): return _resource_dependencies(a), true, ["path"])
	_add(registry, "resource.call_method", "Call a method on a Resource and return the result.", {"path":{"type":"string"},"method":{"type":"string"},"arguments":{"type":"array"},"save_after":{"type":"boolean"}}, func(a): return _resource_call(a), false, ["path","method"], true)

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = [], destructive: bool = false) -> void:
	registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":destructive})

static func _script_info(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var source := ""
	if FileAccess.file_exists(path):
		source = FileAccess.get_file_as_string(path)
	var script: Script = null
	if path.get_extension().to_lower() == "gd" and not source.is_empty():
		var fresh_script := GDScript.new()
		fresh_script.source_code = source
		var parse_error: Error = fresh_script.reload(true)
		if parse_error != OK:
			return U.error("SCRIPT_PARSE_FAILED", "Unable to parse script: %s (%s)" % [path, error_string(parse_error)])
		script = fresh_script
	else:
		var resource: Resource = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
		script = resource as Script
		if script == null:
			return U.error("SCRIPT_LOAD_FAILED", "Unable to load script: " + path)
	var properties: Array = []
	for info_value in script.get_script_property_list():
		properties.append(U.encode_property_info(info_value))
	var methods: Array = []
	for info_value in script.get_script_method_list():
		methods.append(U.encode_method_info(info_value))
	var signals: Array = []
	for info_value in script.get_script_signal_list():
		signals.append(U.encode_signal_info(info_value))
	var constants := {}
	var constant_map: Dictionary = script.get_script_constant_map()
	for key in constant_map.keys():
		constants[str(key)] = U.encode_value(constant_map[key])
	var base: Script = script.get_base_script()
	var result := {
		"path":path,
		"class":script.get_class(),
		"global_name":str(script.get_global_name()),
		"instance_base_type":str(script.get_instance_base_type()),
		"base_script":base.resource_path if base != null else "",
		"properties":properties,
		"methods":methods,
		"signals":signals,
		"constants":constants,
		"line_count":source.count("\n") + 1 if not source.is_empty() else 0,
	}
	if bool(args.get("include_source", false)):
		result["source"] = source
	return U.ok(result)

static func _script_validate(args: Dictionary) -> Dictionary:
	var source := str(args.get("source", ""))
	var path := str(args.get("path", ""))
	if source.is_empty() and not path.is_empty() and U.valid_res_path(path) and FileAccess.file_exists(path):
		source = FileAccess.get_file_as_string(path)
	if source.is_empty():
		return U.error("SOURCE_REQUIRED", "source or readable path is required")
	var script := GDScript.new()
	script.source_code = source
	var err: Error = script.reload(true)
	var methods: Array = []
	if err == OK:
		for info_value in script.get_script_method_list():
			methods.append(U.encode_method_info(info_value))
	return U.ok({"valid":err == OK,"error_code":int(err),"error":error_string(err) if err != OK else "","methods":methods})

static func _script_open(plugin: EditorPlugin) -> Dictionary:
	var editor := plugin.get_editor_interface().get_script_editor()
	var paths: Array = []
	for value in editor.get_open_scripts():
		var script: Script = value as Script
		if script != null:
			paths.append(script.resource_path)
	var current: Script = editor.get_current_script()
	return U.ok({"open":paths,"current":current.resource_path if current != null else ""})

static func _script_reload_open(plugin: EditorPlugin) -> Dictionary:
	plugin.get_editor_interface().get_script_editor().reload_open_files()
	return U.ok({"reloaded":true})

static func _script_save_all(plugin: EditorPlugin) -> Dictionary:
	plugin.get_editor_interface().get_script_editor().save_all_scripts()
	return U.ok({"saved":true})

static func _script_detach(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	var node: Node = U.resolve_node(plugin, str(args.get("node_path", "")))
	if node == null:
		return U.error("NODE_NOT_FOUND", "Node not found")
	node.set_script(null)
	U.mark_unsaved(plugin)
	return U.ok({"node_path":str(args.get("node_path", "")),"script":""})

static func _load_resource(path: String) -> Resource:
	if not U.valid_res_path(path):
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

static func _resource_inspect(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var resource: Resource = _load_resource(path)
	if resource == null:
		return U.error("RESOURCE_LOAD_FAILED", "Unable to load Resource: " + path)
	var mode := str(args.get("property_mode", "storage"))
	var limit := clampi(int(args.get("limit", 200)), 1, 1000)
	var props: Array = []
	for info_value in resource.get_property_list():
		var info: Dictionary = info_value
		var usage := int(info.get("usage", 0))
		if mode == "storage" and (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if mode == "editor" and (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var item := U.encode_property_info(info)
		item["value"] = U.encode_value(resource.get(str(info.get("name", ""))))
		props.append(item)
		if props.size() >= limit:
			break
	var signal_list: Array = []
	for info_value in resource.get_signal_list():
		signal_list.append(U.encode_signal_info(info_value))
	var result := {"resource":U.object_summary(resource),"properties":props,"signals":signal_list}
	if bool(args.get("include_methods", false)):
		var methods: Array = []
		for info_value in resource.get_method_list():
			methods.append(U.encode_method_info(info_value))
			if methods.size() >= 300:
				break
		result["methods"] = methods
	return U.ok(result)

static func _resource_get(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var resource: Resource = _load_resource(path)
	if resource == null:
		return U.error("RESOURCE_LOAD_FAILED", "Unable to load Resource")
	var property := str(args.get("property", ""))
	if not U.property_exists(resource, property):
		return U.error("PROPERTY_NOT_FOUND", "Property not found: " + property)
	return U.ok({"property":property,"info":U.property_info(resource,property),"value":U.encode_value(resource.get(property))})

static func _resource_set(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var resource: Resource = _load_resource(path)
	if resource == null:
		return U.error("RESOURCE_LOAD_FAILED", "Unable to load Resource")
	var property := str(args.get("property", ""))
	if not U.property_exists(resource, property):
		return U.error("PROPERTY_NOT_FOUND", "Property not found: " + property)
	resource.set(property, U.decode_value(args.get("value")))
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		return U.error("SAVE_FAILED", error_string(err))
	return U.ok({"path":path,"property":property,"value":U.encode_value(resource.get(property))})

static func _resource_create(args: Dictionary) -> Dictionary:
	var class_name_text := str(args.get("class", ""))
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	if not ClassDB.class_exists(class_name_text) or not ClassDB.can_instantiate(class_name_text):
		return U.error("INVALID_CLASS", "Class is not instantiable: " + class_name_text)
	var object: Object = ClassDB.instantiate(class_name_text)
	var resource: Resource = object as Resource
	if resource == null:
		return U.error("INVALID_CLASS", "Class is not a Resource: " + class_name_text)
	var properties = args.get("properties", {})
	if properties is Dictionary:
		for key in properties.keys():
			if U.property_exists(resource, str(key)):
				resource.set(str(key), U.decode_value(properties[key]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		return U.error("SAVE_FAILED", error_string(err))
	return U.ok(U.object_summary(resource))

static func _resource_save(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var target := str(args.get("target_path", path))
	if not U.valid_res_path(target):
		return U.error("INVALID_PATH", "target_path must stay inside res://")
	var resource: Resource = _load_resource(path)
	if resource == null:
		return U.error("RESOURCE_LOAD_FAILED", "Unable to load Resource")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var err: Error = ResourceSaver.save(resource, target)
	if err != OK:
		return U.error("SAVE_FAILED", error_string(err))
	return U.ok({"path":target})

static func _resource_duplicate(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var target := str(args.get("target_path", ""))
	if not U.valid_res_path(target):
		return U.error("INVALID_PATH", "target_path must stay inside res://")
	var resource: Resource = _load_resource(path)
	if resource == null:
		return U.error("RESOURCE_LOAD_FAILED", "Unable to load Resource")
	var copy: Resource = resource.duplicate(bool(args.get("deep", true)))
	var err: Error = ResourceSaver.save(copy, target)
	if err != OK:
		return U.error("SAVE_FAILED", error_string(err))
	return U.ok(U.object_summary(copy))

static func _resource_dependencies(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var deps: Array = []
	for value in ResourceLoader.get_dependencies(path):
		deps.append(str(value))
	return U.ok({"path":path,"dependencies":deps,"uid":ResourceLoader.get_resource_uid(path)})

static func _resource_call(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not U.valid_res_path(path):
		return U.error("INVALID_PATH", "path must stay inside res://")
	var resource: Resource = _load_resource(path)
	if resource == null:
		return U.error("RESOURCE_LOAD_FAILED", "Unable to load Resource")
	var method := str(args.get("method", ""))
	if not resource.has_method(method):
		return U.error("METHOD_NOT_FOUND", "Method not found: " + method)
	var call_args: Array = []
	for value in args.get("arguments", []):
		call_args.append(U.decode_value(value))
	var call_result = resource.callv(method, call_args)
	if bool(args.get("save_after", false)):
		var err: Error = ResourceSaver.save(resource, path)
		if err != OK:
			return U.error("SAVE_FAILED", error_string(err))
	return U.ok({"result":U.encode_value(call_result)})