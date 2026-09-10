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
const ObservationCommands := preload("res://addons/godot_mcp_chatgpt/commands/observation_commands.gd")
const WorkflowCommands := preload("res://addons/godot_mcp_chatgpt/commands/workflow_commands.gd")
const AnimationAuthoringCommands := preload("res://addons/godot_mcp_chatgpt/commands/animation_authoring_commands.gd")
const MediaAuthoringCommands := preload("res://addons/godot_mcp_chatgpt/commands/media_authoring_commands.gd")
const UIResourceAuthoringCommands := preload("res://addons/godot_mcp_chatgpt/commands/ui_resource_authoring_commands.gd")
const WorldAuthoringCommands := preload("res://addons/godot_mcp_chatgpt/commands/world_authoring_commands.gd")
const CustomToolCommands := preload("res://addons/godot_mcp_chatgpt/commands/custom_tool_commands.gd")
const CustomToolRegistry := preload("res://addons/godot_mcp_chatgpt/custom/custom_tool_registry.gd")
const LogCapture := preload("res://addons/godot_mcp_chatgpt/debug/log_capture.gd")
const DiagnosticsCommands := preload("res://addons/godot_mcp_chatgpt/commands/diagnostics_commands.gd")
const BatchCommands := preload("res://addons/godot_mcp_chatgpt/commands/batch_commands.gd")
const ConnectionDock := preload("res://addons/godot_mcp_chatgpt/ui/connection_dock.gd")

var _registry: RefCounted
var _client: Node
var _dock: Control
var _bottom_button: Button
var _runtime_manager: Node
var _editor_logger: Logger
var _custom_tools: RefCounted

func _enter_tree() -> void:
	_editor_logger = LogCapture.new()
	OS.add_logger(_editor_logger)
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
	ObservationCommands.register(_registry, self, _runtime_manager, _editor_logger)
	WorkflowCommands.register(_registry, self)
	AnimationAuthoringCommands.register(_registry, self)
	MediaAuthoringCommands.register(_registry, self)
	UIResourceAuthoringCommands.register(_registry, self)
	WorldAuthoringCommands.register(_registry, self)
	_custom_tools = CustomToolRegistry.new()
	var custom_setup: Dictionary = _custom_tools.setup(get_editor_interface().get_editor_settings())
	if not bool(custom_setup.get("ok", false)):
		push_warning("[GodotMCPChatGPT] Custom tool registry setup: %s" % str(custom_setup))
	CustomToolCommands.register(_registry, _custom_tools)
	DiagnosticsCommands.register(_registry, self)
	BatchCommands.register(_registry, self)

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
	if _editor_logger != null:
		OS.remove_logger(_editor_logger)
		_editor_logger = null
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
	if _custom_tools != null:
		_custom_tools.shutdown()
		_custom_tools = null
	_registry = null
