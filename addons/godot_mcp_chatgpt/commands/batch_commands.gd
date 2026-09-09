@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const MAX_OPERATIONS := 50
const MAX_PAYLOAD_BYTES := 524288

static func register(registry: RefCounted) -> void:
	registry.add_command(
		"batch.execute",
		"Execute a bounded sequence of existing Godot MCP tools in order. This is non-atomic and does not roll back earlier successful operations.",
		{
			"type": "object",
			"properties": {
				"operations": {
					"type": "array",
					"minItems": 1,
					"maxItems": MAX_OPERATIONS,
					"items": {
						"type": "object",
						"properties": {
							"tool": {"type": "string"},
							"arguments": {"type": "object"},
						},
						"required": ["tool"],
						"additionalProperties": false,
					},
				},
				"stop_on_error": {"type": "boolean"},
			},
			"required": ["operations"],
			"additionalProperties": false,
		},
		func(args): return await _execute(registry, args),
		{"readOnlyHint": false, "destructiveHint": true}
	)

static func _execute(registry: RefCounted, args: Dictionary) -> Dictionary:
	var operations: Array = args.get("operations", [])
	if operations.is_empty():
		return U.error("BATCH_EMPTY", "operations must contain at least one item")
	if operations.size() > MAX_OPERATIONS:
		return U.error("BATCH_TOO_LARGE", "operations is limited to %d items" % MAX_OPERATIONS)
	var payload_size := JSON.stringify(args).to_utf8_buffer().size()
	if payload_size > MAX_PAYLOAD_BYTES:
		return U.error("BATCH_PAYLOAD_TOO_LARGE", "Batch payload exceeds %d bytes" % MAX_PAYLOAD_BYTES)

	var stop_on_error := bool(args.get("stop_on_error", true))
	var results: Array = []
	var stopped := false
	var failed_index := -1

	for index in operations.size():
		var raw = operations[index]
		if not raw is Dictionary:
			results.append({"index": index, "tool": "", "ok": false, "error": {"code": "INVALID_OPERATION", "message": "Operation must be an object"}})
			failed_index = index
			if stop_on_error:
				stopped = true
				break
			continue
		var operation: Dictionary = raw
		var tool_name := str(operation.get("tool", "")).strip_edges()
		if tool_name.is_empty():
			results.append({"index": index, "tool": "", "ok": false, "error": {"code": "TOOL_REQUIRED", "message": "Operation tool is required"}})
			failed_index = index
			if stop_on_error:
				stopped = true
				break
			continue
		if tool_name.begins_with("batch."):
			results.append({"index": index, "tool": tool_name, "ok": false, "error": {"code": "BATCH_RECURSION_DENIED", "message": "Batch tools cannot invoke batch tools"}})
			failed_index = index
			if stop_on_error:
				stopped = true
				break
			continue
		var call_args = operation.get("arguments", {})
		if not call_args is Dictionary:
			results.append({"index": index, "tool": tool_name, "ok": false, "error": {"code": "INVALID_ARGUMENTS", "message": "Operation arguments must be an object"}})
			failed_index = index
			if stop_on_error:
				stopped = true
				break
			continue

		var outcome: Dictionary = await registry.call_command(tool_name, call_args)
		var entry := {"index": index, "tool": tool_name, "ok": bool(outcome.get("ok", false))}
		if bool(outcome.get("ok", false)):
			entry["result"] = outcome.get("result")
		else:
			entry["error"] = outcome.get("error", {"code": "UNKNOWN_ERROR", "message": "Operation failed"})
			failed_index = index
		results.append(entry)
		if not bool(outcome.get("ok", false)) and stop_on_error:
			stopped = true
			break

	return U.ok({
		"results": results,
		"executed": results.size(),
		"requested": operations.size(),
		"stopped": stopped,
		"failed_index": failed_index,
		"atomic": false,
	})