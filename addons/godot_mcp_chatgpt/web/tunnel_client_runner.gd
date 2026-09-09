@tool
extends Node

signal state_changed(state: String)
signal log_message(message: String)

const PLUGIN_VERSION := "0.3.0"
const TUNNEL_CLIENT_ENV := "GODOT_MCP_CHATGPT_TUNNEL_CLIENT"
const CONTROL_PLANE_URL_ENV := "GODOT_MCP_CHATGPT_CONTROL_PLANE_URL"
const TUNNEL_ID_ENV := "GODOT_MCP_CHATGPT_TUNNEL_ID"
const API_KEY_ENV := "GODOT_MCP_CHATGPT_API_KEY"
const TEST_MODE_ENV := "GODOT_MCP_CHATGPT_TEST_MODE"
const TEST_TUNNEL_ID := "tunnel_0123456789abcdef0123456789abcdef"
const TEST_API_KEY := "devkey_123456789012345678901234567890"
const EDITOR_TUNNEL_ID_SETTING := "godot_mcp_chatgpt/tunnel_id"
const LEGACY_EDITOR_API_KEY_SETTING := "godot_mcp_chatgpt/api_key"
const LocalMCPServer := preload("res://addons/godot_mcp_chatgpt/web/local_mcp_server.gd")

var _registry: RefCounted
var _editor_settings: EditorSettings
var _local_server: Node
var _state := "disconnected"
var _tunnel_id := ""
var _api_key := ""
var _pid := -1
var _runtime_path := ""
var _profile_path := ""

func _ready() -> void:
	set_process(true)
	if OS.get_environment(TEST_MODE_ENV) == "1":
		call_deferred("connect_to_tunnel", TEST_TUNNEL_ID, TEST_API_KEY)
		return
	var dev_tunnel := OS.get_environment(TUNNEL_ID_ENV).strip_edges()
	var dev_key := OS.get_environment(API_KEY_ENV).strip_edges()
	if not dev_tunnel.is_empty() and not dev_key.is_empty():
		call_deferred("connect_to_tunnel", dev_tunnel, dev_key)
	else:
		_emit_log("Waiting for OpenAI Tunnel ID and Runtime API Key.")

func set_registry(registry: RefCounted) -> void:
	_registry = registry

func set_editor_settings(settings: EditorSettings) -> void:
	_editor_settings = settings
	_clear_legacy_saved_api_key()

func get_state() -> String:
	return _state

func get_saved_tunnel_id() -> String:
	if _editor_settings == null or not _editor_settings.has_setting(EDITOR_TUNNEL_ID_SETTING):
		return ""
	return str(_editor_settings.get_setting(EDITOR_TUNNEL_ID_SETTING))

func get_saved_api_key() -> String:
	return ""

func connect_to_tunnel(tunnel_id: String, api_key: String) -> void:
	if _state in ["starting", "connected"]:
		disconnect_from_tunnel()
	_tunnel_id = tunnel_id.strip_edges()
	_api_key = api_key.strip_edges()
	if _tunnel_id.is_empty() or _api_key.is_empty():
		_set_state("credentials_required")
		_emit_log("Tunnel ID and Runtime API Key are required.")
		return
	_runtime_path = _resolve_tunnel_client()
	if _runtime_path.is_empty():
		_set_state("runtime_missing")
		_emit_log("Official OpenAI tunnel-client runtime was not found in this build.")
		return
	if _registry == null:
		_set_state("registry_unavailable")
		_emit_log("Godot command registry is unavailable.")
		return
	_save_tunnel_id()
	_local_server = LocalMCPServer.new()
	_local_server.name = "LocalMCPServer"
	_local_server.set_registry(_registry)
	_local_server.log_message.connect(_emit_log)
	add_child(_local_server)
	var started: Dictionary = _local_server.start_server()
	if not bool(started.get("ok", false)):
		_local_server.queue_free()
		_local_server = null
		_set_state("local_mcp_error")
		_emit_log(str(started.get("error", "Unable to start local MCP.")))
		return
	var profile_result := _write_profile(str(started.get("endpoint", "")))
	if not bool(profile_result.get("ok", false)):
		_stop_local_server()
		_set_state("profile_error")
		_emit_log(str(profile_result.get("error", "Unable to write tunnel profile.")))
		return
	_profile_path = str(profile_result.get("path", ""))
	_set_state("starting")
	_emit_log("Starting official OpenAI tunnel-client.")
	OS.set_environment("CONTROL_PLANE_API_KEY", _api_key)
	_pid = OS.create_process(_runtime_path, PackedStringArray(["run", "--profile-file", _profile_path]), false)
	OS.unset_environment("CONTROL_PLANE_API_KEY")
	if _pid <= 0:
		_stop_local_server()
		_set_state("runtime_error")
		_emit_log("Failed to start official OpenAI tunnel-client.")
		return
	_api_key = ""
	await get_tree().create_timer(1.0).timeout
	if _pid > 0 and OS.is_process_running(_pid):
		_set_state("connected")
		_emit_log("Official OpenAI tunnel-client is running.")
	else:
		_pid = -1
		_stop_local_server()
		_set_state("runtime_error")
		_emit_log("OpenAI tunnel-client exited during startup.")

func disconnect_from_tunnel() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	_api_key = ""
	_stop_local_server()
	_set_state("disconnected")
	_emit_log("Tunnel disconnected.")

func _process(_delta: float) -> void:
	if _pid > 0 and _state == "connected" and not OS.is_process_running(_pid):
		_pid = -1
		_stop_local_server()
		_set_state("runtime_error")
		_emit_log("OpenAI tunnel-client stopped unexpectedly.")

func _resolve_tunnel_client() -> String:
	var override := OS.get_environment(TUNNEL_CLIENT_ENV).strip_edges()
	if not override.is_empty() and FileAccess.file_exists(override):
		return override
	var bundled := "res://addons/godot_mcp_chatgpt/bin/windows/tunnel-client.exe"
	if FileAccess.file_exists(bundled):
		return ProjectSettings.globalize_path(bundled)
	return ""

func _write_profile(mcp_url: String) -> Dictionary:
	var base := "user://godot_mcp_chatgpt/tunnel"
	var absolute_dir := ProjectSettings.globalize_path(base)
	var dir_err := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return {"ok": false, "error": error_string(dir_err)}
	var path := base + "/openai-tunnel.yaml"
	var control_plane := "control_plane:\n  tunnel_id: %s\n  api_key: env:CONTROL_PLANE_API_KEY\n" % _yaml_quote(_tunnel_id)
	var control_plane_override := OS.get_environment(CONTROL_PLANE_URL_ENV).strip_edges()
	if not control_plane_override.is_empty():
		control_plane += "  base_url: %s\n" % _yaml_quote(control_plane_override.trim_suffix("/"))
	var profile := "config_version: 1\n" + control_plane + "log:\n  level: warn\n  format: struct-text\nhealth:\n  listen_addr: 127.0.0.1:0\nadmin_ui:\n  open_browser: false\nmcp:\n  server_urls:\n    - channel: main\n      url: %s\n" % _yaml_quote(mcp_url)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Unable to open tunnel profile for writing"}
	file.store_string(profile)
	file.close()
	return {"ok": true, "path": ProjectSettings.globalize_path(path)}

func _yaml_quote(value: String) -> String:
	return JSON.stringify(value)

func _stop_local_server() -> void:
	if _local_server != null:
		_local_server.stop_server()
		_local_server.queue_free()
		_local_server = null

func _save_tunnel_id() -> void:
	if _editor_settings != null:
		_editor_settings.set_setting(EDITOR_TUNNEL_ID_SETTING, _tunnel_id)

func _clear_legacy_saved_api_key() -> void:
	if _editor_settings != null and _editor_settings.has_setting(LEGACY_EDITOR_API_KEY_SETTING):
		_editor_settings.erase(LEGACY_EDITOR_API_KEY_SETTING)

func _set_state(value: String) -> void:
	if _state == value:
		return
	_state = value
	state_changed.emit(_state)

func _emit_log(message: String) -> void:
	log_message.emit(message)
	print("[GodotMCPChatGPT] %s" % message)