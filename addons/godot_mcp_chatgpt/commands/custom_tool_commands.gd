@tool
extends RefCounted

static func register(registry:RefCounted, custom_tools:RefCounted)->void:
    _add(registry,"custom.list","List third-party custom MCP tools registered with this addon.",{"include_disabled":{"type":"boolean"}},func(a): return {"ok":true,"result":{"tools":custom_tools.list_tools(bool(a.get("include_disabled",true)))}} ,true)
    _add(registry,"custom.get","Inspect one registered third-party custom MCP tool.",{"name":{"type":"string"}},func(a): return _get_custom_tool(custom_tools,a),true,["name"])
    _add(registry,"custom.invoke","Invoke one enabled third-party custom MCP tool after schema validation.",{"name":{"type":"string"},"arguments":{"type":"object"}},func(a): return await custom_tools.invoke(str(a.get("name","")),a.get("arguments",{})),false,["name"],true)
    _add(registry,"custom.set_enabled","Enable or disable one registered custom tool for this project.",{"name":{"type":"string"},"enabled":{"type":"boolean"}},func(a): return custom_tools.set_enabled(str(a.get("name","")),bool(a.get("enabled",true))),false,["name","enabled"])

static func _get_custom_tool(custom_tools:RefCounted,args:Dictionary)->Dictionary:
    var name:=str(args.get("name","")); var spec:Dictionary=custom_tools.get_spec(name)
    if spec.is_empty(): return {"ok":false,"error":{"code":"CUSTOM_TOOL_NOT_FOUND","message":"Custom tool not found: "+name}}
    spec.erase("handler")
    spec["enabled"]=custom_tools.is_enabled(name)
    return {"ok":true,"result":spec}

static func _add(registry:RefCounted,name:String,description:String,properties:Dictionary,handler:Callable,read_only:bool,required:Array=[],destructive:bool=false)->void:
    registry.add_command(name,description,{"type":"object","properties":properties,"required":required,"additionalProperties":false},handler,{"readOnlyHint":read_only,"destructiveHint":destructive})