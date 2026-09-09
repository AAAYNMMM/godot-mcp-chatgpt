@tool
extends EditorPlugin

const WebMCPClient := preload("res://addons/godot_mcp_chatgpt/web/web_mcp_client.gd")
const CommandRegistry := preload("res://addons/godot_mcp_chatgpt/core/command_registry.gd")
const BuiltinCommands := preload("res://addons/godot_mcp_chatgpt/core/builtin_commands.gd")
const ConnectionDock := preload("res://addons/godot_mcp_chatgpt/ui/connection_dock.gd")

var _registry: RefCounted
var _client: Node
var _dock: Control

func _enter_tree() -> void:
	_registry = CommandRegistry.new()
	BuiltinCommands.register(_registry, self)

	_client = WebMCPClient.new()
	_client.name = "WebMCPClient"
	_client.set_registry(_registry)
	_client.set_editor_settings(get_editor_interface().get_editor_settings())
	add_child(_client)

	_dock = ConnectionDock.new()
	_dock.name = "GodotMCPChatGPT"
	_dock.set_client(_client)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	if _client != null:
		_client.disconnect_from_relay()
		_client.queue_free()
		_client = null
	_registry = null
