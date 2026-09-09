@tool
extends EditorPlugin

const SecureTunnelClient := preload("res://addons/godot_mcp_chatgpt/web/secure_tunnel_client.gd")
const CommandRegistry := preload("res://addons/godot_mcp_chatgpt/core/command_registry.gd")
const BuiltinCommands := preload("res://addons/godot_mcp_chatgpt/core/builtin_commands.gd")
const ConnectionDock := preload("res://addons/godot_mcp_chatgpt/ui/connection_dock.gd")

var _registry: RefCounted
var _client: Node
var _dock: Control
var _bottom_button: Button

func _enter_tree() -> void:
	print("[GodotMCPChatGPT] Editor plugin loaded.")
	_registry = CommandRegistry.new()
	BuiltinCommands.register(_registry, self)

	_client = SecureTunnelClient.new()
	_client.name = "WebMCPClient"
	_client.set_registry(_registry)
	_client.set_editor_settings(get_editor_interface().get_editor_settings())
	add_child(_client)

	_dock = ConnectionDock.new()
	_dock.name = "GodotMCPChatGPT"
	_dock.set_client(_client)
	_bottom_button = add_control_to_bottom_panel(_dock, "MCP ChatGPT")
	call_deferred("_show_connection_panel")

func _show_connection_panel() -> void:
	if _dock != null and is_instance_valid(_dock):
		make_bottom_panel_item_visible(_dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
	_bottom_button = null
	if _client != null:
		_client.disconnect_from_tunnel()
		_client.queue_free()
		_client = null
	_registry = null
