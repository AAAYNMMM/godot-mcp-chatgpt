@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const MAX_SCAN_FILES := 10000
const MAX_SEARCH_MATCHES := 300
const TEXT_EXTENSIONS := ["gd", "gdshader", "tscn", "tres", "godot", "cfg", "ini", "json", "md", "txt", "csv", "xml", "yaml", "yml", "shader", "glsl", "cs"]

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
	_add(registry, "project.inspect", "Return a high-value overview of the current Godot project.", {}, func(_a): return _inspect(plugin), true)
	_add(registry, "project.list_directory", "List files and directories under a res:// path.", {"path":{"type":"string"},"recursive":{"type":"boolean"},"max_depth":{"type":"integer"},"include_hidden":{"type":"boolean"}}, func(a): return _list_directory(a), true)
	_add(registry, "project.find_files", "Find project files by glob-like pattern, extension, or substring.", {"query":{"type":"string"},"root":{"type":"string"},"extensions":{"type":"array","items":{"type":"string"}},"limit":{"type":"integer"}}, func(a): return _find_files(a), true)
	_add(registry, "project.search_text", "Search text across project text files with file/line context.", {"query":{"type":"string"},"root":{"type":"string"},"case_sensitive":{"type":"boolean"},"extensions":{"type":"array","items":{"type":"string"}},"limit":{"type":"integer"}}, func(a): return _search_text(a), true)
	_add(registry, "project.get_setting", "Read one ProjectSettings value.", {"name":{"type":"string"}}, func(a): return _get_setting(a), true, ["name"])
	_add(registry, "project.set_setting", "Set and persist one ProjectSettings value.", {"name":{"type":"string"},"value":{}}, func(a): return _set_setting(a), false, ["name","value"], true)
	_add(registry, "project.list_settings", "List ProjectSettings names and values, optionally filtered by prefix.", {"prefix":{"type":"string"},"limit":{"type":"integer"}}, func(a): return _list_settings(a), true)
	_add(registry, "project.get_autoloads", "List configured project autoloads/singletons.", {}, func(_a): return U.ok(_autoloads()), true)
	_add(registry, "project.get_plugins", "List editor plugins configured in project.godot.", {}, func(_a): return _plugins(plugin), true)
	_add(registry, "project.make_directory", "Create a directory inside res://.", {"path":{"type":"string"}}, func(a): return _make_directory(a), false, ["path"])
	_add(registry, "project.move_file", "Move or rename a project file inside res://.", {"from":{"type":"string"},"to":{"type":"string"},"overwrite":{"type":"boolean"}}, func(a): return _move_file(plugin,a), false, ["from","to"], true)
	_add(registry, "project.delete_file", "Delete a project file inside res://.", {"path":{"type":"string"}}, func(a): return _delete_file(plugin,a), false, ["path"], true)
	_add(registry, "input_map.list", "List all InputMap actions with deadzones and events.", {}, func(_a): return U.ok(_input_actions()), true)
	_add(registry, "input_map.get_action", "Inspect one InputMap action.", {"action":{"type":"string"}}, func(a): return _input_get(a), true, ["action"])
	_add(registry, "input_map.add_action", "Create or update an InputMap action and persist it.", {"action":{"type":"string"},"deadzone":{"type":"number"}}, func(a): return _input_add(a), false, ["action"])
	_add(registry, "input_map.remove_action", "Remove an InputMap action and persist it.", {"action":{"type":"string"}}, func(a): return _input_remove(a), false, ["action"], true)
	_add(registry, "input_map.add_event", "Add a keyboard/mouse/joypad event to an InputMap action and persist it.", {"action":{"type":"string"},"event":{"type":"object"}}, func(a): return _input_add_event(a), false, ["action","event"])
	_add(registry, "input_map.clear_action_events", "Remove all events from an InputMap action and persist it.", {"action":{"type":"string"}}, func(a): return _input_clear_events(a), false, ["action"], true)

static func _add(registry, name:String, description:String, properties:Dictionary, handler:Callable, read_only:bool, required:Array = [], destructive:bool=false) -> void:
	registry.add_command(name, description, {"type":"object","properties":properties,"required":required,"additionalProperties":false}, handler, {"readOnlyHint":read_only,"destructiveHint":destructive})

static func _inspect(plugin: EditorPlugin) -> Dictionary:
	var editor := plugin.get_editor_interface()
	var root := editor.get_edited_scene_root()
	var summary := _filesystem_summary("res://")
	return U.ok({
		"name": str(ProjectSettings.get_setting("application/config/name", "")),
		"project_file": ProjectSettings.globalize_path("res://project.godot"),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"current_scene": root.scene_file_path if root != null else "",
		"open_scenes": editor.get_open_scenes(),
		"unsaved_scenes": editor.get_unsaved_scenes(),
		"autoloads": _autoloads(),
		"input_actions": _input_actions(),
		"plugins": _plugins_value(),
		"filesystem": summary,
	})

static func _list_directory(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", "res://")).strip_edges()
	if path == "res://": pass
	elif not U.valid_res_path(path): return U.error("INVALID_PATH", "Path must stay inside res://")
	var recursive := bool(args.get("recursive", false))
	var max_depth := clampi(int(args.get("max_depth", 4)), 0, 32)
	var include_hidden := bool(args.get("include_hidden", false))
	var items:Array=[]
	_walk(path, recursive, max_depth, include_hidden, items, 0)
	return U.ok({"path":path,"items":items,"count":items.size()})

static func _walk(path:String, recursive:bool, max_depth:int, include_hidden:bool, out:Array, depth:int) -> void:
	if out.size() >= MAX_SCAN_FILES: return
	var dir:=DirAccess.open(path)
	if dir==null: return
	dir.list_dir_begin()
	while true:
		var name:=dir.get_next()
		if name.is_empty(): break
		if name in [".",".."]: continue
		if not include_hidden and name.begins_with("."): continue
		var child:=path.path_join(name)
		var is_dir:=dir.current_is_dir()
		out.append({"path":child,"name":name,"kind":"directory" if is_dir else "file","extension":"" if is_dir else name.get_extension().to_lower()})
		if out.size() >= MAX_SCAN_FILES: break
		if is_dir and recursive and depth < max_depth: _walk(child, true, max_depth, include_hidden, out, depth+1)
	dir.list_dir_end()

static func _find_files(args:Dictionary)->Dictionary:
	var query:=str(args.get("query", "")).strip_edges().to_lower()
	var root:=str(args.get("root", "res://")).strip_edges()
	if root!="res://" and not U.valid_res_path(root): return U.error("INVALID_PATH","Root must stay inside res://")
	var ext_filter:Array=[]
	for e in args.get("extensions",[]): ext_filter.append(str(e).trim_prefix(".").to_lower())
	var limit:=clampi(int(args.get("limit",200)),1,2000)
	var all:Array=[]; _walk(root,true,64,false,all,0)
	var result:Array=[]
	for item in all:
		if item.get("kind")!="file": continue
		var path:=str(item.get("path","")); var ext:=path.get_extension().to_lower()
		if not ext_filter.is_empty() and not ext_filter.has(ext): continue
		var lower:=path.to_lower()
		if not query.is_empty() and not lower.contains(query) and not path.get_file().matchn(query): continue
		result.append(path)
		if result.size()>=limit: break
	return U.ok({"query":query,"files":result,"count":result.size(),"truncated":result.size()>=limit})

static func _search_text(args:Dictionary)->Dictionary:
	var query:=str(args.get("query", ""))
	if query.is_empty(): return U.error("QUERY_REQUIRED","query is required")
	var root:=str(args.get("root","res://")).strip_edges()
	if root!="res://" and not U.valid_res_path(root): return U.error("INVALID_PATH","Root must stay inside res://")
	var case_sensitive:=bool(args.get("case_sensitive",false))
	var ext_filter:Array=[]
	for e in args.get("extensions",[]): ext_filter.append(str(e).trim_prefix(".").to_lower())
	if ext_filter.is_empty(): ext_filter=TEXT_EXTENSIONS.duplicate()
	var limit:=clampi(int(args.get("limit",100)),1,MAX_SEARCH_MATCHES)
	var all:Array=[]; _walk(root,true,64,false,all,0)
	var matches:Array=[]; var scanned:=0
	for item in all:
		if item.get("kind")!="file": continue
		var path:=str(item.get("path","")); if not ext_filter.has(path.get_extension().to_lower()): continue
		var file:=FileAccess.open(path,FileAccess.READ); if file==null: continue
		if file.get_length()>2*1024*1024: file.close(); continue
		scanned+=1; var line_no:=0
		while not file.eof_reached():
			var line:=file.get_line(); line_no+=1
			var found:=line.find(query) if case_sensitive else line.to_lower().find(query.to_lower())
			if found>=0:
				matches.append({"path":path,"line":line_no,"column":found+1,"text":line.substr(0,mini(line.length(),500))})
				if matches.size()>=limit: break
		file.close()
		if matches.size()>=limit: break
	return U.ok({"query":query,"matches":matches,"count":matches.size(),"files_scanned":scanned,"truncated":matches.size()>=limit})

static func _get_setting(args:Dictionary)->Dictionary:
	var name:=str(args.get("name","")); if name.is_empty(): return U.error("NAME_REQUIRED","setting name is required")
	return U.ok({"name":name,"exists":ProjectSettings.has_setting(name),"value":U.encode_value(ProjectSettings.get_setting(name)) if ProjectSettings.has_setting(name) else null})

static func _set_setting(args:Dictionary)->Dictionary:
	var name:=str(args.get("name","")); if name.is_empty(): return U.error("NAME_REQUIRED","setting name is required")
	ProjectSettings.set_setting(name,U.decode_value(args.get("value")))
	var err:=ProjectSettings.save(); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
	var exists:=ProjectSettings.has_setting(name)
	return U.ok({"name":name,"exists":exists,"value":U.encode_value(ProjectSettings.get_setting(name)) if exists else null})

static func _list_settings(args:Dictionary)->Dictionary:
	var prefix:=str(args.get("prefix","")); var limit:=clampi(int(args.get("limit",300)),1,2000); var result:Array=[]
	for info in ProjectSettings.get_property_list():
		var name:=str(info.get("name","")); if not prefix.is_empty() and not name.begins_with(prefix): continue
		if not ProjectSettings.has_setting(name): continue
		result.append({"name":name,"value":U.encode_value(ProjectSettings.get_setting(name)),"info":U.encode_property_info(info)})
		if result.size()>=limit: break
	return U.ok({"settings":result,"count":result.size(),"truncated":result.size()>=limit})

static func _autoloads()->Array:
	var result:Array=[]
	for info in ProjectSettings.get_property_list():
		var name:=str(info.get("name","")); if not name.begins_with("autoload/"): continue
		var value:=str(ProjectSettings.get_setting(name,"")); result.append({"name":name.trim_prefix("autoload/"),"path":value.trim_prefix("*"),"singleton":value.begins_with("*")})
	return result

static func _plugins(plugin:EditorPlugin)->Dictionary: return U.ok(_plugins_value())
static func _plugins_value()->Array:
	var enabled:=ProjectSettings.get_setting("editor_plugins/enabled",PackedStringArray()); var result:Array=[]
	for item in enabled: result.append(str(item))
	return result

static func _make_directory(args:Dictionary)->Dictionary:
	var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","Path must stay inside res://")
	var err:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path)); if err!=OK and err!=ERR_ALREADY_EXISTS: return U.error("MKDIR_FAILED",error_string(err))
	return U.ok({"path":path})

static func _move_file(plugin:EditorPlugin,args:Dictionary)->Dictionary:
	var from:=str(args.get("from","")); var to:=str(args.get("to","")); var overwrite:=bool(args.get("overwrite",false))
	if not U.valid_res_path(from) or not U.valid_res_path(to): return U.error("INVALID_PATH","Paths must stay inside res://")
	if not FileAccess.file_exists(from): return U.error("NOT_FOUND","Source file not found")
	if FileAccess.file_exists(to) and not overwrite: return U.error("FILE_EXISTS","Destination exists; pass overwrite=true")
	var parent:=to.get_base_dir(); if parent!="res://": DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	if overwrite and FileAccess.file_exists(to): DirAccess.remove_absolute(ProjectSettings.globalize_path(to))
	var err:=DirAccess.rename_absolute(ProjectSettings.globalize_path(from),ProjectSettings.globalize_path(to)); if err!=OK: return U.error("MOVE_FAILED",error_string(err))
	plugin.get_editor_interface().get_resource_filesystem().scan_sources()
	return U.ok({"from":from,"to":to})

static func _delete_file(plugin:EditorPlugin,args:Dictionary)->Dictionary:
	var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","Path must stay inside res://")
	if not FileAccess.file_exists(path): return U.error("NOT_FOUND","File not found")
	var err:=DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); if err!=OK: return U.error("DELETE_FAILED",error_string(err))
	plugin.get_editor_interface().get_resource_filesystem().scan_sources()
	return U.ok({"path":path,"deleted":true})

static func _input_actions()->Array:
	var result:Array=[]
	for action in InputMap.get_actions():
		var name:=str(action); if name.begins_with("ui_") and not ProjectSettings.has_setting("input/"+name): continue
		result.append(_input_action_value(name))
	return result

static func _input_action_value(action:String)->Dictionary:
	var events:Array=[]
	for event in InputMap.action_get_events(action): events.append(_encode_input_event(event))
	return {"action":action,"deadzone":InputMap.action_get_deadzone(action),"events":events}

static func _input_get(args:Dictionary)->Dictionary:
	var action:=str(args.get("action","")); if not InputMap.has_action(action): return U.error("ACTION_NOT_FOUND","Input action not found: "+action)
	return U.ok(_input_action_value(action))

static func _input_add(args:Dictionary)->Dictionary:
	var action:=str(args.get("action","")); if action.is_empty(): return U.error("ACTION_REQUIRED","action is required")
	var deadzone:=float(args.get("deadzone",0.5)); var key:="input/"+action
	var current:=ProjectSettings.get_setting(key,{"deadzone":deadzone,"events":[]}); if not current is Dictionary: current={"deadzone":deadzone,"events":[]}
	current["deadzone"]=deadzone; if not current.has("events"): current["events"]=[]
	ProjectSettings.set_setting(key,current); var err:=ProjectSettings.save(); InputMap.load_from_project_settings(); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
	return U.ok(_input_action_value(action))

static func _input_remove(args:Dictionary)->Dictionary:
	var action:=str(args.get("action","")); ProjectSettings.set_setting("input/"+action,null); var err:=ProjectSettings.save(); InputMap.load_from_project_settings(); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
	return U.ok({"action":action,"removed":true})

static func _input_add_event(args:Dictionary)->Dictionary:
	var action:=str(args.get("action","")); if action.is_empty(): return U.error("ACTION_REQUIRED","action is required")
	var event_data:=args.get("event",{}); if not event_data is Dictionary: return U.error("INVALID_EVENT","event must be an object")
	var event:=_decode_input_event(event_data); if event==null: return U.error("INVALID_EVENT","Unsupported input event type")
	if not ProjectSettings.has_setting("input/"+action): _input_add({"action":action,"deadzone":0.5})
	var current:=ProjectSettings.get_setting("input/"+action,{"deadzone":0.5,"events":[]}); var events:Array=current.get("events",[]); events.append(event); current["events"]=events
	ProjectSettings.set_setting("input/"+action,current); var err:=ProjectSettings.save(); InputMap.load_from_project_settings(); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
	return U.ok(_input_action_value(action))

static func _input_clear_events(args:Dictionary)->Dictionary:
	var action:=str(args.get("action","")); if not ProjectSettings.has_setting("input/"+action): return U.error("ACTION_NOT_FOUND","Input action not found")
	var current:=ProjectSettings.get_setting("input/"+action,{}); current["events"]=[]; ProjectSettings.set_setting("input/"+action,current); var err:=ProjectSettings.save(); InputMap.load_from_project_settings(); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
	return U.ok(_input_action_value(action))

static func _decode_input_event(data:Dictionary)->InputEvent:
	match str(data.get("type","")):
		"key":
			var e:=InputEventKey.new(); e.keycode=int(data.get("keycode",0)); e.physical_keycode=int(data.get("physical_keycode",0)); e.unicode=int(data.get("unicode",0)); e.ctrl_pressed=bool(data.get("ctrl",false)); e.shift_pressed=bool(data.get("shift",false)); e.alt_pressed=bool(data.get("alt",false)); e.meta_pressed=bool(data.get("meta",false)); return e
		"mouse_button":
			var e:=InputEventMouseButton.new(); e.button_index=int(data.get("button_index",1)); e.ctrl_pressed=bool(data.get("ctrl",false)); e.shift_pressed=bool(data.get("shift",false)); e.alt_pressed=bool(data.get("alt",false)); e.meta_pressed=bool(data.get("meta",false)); return e
		"joypad_button":
			var e:=InputEventJoypadButton.new(); e.button_index=int(data.get("button_index",0)); return e
		"joypad_motion":
			var e:=InputEventJoypadMotion.new(); e.axis=int(data.get("axis",0)); e.axis_value=float(data.get("axis_value",1.0)); return e
	return null

static func _encode_input_event(event:InputEvent)->Dictionary:
	var result:={"class":event.get_class(),"text":event.as_text()}
	if event is InputEventKey: result.merge({"type":"key","keycode":event.keycode,"physical_keycode":event.physical_keycode,"unicode":event.unicode,"ctrl":event.ctrl_pressed,"shift":event.shift_pressed,"alt":event.alt_pressed,"meta":event.meta_pressed},true)
	elif event is InputEventMouseButton: result.merge({"type":"mouse_button","button_index":event.button_index},true)
	elif event is InputEventJoypadButton: result.merge({"type":"joypad_button","button_index":event.button_index},true)
	elif event is InputEventJoypadMotion: result.merge({"type":"joypad_motion","axis":event.axis,"axis_value":event.axis_value},true)
	return result

static func _filesystem_summary(root:String)->Dictionary:
	var items:Array=[]; _walk(root,true,64,false,items,0); var files:=0; var dirs:=0; var by_ext:={}
	for item in items:
		if item.get("kind")=="directory": dirs+=1
		else:
			files+=1; var ext:=str(item.get("extension","")); by_ext[ext]=int(by_ext.get(ext,0))+1
	return {"files":files,"directories":dirs,"by_extension":by_ext,"truncated":items.size()>=MAX_SCAN_FILES}