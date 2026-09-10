@tool
class_name GodotMCPChatGPTCustomTools
extends RefCounted

const MAX_TOOLS := 64
const MAX_PENDING := 128
const MAX_PROMOTED := 2
const MAX_DESCRIPTION := 800
const MAX_ARGUMENT_BYTES := 524288
const MAX_RESULT_BYTES := 524288
const META_SECTION := "godot_mcp_chatgpt"
const META_ENABLED := "enabled_custom_tools"

static var _instance: GodotMCPChatGPTCustomTools
static var _pending: Array[Dictionary] = []

var _specs: Dictionary = {}
var _by_source: Dictionary = {}
var _enabled: Dictionary = {}
var _editor_settings: EditorSettings

signal tools_changed
signal registry_ready

static func get_instance() -> GodotMCPChatGPTCustomTools:
    return _instance

static func register(spec: Dictionary) -> Dictionary:
    if _instance != null:
        return _instance._register(spec)
    return _queue_pending(spec)

static func _queue_pending(spec: Dictionary) -> Dictionary:
    var name := str(spec.get("name", ""))
    var source_path := str(spec.get("source_path", ""))
    for i in _pending.size():
        var existing: Dictionary = _pending[i]
        if str(existing.get("name", "")) == name and str(existing.get("source_path", "")) == source_path:
            _pending[i] = spec.duplicate(true)
            return {"ok":true,"result":{"queued":true,"replaced":true,"name":name}}
    if _pending.size() >= MAX_PENDING:
        return _error_static("CUSTOM_PENDING_LIMIT", "Pending custom tool registrations are limited to %d" % MAX_PENDING)
    _pending.append(spec.duplicate(true))
    return {"ok":true,"result":{"queued":true,"replaced":false,"name":name}}

static func unregister(name: String, source_path: String = "") -> Dictionary:
    if _instance != null:
        return _instance._unregister(name,source_path)
    for i in range(_pending.size()-1,-1,-1):
        var pending:Dictionary=_pending[i]
        if str(pending.get("name",""))==name and (source_path.is_empty() or str(pending.get("source_path",""))==source_path):
            _pending.remove_at(i)
            return {"ok":true,"result":{"removed":true,"queued":true,"name":name}}
    return _error_static("CUSTOM_TOOL_NOT_FOUND","Custom tool not found: "+name)

static func unregister_source(source_path: String) -> int:
    if _instance != null:
        return _instance._unregister_source(source_path)
    var removed:=0
    for i in range(_pending.size()-1,-1,-1):
        if str((_pending[i] as Dictionary).get("source_path",""))==source_path:
            _pending.remove_at(i); removed+=1
    return removed

func setup(settings: EditorSettings) -> Dictionary:
    _editor_settings=settings
    _load_enabled()
    _instance=self
    var queued:=_pending.duplicate(true); _pending.clear()
    var errors:Array=[]
    for spec_value in queued:
        var result:=_register(spec_value)
        if not bool(result.get("ok",false)): errors.append(result.get("error",{}))
    registry_ready.emit()
    return {"ok":errors.is_empty(),"result":{"registered":_specs.size(),"queued_processed":queued.size(),"errors":errors}}

func shutdown() -> void:
    # Preserve still-valid third-party registrations across this plugin's own
    # disable/re-enable cycle. Invalid handlers are intentionally dropped.
    for spec_value in _specs.values():
        var spec: Dictionary = spec_value
        var handler_value = spec.get("handler")
        if handler_value is Callable and (handler_value as Callable).is_valid():
            _queue_pending(spec)
    _specs.clear(); _by_source.clear(); _enabled.clear(); _editor_settings=null
    if _instance==self: _instance=null

func _register(spec: Dictionary) -> Dictionary:
    if _specs.size()>=MAX_TOOLS and not _specs.has(str(spec.get("name",""))):
        return _error("CUSTOM_TOOL_LIMIT","Custom tool registry is limited to %d tools" % MAX_TOOLS)
    var validation:=_validate_spec(spec)
    if not bool(validation.get("ok",false)): return validation
    var normalized:Dictionary=validation.result
    var name:=str(normalized.name); var source:=str(normalized.source_path)
    var existing:Dictionary=_specs.get(name,{})
    if not existing.is_empty() and str(existing.get("source_path",""))!=source:
        return _error("CUSTOM_TOOL_NAME_COLLISION","Custom tool name is already registered by another addon",{"name":name,"existing_source":existing.get("source_path","")})
    if bool(normalized.get("promoted",false)) and (existing.is_empty() or not bool(existing.get("promoted",false))) and _promoted_count()>=MAX_PROMOTED:
        return _error("CUSTOM_PROMOTION_LIMIT","At most %d custom tools may be promoted" % MAX_PROMOTED)
    if not existing.is_empty(): _erase_source_index(name,str(existing.get("source_path","")))
    _specs[name]=normalized
    if not _by_source.has(source): _by_source[source]=[]
    var names:Array=_by_source[source]
    if not names.has(name): names.append(name)
    _by_source[source]=names
    tools_changed.emit()
    return {"ok":true,"result":{"name":name,"registered":true,"enabled":is_enabled(name),"promoted":bool(normalized.get("promoted",false)),"source_path":source}}

func _unregister(name: String, source_path: String = "") -> Dictionary:
    if not _specs.has(name): return _error("CUSTOM_TOOL_NOT_FOUND","Custom tool not found: "+name)
    var spec:Dictionary=_specs[name]
    if not source_path.is_empty() and str(spec.get("source_path",""))!=source_path:
        return _error("CUSTOM_TOOL_SOURCE_MISMATCH","source_path does not own custom tool: "+name)
    _specs.erase(name); _erase_source_index(name,str(spec.get("source_path",""))); tools_changed.emit()
    return {"ok":true,"result":{"name":name,"removed":true}}

func _unregister_source(source_path: String) -> int:
    var names:Array=Array(_by_source.get(source_path,[])).duplicate()
    for name in names: _specs.erase(str(name))
    _by_source.erase(source_path)
    if not names.is_empty(): tools_changed.emit()
    return names.size()

func list_tools(include_disabled: bool = true) -> Array:
    var out:Array=[]
    var names:=_specs.keys(); names.sort()
    for name_value in names:
        var name:=str(name_value)
        if not include_disabled and not is_enabled(name): continue
        var s:Dictionary=_specs[name]
        out.append({"name":name,"description":s.description,"input_schema":s.input_schema,"source":s.source,"source_path":s.source_path,"handler_script_path":s.get("handler_script_path",""),"read_only":s.read_only,"destructive":s.destructive,"promoted":s.promoted,"enabled":is_enabled(name)})
    return out

func promoted_specs() -> Array:
    var out:Array=[]
    for spec in list_tools(false):
        if bool((spec as Dictionary).get("promoted",false)): out.append(spec)
    return out

func get_spec(name:String) -> Dictionary:
    return (_specs.get(name,{}) as Dictionary).duplicate(true)

func is_enabled(name:String)->bool:
    if not _specs.has(name): return false
    return _enabled.has(_enable_key(_specs[name]))

func set_enabled(name:String,enabled:bool)->Dictionary:
    if not _specs.has(name): return _error("CUSTOM_TOOL_NOT_FOUND","Custom tool not found: "+name)
    var spec: Dictionary = _specs[name]
    var key := _enable_key(spec)
    if enabled: _enabled[key]=true
    else: _enabled.erase(key)
    _save_enabled(); tools_changed.emit()
    return {"ok":true,"result":{"name":name,"enabled":enabled,"source_path":spec.get("source_path","")}}

func invoke(name:String,args:Dictionary)->Dictionary:
    if not _specs.has(name): return _error("CUSTOM_TOOL_NOT_FOUND","Custom tool not found: "+name)
    if not is_enabled(name): return _error("CUSTOM_TOOL_DISABLED","Custom tool is disabled until explicitly enabled: "+name)
    var argument_bytes := JSON.stringify(args).to_utf8_buffer().size()
    if argument_bytes > MAX_ARGUMENT_BYTES: return _error("CUSTOM_ARGUMENTS_TOO_LARGE","Custom tool arguments exceed %d bytes" % MAX_ARGUMENT_BYTES,{"bytes":argument_bytes,"limit":MAX_ARGUMENT_BYTES})
    var spec:Dictionary=_specs[name]
    var validation:=_validate_schema(args,spec.input_schema,"arguments")
    if not bool(validation.get("ok",false)): return validation
    var handler:Callable=spec.handler
    if not handler.is_valid(): return _error("CUSTOM_HANDLER_INVALID","Custom tool handler is no longer valid: "+name)
    var value=await handler.call(args)
    var result_bytes := JSON.stringify(value).to_utf8_buffer().size()
    if result_bytes > MAX_RESULT_BYTES: return _error("CUSTOM_RESULT_TOO_LARGE","Custom tool result exceeds %d bytes" % MAX_RESULT_BYTES,{"bytes":result_bytes,"limit":MAX_RESULT_BYTES})
    if value is Dictionary and (value as Dictionary).has("ok"): return value
    return {"ok":true,"result":value}

func _validate_spec(spec:Dictionary)->Dictionary:
    var name:=str(spec.get("name","")).strip_edges()
    if not _valid_name(name): return _error("CUSTOM_NAME_INVALID","name must match [a-z][a-z0-9_]{0,63}")
    if name=="manage": return _error("CUSTOM_NAME_RESERVED","Custom tool name 'manage' is reserved")
    var description:=str(spec.get("description","")).strip_edges()
    if description.is_empty() or description.length()>MAX_DESCRIPTION: return _error("CUSTOM_DESCRIPTION_INVALID","description is required and limited to %d characters" % MAX_DESCRIPTION)
    var source_path:=str(spec.get("source_path","")).strip_edges()
    if not _valid_source_path(source_path): return _error("CUSTOM_SOURCE_INVALID","source_path must be an existing plugin.cfg under res://addons/")
    var schema_value=spec.get("input_schema",{})
    if not schema_value is Dictionary: return _error("CUSTOM_SCHEMA_INVALID","input_schema must be an object schema")
    var schema:Dictionary=(schema_value as Dictionary).duplicate(true)
    if schema.is_empty(): schema={"type":"object","properties":{},"additionalProperties":false}
    if str(schema.get("type","object"))!="object": return _error("CUSTOM_SCHEMA_INVALID","input_schema root type must be object")
    schema["type"]="object"
    if not schema.has("properties"): schema["properties"]={}
    if not schema.get("properties") is Dictionary: return _error("CUSTOM_SCHEMA_INVALID","input_schema.properties must be an object")
    if not schema.has("additionalProperties"): schema["additionalProperties"]=false
    var shape:=_validate_schema_shape(schema,"input_schema")
    if not bool(shape.get("ok",false)): return shape
    if not spec.has("read_only") or not (spec.get("read_only") is bool): return _error("CUSTOM_HINT_REQUIRED","read_only must be explicitly provided as a boolean")
    if not spec.has("destructive") or not (spec.get("destructive") is bool): return _error("CUSTOM_HINT_REQUIRED","destructive must be explicitly provided as a boolean")
    var read_only := bool(spec.get("read_only"))
    var destructive := bool(spec.get("destructive"))
    if read_only and destructive: return _error("CUSTOM_HINT_CONFLICT","A destructive custom tool cannot be marked read_only")
    var handler_value=spec.get("handler")
    if not handler_value is Callable or not (handler_value as Callable).is_valid(): return _error("CUSTOM_HANDLER_INVALID","handler must be a valid Callable")
    var ownership:=_validate_handler_owner(handler_value as Callable,source_path)
    if not bool(ownership.get("ok",false)): return ownership
    return {"ok":true,"result":{"name":name,"description":description,"input_schema":schema,"handler":handler_value,"handler_script_path":str(ownership.result.script_path),"source":str(spec.get("source",_plugin_name(source_path))),"source_path":source_path,"read_only":read_only,"destructive":destructive,"promoted":bool(spec.get("promoted",false))}}

func _validate_schema_shape(schema:Dictionary,path:String)->Dictionary:
    var allowed_types=["object","array","string","integer","number","boolean","null"]
    var type_name:=str(schema.get("type",""))
    if not type_name.is_empty() and not allowed_types.has(type_name): return _error("CUSTOM_SCHEMA_INVALID",path+" has unsupported type")
    if schema.has("required"):
        if not schema.required is Array: return _error("CUSTOM_SCHEMA_INVALID",path+".required must be an array")
        for key in schema.required:
            if not (schema.get("properties",{}) as Dictionary).has(str(key)): return _error("CUSTOM_SCHEMA_INVALID",path+" requires undeclared property "+str(key))
    if schema.has("properties"):
        if not schema.properties is Dictionary: return _error("CUSTOM_SCHEMA_INVALID",path+".properties must be an object")
        for key in schema.properties.keys():
            if not schema.properties[key] is Dictionary: return _error("CUSTOM_SCHEMA_INVALID",path+"."+str(key)+" must be a schema object")
            var r:=_validate_schema_shape(schema.properties[key],path+"."+str(key)); if not bool(r.get("ok",false)): return r
    if schema.has("items"):
        if not schema.items is Dictionary: return _error("CUSTOM_SCHEMA_INVALID",path+".items must be a schema object")
        var r:=_validate_schema_shape(schema.items,path+"[]"); if not bool(r.get("ok",false)): return r
    return {"ok":true}

func _validate_schema(value,schema_value,path:String)->Dictionary:
    if not schema_value is Dictionary: return {"ok":true}
    var schema:Dictionary=schema_value
    if schema.has("enum") and schema.enum is Array and not (schema.enum as Array).has(value): return _error("INVALID_ARGUMENTS",path+" must match enum",{"path":path})
    var t:=str(schema.get("type",""))
    if not t.is_empty() and not _matches_type(value,t): return _error("INVALID_ARGUMENTS",path+" must be "+t,{"path":path})
    if t=="object" and value is Dictionary:
        var obj:Dictionary=value; var props:Dictionary=schema.get("properties",{})
        for req in schema.get("required",[]):
            if not obj.has(str(req)): return _error("INVALID_ARGUMENTS",path+"."+str(req)+" is required",{"path":path+"."+str(req)})
        if schema.get("additionalProperties",true)==false:
            for key in obj.keys():
                if not props.has(str(key)): return _error("INVALID_ARGUMENTS",path+"."+str(key)+" is not allowed",{"path":path+"."+str(key)})
        for key in obj.keys():
            if props.has(str(key)):
                var r:=_validate_schema(obj[key],props[str(key)],path+"."+str(key)); if not bool(r.get("ok",false)): return r
    if t=="array" and value is Array:
        var arr:Array=value
        if schema.has("maxItems") and arr.size()>int(schema.maxItems): return _error("INVALID_ARGUMENTS",path+" exceeds maxItems")
        if schema.has("minItems") and arr.size()<int(schema.minItems): return _error("INVALID_ARGUMENTS",path+" is below minItems")
        for i in arr.size():
            var r:=_validate_schema(arr[i],schema.get("items",{}),"%s[%d]"%[path,i]); if not bool(r.get("ok",false)): return r
    if (t=="number" or t=="integer") and (value is int or value is float):
        if schema.has("minimum") and float(value)<float(schema.minimum): return _error("INVALID_ARGUMENTS",path+" is below minimum")
        if schema.has("maximum") and float(value)>float(schema.maximum): return _error("INVALID_ARGUMENTS",path+" exceeds maximum")
    if t=="string" and value is String:
        var text := value as String
        if schema.has("minLength") and text.length()<int(schema.minLength): return _error("INVALID_ARGUMENTS",path+" is below minLength")
        if schema.has("maxLength") and text.length()>int(schema.maxLength): return _error("INVALID_ARGUMENTS",path+" exceeds maxLength")
    if t=="object" and value is Dictionary:
        var object_value := value as Dictionary
        if schema.has("minProperties") and object_value.size()<int(schema.minProperties): return _error("INVALID_ARGUMENTS",path+" is below minProperties")
        if schema.has("maxProperties") and object_value.size()>int(schema.maxProperties): return _error("INVALID_ARGUMENTS",path+" exceeds maxProperties")
    return {"ok":true}

func _matches_type(value,t:String)->bool:
    match t:
        "object": return value is Dictionary
        "array": return value is Array
        "string": return value is String
        "integer": return value is int or (value is float and floorf(float(value))==float(value))
        "number": return value is int or value is float
        "boolean": return value is bool
        "null": return value==null
        _: return true

func _promoted_count()->int:
    var n:=0
    for s in _specs.values():
        if bool((s as Dictionary).get("promoted",false)): n+=1
    return n

func _valid_name(name:String)->bool:
    if name.length()<1 or name.length()>64: return false
    var re:=RegEx.new(); re.compile("^[a-z][a-z0-9_]*$"); return re.search(name)!=null

func _valid_source_path(path:String)->bool:
    if not path.begins_with("res://addons/") or not path.ends_with("/plugin.cfg") or path.find("..")>=0 or not FileAccess.file_exists(path): return false
    var cfg:=ConfigFile.new(); if cfg.load(path)!=OK: return false
    var script_entry:=str(cfg.get_value("plugin","script","")).strip_edges()
    if script_entry.is_empty(): return false
    var addon_dir:=path.get_base_dir()
    var declared_path:=script_entry if script_entry.begins_with("res://") else addon_dir.path_join(script_entry).simplify_path()
    if not declared_path.begins_with(addon_dir+"/"): return false
    return FileAccess.file_exists(declared_path)

func _plugin_name(path:String)->String:
    var cfg:=ConfigFile.new(); if cfg.load(path)!=OK: return ""
    return str(cfg.get_value("plugin","name",""))

func _validate_handler_owner(handler:Callable,source_path:String)->Dictionary:
    var owner=handler.get_object()
    if owner==null: return _error("CUSTOM_HANDLER_OWNER_INVALID","Custom tool handler must be bound to a GDScript object owned by the registering addon")
    var script:Script=null
    if owner is Script: script=owner as Script
    elif owner is Object:
        var candidate=(owner as Object).get_script()
        if candidate is Script: script=candidate as Script
    var script_path:=script.resource_path if script!=null else ""
    var addon_dir:=source_path.get_base_dir()
    if script_path.is_empty() or not (script_path==addon_dir or script_path.begins_with(addon_dir+"/")):
        return _error("CUSTOM_HANDLER_OWNER_MISMATCH","Custom tool handler script must live inside the addon that owns source_path",{"source_path":source_path,"handler_script_path":script_path})
    return {"ok":true,"result":{"script_path":script_path}}

func _erase_source_index(name:String,source:String)->void:
    var names:Array=_by_source.get(source,[]); names.erase(name)
    if names.is_empty(): _by_source.erase(source)
    else: _by_source[source]=names

func _enable_key(spec:Dictionary)->String:
    return str(spec.get("source_path", "")) + "::" + str(spec.get("name", ""))

func _load_enabled()->void:
    _enabled.clear()
    if _editor_settings==null: return
    var stored=_editor_settings.get_project_metadata(META_SECTION,META_ENABLED,PackedStringArray())
    for key in PackedStringArray(stored): _enabled[str(key)]=true

func _save_enabled()->void:
    if _editor_settings==null: return
    var keys:=_enabled.keys(); keys.sort()
    var stored:=PackedStringArray()
    for key in keys: stored.append(str(key))
    _editor_settings.set_project_metadata(META_SECTION,META_ENABLED,stored)

func _error(code:String,message:String,details:Dictionary={})->Dictionary:
    var e:={"code":code,"message":message}; for key in details.keys(): e[key]=details[key]
    return {"ok":false,"error":e}

static func _error_static(code:String,message:String)->Dictionary:
    return {"ok":false,"error":{"code":code,"message":message}}