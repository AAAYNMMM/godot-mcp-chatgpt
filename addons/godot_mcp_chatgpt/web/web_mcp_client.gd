@tool
extends Node

signal state_changed(state: String)
signal log_message(message: String)

const PROTOCOL_VERSION := "godot-mcp-chatgpt/1"
const RELAY_URL_SETTING := "godot_mcp_chatgpt/relay_url"
const RELAY_URL_ENV := "GODOT_MCP_CHATGPT_RELAY_URL"
const EDITOR_TUNNEL_ID_SETTING := "godot_mcp_chatgpt/tunnel_id"
const EDITOR_API_KEY_SETTING := "godot_mcp_chatgpt/api_key"
const RECONNECT_DELAY_MS := 2000

var _registry: RefCounted
var _editor_settings: EditorSettings
var _peer: WebSocketPeer
var _state := "disconnected"
var _tunnel_id := ""
var _api_key := ""
var _should_reconnect := false
var _handshake_sent := false
var _next_reconnect_at := 0
var _request_queue: Array[Dictionary] = []
var _dispatching := false

func _ready() -> void:
	set_process(true)

func set_registry(registry: RefCounted) -> void:
	_registry = registry

func set_editor_settings(settings: EditorSettings) -> void:
	_editor_settings = settings

func get_state() -> String:
	return _state

func get_saved_tunnel_id() -> String:
	if _editor_settings == null:
		return ""
	return str(_editor_settings.get_setting(EDITOR_TUNNEL_ID_SETTING, ""))

func get_saved_api_key() -> String:
	if _editor_settings == null:
		return ""
	return str(_editor_settings.get_setting(EDITOR_API_KEY_SETTING, ""))

func connect_to_relay(tunnel_id: String, api_key: String) -> void:
	_tunnel_id = tunnel_id.strip_edges()
	_api_key = api_key.strip_edges()
	if _tunnel_id.is_empty() or _api_key.is_empty():
		_set_state("credentials_required")
		_emit_log("Tunnel ID and API Key are required.")
		return

	var relay_url := _resolve_relay_url()
	if relay_url.is_empty():
		_set_state("relay_not_configured")
		_emit_log("Relay endpoint is not configured in this build.")
		return

	_save_credentials()
	_should_reconnect = true
	_open_socket(relay_url)

func disconnect_from_relay() -> void:
	_should_reconnect = false
	_request_queue.clear()
	_dispatching = false
	if _peer != null:
		_peer.close(1000, "user disconnect")
		_peer.poll()
	_peer = null
	_handshake_sent = false
	_set_state("disconnected")

func _process(_delta: float) -> void:
	if _peer == null:
		_maybe_reconnect()
		return

	_peer.poll()
	var ready_state := _peer.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN:
		if not _handshake_sent:
			_send_registration()
		while _peer.get_available_packet_count() > 0:
			_handle_packet(_peer.get_packet().get_string_from_utf8())
		return

	if ready_state == WebSocketPeer.STATE_CLOSING:
		return

	if ready_state == WebSocketPeer.STATE_CLOSED:
		var code := _peer.get_close_code()
		_peer = null
		_handshake_sent = false
		if _should_reconnect:
			_set_state("reconnecting")
			_next_reconnect_at = Time.get_ticks_msec() + RECONNECT_DELAY_MS
			_emit_log("Relay disconnected (code %d); reconnect scheduled." % code)
		else:
			_set_state("disconnected")

func _open_socket(relay_url: String) -> void:
	_peer = WebSocketPeer.new()
	_peer.handshake_headers = PackedStringArray(["User-Agent: godot-mcp-chatgpt/0.1.0"])
	var err := _peer.connect_to_url(relay_url)
	if err != OK:
		_peer = null
		_set_state("connection_error")
		_emit_log("Unable to start relay connection: %s" % error_string(err))
		_next_reconnect_at = Time.get_ticks_msec() + RECONNECT_DELAY_MS
		return
	_handshake_sent = false
	_set_state("connecting")

func _maybe_reconnect() -> void:
	if not _should_reconnect:
		return
	if Time.get_ticks_msec() < _next_reconnect_at:
		return
	var relay_url := _resolve_relay_url()
	if relay_url.is_empty():
		_should_reconnect = false
		_set_state("relay_not_configured")
		return
	_open_socket(relay_url)

func _send_registration() -> void:
	if _registry == null:
		_set_state("registry_unavailable")
		return
	var payload := {
		"type": "register",
		"protocol": PROTOCOL_VERSION,
		"tunnel_id": _tunnel_id,
		"api_key": _api_key,
		"client": {
			"plugin_version": "0.1.0",
			"godot_version": Engine.get_version_info().get("string", "unknown"),
			"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
		},
		"tools": _registry.catalogue(),
	}
	_send_json(payload)
	_handshake_sent = true
	_set_state("authenticating")

func _handle_packet(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		_emit_log("Ignored malformed relay message.")
		return
	var message: Dictionary = parsed
	match str(message.get("type", "")):
		"registered":
			_set_state("connected")
			_emit_log("Web MCP relay connected.")
		"tool_call":
			_request_queue.append(message)
			if not _dispatching:
				_drain_queue()
		"ping":
			_send_json({"type": "pong", "ts": message.get("ts", 0)})
		"error":
			var code := str(message.get("code", "REMOTE_ERROR"))
			var detail := str(message.get("message", "Relay rejected the request."))
			_emit_log("Relay error %s: %s" % [code, detail])
			if bool(message.get("fatal", false)):
				_should_reconnect = false
				_set_state("authentication_failed" if code == "AUTH_FAILED" else "connection_error")
				if _peer != null:
					_peer.close(1008, code)
		_:
			_emit_log("Ignored unsupported relay message type.")

func _drain_queue() -> void:
	if _dispatching:
		return
	_dispatching = true
	while not _request_queue.is_empty():
		var request: Dictionary = _request_queue.pop_front()
		await _execute_request(request)
	_dispatching = false

func _execute_request(request: Dictionary) -> void:
	var request_id := str(request.get("request_id", ""))
	var method := str(request.get("name", ""))
	var arguments_value = request.get("arguments", {})
	var arguments: Dictionary = arguments_value if arguments_value is Dictionary else {}
	if request_id.is_empty() or method.is_empty():
		_send_json({
			"type": "tool_result",
			"request_id": request_id,
			"ok": false,
			"error": {"code": "INVALID_REQUEST", "message": "request_id and name are required"},
		})
		return
	if _registry == null:
		_send_json({
			"type": "tool_result",
			"request_id": request_id,
			"ok": false,
			"error": {"code": "REGISTRY_UNAVAILABLE", "message": "Godot command registry is unavailable"},
		})
		return
	var result: Dictionary = await _registry.call_command(method, arguments)
	_send_json({
		"type": "tool_result",
		"request_id": request_id,
		"ok": bool(result.get("ok", false)),
		"result": result.get("result"),
		"error": result.get("error"),
	})

func _send_json(payload: Dictionary) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_peer.send_text(JSON.stringify(payload))

func _resolve_relay_url() -> String:
	var from_env := OS.get_environment(RELAY_URL_ENV).strip_edges()
	if not from_env.is_empty():
		return from_env
	return str(ProjectSettings.get_setting(RELAY_URL_SETTING, "")).strip_edges()

func _save_credentials() -> void:
	if _editor_settings == null:
		return
	_editor_settings.set_setting(EDITOR_TUNNEL_ID_SETTING, _tunnel_id)
	_editor_settings.set_setting(EDITOR_API_KEY_SETTING, _api_key)

func _set_state(value: String) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(_state)

func _emit_log(message: String) -> void:
	log_message.emit(message)
	print("[GodotMCPChatGPT] %s" % message)
