@tool
extends Node

signal log_message(message: String)

const PLUGIN_VERSION := "0.4.0"
const CLIENT_NAME := "godot-mcp-chatgpt"
const MCP_PROTOCOL_VERSION := "2025-11-25"
const MCP_SUPPORTED_VERSIONS := ["2026-07-28", "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
const MAX_BODY_BYTES := 1048576
const PublicToolSurface := preload("res://addons/godot_mcp_chatgpt/core/public_tool_surface.gd")

var _registry: RefCounted
var _public_surface: RefCounted
var _server := TCPServer.new()
var _port := 0
var _path := ""
var _connections: Dictionary = {}
var _request_queue: Array[Dictionary] = []
var _dispatching := false

func set_registry(registry: RefCounted) -> void:
	_registry = registry
	_public_surface = PublicToolSurface.new()
	var setup_result: Dictionary = _public_surface.setup(registry)
	if not bool(setup_result.get("ok", false)):
		push_error("[GodotMCPChatGPT] Public tool surface setup failed: %s" % str(setup_result))

func start_server() -> Dictionary:
	if _server.is_listening():
		return {"ok": true, "endpoint": endpoint(), "port": _port}
	for attempt in range(64):
		var candidate := 39000 + randi_range(0, 9999)
		var err := _server.listen(candidate, "127.0.0.1")
		if err == OK:
			_port = candidate
			_path = "/mcp/" + _random_token(24)
			set_process(true)
			_emit_log("Local Streamable HTTP MCP ready on loopback.")
			return {"ok": true, "endpoint": endpoint(), "port": _port}
	return {"ok": false, "error": "Unable to bind a loopback MCP port"}

func stop_server() -> void:
	set_process(false)
	for connection in _connections.values():
		var peer = connection.get("peer")
		if peer is StreamPeerTCP:
			peer.disconnect_from_host()
	_connections.clear()
	_request_queue.clear()
	_dispatching = false
	if _server.is_listening():
		_server.stop()
	_port = 0
	_path = ""

func endpoint() -> String:
	if _port <= 0 or _path.is_empty():
		return ""
	return "http://127.0.0.1:%d%s" % [_port, _path]

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer != null:
			_connections[peer.get_instance_id()] = {"peer": peer, "buffer": PackedByteArray(), "queued": false}

	var remove_ids: Array[int] = []
	for id_value in _connections.keys():
		var id := int(id_value)
		var connection: Dictionary = _connections[id]
		var peer: StreamPeerTCP = connection["peer"]
		peer.poll()
		var status := peer.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			if not bool(connection.get("queued", false)):
				var available := peer.get_available_bytes()
				if available > 0:
					var read_result := peer.get_data(available)
					if int(read_result[0]) == OK:
						var buffer: PackedByteArray = connection["buffer"]
						buffer.append_array(read_result[1])
						connection["buffer"] = buffer
						_connections[id] = connection
						_try_parse_request(id)
		elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			remove_ids.append(id)
	for id in remove_ids:
		_connections.erase(id)

func _try_parse_request(connection_id: int) -> void:
	if not _connections.has(connection_id):
		return
	var connection: Dictionary = _connections[connection_id]
	var buffer: PackedByteArray = connection["buffer"]
	var header_end := _find_header_end(buffer)
	if header_end < 0:
		if buffer.size() > 65536:
			_send_http(connection_id, 431, "Request Header Fields Too Large", "", "text/plain")
		return
	var header_text := buffer.slice(0, header_end).get_string_from_utf8()
	var lines := header_text.split("\r\n")
	if lines.is_empty():
		_send_http(connection_id, 400, "Bad Request", "", "text/plain")
		return
	var request_line := str(lines[0]).split(" ", false)
	if request_line.size() < 2:
		_send_http(connection_id, 400, "Bad Request", "", "text/plain")
		return
	var method := str(request_line[0]).to_upper()
	var request_path := str(request_line[1])
	var headers: Dictionary = {}
	var content_length := 0
	for index in range(1, lines.size()):
		var line := str(lines[index])
		var colon := line.find(":")
		if colon <= 0:
			continue
		var name := line.substr(0, colon).strip_edges().to_lower()
		var value := line.substr(colon + 1).strip_edges()
		headers[name] = value
		if name == "content-length":
			content_length = int(value)
	if content_length < 0 or content_length > MAX_BODY_BYTES:
		_send_http(connection_id, 413, "Payload Too Large", "", "text/plain")
		return
	var body_start := header_end + 4
	if buffer.size() < body_start + content_length:
		return
	var body := ""
	if content_length > 0:
		body = buffer.slice(body_start, body_start + content_length).get_string_from_utf8()
	connection["queued"] = true
	_connections[connection_id] = connection
	_request_queue.append({"connection_id": connection_id, "method": method, "path": request_path, "headers": headers, "body": body})
	if not _dispatching:
		_drain_queue()

func _drain_queue() -> void:
	if _dispatching:
		return
	_dispatching = true
	while not _request_queue.is_empty():
		var request: Dictionary = _request_queue.pop_front()
		await _handle_http_request(request)
	_dispatching = false

func _handle_http_request(request: Dictionary) -> void:
	var id := int(request.get("connection_id", 0))
	if str(request.get("path", "")) != _path:
		_send_http(id, 404, "Not Found", "", "text/plain")
		return
	var http_method := str(request.get("method", ""))
	if http_method == "DELETE":
		# Stateless transport: there is no server-side session to destroy, but
		# Streamable HTTP clients may still request termination. Acknowledge it.
		_send_http(id, 204, "No Content", "", "")
		return
	if http_method != "POST":
		_send_http(id, 405, "Method Not Allowed", "", "text/plain")
		return
	var body := str(request.get("body", ""))
	if body.is_empty():
		# tunnel-client performs an unauthenticated empty POST while probing for OAuth.
		# Match the SDK-backed CWapi surface with a quiet bad-request response.
		_send_http(id, 400, "Bad Request", "", "text/plain")
		return
	var parsed = JSON.parse_string(body)
	if not parsed is Dictionary:
		_send_mcp_response(id, _rpc_error(null, -32700, "Parse error"), request.get("headers", {}), 400)
		return
	var rpc: Dictionary = parsed
	if not rpc.has("id"):
		# Match the behavior of the SDK-backed CWapi Streamable HTTP MCP.
		_send_http(id, 202, "Accepted", "", "application/json")
		return
	var response := await _dispatch_jsonrpc(rpc)
	_send_mcp_response(id, response, request.get("headers", {}), 200)

func _dispatch_jsonrpc(rpc: Dictionary) -> Dictionary:
	var rpc_id = rpc.get("id")
	if str(rpc.get("jsonrpc", "")) != "2.0" or not rpc.has("method"):
		return _rpc_error(rpc_id, -32600, "Invalid Request")
	var method := str(rpc.get("method", ""))
	var params_value = rpc.get("params", {})
	var params: Dictionary = params_value if params_value is Dictionary else {}
	match method:
		"server/discover":
			return _rpc_result(rpc_id, {
				"ttlMs": 0,
				"cacheScope": "public",
				"supportedVersions": MCP_SUPPORTED_VERSIONS,
				"capabilities": {"tools": {"listChanged": true}},
			})
		"initialize":
			return _rpc_result(rpc_id, {
				"protocolVersion": MCP_PROTOCOL_VERSION,
				"capabilities": {"logging": {}, "tools": {"listChanged": true}},
				"serverInfo": {"name": CLIENT_NAME, "version": PLUGIN_VERSION},
			})
		"ping":
			return _rpc_result(rpc_id, {})
		"tools/list":
			return _rpc_result(rpc_id, {"ttlMs": 0, "cacheScope": "public", "tools": _mcp_tool_catalogue()})
		"tools/call":
			var name := str(params.get("name", ""))
			var args_value = params.get("arguments", {})
			var args: Dictionary = args_value if args_value is Dictionary else {}
			var result: Dictionary = await _public_surface.call_tool(name, args) if _public_surface != null else {"ok": false, "error": {"code": "PUBLIC_SURFACE_UNAVAILABLE", "message": "Public MCP tool surface is unavailable"}}
			return _rpc_result(rpc_id, _format_tool_result(result))
		_:
			return _rpc_error(rpc_id, -32601, "method not found: %s" % JSON.stringify(method))

func _format_tool_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return {"content": [{"type": "text", "text": JSON.stringify(result.get("error"))}], "isError": true}
	var value = result.get("result")
	if value is Dictionary and value.has("__mcp_image"):
		var metadata: Dictionary = value.duplicate(true)
		var image_value = metadata.get("__mcp_image", {})
		metadata.erase("__mcp_image")
		var content: Array = [{"type": "text", "text": JSON.stringify(metadata)}]
		if image_value is Dictionary:
			var image: Dictionary = image_value
			var data := str(image.get("data", ""))
			if not data.is_empty():
				content.append({"type": "image", "data": data, "mimeType": str(image.get("mime_type", "image/png"))})
		return {"content": content}
	return {"content": [{"type": "text", "text": JSON.stringify(value)}]}

func _mcp_tool_catalogue() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var sources: Array = _public_surface.catalogue() if _public_surface != null else []
	for source in sources:
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

func _send_mcp_response(connection_id: int, payload: Dictionary, headers: Dictionary, status_code: int) -> void:
	var accept := str(headers.get("accept", "")).to_lower()
	var json_text := JSON.stringify(payload)
	if accept.contains("text/event-stream"):
		var sse := "event: message\ndata: %s\n\n" % json_text
		_send_http(connection_id, status_code, "OK", sse, "text/event-stream")
	else:
		_send_http(connection_id, status_code, "OK", json_text, "application/json")

func _send_http(connection_id: int, status_code: int, reason: String, body: String, content_type: String) -> void:
	if not _connections.has(connection_id):
		return
	var connection: Dictionary = _connections[connection_id]
	var peer: StreamPeerTCP = connection["peer"]
	var body_bytes := body.to_utf8_buffer()
	var header := "HTTP/1.1 %d %s\r\n" % [status_code, reason]
	if not content_type.is_empty():
		header += "Content-Type: %s\r\n" % content_type
	header += "Content-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n" % body_bytes.size()
	peer.put_data(header.to_utf8_buffer())
	if body_bytes.size() > 0:
		peer.put_data(body_bytes)
	peer.disconnect_from_host()
	_connections.erase(connection_id)

func _find_header_end(buffer: PackedByteArray) -> int:
	if buffer.size() < 4:
		return -1
	for index in range(buffer.size() - 3):
		if buffer[index] == 13 and buffer[index + 1] == 10 and buffer[index + 2] == 13 and buffer[index + 3] == 10:
			return index
	return -1

func _rpc_result(rpc_id, result) -> Dictionary:
	return {"jsonrpc": "2.0", "id": rpc_id, "result": result}

func _rpc_error(rpc_id, code: int, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": rpc_id, "error": {"code": code, "message": message}}

func _random_token(byte_count: int) -> String:
	var bytes := Crypto.new().generate_random_bytes(byte_count)
	return bytes.hex_encode() if bytes.size() == byte_count else "%x%x" % [Time.get_ticks_usec(), randi()]

func _emit_log(message: String) -> void:
	log_message.emit(message)
	print("[GodotMCPChatGPT] %s" % message)