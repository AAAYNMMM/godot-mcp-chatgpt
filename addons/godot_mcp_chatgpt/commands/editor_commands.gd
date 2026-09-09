@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
    _add(registry, "editor.inspect", "Return a high-value snapshot of the Godot editor state.", {}, func(_a): return _inspect(plugin), true)
    _add(registry, "editor.get_selection", "Return selected scene nodes and FileSystem paths.", {}, func(_a): return _get_selection(plugin), true)
    _add(registry, "editor.set_selection", "Replace or extend the selected scene nodes by path.", {"node_paths":{"type":"array","items":{"type":"string"}},"clear_first":{"type":"boolean"},"ignore_missing":{"type":"boolean"}}, func(a): return _set_selection(plugin,a), false, ["node_paths"])
    _add(registry, "editor.clear_selection", "Clear the current scene-node selection.", {}, func(_a): return _clear_selection(plugin), false)
    _add(registry, "editor.get_filesystem_state", "Return Godot editor filesystem scan/import state and current FileSystem selection.", {}, func(_a): return _filesystem_state(plugin), true)
    _add(registry, "editor.scan_filesystem", "Ask the Godot editor filesystem to rescan project files.", {"sources_only":{"type":"boolean"}}, func(a): return _scan_filesystem(plugin,a), false)
    _add(registry, "editor.reimport_files", "Reimport one or more project resource files through the Godot editor filesystem.", {"paths":{"type":"array","items":{"type":"string"}}}, func(a): return _reimport_files(plugin,a), false, ["paths"])
    _add(registry, "editor.select_file", "Select a res:// file in the Godot FileSystem dock.", {"path":{"type":"string"}}, func(a): return _select_file(plugin,a), false, ["path"])
    _add(registry, "editor.get_script_state", "Return open/current/unsaved scripts in the Script editor.", {}, func(_a): return _script_state(plugin), true)
    _add(registry, "editor.open_script", "Open a project script in the Godot Script editor at an optional line and column.", {"path":{"type":"string"},"line":{"type":"integer"},"column":{"type":"integer"},"grab_focus":{"type":"boolean"}}, func(a): return _open_script(plugin,a), false, ["path"])
    _add(registry, "editor.close_script", "Close a script file in the Godot Script editor.", {"path":{"type":"string"}}, func(a): return _close_script(plugin,a), false, ["path"])
    _add(registry, "editor.is_playing", "Return whether the editor is currently running a game scene.", {}, func(_a): return U.ok({"playing":plugin.get_editor_interface().is_playing_scene()}), true)
    _add(registry, "editor.get_playing_scene", "Return the scene path currently being played by the editor.", {}, func(_a): return U.ok({"playing":plugin.get_editor_interface().is_playing_scene(),"scene":plugin.get_editor_interface().get_playing_scene()}), true)
    _add(registry, "editor.run_main_scene", "Run the project's configured main scene.", {}, func(_a): return _run_main(plugin), false)
    _add(registry, "editor.run_current_scene", "Run the currently edited scene.", {}, func(_a): return _run_current(plugin), false)
    _add(registry, "editor.run_custom_scene", "Run a specific res:// .tscn scene.", {"path":{"type":"string"}}, func(a): return _run_custom(plugin,a), false, ["path"])
    _add(registry, "editor.stop_playing", "Stop the scene currently being played by the Godot editor.", {}, func(_a): return _stop_playing(plugin), false)
    _add(registry, "editor.save_all", "Save all open scenes and scripts.", {}, func(_a): return _save_all(plugin), false)

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = []) -> void:
    registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":false})

static func _inspect(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    var root := editor.get_edited_scene_root()
    return U.ok({
        "editor_language": editor.get_editor_language(),
        "editor_scale": editor.get_editor_scale(),
        "feature_profile": editor.get_current_feature_profile(),
        "distraction_free": editor.is_distraction_free_mode_enabled(),
        "multi_window": editor.is_multi_window_enabled(),
        "current_scene": root.scene_file_path if root != null else "",
        "open_scenes": Array(editor.get_open_scenes()),
        "unsaved_scenes": Array(editor.get_unsaved_scenes()),
        "selection": _selection_value(plugin),
        "filesystem": _filesystem_state_value(plugin),
        "scripts": _script_state_value(plugin),
        "playing": editor.is_playing_scene(),
        "playing_scene": editor.get_playing_scene(),
    })

static func _selection_value(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    var root := editor.get_edited_scene_root()
    var selection := editor.get_selection()
    var selected: Array = []
    var top_selected: Array = []
    for value in selection.get_selected_nodes():
        var node := value as Node
        if node != null:
            selected.append({"path":U.node_path_relative(root,node) if root != null and root.is_ancestor_of(node) or node == root else str(node.get_path()),"name":str(node.name),"class":node.get_class()})
    for value in selection.get_top_selected_nodes():
        var node := value as Node
        if node != null:
            top_selected.append({"path":U.node_path_relative(root,node) if root != null and (root.is_ancestor_of(node) or node == root) else str(node.get_path()),"name":str(node.name),"class":node.get_class()})
    return {"nodes":selected,"top_nodes":top_selected,"filesystem_paths":Array(editor.get_selected_paths())}

static func _get_selection(plugin: EditorPlugin) -> Dictionary:
    return U.ok(_selection_value(plugin))

static func _set_selection(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var editor := plugin.get_editor_interface()
    var selection := editor.get_selection()
    var clear_first := bool(args.get("clear_first", true))
    var ignore_missing := bool(args.get("ignore_missing", false))
    if clear_first:
        selection.clear()
    var missing: Array = []
    var added: Array = []
    for path_value in args.get("node_paths", []):
        var path_text := str(path_value)
        var node := U.resolve_node(plugin, path_text)
        if node == null:
            missing.append(path_text)
            if not ignore_missing:
                return U.error("NODE_NOT_FOUND", "Node not found: " + path_text)
            continue
        selection.add_node(node)
        added.append(path_text)
    return U.ok({"added":added,"missing":missing,"selection":_selection_value(plugin)})

static func _clear_selection(plugin: EditorPlugin) -> Dictionary:
    plugin.get_editor_interface().get_selection().clear()
    return U.ok(_selection_value(plugin))

static func _filesystem_state_value(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    var fs := editor.get_resource_filesystem()
    return {
        "scanning": fs.is_scanning(),
        "importing": fs.is_importing(),
        "scanning_progress": fs.get_scanning_progress(),
        "selected_paths": Array(editor.get_selected_paths()),
        "current_path": editor.get_current_path(),
        "current_directory": editor.get_current_directory(),
    }

static func _filesystem_state(plugin: EditorPlugin) -> Dictionary:
    return U.ok(_filesystem_state_value(plugin))

static func _scan_filesystem(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var fs := plugin.get_editor_interface().get_resource_filesystem()
    if bool(args.get("sources_only", false)):
        fs.scan_sources()
    else:
        fs.scan()
    return U.ok(_filesystem_state_value(plugin))

static func _reimport_files(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var paths := PackedStringArray()
    for value in args.get("paths", []):
        var path := str(value).strip_edges()
        if not U.valid_res_path(path):
            return U.error("INVALID_PATH", "Every path must stay inside res://")
        paths.append(path)
    if paths.is_empty():
        return U.error("PATHS_REQUIRED", "paths must contain at least one res:// file")
    plugin.get_editor_interface().get_resource_filesystem().reimport_files(paths)
    return U.ok({"paths":Array(paths),"filesystem":_filesystem_state_value(plugin)})

static func _select_file(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var path := str(args.get("path", "")).strip_edges()
    if not U.valid_res_path(path):
        return U.error("INVALID_PATH", "path must stay inside res://")
    if not FileAccess.file_exists(path):
        return U.error("FILE_NOT_FOUND", "File not found: " + path)
    plugin.get_editor_interface().select_file(path)
    return U.ok({"selected":path,"filesystem":_filesystem_state_value(plugin)})

static func _script_state_value(plugin: EditorPlugin) -> Dictionary:
    var script_editor := plugin.get_editor_interface().get_script_editor()
    var open_paths: Array = []
    for value in script_editor.get_open_scripts():
        var script := value as Script
        if script != null:
            open_paths.append(script.resource_path)
    var current := script_editor.get_current_script()
    return {"open":open_paths,"current":current.resource_path if current != null else "","unsaved":Array(script_editor.get_unsaved_files())}

static func _script_state(plugin: EditorPlugin) -> Dictionary:
    return U.ok(_script_state_value(plugin))

static func _open_script(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var path := str(args.get("path", "")).strip_edges()
    if not U.valid_res_path(path):
        return U.error("INVALID_PATH", "path must stay inside res://")
    var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
    if script == null:
        return U.error("SCRIPT_LOAD_FAILED", "Unable to load script: " + path)
    plugin.get_editor_interface().edit_script(script, int(args.get("line", -1)), int(args.get("column", 0)), bool(args.get("grab_focus", true)))
    return U.ok({"path":path,"scripts":_script_state_value(plugin)})

static func _close_script(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var path := str(args.get("path", "")).strip_edges()
    if not U.valid_res_path(path):
        return U.error("INVALID_PATH", "path must stay inside res://")
    var err := plugin.get_editor_interface().get_script_editor().close_file(path)
    if err != OK:
        return U.error("SCRIPT_CLOSE_FAILED", error_string(err))
    return U.ok({"path":path,"scripts":_script_state_value(plugin)})

static func _run_main(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    editor.play_main_scene()
    return U.ok({"playing":editor.is_playing_scene(),"scene":editor.get_playing_scene()})

static func _run_current(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    if editor.get_edited_scene_root() == null:
        return U.error("NO_SCENE", "No edited scene is open")
    editor.play_current_scene()
    return U.ok({"playing":editor.is_playing_scene(),"scene":editor.get_playing_scene()})

static func _run_custom(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var path := str(args.get("path", "")).strip_edges()
    if not U.valid_res_path(path) or path.get_extension().to_lower() != "tscn":
        return U.error("INVALID_SCENE_PATH", "path must be a res:// .tscn scene")
    if not FileAccess.file_exists(path):
        return U.error("SCENE_NOT_FOUND", "Scene not found: " + path)
    var editor := plugin.get_editor_interface()
    editor.play_custom_scene(path)
    return U.ok({"playing":editor.is_playing_scene(),"scene":editor.get_playing_scene()})

static func _stop_playing(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    editor.stop_playing_scene()
    return U.ok({"playing":editor.is_playing_scene(),"scene":editor.get_playing_scene()})

static func _save_all(plugin: EditorPlugin) -> Dictionary:
    var editor := plugin.get_editor_interface()
    editor.save_all_scenes()
    editor.get_script_editor().save_all_scripts()
    return U.ok({"unsaved_scenes":Array(editor.get_unsaved_scenes()),"unsaved_scripts":Array(editor.get_script_editor().get_unsaved_files())})