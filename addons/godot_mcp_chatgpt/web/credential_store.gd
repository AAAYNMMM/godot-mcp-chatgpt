@tool
extends RefCounted

const VALUE_ENV := "GODOT_MCP_CHATGPT_CREDENTIAL_VALUE"
const TEST_TARGET_ENV := "GODOT_MCP_CHATGPT_CREDENTIAL_TEST_TARGET"
const HELPER_PATH := "res://addons/godot_mcp_chatgpt/bin/windows/godot-mcp-credential.exe"

static func is_available() -> bool:
	return OS.get_name() == "Windows" and FileAccess.file_exists(HELPER_PATH)

static func read() -> Dictionary:
	if not is_available():
		return {"ok": false, "present": false, "value": "", "error": "Windows Credential Manager helper is unavailable"}
	var output: Array = []
	var code := OS.execute(ProjectSettings.globalize_path(HELPER_PATH), _helper_args("read"), output, true)
	if code == 3:
		return {"ok": true, "present": false, "value": ""}
	if code != 0:
		return {"ok": false, "present": false, "value": "", "error": _output_text(output, "Credential read failed")}
	var value := _output_text(output, "").strip_edges()
	if value.is_empty():
		return {"ok": false, "present": false, "value": "", "error": "Credential Manager returned an empty Runtime API Key"}
	return {"ok": true, "present": true, "value": value}

static func present() -> bool:
	var result := read()
	return bool(result.get("ok", false)) and bool(result.get("present", false))

static func write(value: String) -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "Windows Credential Manager helper is unavailable"}
	var clean := value.strip_edges()
	if clean.is_empty() or clean != value or clean.contains(" ") or clean.contains("\t") or clean.contains("\r") or clean.contains("\n"):
		return {"ok": false, "error": "Runtime API Key is invalid"}
	var output: Array = []
	OS.set_environment(VALUE_ENV, clean)
	var code := OS.execute(ProjectSettings.globalize_path(HELPER_PATH), _helper_args("write"), output, true)
	OS.unset_environment(VALUE_ENV)
	if code != 0:
		return {"ok": false, "error": _output_text(output, "Credential write failed")}
	return {"ok": true}

static func delete() -> Dictionary:
	if not is_available():
		return {"ok": false, "error": "Windows Credential Manager helper is unavailable"}
	var output: Array = []
	var code := OS.execute(ProjectSettings.globalize_path(HELPER_PATH), _helper_args("delete"), output, true)
	if code != 0:
		return {"ok": false, "error": _output_text(output, "Credential delete failed")}
	return {"ok": true}

static func _helper_args(command: String) -> PackedStringArray:
	var args := PackedStringArray([command])
	var test_target := OS.get_environment(TEST_TARGET_ENV).strip_edges()
	if not test_target.is_empty():
		args.append("--test-target")
		args.append(test_target)
	return args
static func _output_text(output: Array, fallback: String) -> String:
	var parts: PackedStringArray = []
	for item in output:
		var text := str(item).strip_edges()
		if not text.is_empty():
			parts.append(text)
	return fallback if parts.is_empty() else "\n".join(parts)