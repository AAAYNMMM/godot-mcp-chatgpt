@tool
extends Node

signal state_changed(state: String)
signal log_message(message: String)

const PLUGIN_VERSION := "0.2.2"
const CLIENT_NAME := "godot-mcp-chatgpt"
const WIRE_PROTOCOL_VERSION := "2026-08-25"
const DEFAULT_CONTROL_PLANE_URL := "https://api.openai.com"
const CONTROL_PLANE_URL_ENV := "GODOT_MCP_CHATGPT_CONTROL_PLANE_URL"
const TUNNEL_ID_ENV := "GODOT_MCP_CHATGPT_TUNNEL_ID"
const API_KEY_ENV := "GODOT_MCP_CHATGPT_API_KEY"
const EDITOR_TUNNEL_ID_SETTING := "godot_mcp_chatgpt/tunnel_id"
const EDITOR_API_KEY_SETTING := "godot_mcp_chatgpt/api_key"
const POLL_TIMEOUT_MS := 15000
const HTTP_TIMEOUT_SECONDS := 25.0
const MAX_BACKOFF_SECONDS := 15.0
const MAX_RESPONSE_RETRIES := 5
const MCP_PROTOCOL_FALLBACK := "2025-11-25"
const MCP_PROTOCOLS := ["2026-07-28", "2025-11-25", "2025-06-18"]

var _registry: RefCounted
var _editor_settings: EditorSettings
var _state := "disconnected"
var _tunnel_id := ""
var _api_key := ""
var _should_connect := false
var _generation := 0
var _client_instance_id := ""


func _ready() -> void:
	_client_instance_id = _generate_instance_id()
	var dev_tunnel := OS.get_environment(TUNNEL_ID_ENV).strip_edges()
	var dev_key := OS.get_environment(API_KEY_ENV).strip_edges()
	if not dev_tunnel.is_empty() and not dev_key.is_empty():
		_emit_log("Development auto-connect credentials detected.")
		call_deferred("connect_to_tunnel", dev_tunnel, dev_key)
	else:
		_emit_log("Waiting for OpenAI Tunnel ID and Runtime API Key.")


func set_registry(registry: RefCounted) -> void:
	_registry = registry


func set_editor_settings(settings: EditorSettings) -> void:
	_editor_settings = settings


func get_state() -> String:
	return _state


func get_saved_tunnel_id() -> String:
	if _editor_settings == null or not _editor_settings.has_setting(EDITOR_TUNNEL_ID_SETTING):
		return ""
	return str(_editor_settings.get_setting(EDITOR_TUNNEL_ID_SETTING))


func get_saved_api_key() -> String:
	# Runtime API keys are intentionally never persisted by the addon.
	return ""


func connect_to_tunnel(tunnel_id: String, api_key: String) -> void:
	_tunnel_id = tunnel_id.strip_edges()
	_api_key = api_key.strip_edges()
	if _tunnel_id.is_empty() or _api_key.is_empty():
		_set_state("credentials_required")
		_emit_log("Tunnel ID and API Key are required.")
		return
	if _registry == null:
		_set_state("registry_unavailable")
		_emit_log("Godot command registry is unavailable.")
		return

	_save_tunnel_id()
	_should_connect = true
	_generation += 1
	var generation := _generation
	_set_state("connecting")
	_emit_log("Connecting to OpenAI Secure MCP Tunnel.")
	call_deferred("_start_connection", generation)


func disconnect_from_tunnel() -> void:
	_should_connect = false
	_generation += 1
	_tunnel_id = ""
	_api_key = ""
	_set_state("disconnected")
	_emit_log("Secure MCP Tunnel disconnected.")


func _start_connection(generation: int) -> void:
	var metadata := await _request_json(
		HTTPClient.METHOD_GET,
		_control_plane_url() + "/v1/tunnels/" + _tunnel_id.uri_encode(),
		_common_headers(),
		""
	)
	if not _is_generation_active(generation):
		return
	var code := int(metadata.get("code", 0))
	if code == 401 or code == 403:
		_fail_auth("Tunnel credentials were rejected.")
		return
	if code == 404:
		_should_connect = false
		_set_state("tunnel_not_found")
		_emit_log("Tunnel ID was not found.")
		return
	if code < 200 or code >= 300:
		_set_state("reconnecting")
		_emit_log("Tunnel metadata check failed; retrying through poll loop.")
	else:
		_set_state("connected")
		_emit_log("OpenAI Secure MCP Tunnel connected.")
	await _poll_loop(generation)


func _poll_loop(generation: int) -> void:
	var backoff := 1.0
	while _is_generation_active(generation):
		var url := _control_plane_url() + "/v1/tunnels/" + _tunnel_id.uri_encode() + "/poll?limit=10&timeout_ms=%d" % POLL_TIMEOUT_MS
		var response := await _request_json(HTTPClient.METHOD_GET, url, _common_headers(), "")
		if not _is_generation_active(generation):
			return
		var code := int(response.get("code", 0))
		if code == 401 or code == 403:
			_fail_auth("Tunnel authorization expired or was revoked.")
			return
		if code == 204:
			if _state != "connected":
				_set_state("connected")
			backoff = 1.0
			continue
		if code == 200:
			if _state != "connected":
				_set_state("connected")
				_emit_log("OpenAI Secure MCP Tunnel connected.")
			backoff = 1.0
			var payload = response.get("json")
			if not payload is Dictionary:
				_emit_log("Tunnel poll returned malformed JSON; retrying.")
				await _backoff_delay(backoff, generation)
				backoff = minf(backoff * 2.0, MAX_BACKOFF_SECONDS)
				continue
			var commands_value = payload.get("commands", [])
			if commands_value is Array:
				var received_at_ms := int(response.get("received_at_ms", Time.get_ticks_msec()))
				for command_value in commands_value:
					if not _is_generation_active(generation):
						return
					if command_value is Dictionary:
						await _process_command(command_value, received_at_ms, generation)
			continue

		if code == 429 or code >= 500 or code == 0:
			_set_state("reconnecting")
			await _backoff_delay(backoff, generation)
			backoff = minf(backoff * 2.0, MAX_BACKOFF_SECONDS)
			continue

		_emit_log("Tunnel poll failed with HTTP %d." % code)
		_set_state("connection_error")
		await _backoff_delay(backoff, generation)
		backoff = minf(backoff * 2.0, MAX_BACKOFF_SECONDS)


func _process_command(command: Dictionary, poll_received_at_ms: int, generation: int) -> void:
	var request_id := str(command.get("request_id", ""))
	var shard_token := str(command.get("shard_token", ""))
	var channel := str(command.get("channel", "main"))
	var command_type := str(command.get("command_type", ""))
	if request_id.is_empty() or shard_token.is_empty():
		_emit_log("Ignored tunnel command missing correlation fields.")
		return

	var timeout_ms := _parse_response_timeout_ms(command.get("response_timeout"))
	var deadline_ms := -1
	if timeout_ms >= 0:
		deadline_ms = poll_received_at_ms + timeout_ms
		if Time.get_ticks_msec() >= deadline_ms:
			return

	match command_type:
		"jsonrpc":
			var rpc = command.get("jsonrpc")
			if not rpc is Dictionary:
				await _post_jsonrpc_error(command, null, -32600, "Invalid Request", deadline_ms, generation)
				return
			var dispatch := await _dispatch_jsonrpc(rpc)
			if deadline_ms >= 0 and Time.get_ticks_msec() >= deadline_ms:
				return
			if bool(dispatch.get("notification", false)):
				await _post_terminal(command, {}, 204, "notify_ack", deadline_ms, generation)
			else:
				await _post_terminal(command, dispatch.get("rpc", {}), 200, "jsonrpc_response", deadline_ms, generation)
		"session_termination":
			await _post_terminal(command, {}, 204, "session_termination_response", deadline_ms, generation)
		_:
			_emit_log("Ignored unsupported tunnel command type: %s" % command_type)


func _dispatch_jsonrpc(rpc: Dictionary) -> Dictionary:
	var has_id := rpc.has("id")
	var rpc_id = rpc.get("id")
	if str(rpc.get("jsonrpc", "")) != "2.0" or not rpc.has("method"):
		return {"notification": not has_id, "rpc": _rpc_error(rpc_id, -32600, "Invalid Request")}

	var method := str(rpc.get("method", ""))
	var params_value = rpc.get("params", {})
	var params: Dictionary = params_value if params_value is Dictionary else {}

	if not has_id:
		# MCP lifecycle notifications are acknowledged at the tunnel layer.
		return {"notification": true}

	match method:
		"initialize":
			var requested := str(params.get("protocolVersion", ""))
			var negotiated := requested if requested in MCP_PROTOCOLS else MCP_PROTOCOL_FALLBACK
			return {"notification": false, "rpc": _rpc_result(rpc_id, {
				"protocolVersion": negotiated,
				"capabilities": {"tools": {}},
				"serverInfo": {"name": CLIENT_NAME, "version": PLUGIN_VERSION},
			})}
		"ping":
			return {"notification": false, "rpc": _rpc_result(rpc_id, {})}
		"tools/list":
			return {"notification": false, "rpc": _rpc_result(rpc_id, {"tools": _mcp_tool_catalogue()})}
		"tools/call":
			var name := str(params.get("name", ""))
			var args_value = params.get("arguments", {})
			var args: Dictionary = args_value if args_value is Dictionary else {}
			var result: Dictionary = await _registry.call_command(name, args)
			var tool_result := {
				"content": [{
					"type": "text",
					"text": JSON.stringify(result.get("result") if bool(result.get("ok", false)) else result.get("error")),
				}],
			}
			if not bool(result.get("ok", false)):
				tool_result["isError"] = true
			return {"notification": false, "rpc": _rpc_result(rpc_id, tool_result)}
		_:
			return {"notification": false, "rpc": _rpc_error(rpc_id, -32601, "Method not found")}


func _mcp_tool_catalogue() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for source in _registry.catalogue():
		var item := {
			"name": source.get("name", ""),
			"description": source.get("description", ""),
			"inputSchema": source.get("input_schema", {"type": "object"}),
		}
		var annotations = source.get("annotations", {})
		if annotations is Dictionary and not annotations.is_empty():
			item["annotations"] = annotations
		output.append(item)
	return output


func _post_jsonrpc_error(command: Dictionary, rpc_id, code: int, message: String, deadline_ms: int, generation: int) -> void:
	await _post_terminal(command, _rpc_error(rpc_id, code, message), 400, "jsonrpc_response", deadline_ms, generation)


func _post_terminal(command: Dictionary, resp_json: Dictionary, resp_code: int, resp_type: String, deadline_ms: int, generation: int) -> bool:
	var request_id := str(command.get("request_id", ""))
	var shard_token := str(command.get("shard_token", ""))
	var channel := str(command.get("channel", "main"))
	var body := {
		"request_id": request_id,
		"channel": channel,
		"resp_code": resp_code,
		"resp_type": resp_type,
	}
	if not resp_json.is_empty():
		body["resp_json"] = resp_json
		body["resp_headers"] = {"Content-Type": ["application/json"]}
	var body_text := JSON.stringify(body)
	var headers := _common_headers()
	headers.append("Content-Type: application/json")
	headers.append("X-Tunnel-Shard-Token: " + shard_token)
	var url := _control_plane_url() + "/v1/tunnels/" + _tunnel_id.uri_encode() + "/response"
	var backoff := 0.5
	for attempt in range(MAX_RESPONSE_RETRIES):
		if not _is_generation_active(generation):
			return false
		if deadline_ms >= 0 and Time.get_ticks_msec() >= deadline_ms:
			return false
		var response := await _request_json(HTTPClient.METHOD_POST, url, headers, body_text)
		var code := int(response.get("code", 0))
		if code >= 200 and code < 300:
			return true
		if code == 404:
			# The control plane already considers this command terminal.
			return true
		if code == 401 or code == 403:
			_fail_auth("Tunnel authorization expired while posting a response.")
			return false
		if not (code == 0 or code == 408 or code == 429 or code == 502 or code == 503 or code == 504):
			_emit_log("Tunnel response POST failed with HTTP %d." % code)
			return false
		if attempt + 1 < MAX_RESPONSE_RETRIES:
			await _backoff_delay(backoff, generation, deadline_ms)
			backoff = minf(backoff * 2.0, 4.0)
	return false


func _request_json(method: int, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = HTTP_TIMEOUT_SECONDS
	add_child(request)
	var err := request.request(url, headers, method, body)
	if err != OK:
		request.queue_free()
		return {"code": 0, "result": err, "json": null, "received_at_ms": Time.get_ticks_msec()}
	var completed: Array = await request.request_completed
	var received_at_ms := Time.get_ticks_msec()
	request.queue_free()
	if completed.size() < 4:
		return {"code": 0, "result": -1, "json": null, "received_at_ms": received_at_ms}
	var result := int(completed[0])
	var code := int(completed[1])
	var body_bytes: PackedByteArray = completed[3]
	var text := body_bytes.get_string_from_utf8()
	var parsed = null
	if not text.is_empty():
		parsed = JSON.parse_string(text)
	return {
		"result": result,
		"code": code,
		"headers": completed[2],
		"text": text,
		"json": parsed,
		"received_at_ms": received_at_ms,
	}


func _common_headers() -> PackedStringArray:
	return PackedStringArray([
		"Authorization: Bearer " + _api_key,
		"Accept: application/json",
		"X-Tunnel-Client-Name: " + CLIENT_NAME,
		"X-Tunnel-Client-Version: " + PLUGIN_VERSION,
		"X-Tunnel-Client-Wire-Protocol-Version: " + WIRE_PROTOCOL_VERSION,
		"X-Tunnel-Client-Instance-Id: " + _client_instance_id,
		"X-Tunnel-MCP-Server-Info: " + _server_info_header(),
	])


func _server_info_header() -> String:
	var info := {
		"version": 1,
		"channels": [{"name": "main", "proc_affinity": true}],
	}
	return JSON.stringify(info, "", false)


func _control_plane_url() -> String:
	var override := OS.get_environment(CONTROL_PLANE_URL_ENV).strip_edges()
	if not override.is_empty():
		return override.trim_suffix("/")
	return DEFAULT_CONTROL_PLANE_URL


func _parse_response_timeout_ms(value) -> int:
	if value == null or not value is String:
		return -1
	var text: String = value
	var regex := RegEx.new()
	if regex.compile("^([0-9]+)(ns|us|ms|s|m|h)$") != OK:
		return -1
	var match := regex.search(text)
	if match == null:
		return -1
	var digits := match.get_string(1)
	if digits.length() > 15:
		return -1
	var amount := int(digits)
	var unit := match.get_string(2)
	match unit:
		"ns", "us":
			return 0 if amount == 0 else maxi(1, int(ceil(float(amount) / (1000000.0 if unit == "ns" else 1000.0))))
		"ms":
			return amount
		"s":
			return _safe_multiply_timeout(amount, 1000)
		"m":
			return _safe_multiply_timeout(amount, 60000)
		"h":
			return _safe_multiply_timeout(amount, 3600000)
	return -1


func _safe_multiply_timeout(amount: int, multiplier: int) -> int:
	if amount > 9223372036854775807 / multiplier:
		return -1
	return amount * multiplier


func _backoff_delay(seconds: float, generation: int, deadline_ms: int = -1) -> void:
	if not _is_generation_active(generation):
		return
	var jitter := randf_range(0.0, seconds * 0.25)
	var delay := seconds + jitter
	if deadline_ms >= 0:
		var remaining := float(deadline_ms - Time.get_ticks_msec()) / 1000.0
		if remaining <= 0.0:
			return
		delay = minf(delay, remaining)
	await get_tree().create_timer(maxf(delay, 0.01)).timeout


func _rpc_result(rpc_id, result) -> Dictionary:
	return {"jsonrpc": "2.0", "id": rpc_id, "result": result}


func _rpc_error(rpc_id, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": rpc_id, "error": {"code": code, "message": message}}


func _save_tunnel_id() -> void:
	if _editor_settings == null:
		return
	_editor_settings.set_setting(EDITOR_TUNNEL_ID_SETTING, _tunnel_id)
	# Clean up plaintext keys that may have been written by development builds before 0.2.2.
	if _editor_settings.has_setting(EDITOR_API_KEY_SETTING):
		_editor_settings.set_setting(EDITOR_API_KEY_SETTING, null)


func _fail_auth(message: String) -> void:
	_should_connect = false
	_generation += 1
	_set_state("authentication_failed")
	_emit_log(message)


func _is_generation_active(generation: int) -> bool:
	return _should_connect and generation == _generation and is_inside_tree()


func _set_state(value: String) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(_state)


func _emit_log(message: String) -> void:
	log_message.emit(message)
	print("[GodotMCPChatGPT] %s" % message)


func _generate_instance_id() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(16)
	if bytes.size() == 16:
		return bytes.hex_encode()
	return "%d-%d" % [Time.get_ticks_usec(), randi()]
