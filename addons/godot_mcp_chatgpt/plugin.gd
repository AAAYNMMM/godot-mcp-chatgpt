@tool
extends EditorPlugin

const TunnelClientRunner := preload("res://addons/godot_mcp_chatgpt/web/tunnel_client_runner.gd")
const CommandRegistry := preload("res://addons/godot_mcp_chatgpt/core/command_registry.gd")
const BuiltinCommands := preload("res://addons/godot_mcp_chatgpt/core/builtin_commands.gd")
const ProjectCommands := preload("res://addons/godot_mcp_chatgpt/commands/project_commands.gd")
const SceneNodeCommands := preload("res://addons/godot_mcp_chatgpt/commands/scene_node_commands.gd")
const ScriptResourceCommands := preload("res://addons/godot_mcp_chatgpt/commands/script_resource_commands.gd")
const ClassDBCommands := preload("res://addons/godot_mcp_chatgpt/commands/classdb_commands.gd")
const EditorCommands := preload("res://addons/godot_mcp_chatgpt/commands/editor_commands.gd")
const RuntimeDebuggerManager := preload("res://addons/godot_mcp_chatgpt/debug/runtime_debugger_manager.gd")
const RuntimeDebuggerCommands := preload("res://addons/godot_mcp_chatgpt/commands/runtime_debugger_commands.gd")
const DiagnosticsCommands := preload("res://addons/godot_mcp_chatgpt/commands/diagnostics_commands.gd")
const BatchCommands := preload("res://addons/godot_mcp_chatgpt/commands/batch_commands.gd")
const ConnectionDock := preload("res://addons/godot_mcp_chatgpt/ui/connection_dock.gd")

var _registry: RefCounted
var _client: Node
var _dock: Control
var _bottom_button: Button
var _runtime_manager: Node

func _enter_tree() -> void:
	print("[GodotMCPChatGPT] Editor plugin loaded.")
	_registry = CommandRegistry.new()
	BuiltinCommands.register(_registry, self)
	ProjectCommands.register(_registry, self)
	SceneNodeCommands.register(_registry, self)
	ScriptResourceCommands.register(_registry, self)
	ClassDBCommands.register(_registry, self)
	EditorCommands.register(_registry, self)

	_runtime_manager = RuntimeDebuggerManager.new()
	_runtime_manager.name = "RuntimeDebuggerManager"
	add_child(_runtime_manager)
	var runtime_setup: Dictionary = _runtime_manager.setup(self)
	if not bool(runtime_setup.get("ok", false)):
		push_warning("[GodotMCPChatGPT] Runtime debugger setup: %s" % str(runtime_setup))
	RuntimeDebuggerCommands.register(_registry, self, _runtime_manager)
	DiagnosticsCommands.register(_registry, self)
	BatchCommands.register(_registry)

	_client = TunnelClientRunner.new()
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

func _disable_plugin() -> void:
	if _runtime_manager != null:
		var cleanup: Dictionary = _runtime_manager.remove_runtime_autoload()
		if not bool(cleanup.get("ok", false)):
			push_warning("[GodotMCPChatGPT] Runtime autoload cleanup: %s" % str(cleanup))

func _exit_tree() -> void:
	if _runtime_manager != null:
		_runtime_manager.shutdown()
		_runtime_manager.queue_free()
		_runtime_manager = null
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
