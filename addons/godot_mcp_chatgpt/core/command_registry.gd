@tool
extends RefCounted

var _commands: Dictionary = {}

func add_command(name: String, description: String, input_schema: Dictionary, handler: Callable, annotations: Dictionary = {}) -> void:
	_commands[name] = {
		"name": name,
		"description": description,
		"input_schema": input_schema,
		"annotations": annotations,
		"handler": handler,
	}

func has_command(name: String) -> bool:
	return _commands.has(name)

func catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for name in _commands.keys():
		var entry: Dictionary = _commands[name]
		result.append({
			"name": entry["name"],
			"description": entry["description"],
			"input_schema": entry["input_schema"],
			"annotations": entry["annotations"],
		})
	return result

func call_command(name: String, arguments: Dictionary) -> Dictionary:
	if not _commands.has(name):
		return _error("METHOD_NOT_FOUND", "Unknown Godot MCP command: %s" % name)
	var handler: Callable = _commands[name]["handler"]
	if not handler.is_valid():
		return _error("HANDLER_INVALID", "Command handler is unavailable: %s" % name)
	var value = await handler.call(arguments)
	if value is Dictionary:
		return value
	return {"ok": true, "result": value}

func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
