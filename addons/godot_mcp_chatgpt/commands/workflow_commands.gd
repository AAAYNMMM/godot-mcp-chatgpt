@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const RESERVED_RUNTIME_AUTOLOAD := "GodotMCPChatGPTRuntime"
const MAX_TEST_FILES := 100
const MAX_TEST_METHODS := 500
const TEST_FRESHNESS_WARNING := "Test results are editor-session scoped. If dependencies changed after a script was loaded, reload/rescan before treating same-editor results as authoritative."
static var _last_test_result: Dictionary = {}

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
    _add(registry, "script.patch", "Patch a project text/GDScript file by exact anchor with ambiguity detection and optional validation.", {
        "path":{"type":"string"},"find":{"type":"string"},"replace":{"type":"string"},"replace_all":{"type":"boolean"},"expected_count":{"type":"integer","minimum":1},"require_valid":{"type":"boolean"}
    }, func(a): return _script_patch(plugin,a), false, ["path","find","replace"])
    _add(registry, "script.get_diagnostics", "Parse a GDScript file or source and return structured validity/parse diagnostics without mutating it.", {"path":{"type":"string"},"source":{"type":"string"}}, func(a): return _script_diagnostics(a), true)

    _add(registry, "test.run", "Discover and run bounded project GDScript test methods. Test scripts may extend addons/godot_mcp_chatgpt/testing/test_suite.gd and methods named test_* are executed.", {
        "root":{"type":"string"},"paths":{"type":"array","items":{"type":"string"},"maxItems":100},"name_contains":{"type":"string"},"max_files":{"type":"integer","minimum":1,"maximum":100},"max_tests":{"type":"integer","minimum":1,"maximum":500}
    }, func(a): return await _test_run(plugin,a), false)
    _add(registry, "test.get_results", "Return the most recent GDScript test-run result from this editor session.", {}, func(_a): return _test_results(), true)
    _add(registry, "test.list", "Discover project GDScript test scripts and test_* methods without executing them.", {"root":{"type":"string"},"paths":{"type":"array","items":{"type":"string"},"maxItems":100},"name_contains":{"type":"string"},"max_files":{"type":"integer","minimum":1,"maximum":100}}, func(a): return _test_list(a), true)

    _add(registry, "autoload.list", "List project autoload entries including singleton mode.", {}, func(_a): return U.ok({"autoloads":_autoload_list()}), true)
    _add(registry, "autoload.add", "Add and persist a project autoload. The reserved Godot MCP runtime autoload name cannot be replaced.", {"name":{"type":"string"},"path":{"type":"string"},"singleton":{"type":"boolean"}}, func(a): return _autoload_add(a), false, ["name","path"])
    _add(registry, "autoload.remove", "Remove and persist a project autoload. The reserved Godot MCP runtime autoload cannot be removed through this tool.", {"name":{"type":"string"}}, func(a): return _autoload_remove(a), false, ["name"], true)

    _add(registry, "editor.undo", "Undo the latest action in the edited scene's Godot UndoRedo history.", {}, func(_a): return _history_action(plugin,false), false)
    _add(registry, "editor.redo", "Redo the latest action in the edited scene's Godot UndoRedo history.", {}, func(_a): return _history_action(plugin,true), false)
    _add(registry, "editor.get_undo_state", "Inspect edited-scene UndoRedo history availability and version.", {}, func(_a): return _history_state(plugin), true)

static func _add(registry: RefCounted, name: String, description: String, properties: Dictionary, handler: Callable, read_only: bool, required: Array = [], destructive: bool = false) -> void:
    registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":destructive})

static func _script_patch(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var path := str(args.get("path", ""))
    if not U.valid_res_path(path):
        return U.error("INVALID_PATH", "path must stay inside res://")
    if not FileAccess.file_exists(path):
        return U.error("FILE_NOT_FOUND", "File not found: " + path)
    var find_text := str(args.get("find", ""))
    if find_text.is_empty():
        return U.error("PATCH_ANCHOR_REQUIRED", "find must not be empty")
    var content := FileAccess.get_file_as_string(path)
    var count := content.count(find_text)
    if count == 0:
        return _error_with_details("PATCH_ANCHOR_NOT_FOUND", "Patch anchor was not found", {"path":path})
    var expected := int(args.get("expected_count", 0))
    if expected > 0 and count != expected:
        return _error_with_details("PATCH_COUNT_MISMATCH", "Anchor count did not match expected_count", {"actual_count":count,"expected_count":expected})
    var replace_all := bool(args.get("replace_all", false))
    if not replace_all and count > 1:
        return _error_with_details("PATCH_AMBIGUOUS", "Patch anchor occurs more than once; set replace_all=true or use a more specific anchor", {"count":count})
    var replacement := str(args.get("replace", ""))
    var updated := content.replace(find_text,replacement) if replace_all else _replace_first(content,find_text,replacement)
    var diagnostics := _diagnose_source(updated) if path.get_extension().to_lower() == "gd" else {"valid":true,"error":"","error_code":0}
    if bool(args.get("require_valid",false)) and not bool(diagnostics.get("valid",false)):
        return _error_with_details("PATCH_INVALID_GDSCRIPT", "Patch would produce invalid GDScript and require_valid=true", {"diagnostics":diagnostics,"written":false})
    var file := FileAccess.open(path,FileAccess.WRITE)
    if file == null:
        return U.error("OPEN_FAILED","Unable to write file: "+path)
    file.store_string(updated); file.close()
    var fs := plugin.get_editor_interface().get_resource_filesystem()
    if fs != null: fs.scan_sources()
    return U.ok({"path":path,"replacements":count if replace_all else 1,"bytes":updated.to_utf8_buffer().size(),"written":true,"valid":diagnostics.get("valid",true),"diagnostics":diagnostics})

static func _replace_first(content: String, find_text: String, replacement: String) -> String:
    var index := content.find(find_text)
    if index < 0: return content
    return content.substr(0,index) + replacement + content.substr(index + find_text.length())

static func _error_with_details(code: String, message: String, details: Dictionary) -> Dictionary:
    var error := {"code":code,"message":message}
    for key in details.keys(): error[key]=details[key]
    return {"ok":false,"error":error}

static func _script_diagnostics(args: Dictionary) -> Dictionary:
    var source := str(args.get("source", ""))
    var path := str(args.get("path", ""))
    if source.is_empty():
        if not U.valid_res_path(path): return U.error("INVALID_PATH","path must stay inside res://")
        if not FileAccess.file_exists(path): return U.error("FILE_NOT_FOUND","File not found: "+path)
        source = FileAccess.get_file_as_string(path)
    var diagnostics := _diagnose_source(source)
    diagnostics["path"] = path
    return U.ok(diagnostics)

static func _diagnose_source(source: String) -> Dictionary:
    var script := GDScript.new(); script.source_code = source
    var err := script.reload(true)
    var methods: Array = []
    if err == OK:
        for info in script.get_script_method_list(): methods.append(U.encode_method_info(info))
    return {"valid":err==OK,"error_code":int(err),"error":error_string(err) if err!=OK else "","methods":methods,"line_count":source.count("\n")+1}

static func _test_paths(args: Dictionary) -> Dictionary:
    var explicit: Array = args.get("paths",[])
    var max_files := clampi(int(args.get("max_files",MAX_TEST_FILES)),1,MAX_TEST_FILES)
    var filter := str(args.get("name_contains","")).to_lower()
    var paths: Array[String] = []
    if not explicit.is_empty():
        for value in explicit:
            var path := str(value)
            if not U.valid_res_path(path) or not path.ends_with(".gd"): return U.error("INVALID_PATH","Test paths must be res:// .gd files")
            if FileAccess.file_exists(path) and (filter.is_empty() or path.to_lower().contains(filter)): paths.append(path)
            if paths.size()>=max_files: break
    else:
        var root := str(args.get("root","res://tests"))
        if root != "res://" and not U.valid_res_path(root): return U.error("INVALID_PATH","test root must stay inside res://")
        _find_test_scripts(root,paths,max_files,filter)
    paths.sort()
    return U.ok(paths)

static func _find_test_scripts(root: String, out: Array[String], limit: int, filter: String) -> void:
    if out.size()>=limit: return
    var dir := DirAccess.open(root); if dir==null: return
    dir.list_dir_begin()
    while true:
        var name:=dir.get_next(); if name.is_empty(): break
        if name in [".",".."]: continue
        var path:=root.path_join(name)
        if dir.current_is_dir():
            if not name.begins_with("."): _find_test_scripts(path,out,limit,filter)
        elif name.ends_with(".gd") and (name.begins_with("test_") or name.ends_with("_test.gd")) and (filter.is_empty() or path.to_lower().contains(filter)):
            out.append(path)
        if out.size()>=limit: break
    dir.list_dir_end()

static func _test_list(args: Dictionary) -> Dictionary:
    var path_result := _test_paths(args)
    if not bool(path_result.get("ok",false)): return path_result
    var suites: Array=[]
    for path in path_result.result:
        var info:=_test_script_info(path); suites.append(info)
    return U.ok({"suites":suites,"count":suites.size(),"freshness_warning":TEST_FRESHNESS_WARNING,"editor_session_only":true})

static func _test_script_info(path: String) -> Dictionary:
    var resource := ResourceLoader.load(path,"Script",ResourceLoader.CACHE_MODE_IGNORE)
    var script := resource as Script
    if script==null: return {"path":path,"loadable":false,"tests":[]}
    var tests:Array=[]
    for method in script.get_script_method_list():
        var name:=str(method.get("name","")); if name.begins_with("test_"): tests.append(name)
    tests.sort()
    return {"path":path,"loadable":script.can_instantiate(),"tests":tests,"count":tests.size()}

static func _test_run(plugin: EditorPlugin, args: Dictionary) -> Dictionary:
    var path_result := _test_paths(args)
    if not bool(path_result.get("ok",false)): return path_result
    var max_tests:=clampi(int(args.get("max_tests",MAX_TEST_METHODS)),1,MAX_TEST_METHODS)
    var result := {"suites":[],"passed":0,"failed":0,"tests":0,"load_errors":[],"started_ms":Time.get_ticks_msec(),"freshness_warning":TEST_FRESHNESS_WARNING,"editor_session_only":true,"started_unix":Time.get_unix_time_from_system()}
    for path in path_result.result:
        if int(result.tests)>=max_tests: break
        var suite_result := await _run_suite(plugin,path,max_tests-int(result.tests))
        result.suites.append(suite_result)
        result.tests += int(suite_result.get("tests",0)); result.passed += int(suite_result.get("passed",0)); result.failed += int(suite_result.get("failed",0))
        if suite_result.has("load_error"): result.load_errors.append({"path":path,"error":suite_result.load_error})
    result["duration_ms"] = Time.get_ticks_msec()-int(result.started_ms)
    result["ok"] = int(result.failed)==0 and result.load_errors.is_empty()
    result["completed_unix"] = Time.get_unix_time_from_system()
    _last_test_result = result.duplicate(true)
    return U.ok(result)

static func _test_results() -> Dictionary:
    if _last_test_result.is_empty():
        return U.ok({"has_result":false,"freshness_warning":TEST_FRESHNESS_WARNING,"editor_session_only":true})
    var result := _last_test_result.duplicate(true)
    result["has_result"] = true
    result["freshness_warning"] = TEST_FRESHNESS_WARNING
    result["editor_session_only"] = true
    return U.ok(result)

static func _run_suite(plugin: EditorPlugin, path: String, remaining: int) -> Dictionary:
    var script := ResourceLoader.load(path,"Script",ResourceLoader.CACHE_MODE_IGNORE) as Script
    if script==null:
        return {"path":path,"tests":0,"passed":0,"failed":0,"load_error":"Script could not be loaded"}
    if not script.can_instantiate():
        var reload_error: Error = script.reload(true)
        var source := FileAccess.get_file_as_string(path)
        var tool_hint := " Add @tool at the top of the test script so it can execute inside the editor." if not source.strip_edges().begins_with("@tool") else ""
        return {"path":path,"tests":0,"passed":0,"failed":0,"load_error":"Script cannot instantiate (reload=%s).%s" % [error_string(reload_error),tool_hint]}
    var instance = script.new()
    var added_to_tree:=false
    if instance is Node:
        plugin.add_child(instance); added_to_tree=true
    var methods:Array[String]=[]
    for method in script.get_script_method_list():
        var name:=str(method.get("name","")); if name.begins_with("test_"): methods.append(name)
    methods.sort()
    if methods.size()>remaining: methods=methods.slice(0,remaining)
    var suite := {"path":path,"tests":methods.size(),"passed":0,"failed":0,"results":[]}
    if instance.has_method("before_all"): await instance.call("before_all")
    for method_name in methods:
        if instance.has_method("_mcp_reset_assertions"): instance.call("_mcp_reset_assertions")
        if instance.has_method("before_each"): await instance.call("before_each")
        var value = await instance.call(method_name)
        if instance.has_method("after_each"): await instance.call("after_each")
        var failures:Array=[]
        if instance.has_method("get_failures"): failures=Array(instance.call("get_failures"))
        if value is bool and not value: failures.append("test returned false")
        elif value is Dictionary and value.has("ok") and not bool(value.get("ok",false)): failures.append(str(value.get("error","test returned ok=false")))
        var passed:=failures.is_empty()
        if passed:
            suite.passed+=1
        else:
            suite.failed+=1
        suite.results.append({"name":method_name,"passed":passed,"failures":failures,"return_value":U.encode_value(value)})
    if instance.has_method("after_all"): await instance.call("after_all")
    if added_to_tree:
        plugin.remove_child(instance); instance.queue_free()
    elif instance is RefCounted:
        pass
    elif instance is Object:
        instance.free()
    return suite

static func _autoload_list() -> Array:
    var result:Array=[]
    for info in ProjectSettings.get_property_list():
        var key:=str(info.get("name","")); if not key.begins_with("autoload/"): continue
        var raw:=str(ProjectSettings.get_setting(key,"")); result.append({"name":key.trim_prefix("autoload/"),"path":raw.trim_prefix("*"),"singleton":raw.begins_with("*")})
    result.sort_custom(func(a,b): return str(a.name)<str(b.name)); return result

static func _autoload_add(args: Dictionary) -> Dictionary:
    var name:=str(args.get("name","")).strip_edges(); var path:=str(args.get("path","")).strip_edges()
    if name.is_empty() or not name.is_valid_identifier(): return U.error("INVALID_AUTOLOAD_NAME","name must be a valid identifier")
    if name==RESERVED_RUNTIME_AUTOLOAD: return U.error("RESERVED_AUTOLOAD","The Godot MCP runtime autoload is reserved")
    if not U.valid_res_path(path): return U.error("INVALID_PATH","autoload path must stay inside res://")
    if not FileAccess.file_exists(path): return U.error("FILE_NOT_FOUND","Autoload file not found: "+path)
    var key:="autoload/"+name
    if ProjectSettings.has_setting(key): return U.error("AUTOLOAD_EXISTS","Autoload already exists: "+name)
    ProjectSettings.set_setting(key,("*" if bool(args.get("singleton",true)) else "")+path)
    ProjectSettings.set_initial_value(key,""); ProjectSettings.set_as_basic(key,true)
    var err:=ProjectSettings.save(); if err!=OK: ProjectSettings.clear(key); return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"name":name,"path":path,"singleton":bool(args.get("singleton",true)),"persisted":true})

static func _autoload_remove(args: Dictionary) -> Dictionary:
    var name:=str(args.get("name","")).strip_edges()
    if name==RESERVED_RUNTIME_AUTOLOAD: return U.error("RESERVED_AUTOLOAD","The Godot MCP runtime autoload cannot be removed")
    var key:="autoload/"+name
    if not ProjectSettings.has_setting(key): return U.error("AUTOLOAD_NOT_FOUND","Autoload not found: "+name)
    var old=ProjectSettings.get_setting(key); ProjectSettings.clear(key)
    var err:=ProjectSettings.save(); if err!=OK: ProjectSettings.set_setting(key,old); return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"name":name,"removed":true,"persisted":true})

static func _history(plugin: EditorPlugin) -> UndoRedo:
    var root:=plugin.get_editor_interface().get_edited_scene_root(); if root==null: return null
    var manager:=plugin.get_undo_redo(); return manager.get_history_undo_redo(manager.get_object_history_id(root))

static func _history_state(plugin: EditorPlugin) -> Dictionary:
    var h:=_history(plugin); if h==null: return U.error("NO_SCENE_HISTORY","No edited-scene UndoRedo history")
    return U.ok({"version":h.get_version(),"has_undo":h.has_undo(),"has_redo":h.has_redo(),"current_action":h.get_current_action_name()})

static func _history_action(plugin: EditorPlugin, redo: bool) -> Dictionary:
    var h:=_history(plugin); if h==null: return U.error("NO_SCENE_HISTORY","No edited-scene UndoRedo history")
    var before:=h.get_version(); var ok:=h.redo() if redo else h.undo()
    return U.ok({"operation":"redo" if redo else "undo","performed":ok,"version_before":before,"version_after":h.get_version(),"has_undo":h.has_undo(),"has_redo":h.has_redo()})