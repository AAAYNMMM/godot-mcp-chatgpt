@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const MAX_OPERATIONS := 50
const MAX_PAYLOAD_BYTES := 524288

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
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

	registry.add_command(
		"batch.execute_transaction",
		"Execute a bounded all-or-nothing batch of supported UndoRedo-backed editor mutations. Unsupported/non-undoable operations are rejected before execution.",
		{
			"type":"object",
			"properties":{
				"operations":{"type":"array","minItems":1,"maxItems":MAX_OPERATIONS,"items":{"type":"object","properties":{"tool":{"type":"string"},"arguments":{"type":"object"}},"required":["tool"],"additionalProperties":false}},
			},
			"required":["operations"],
			"additionalProperties":false,
		},
		func(args): return await _execute_transaction(registry, plugin, args),
		{"readOnlyHint":false,"destructiveHint":true}
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

static func _execute_transaction(registry: RefCounted, plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	const SUPPORTED := ["node.create", "node.set_property", "node.delete"]
	var operations: Array = args.get("operations", [])
	if operations.is_empty(): return U.error("BATCH_EMPTY", "operations must contain at least one item")
	if operations.size() > MAX_OPERATIONS: return U.error("BATCH_TOO_LARGE", "operations is limited to %d items" % MAX_OPERATIONS)
	if JSON.stringify(args).to_utf8_buffer().size() > MAX_PAYLOAD_BYTES: return U.error("BATCH_PAYLOAD_TOO_LARGE", "Batch payload exceeds %d bytes" % MAX_PAYLOAD_BYTES)
	for index in operations.size():
		var raw=operations[index]
		if not raw is Dictionary: return U.error("INVALID_OPERATION", "operations[%d] must be an object" % index)
		var tool:=str(raw.get("tool", ""))
		if not SUPPORTED.has(tool): return _error_with_details("TRANSACTION_TOOL_NOT_UNDOABLE", "Transactional batch only accepts proven UndoRedo-backed tools", {"index":index,"tool":tool,"supported":SUPPORTED})
		if not raw.get("arguments", {}) is Dictionary: return U.error("INVALID_ARGUMENTS", "operations[%d].arguments must be an object" % index)
	var root:=plugin.get_editor_interface().get_edited_scene_root()
	if root==null: return U.error("NO_SCENE", "Transactional batch requires an edited scene")
	var manager:=plugin.get_undo_redo()
	var history:=manager.get_history_undo_redo(manager.get_object_history_id(root))
	if history==null: return U.error("UNDO_HISTORY_UNAVAILABLE", "Edited-scene UndoRedo history is unavailable")
	var committed_actions:=0
	var results:Array=[]
	for index in operations.size():
		var operation:Dictionary=operations[index]
		var before:=history.get_version()
		var outcome:Dictionary=await registry.call_command(str(operation.tool), Dictionary(operation.get("arguments", {})))
		var after:=history.get_version()
		var delta:=maxi(0,after-before)
		committed_actions+=delta
		results.append({"index":index,"tool":str(operation.tool),"ok":bool(outcome.get("ok",false)),"result":outcome.get("result") if bool(outcome.get("ok",false)) else null,"error":outcome.get("error") if not bool(outcome.get("ok",false)) else null,"undo_actions":delta})
		if not bool(outcome.get("ok",false)):
			var rollback_ok:=_rollback_history(history,committed_actions)
			return U.ok({"atomic":true,"committed":false,"rolled_back":rollback_ok,"failed_index":index,"results":results})
		if delta<=0:
			var rollback_ok:=_rollback_history(history,committed_actions)
			return _error_with_details("TRANSACTION_UNDO_RECORD_MISSING", "A supposedly undoable operation did not commit an UndoRedo action", {"index":index,"tool":str(operation.tool),"rolled_back":rollback_ok,"results":results})
	return U.ok({"atomic":true,"committed":true,"rolled_back":false,"failed_index":-1,"undo_actions":committed_actions,"results":results})

static func _rollback_history(history: UndoRedo, actions: int) -> bool:
	var ok:=true
	for _i in range(actions):
		if not history.has_undo() or not history.undo(): ok=false
	return ok


static func _error_with_details(code: String, message: String, details: Dictionary) -> Dictionary:
	var error := {"code":code,"message":message}
	for key in details.keys(): error[key]=details[key]
	return {"ok":false,"error":error}
