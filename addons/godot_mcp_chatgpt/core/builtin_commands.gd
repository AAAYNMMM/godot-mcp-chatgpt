@tool
extends RefCounted

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
	registry.add_command(
		"godot.get_status",
		"Return the connected Godot editor status and version.",
		{"type": "object", "properties": {}, "additionalProperties": false},
		func(_args: Dictionary) -> Dictionary:
			return {
				"ok": true,
				"result": {
					"godot_version": Engine.get_version_info().get("string", "unknown"),
					"editor": Engine.is_editor_hint(),
					"project_name": str(ProjectSettings.get_setting("application/config/name", "")),
				}
			},
		{"readOnlyHint": true, "destructiveHint": false}
	)

	registry.add_command(
		"project.get_info",
		"Return basic information about the currently open Godot project.",
		{"type": "object", "properties": {}, "additionalProperties": false},
		func(_args: Dictionary) -> Dictionary:
			var editor_interface := plugin.get_editor_interface()
			var scene_root := editor_interface.get_edited_scene_root()
			return {
				"ok": true,
				"result": {
					"name": str(ProjectSettings.get_setting("application/config/name", "")),
					"project_file": ProjectSettings.globalize_path("res://project.godot"),
					"edited_scene": scene_root.scene_file_path if scene_root != null else "",
				}
			},
		{"readOnlyHint": true, "destructiveHint": false}
	)
