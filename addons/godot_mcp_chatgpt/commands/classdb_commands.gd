@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, _plugin: EditorPlugin) -> void:
	_add(registry, "classdb.search", "Search Godot ClassDB classes by substring with inheritance and instantiability.", {"query":{"type":"string"},"inherits":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _search(a), true)
	_add(registry, "classdb.inspect", "Inspect a Godot class: inheritance, properties, methods, signals, constants and enums.", {"class":{"type":"string"},"include_inherited":{"type":"boolean"},"member_filter":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _inspect(a), true, ["class"])
	_add(registry, "classdb.get_properties", "List properties for a Godot class.", {"class":{"type":"string"},"include_inherited":{"type":"boolean"},"name_contains":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _properties(a), true, ["class"])
	_add(registry, "classdb.get_methods", "List methods for a Godot class.", {"class":{"type":"string"},"include_inherited":{"type":"boolean"},"name_contains":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _methods(a), true, ["class"])
	_add(registry, "classdb.get_signals", "List signals for a Godot class.", {"class":{"type":"string"},"include_inherited":{"type":"boolean"},"name_contains":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _signals(a), true, ["class"])
	_add(registry, "classdb.get_enums", "List enums and enum values for a Godot class.", {"class":{"type":"string"},"include_inherited":{"type":"boolean"}}, func(a): return _enums(a), true, ["class"])
	_add(registry, "classdb.get_constants", "List integer constants for a Godot class.", {"class":{"type":"string"},"include_inherited":{"type":"boolean"},"name_contains":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _constants(a), true, ["class"])
	_add(registry, "classdb.get_inheritance", "Return the inheritance chain for a Godot class.", {"class":{"type":"string"}}, func(a): return _inheritance(a), true, ["class"])
	_add(registry, "classdb.can_instantiate", "Check whether a Godot class exists and can be instantiated.", {"class":{"type":"string"}}, func(a): return _can_instantiate(a), true, ["class"])

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = []) -> void:
	registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":false})

static func _validate_class(args: Dictionary) -> Dictionary:
	var class_id := str(args.get("class", "")).strip_edges()
	if class_id.is_empty():
		return U.error("CLASS_REQUIRED", "class is required")
	if not ClassDB.class_exists(class_id):
		return U.error("CLASS_NOT_FOUND", "Godot class not found: " + class_id)
	return U.ok(class_id)

static func _search(args: Dictionary) -> Dictionary:
	var query := str(args.get("query", "")).to_lower()
	var inherits := str(args.get("inherits", "")).strip_edges()
	if not inherits.is_empty() and not ClassDB.class_exists(inherits):
		return U.error("CLASS_NOT_FOUND", "inherits class not found: " + inherits)
	var limit := clampi(int(args.get("limit", 200)), 1, 2000)
	var result: Array = []
	for class_id_value in ClassDB.get_class_list():
		var class_id := str(class_id_value)
		if not query.is_empty() and not class_id.to_lower().contains(query):
			continue
		if not inherits.is_empty() and class_id != inherits and not ClassDB.is_parent_class(class_id, inherits):
			continue
		result.append({
			"class": class_id,
			"parent": str(ClassDB.get_parent_class(class_id)),
			"can_instantiate": ClassDB.can_instantiate(class_id),
			"is_virtual": not ClassDB.can_instantiate(class_id),
		})
		if result.size() >= limit:
			break
	return U.ok({"query":query,"inherits":inherits,"classes":result,"count":result.size(),"truncated":result.size() >= limit})

static func _inspect(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	var include_inherited := bool(args.get("include_inherited", true))
	var filter := str(args.get("member_filter", "")).to_lower()
	var limit := clampi(int(args.get("limit", 300)), 1, 2000)
	var props := _property_list(class_id, include_inherited, filter, limit)
	var methods := _method_list(class_id, include_inherited, filter, limit)
	var signals := _signal_list(class_id, include_inherited, filter, limit)
	var constants := _constant_list(class_id, include_inherited, filter, limit)
	var enums := _enum_list(class_id, include_inherited)
	return U.ok({
		"class": class_id,
		"parent": str(ClassDB.get_parent_class(class_id)),
		"inheritance": _inheritance_chain(class_id),
		"can_instantiate": ClassDB.can_instantiate(class_id),
		"properties": props,
		"methods": methods,
		"signals": signals,
		"constants": constants,
		"enums": enums,
	})

static func _properties(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	var include_inherited := bool(args.get("include_inherited", true))
	var filter := str(args.get("name_contains", "")).to_lower()
	var limit := clampi(int(args.get("limit", 500)), 1, 3000)
	return U.ok({"class":class_id,"properties":_property_list(class_id,include_inherited,filter,limit)})

static func _methods(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	var include_inherited := bool(args.get("include_inherited", true))
	var filter := str(args.get("name_contains", "")).to_lower()
	var limit := clampi(int(args.get("limit", 700)), 1, 4000)
	return U.ok({"class":class_id,"methods":_method_list(class_id,include_inherited,filter,limit)})

static func _signals(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	var include_inherited := bool(args.get("include_inherited", true))
	var filter := str(args.get("name_contains", "")).to_lower()
	var limit := clampi(int(args.get("limit", 500)), 1, 3000)
	return U.ok({"class":class_id,"signals":_signal_list(class_id,include_inherited,filter,limit)})

static func _enums(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	return U.ok({"class":class_id,"enums":_enum_list(class_id,bool(args.get("include_inherited",true)))})

static func _constants(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	var include_inherited := bool(args.get("include_inherited", true))
	var filter := str(args.get("name_contains", "")).to_lower()
	var limit := clampi(int(args.get("limit", 700)), 1, 4000)
	return U.ok({"class":class_id,"constants":_constant_list(class_id,include_inherited,filter,limit)})

static func _inheritance(args: Dictionary) -> Dictionary:
	var valid := _validate_class(args)
	if not bool(valid.get("ok", false)):
		return valid
	var class_id := str(valid.get("result"))
	return U.ok({"class":class_id,"inheritance":_inheritance_chain(class_id)})

static func _can_instantiate(args: Dictionary) -> Dictionary:
	var class_id := str(args.get("class", "")).strip_edges()
	return U.ok({"class":class_id,"exists":ClassDB.class_exists(class_id),"can_instantiate":ClassDB.can_instantiate(class_id) if ClassDB.class_exists(class_id) else false})

static func _property_list(class_id: String, include_inherited: bool, filter: String, limit: int) -> Array:
	var result: Array = []
	for info_value in ClassDB.class_get_property_list(class_id, not include_inherited):
		var info: Dictionary = info_value
		var name := str(info.get("name", ""))
		if not filter.is_empty() and not name.to_lower().contains(filter):
			continue
		var item := U.encode_property_info(info)
		item["default_value"] = U.encode_value(ClassDB.class_get_property_default_value(class_id, name))
		item["getter"] = str(ClassDB.class_get_property_getter(class_id, name))
		item["setter"] = str(ClassDB.class_get_property_setter(class_id, name))
		result.append(item)
		if result.size() >= limit:
			break
	return result

static func _method_list(class_id: String, include_inherited: bool, filter: String, limit: int) -> Array:
	var result: Array = []
	for info_value in ClassDB.class_get_method_list(class_id, not include_inherited):
		var info: Dictionary = info_value
		if not filter.is_empty() and not str(info.get("name", "")).to_lower().contains(filter):
			continue
		result.append(U.encode_method_info(info))
		if result.size() >= limit:
			break
	return result

static func _signal_list(class_id: String, include_inherited: bool, filter: String, limit: int) -> Array:
	var result: Array = []
	for info_value in ClassDB.class_get_signal_list(class_id, not include_inherited):
		var info: Dictionary = info_value
		if not filter.is_empty() and not str(info.get("name", "")).to_lower().contains(filter):
			continue
		result.append(U.encode_signal_info(info))
		if result.size() >= limit:
			break
	return result

static func _constant_list(class_id: String, include_inherited: bool, filter: String, limit: int) -> Array:
	var result: Array = []
	for constant_value in ClassDB.class_get_integer_constant_list(class_id, not include_inherited):
		var constant_name := str(constant_value)
		if not filter.is_empty() and not constant_name.to_lower().contains(filter):
			continue
		result.append({"name":constant_name,"value":ClassDB.class_get_integer_constant(class_id,constant_name),"enum":str(ClassDB.class_get_integer_constant_enum(class_id,constant_name,not include_inherited))})
		if result.size() >= limit:
			break
	return result

static func _enum_list(class_id: String, include_inherited: bool) -> Array:
	var result: Array = []
	for enum_value in ClassDB.class_get_enum_list(class_id, not include_inherited):
		var enum_name := str(enum_value)
		var values := {}
		for constant_value in ClassDB.class_get_enum_constants(class_id, enum_name, not include_inherited):
			var constant_name := str(constant_value)
			values[constant_name] = ClassDB.class_get_integer_constant(class_id, constant_name)
		result.append({"name":enum_name,"bitfield":ClassDB.is_class_enum_bitfield(class_id,enum_name,not include_inherited),"values":values})
	return result

static func _inheritance_chain(class_id: String) -> Array:
	var result: Array = [class_id]
	var current := class_id
	while true:
		var parent := str(ClassDB.get_parent_class(current))
		if parent.is_empty():
			break
		result.append(parent)
		current = parent
	return result