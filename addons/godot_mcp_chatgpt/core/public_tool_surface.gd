@tool
extends RefCounted

const CustomToolRegistry := preload("res://addons/godot_mcp_chatgpt/custom/custom_tool_registry.gd")
const GROUPED_DOMAINS := {"world":["tilemap","tileset","gridmap","csg"]}

const DIRECT_TOOLS: Array[String] = [
	"godot.get_status",
	"project.inspect",
	"project.search_text",
	"scene.get_current",
	"scene.get_tree",
	"scene.open",
	"scene.save",
	"node.create",
	"node.find",
	"node.get_properties",
	"node.set_property",
	"script.read",
	"script.write",
	"script.patch",
	"script.validate",
	"script.attach",
	"classdb.search",
	"editor.take_screenshot",
	"editor.run_project",
	"editor.run_custom_scene",
	"runtime.status",
	"runtime.get_tree",
	"runtime.inspect",
	"runtime.get_property",
	"runtime.set_property",
	"runtime.call_method",
	"diagnostics.run_capture",
	"batch.execute",
	"batch.execute_transaction",
	"logs.read",
	"test.run",
]

const MANAGED_DOMAINS: Array[String] = [
	"project",
	"input_map",
	"scene",
	"node",
	"script",
	"resource",
	"classdb",
	"editor",
	"debugger",
	"runtime",
	"logs",
	"test",
	"autoload",
	"content",
	"world",
	"custom",
]

var _registry: RefCounted
var _definitions: Dictionary = {}
var _domain_operations: Dictionary = {}
var _domain_targets: Dictionary = {}
var _direct_lookup: Dictionary = {}
var _catalogue: Array[Dictionary] = []
var _build_errors: Array[Dictionary] = []

func setup(registry: RefCounted) -> Dictionary:
	_registry = registry
	_definitions.clear()
	_domain_operations.clear()
	_domain_targets.clear()
	_direct_lookup.clear()
	_catalogue.clear()
	_build_errors.clear()

	if _registry == null:
		return _error("PUBLIC_SURFACE_REGISTRY_REQUIRED", "Internal CommandRegistry is required")

	for definition_value in _registry.catalogue():
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		var name := str(definition.get("name", ""))
		if name.is_empty():
			continue
		_definitions[name] = definition

	for name in DIRECT_TOOLS:
		if not _definitions.has(name):
			_build_errors.append({"code": "PUBLIC_DIRECT_TARGET_MISSING", "tool": name})
			continue
		_direct_lookup[name] = true
		_catalogue.append(_public_definition_from_atomic(_definitions[name]))

	for domain in MANAGED_DOMAINS:
		var operations: Array[String] = []
		var targets: Dictionary = {}
		var source_domains: Array = GROUPED_DOMAINS.get(domain, [domain])
		for source_domain_value in source_domains:
			var source_domain := str(source_domain_value)
			var prefix := source_domain + "."
			for atomic_name_value in _definitions.keys():
				var atomic_name := str(atomic_name_value)
				if atomic_name.begins_with(prefix):
					var atomic_op := atomic_name.substr(prefix.length())
					var public_op := atomic_op if source_domain == domain else source_domain + "_" + atomic_op
					operations.append(public_op)
					targets[public_op] = atomic_name
		operations.sort()
		if operations.is_empty():
			_build_errors.append({"code": "PUBLIC_DOMAIN_EMPTY", "domain": domain})
			continue
		_domain_operations[domain] = operations
		_domain_targets[domain] = targets
		_catalogue.append(_manage_definition(domain, operations))

	var coverage := coverage_report()
	if not bool(coverage.get("ok", false)):
		return coverage
	if not _build_errors.is_empty():
		return _error("PUBLIC_SURFACE_BUILD_FAILED", "Public tool surface has build errors", {"errors": _build_errors.duplicate(true)})
	return {"ok": true, "result": coverage.get("result", {})}

func catalogue() -> Array[Dictionary]:
	var output: Array[Dictionary] = _catalogue.duplicate(true)
	for promoted in _promoted_definitions():
		output.append(promoted)
	return output

func public_tool_count() -> int:
	return _catalogue.size() + _promoted_definitions().size()

func atomic_tool_count() -> int:
	return _definitions.size()

func has_public_tool(name: String) -> bool:
	if _direct_lookup.has(name):
		return true
	if name.ends_with(".manage") and _domain_operations.has(name.trim_suffix(".manage")):
		return true
	return _promoted_spec_for_public_name(name) != null

func call_tool(name: String, arguments: Dictionary) -> Dictionary:
	if _registry == null:
		return _error("PUBLIC_SURFACE_UNAVAILABLE", "Public MCP tool surface is not initialized")

	if _direct_lookup.has(name):
		return await _registry.call_command(name, arguments)

	if name.ends_with(".manage"):
		var domain := name.trim_suffix(".manage")
		if _domain_operations.has(domain):
			return await _call_manage(domain, arguments)

	var promoted_spec = _promoted_spec_for_public_name(name)
	if promoted_spec != null:
		var custom_tools = CustomToolRegistry.get_instance()
		if custom_tools == null:
			return _error("CUSTOM_REGISTRY_UNAVAILABLE", "Custom tool registry is unavailable")
		return await custom_tools.invoke(str((promoted_spec as Dictionary).get("name", "")), arguments)

	return _error("PUBLIC_TOOL_NOT_FOUND", "Unknown public Godot MCP tool: %s" % name, {"available_tools": _public_names()})

func coverage_report() -> Dictionary:
	var uncovered: Array[String] = []
	var mapped: Dictionary = {}
	for direct_name_value in _direct_lookup.keys():
		mapped[str(direct_name_value)] = true
	for domain_value in _domain_targets.keys():
		var domain := str(domain_value)
		var targets: Dictionary = _domain_targets[domain]
		for atomic_name_value in targets.values():
			mapped[str(atomic_name_value)] = true
	for atomic_name_value in _definitions.keys():
		var atomic_name := str(atomic_name_value)
		if not mapped.has(atomic_name):
			uncovered.append(atomic_name)
	uncovered.sort()

	var duplicates: Array[String] = []
	var seen: Dictionary = {}
	for definition_value in _catalogue:
		var public_name := str((definition_value as Dictionary).get("name", ""))
		if seen.has(public_name):
			duplicates.append(public_name)
		seen[public_name] = true

	var result := {
		"atomic_tools": atomic_tool_count(),
		"public_tools": public_tool_count(),
		"public_limit": 50,
		"uncovered_atomic_tools": uncovered,
		"duplicate_public_tools": duplicates,
		"build_errors": _build_errors.duplicate(true),
	}
	if public_tool_count() > 50:
		return _error("PUBLIC_TOOL_LIMIT_EXCEEDED", "Default public MCP surface exceeds 50 tools", result)
	if not uncovered.is_empty():
		return _error("PUBLIC_SURFACE_COVERAGE_GAP", "Some internal atomic commands are not reachable through the public surface", result)
	if not duplicates.is_empty():
		return _error("PUBLIC_SURFACE_DUPLICATE", "Duplicate public MCP tool names were generated", result)
	return {"ok": true, "result": result}

func _call_manage(domain: String, arguments: Dictionary) -> Dictionary:
	for key_value in arguments.keys():
		var key := str(key_value)
		if key != "op" and key != "params":
			return _error("INVALID_ARGUMENTS", "Unknown argument for %s.manage: %s" % [domain, key], {"allowed": ["op", "params"]})
	var op := str(arguments.get("op", "")).strip_edges()
	if op.is_empty():
		return _error("OP_REQUIRED", "%s.manage requires a non-empty op" % domain, {"operations": _domain_operations[domain]})
	var operations: Array = _domain_operations[domain]
	if not operations.has(op):
		return _error("OP_NOT_FOUND", "Unknown %s operation: %s" % [domain, op], {"operations": operations})
	var params_value = arguments.get("params", {})
	if not params_value is Dictionary:
		return _error("INVALID_ARGUMENTS", "%s.manage params must be an object" % domain)
	var params: Dictionary = params_value
	var targets: Dictionary = _domain_targets.get(domain, {})
	var atomic_name := str(targets.get(op, ""))
	if atomic_name.is_empty():
		return _error("OP_TARGET_MISSING", "No internal command is mapped for %s.%s" % [domain, op])
	var definition: Dictionary = _definitions.get(atomic_name, {})
	var validation := _validate_against_schema(params, definition.get("input_schema", {}), "params")
	if not bool(validation.get("ok", false)):
		var error_value = validation.get("error", {})
		if error_value is Dictionary:
			error_value["atomic_tool"] = atomic_name
			validation["error"] = error_value
		return validation
	return await _registry.call_command(atomic_name, params)

func _public_definition_from_atomic(definition: Dictionary) -> Dictionary:
	var input_schema_value = definition.get("input_schema", {"type": "object"})
	var input_schema: Dictionary = input_schema_value if input_schema_value is Dictionary else {"type": "object"}
	var annotations_value = definition.get("annotations", {})
	var annotations: Dictionary = annotations_value if annotations_value is Dictionary else {}
	return {
		"name": str(definition.get("name", "")),
		"description": str(definition.get("description", "")),
		"input_schema": input_schema.duplicate(true),
		"annotations": annotations.duplicate(true),
	}

func _manage_definition(domain: String, operations: Array[String]) -> Dictionary:
	var operation_text := ", ".join(operations)
	var annotations := _aggregate_annotations(domain, operations)
	return {
		"name": domain + ".manage",
		"description": "Access long-tail %s operations through one compact tool. Supported op values: %s. params is validated against the selected internal atomic command schema." % [domain, operation_text],
		"input_schema": {
			"type": "object",
			"properties": {
				"op": {"type": "string", "enum": operations.duplicate(), "description": "Operation to execute."},
				"params": {"type": "object", "description": "Arguments for the selected operation. The server validates these against the underlying atomic command schema."},
			},
			"required": ["op"],
			"additionalProperties": false,
		},
		"annotations": annotations,
	}

func _aggregate_annotations(domain: String, operations: Array[String]) -> Dictionary:
	var all_read_only := true
	var any_destructive := false
	var targets: Dictionary = _domain_targets.get(domain, {})
	for op in operations:
		var definition: Dictionary = _definitions.get(str(targets.get(op, "")), {})
		var annotations_value = definition.get("annotations", {})
		var annotations: Dictionary = annotations_value if annotations_value is Dictionary else {}
		if not bool(annotations.get("readOnlyHint", false)):
			all_read_only = false
		if bool(annotations.get("destructiveHint", false)):
			any_destructive = true
	return {"readOnlyHint": all_read_only, "destructiveHint": any_destructive}

func _public_names() -> Array[String]:
	var names: Array[String] = []
	for definition_value in catalogue():
		var definition: Dictionary = definition_value
		names.append(str(definition.get("name", "")))
	return names

func _promoted_definitions() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var custom_tools = CustomToolRegistry.get_instance()
	if custom_tools == null:
		return output
	for spec_value in custom_tools.promoted_specs():
		var spec: Dictionary = spec_value
		output.append({
			"name": "custom." + str(spec.get("name", "")),
			"description": str(spec.get("description", "")),
			"input_schema": (spec.get("input_schema", {}) as Dictionary).duplicate(true),
			"annotations": {"readOnlyHint": bool(spec.get("read_only", true)), "destructiveHint": bool(spec.get("destructive", false))},
		})
	return output

func _promoted_spec_for_public_name(public_name: String):
	if not public_name.begins_with("custom.") or public_name == "custom.manage":
		return null
	var target_name := public_name.trim_prefix("custom.")
	var custom_tools = CustomToolRegistry.get_instance()
	if custom_tools == null:
		return null
	for spec_value in custom_tools.promoted_specs():
		var spec: Dictionary = spec_value
		if str(spec.get("name", "")) == target_name:
			return spec
	return null

func _validate_against_schema(value, schema_value, path: String) -> Dictionary:
	if not schema_value is Dictionary or (schema_value as Dictionary).is_empty():
		return {"ok": true}
	var schema: Dictionary = schema_value

	if schema.has("enum"):
		var enum_values = schema.get("enum", [])
		if enum_values is Array and not (enum_values as Array).has(value):
			return _validation_error(path, "must be one of the allowed enum values")

	var expected_type := str(schema.get("type", ""))
	if not expected_type.is_empty() and not _matches_type(value, expected_type):
		return _validation_error(path, "must be %s" % expected_type)

	if expected_type == "object" and value is Dictionary:
		var object: Dictionary = value
		var properties_value = schema.get("properties", {})
		var properties: Dictionary = properties_value if properties_value is Dictionary else {}
		var required_value = schema.get("required", [])
		if required_value is Array:
			for required_key_value in required_value:
				var required_key := str(required_key_value)
				if not object.has(required_key):
					return _validation_error(path + "." + required_key, "is required")
		if schema.get("additionalProperties", true) == false:
			for key_value in object.keys():
				var key := str(key_value)
				if not properties.has(key):
					return _validation_error(path + "." + key, "is not an allowed property")
		for key_value in object.keys():
			var key := str(key_value)
			if properties.has(key):
				var child_result := _validate_against_schema(object[key_value], properties[key], path + "." + key)
				if not bool(child_result.get("ok", false)):
					return child_result

	if expected_type == "array" and value is Array:
		var array: Array = value
		if schema.has("minItems") and array.size() < int(schema["minItems"]):
			return _validation_error(path, "must contain at least %d items" % int(schema["minItems"]))
		if schema.has("maxItems") and array.size() > int(schema["maxItems"]):
			return _validation_error(path, "must contain at most %d items" % int(schema["maxItems"]))
		var item_schema = schema.get("items", {})
		for index in array.size():
			var child_result := _validate_against_schema(array[index], item_schema, "%s[%d]" % [path, index])
			if not bool(child_result.get("ok", false)):
				return child_result

	if expected_type == "integer" or expected_type == "number":
		if schema.has("minimum") and float(value) < float(schema["minimum"]):
			return _validation_error(path, "must be >= %s" % str(schema["minimum"]))
		if schema.has("maximum") and float(value) > float(schema["maximum"]):
			return _validation_error(path, "must be <= %s" % str(schema["maximum"]))

	return {"ok": true}

func _matches_type(value, expected_type: String) -> bool:
	match expected_type:
		"object":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String
		"integer":
			return value is int or (value is float and float(value) == floor(float(value)))
		"number":
			return value is int or value is float
		"boolean":
			return value is bool
		"null":
			return value == null
		_:
			return true

func _validation_error(path: String, reason: String) -> Dictionary:
	return _error("INVALID_ARGUMENTS", "%s %s" % [path, reason], {"path": path, "reason": reason})

func _error(code: String, message: String, details: Dictionary = {}) -> Dictionary:
	var error := {"code": code, "message": message}
	for key in details.keys():
		error[key] = details[key]
	return {"ok": false, "error": error}
