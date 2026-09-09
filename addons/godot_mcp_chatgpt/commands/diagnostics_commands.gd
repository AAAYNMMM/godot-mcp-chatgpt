@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const RUNNER_PATH := "res://addons/godot_mcp_chatgpt/bin/windows/godot-mcp-runner.exe"
const DEFAULT_TIMEOUT_MS := 10000
const DEFAULT_MAX_OUTPUT_BYTES := 1048576
const DEFAULT_QUIT_AFTER := 10
const MAX_USER_ARGS := 32
const MAX_USER_ARG_LENGTH := 1024

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
	registry.add_command(
		"diagnostics.run_capture",
		"Run the current Godot project in a bounded child process and capture stdout, stderr, exit state, duration, and timeout state separately.",
		{
			"type": "object",
			"properties": {
				"scene": {"type": "string"},
				"quit_after": {"type": "integer", "minimum": 1, "maximum": 36000},
				"timeout_ms": {"type": "integer", "minimum": 100, "maximum": 120000},
				"max_output_bytes": {"type": "integer", "minimum": 4096, "maximum": 8388608},
				"headless": {"type": "boolean"},
				"user_args": {"type": "array", "items": {"type": "string"}, "maxItems": MAX_USER_ARGS},
			},
			"additionalProperties": false,
		},
		func(args): return _run_capture(plugin, args),
		{"readOnlyHint": true, "destructiveHint": false}
	)

static func _run_capture(_plugin: EditorPlugin, args: Dictionary) -> Dictionary:
	if OS.get_name() != "Windows":
		return U.error("UNSUPPORTED_PLATFORM", "Captured-run diagnostics are currently packaged for Windows only")
	if not FileAccess.file_exists(RUNNER_PATH):
		return U.error("RUNNER_MISSING", "Captured-run helper is missing from this plugin build")

	var scene := str(args.get("scene", "")).strip_edges()
	if not scene.is_empty():
		if not U.valid_res_path(scene):
			return U.error("INVALID_SCENE_PATH", "Scene must stay inside res://")
		var extension := scene.get_extension().to_lower()
		if extension not in ["tscn", "scn"]:
			return U.error("INVALID_SCENE_PATH", "Scene must be a .tscn or .scn file")
		if not ResourceLoader.exists(scene):
			return U.error("SCENE_NOT_FOUND", "Scene does not exist: %s" % scene)

	var quit_after := clampi(int(args.get("quit_after", DEFAULT_QUIT_AFTER)), 1, 36000)
	var timeout_ms := clampi(int(args.get("timeout_ms", DEFAULT_TIMEOUT_MS)), 100, 120000)
	var max_output_bytes := clampi(int(args.get("max_output_bytes", DEFAULT_MAX_OUTPUT_BYTES)), 4096, 8388608)
	var headless := bool(args.get("headless", true))

	var user_args: Array = args.get("user_args", [])
	if user_args.size() > MAX_USER_ARGS:
		return U.error("TOO_MANY_USER_ARGS", "user_args is limited to %d entries" % MAX_USER_ARGS)
	var clean_user_args: PackedStringArray = []
	for raw in user_args:
		var value := str(raw)
		if value.length() > MAX_USER_ARG_LENGTH:
			return U.error("USER_ARG_TOO_LONG", "Each user argument is limited to %d characters" % MAX_USER_ARG_LENGTH)
		clean_user_args.append(value)

	var godot_executable := OS.get_executable_path()
	if godot_executable.is_empty() or not FileAccess.file_exists(godot_executable):
		return U.error("GODOT_EXECUTABLE_NOT_FOUND", "Unable to resolve the current Godot executable")

	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var godot_args := PackedStringArray(["--path", project_dir, "--quit-after", str(quit_after), "--no-header"])
	if headless:
		godot_args.append("--headless")
	if not scene.is_empty():
		godot_args.append("--scene")
		godot_args.append(scene)
	if not clean_user_args.is_empty():
		godot_args.append("--")
		godot_args.append_array(clean_user_args)

	var helper_args := PackedStringArray([
		"--timeout-ms", str(timeout_ms),
		"--max-output-bytes", str(max_output_bytes),
		"--",
		godot_executable,
	])
	helper_args.append_array(godot_args)

	var helper_output: Array = []
	var helper_code := OS.execute(ProjectSettings.globalize_path(RUNNER_PATH), helper_args, helper_output, true)
	if helper_output.is_empty():
		return U.error("RUNNER_NO_OUTPUT", "Captured-run helper returned no structured result")
	var raw_json := "\n".join(PackedStringArray(helper_output)).strip_edges()
	var parsed = JSON.parse_string(raw_json)
	if not parsed is Dictionary:
		return U.error("RUNNER_INVALID_OUTPUT", "Captured-run helper returned invalid JSON")
	var process_result: Dictionary = parsed
	if helper_code != 0 and int(process_result.get("exit_code", -1)) == -1:
		return U.error("RUNNER_FAILED", str(process_result.get("error", "Captured-run helper failed")))

	return U.ok({
		"process_ok": bool(process_result.get("ok", false)),
		"exit_code": int(process_result.get("exit_code", -1)),
		"timed_out": bool(process_result.get("timed_out", false)),
		"duration_ms": int(process_result.get("duration_ms", 0)),
		"stdout": str(process_result.get("stdout", "")),
		"stderr": str(process_result.get("stderr", "")),
		"stdout_truncated": bool(process_result.get("stdout_truncated", false)),
		"stderr_truncated": bool(process_result.get("stderr_truncated", false)),
		"runner_error": str(process_result.get("error", "")),
		"scene": scene,
		"quit_after": quit_after,
		"headless": headless,
	})
