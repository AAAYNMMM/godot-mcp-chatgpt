@tool
extends VBoxContainer

var _client: Node
var _tunnel_edit: LineEdit
var _api_key_edit: LineEdit
var _connect_button: Button
var _status_label: Label
var _log_label: Label

func _ready() -> void:
	_build_ui()
	_refresh_from_client()

func set_client(client: Node) -> void:
	_client = client
	if _client != null:
		_client.state_changed.connect(_on_state_changed)
		_client.log_message.connect(_on_log_message)
	if is_node_ready():
		_refresh_from_client()

func _build_ui() -> void:
	custom_minimum_size = Vector2(310, 0)

	var title := Label.new()
	title.text = "Godot MCP ChatGPT"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "OpenAI Secure MCP Tunnel (official tunnel-client)"
	subtitle.modulate.a = 0.7
	add_child(subtitle)

	add_child(HSeparator.new())

	var tunnel_label := Label.new()
	tunnel_label.text = "Tunnel ID"
	add_child(tunnel_label)
	_tunnel_edit = LineEdit.new()
	_tunnel_edit.placeholder_text = "tunnel_..."
	_tunnel_edit.clear_button_enabled = true
	add_child(_tunnel_edit)

	var key_label := Label.new()
	key_label.text = "API Key"
	add_child(key_label)
	_api_key_edit = LineEdit.new()
	_api_key_edit.placeholder_text = "Runtime API key"
	_api_key_edit.secret = true
	_api_key_edit.secret_character = "•"
	add_child(_api_key_edit)

	_connect_button = Button.new()
	_connect_button.text = "Connect"
	_connect_button.pressed.connect(_on_connect_pressed)
	add_child(_connect_button)

	_status_label = Label.new()
	_status_label.text = "Status: disconnected"
	add_child(_status_label)

	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.modulate.a = 0.75
	add_child(_log_label)

	var hint := Label.new()
	hint.text = "Only Tunnel ID and Runtime API Key are required. The addon runs the official OpenAI tunnel-client; the API Key is not written to the profile."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate.a = 0.6
	add_child(hint)

func _refresh_from_client() -> void:
	if _client == null or _tunnel_edit == null:
		return
	_tunnel_edit.text = _client.get_saved_tunnel_id()
	_api_key_edit.text = _client.get_saved_api_key()
	_on_state_changed(_client.get_state())

func _on_connect_pressed() -> void:
	if _client == null:
		return
	var state: String = str(_client.get_state())
	if state in ["starting", "connected"]:
		_client.disconnect_from_tunnel()
		return
	_client.connect_to_tunnel(_tunnel_edit.text, _api_key_edit.text)

func _on_state_changed(state: String) -> void:
	if _status_label == null:
		return
	_status_label.text = "Status: %s" % state
	if _connect_button != null:
		_connect_button.text = "Disconnect" if state in ["starting", "connected"] else "Connect"

func _on_log_message(message: String) -> void:
	if _log_label != null:
		_log_label.text = message
