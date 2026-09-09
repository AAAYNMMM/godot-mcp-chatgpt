@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
    _add(registry,"content.animation_player_create","Create an AnimationPlayer in the edited scene.",{"parent_path":{"type":"string"},"name":{"type":"string"}},func(a): return await registry.call_command("node.create",{"parent_path":str(a.get("parent_path",".")),"type":"AnimationPlayer","name":str(a.get("name","AnimationPlayer"))}),false)
    _add(registry,"content.animation_create","Create an AnimationLibrary if needed and add an Animation clip using Godot UndoRedo.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"},"length":{"type":"number","minimum":0.001},"loop_mode":{"type":"string","enum":["none","linear","ping_pong"]}},func(a): return _animation_create(plugin,a),false,["player_path","animation"])
    _add(registry,"content.animation_delete","Delete an animation clip with UndoRedo support.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"}},func(a): return _animation_delete(plugin,a),false,["player_path","animation"],true)
    _add(registry,"content.animation_validate","Validate animation tracks, paths, key ordering and clip length.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"}},func(a): return _animation_validate(plugin,a),true,["player_path","animation"])
    _add(registry,"content.animation_add_property_track","Add a value/property track and keys. Changes are recorded in UndoRedo.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"},"target_path":{"type":"string"},"property":{"type":"string"},"keys":{"type":"array","maxItems":256},"interpolation":{"type":"string","enum":["nearest","linear","cubic","linear_angle","cubic_angle"]}},func(a): return _animation_property_track(plugin,a),false,["player_path","animation","target_path","property","keys"])
    _add(registry,"content.animation_add_method_track","Add a method track with bounded method-call keys. Changes are recorded in UndoRedo.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"},"target_path":{"type":"string"},"keys":{"type":"array","maxItems":128}},func(a): return _animation_method_track(plugin,a),false,["player_path","animation","target_path","keys"])
    _add(registry,"content.animation_set_autoplay","Set AnimationPlayer autoplay clip using UndoRedo.",{"player_path":{"type":"string"},"animation":{"type":"string"}},func(a): return _animation_autoplay(plugin,a),false,["player_path","animation"])
    _add(registry,"content.animation_play","Preview/play an animation in the editor AnimationPlayer.",{"player_path":{"type":"string"},"animation":{"type":"string"},"custom_blend":{"type":"number"},"custom_speed":{"type":"number"}},func(a): return _animation_play(plugin,a),false,["player_path","animation"])
    _add(registry,"content.animation_stop","Stop an editor AnimationPlayer preview.",{"player_path":{"type":"string"},"keep_state":{"type":"boolean"}},func(a): return _animation_stop(plugin,a),false,["player_path"])
    _add(registry,"content.animation_list","List AnimationPlayer libraries and clips.",{"player_path":{"type":"string"}},func(a): return _animation_list(plugin,a),true,["player_path"])
    _add(registry,"content.animation_get","Inspect one Animation clip and its tracks/keys.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"},"max_keys":{"type":"integer","minimum":1,"maximum":512}},func(a): return _animation_get(plugin,a),true,["player_path","animation"])
    _add(registry,"content.animation_create_simple","Create/replace a simple single-property animation clip.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"},"target_path":{"type":"string"},"property":{"type":"string"},"from":{},"to":{},"duration":{"type":"number","minimum":0.001},"loop_mode":{"type":"string","enum":["none","linear","ping_pong"]}},func(a): return _animation_simple(plugin,a),false,["player_path","animation","target_path","property","from","to"])
    _add(registry,"content.animation_apply_preset","Apply a bounded fade/slide/shake/pulse preset to a clip.",{"player_path":{"type":"string"},"animation":{"type":"string"},"library":{"type":"string"},"target_path":{"type":"string"},"preset":{"type":"string","enum":["fade","slide","shake","pulse"]},"duration":{"type":"number","minimum":0.001},"from":{},"to":{},"amplitude":{"type":"number"}},func(a): return _animation_preset(plugin,a),false,["player_path","animation","target_path","preset"])

static func _add(registry: RefCounted,name:String,description:String,properties:Dictionary,handler:Callable,read_only:bool,required:Array=[],destructive:bool=false)->void:
    registry.add_command(name,description,{"type":"object","properties":properties,"required":required,"additionalProperties":false},handler,{"readOnlyHint":read_only,"destructiveHint":destructive})

static func _player(plugin: EditorPlugin,path:String) -> AnimationPlayer:
    return U.resolve_node(plugin,path) as AnimationPlayer

static func _library_name(args:Dictionary)->StringName:
    return StringName(str(args.get("library","")))

static func _ensure_library(plugin:EditorPlugin,player:AnimationPlayer,name:StringName)->AnimationLibrary:
    if player.has_animation_library(name):
        return player.get_animation_library(name)
    var lib:=AnimationLibrary.new()
    var manager:=plugin.get_undo_redo()
    manager.create_action("Godot MCP: Add Animation Library",0,player)
    manager.add_do_method(player,"add_animation_library",name,lib)
    manager.add_undo_method(player,"remove_animation_library",name)
    manager.add_do_reference(lib)
    manager.commit_action()
    U.mark_unsaved(plugin)
    return player.get_animation_library(name)

static func _animation_create(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var name:=StringName(str(args.get("animation","")).strip_edges())
    if str(name).is_empty(): return U.error("ANIMATION_NAME_REQUIRED","animation is required")
    var lib_name:=_library_name(args)
    var lib:=_ensure_library(plugin,player,lib_name)
    if lib==null: return U.error("ANIMATION_LIBRARY_FAILED","Unable to create/find animation library")
    if lib.has_animation(name): return U.error("ANIMATION_EXISTS","Animation already exists: "+str(name))
    var anim:=Animation.new()
    anim.length=maxf(0.001,float(args.get("length",1.0)))
    anim.loop_mode=_loop_mode(str(args.get("loop_mode","none")))
    var manager:=plugin.get_undo_redo()
    manager.create_action("Godot MCP: Create Animation",0,player)
    manager.add_do_method(lib,"add_animation",name,anim)
    manager.add_undo_method(lib,"remove_animation",name)
    manager.add_do_reference(anim)
    manager.commit_action()
    U.mark_unsaved(plugin)
    return U.ok({"player_path":str(args.get("player_path","")),"library":str(lib_name),"animation":str(name),"length":anim.length,"loop_mode":_loop_name(anim.loop_mode),"undoable":true})

static func _animation_delete(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var found:=_clip(plugin,args)
    if not bool(found.get("ok",false)): return found
    var lib:AnimationLibrary=found.result.library
    var anim:Animation=found.result.animation_resource
    var name:StringName=found.result.animation_name
    var player:AnimationPlayer=found.result.player
    var manager:=plugin.get_undo_redo()
    manager.create_action("Godot MCP: Delete Animation",0,player)
    manager.add_do_method(lib,"remove_animation",name)
    manager.add_undo_method(lib,"add_animation",name,anim)
    manager.add_undo_reference(anim)
    manager.commit_action()
    U.mark_unsaved(plugin)
    return U.ok({"animation":str(name),"deleted":true,"undoable":true})

static func _clip(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var lib_name:=_library_name(args)
    if not player.has_animation_library(lib_name): return U.error("ANIMATION_LIBRARY_NOT_FOUND","Animation library not found: "+str(lib_name))
    var lib:=player.get_animation_library(lib_name)
    var name:=StringName(str(args.get("animation","")))
    if not lib.has_animation(name): return U.error("ANIMATION_NOT_FOUND","Animation not found: "+str(name))
    return U.ok({"player":player,"library":lib,"animation_resource":lib.get_animation(name),"animation_name":name,"library_name":lib_name})

static func _animation_property_track(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var found:=_clip(plugin,args)
    if not bool(found.get("ok",false)): return found
    var anim:Animation=found.result.animation_resource
    var target:=str(args.get("target_path","."))
    var property:=str(args.get("property","")).strip_edges()
    if property.is_empty(): return U.error("PROPERTY_REQUIRED","property is required")
    var keys:Array=args.get("keys",[])
    if keys.is_empty(): return U.error("ANIMATION_KEYS_REQUIRED","keys must not be empty")
    for raw in keys:
        if not raw is Dictionary: return U.error("INVALID_ANIMATION_KEY","Each key must be an object")
    var track:=anim.add_track(Animation.TYPE_VALUE)
    var path:=NodePath(target+":"+property)
    var interpolation:=_interpolation(str(args.get("interpolation","linear")))
    anim.track_set_path(track,path)
    anim.track_set_interpolation_type(track,interpolation)
    for raw in keys:
        var key:Dictionary=raw
        anim.track_insert_key(track,float(key.get("time",0.0)),U.decode_value(key.get("value")),float(key.get("transition",1.0)))
    _record_track_undo(plugin,found.result.player,anim,track,Animation.TYPE_VALUE,path,keys,interpolation)
    U.mark_unsaved(plugin)
    return U.ok({"animation":str(found.result.animation_name),"track":track,"type":"value","path":str(path),"keys":keys.size(),"undoable":true})

static func _record_track_undo(plugin:EditorPlugin,player:AnimationPlayer,anim:Animation,track:int,track_type:int,path:NodePath,keys:Array,interpolation:int)->void:
    var manager:=plugin.get_undo_redo()
    manager.create_action("Godot MCP: Add Animation Track",0,player)
    manager.add_do_method(anim,"add_track",track_type,track)
    manager.add_do_method(anim,"track_set_path",track,path)
    if track_type==Animation.TYPE_VALUE:
        manager.add_do_method(anim,"track_set_interpolation_type",track,interpolation)
    for raw in keys:
        var key:Dictionary=raw
        var value=U.decode_value(key.get("value"))
        if track_type==Animation.TYPE_METHOD:
            var call_args:Array=[]
            for item in key.get("arguments",[]): call_args.append(U.decode_value(item))
            value={"method":StringName(str(key.get("method",""))),"args":call_args}
        manager.add_do_method(anim,"track_insert_key",track,float(key.get("time",0.0)),value,float(key.get("transition",1.0)))
    manager.add_undo_method(anim,"remove_track",track)
    manager.commit_action(false)

static func _animation_method_track(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var found:=_clip(plugin,args)
    if not bool(found.get("ok",false)): return found
    var anim:Animation=found.result.animation_resource
    var keys:Array=args.get("keys",[])
    if keys.is_empty(): return U.error("ANIMATION_KEYS_REQUIRED","keys must not be empty")
    for raw in keys:
        if not raw is Dictionary: return U.error("INVALID_ANIMATION_KEY","Each method key must be an object")
        if str(raw.get("method","")).strip_edges().is_empty(): return U.error("METHOD_REQUIRED","method-track keys require method")
    var target:=str(args.get("target_path","."))
    var track:=anim.add_track(Animation.TYPE_METHOD)
    anim.track_set_path(track,NodePath(target))
    for raw in keys:
        var key:Dictionary=raw
        var call_args:Array=[]
        for value in key.get("arguments",[]): call_args.append(U.decode_value(value))
        anim.track_insert_key(track,float(key.get("time",0.0)),{"method":StringName(str(key.get("method",""))),"args":call_args},float(key.get("transition",1.0)))
    _record_track_undo(plugin,found.result.player,anim,track,Animation.TYPE_METHOD,NodePath(target),keys,Animation.INTERPOLATION_LINEAR)
    U.mark_unsaved(plugin)
    return U.ok({"animation":str(found.result.animation_name),"track":track,"type":"method","path":target,"keys":keys.size(),"undoable":true})

static func _animation_autoplay(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var name:=StringName(str(args.get("animation","")))
    if not str(name).is_empty() and not player.has_animation(name): return U.error("ANIMATION_NOT_FOUND","Animation not found: "+str(name))
    var old:=player.autoplay
    var manager:=plugin.get_undo_redo()
    manager.create_action("Godot MCP: Set Animation Autoplay",0,player)
    manager.add_do_property(player,"autoplay",name)
    manager.add_undo_property(player,"autoplay",old)
    manager.commit_action()
    U.mark_unsaved(plugin)
    return U.ok({"autoplay":str(player.autoplay),"undoable":true})

static func _animation_play(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var name:=StringName(str(args.get("animation","")))
    if not player.has_animation(name): return U.error("ANIMATION_NOT_FOUND","Animation not found: "+str(name))
    player.play(name,float(args.get("custom_blend",-1.0)),float(args.get("custom_speed",1.0)))
    return U.ok({"playing":true,"animation":str(name)})

static func _animation_stop(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    player.stop(bool(args.get("keep_state",false)))
    return U.ok({"playing":false})

static func _animation_list(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var libraries:Array=[]
    for lib_name in player.get_animation_library_list():
        var lib:=player.get_animation_library(lib_name)
        var clips:Array=[]
        for name in lib.get_animation_list():
            var anim:=lib.get_animation(name)
            clips.append({"name":str(name),"length":anim.length,"loop_mode":_loop_name(anim.loop_mode),"tracks":anim.get_track_count()})
        libraries.append({"name":str(lib_name),"animations":clips})
    return U.ok({"player":str(args.get("player_path","")),"libraries":libraries,"autoplay":str(player.autoplay)})

static func _animation_get(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var found:=_clip(plugin,args)
    if not bool(found.get("ok",false)): return found
    var anim:Animation=found.result.animation_resource
    var max_keys:=clampi(int(args.get("max_keys",128)),1,512)
    var tracks:Array=[]
    var emitted:=0
    for i in anim.get_track_count():
        var keys:Array=[]
        for k in anim.track_get_key_count(i):
            if emitted>=max_keys: break
            keys.append({"time":anim.track_get_key_time(i,k),"value":U.encode_value(anim.track_get_key_value(i,k)),"transition":anim.track_get_key_transition(i,k)})
            emitted+=1
        tracks.append({"index":i,"type":anim.track_get_type(i),"path":str(anim.track_get_path(i)),"enabled":anim.track_is_enabled(i),"keys":keys,"key_count":anim.track_get_key_count(i)})
    return U.ok({"animation":str(found.result.animation_name),"library":str(found.result.library_name),"length":anim.length,"loop_mode":_loop_name(anim.loop_mode),"tracks":tracks,"truncated":emitted>=max_keys})

static func _animation_validate(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var found:=_clip(plugin,args)
    if not bool(found.get("ok",false)): return found
    var anim:Animation=found.result.animation_resource
    var player:AnimationPlayer=found.result.player
    var issues:Array=[]
    if anim.length<=0.0: issues.append({"code":"INVALID_LENGTH","message":"Animation length must be > 0"})
    var root:=player.get_node_or_null(player.root_node)
    for i in anim.get_track_count():
        var path:=anim.track_get_path(i)
        var node_text:=str(path).get_slice(":",0)
        var node_path:=NodePath(node_text)
        if root!=null and node_text!="." and root.get_node_or_null(node_path)==null: issues.append({"code":"TRACK_TARGET_MISSING","track":i,"path":str(path)})
        var last:=-INF
        for k in anim.track_get_key_count(i):
            var time:=anim.track_get_key_time(i,k)
            if time<last: issues.append({"code":"KEY_ORDER","track":i,"key":k})
            if time<0.0 or time>anim.length+0.0001: issues.append({"code":"KEY_OUTSIDE_LENGTH","track":i,"key":k,"time":time})
            last=time
    return U.ok({"valid":issues.is_empty(),"issues":issues,"tracks":anim.get_track_count(),"length":anim.length})

static func _animation_simple(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var lib_name:=_library_name(args)
    var lib:=_ensure_library(plugin,player,lib_name)
    var name:=StringName(str(args.get("animation","")))
    if lib.has_animation(name):
        var deleted:=_animation_delete(plugin,args)
        if not bool(deleted.get("ok",false)): return deleted
    var create_args:=args.duplicate(true)
    create_args["length"]=float(args.get("duration",1.0))
    var created:=_animation_create(plugin,create_args)
    if not bool(created.get("ok",false)): return created
    return _animation_property_track(plugin,{"player_path":args.get("player_path"),"animation":args.get("animation"),"library":str(lib_name),"target_path":args.get("target_path"),"property":args.get("property"),"keys":[{"time":0.0,"value":args.get("from")},{"time":float(args.get("duration",1.0)),"value":args.get("to")}],"interpolation":"linear"})

static func _animation_preset(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var preset:=str(args.get("preset",""))
    var duration:=maxf(0.001,float(args.get("duration",0.5)))
    var target:=str(args.get("target_path","."))
    var common={"player_path":args.get("player_path"),"animation":args.get("animation"),"library":str(args.get("library","")),"target_path":target,"duration":duration,"loop_mode":"none"}
    match preset:
        "fade":
            common["property"]="modulate:a"; common["from"]=args.get("from",0.0); common["to"]=args.get("to",1.0)
            return _animation_simple(plugin,common)
        "slide":
            common["property"]="position"; common["from"]=args.get("from",{"__godot_type":"Vector2","x":-64.0,"y":0.0}); common["to"]=args.get("to",{"__godot_type":"Vector2","x":0.0,"y":0.0})
            return _animation_simple(plugin,common)
        "shake":
            var amp:=float(args.get("amplitude",8.0))
            var setup:=_prepare_preset_clip(plugin,args,duration)
            if not bool(setup.get("ok",false)): return setup
            return _animation_property_track(plugin,{"player_path":args.get("player_path"),"animation":args.get("animation"),"library":str(args.get("library","")),"target_path":target,"property":"position","keys":[{"time":0.0,"value":{"__godot_type":"Vector2","x":0,"y":0}},{"time":duration*0.25,"value":{"__godot_type":"Vector2","x":amp,"y":0}},{"time":duration*0.5,"value":{"__godot_type":"Vector2","x":-amp,"y":0}},{"time":duration*0.75,"value":{"__godot_type":"Vector2","x":amp*0.5,"y":0}},{"time":duration,"value":{"__godot_type":"Vector2","x":0,"y":0}}],"interpolation":"linear"})
        "pulse":
            var amp:=float(args.get("amplitude",0.15))
            var setup:=_prepare_preset_clip(plugin,args,duration)
            if not bool(setup.get("ok",false)): return setup
            return _animation_property_track(plugin,{"player_path":args.get("player_path"),"animation":args.get("animation"),"library":str(args.get("library","")),"target_path":target,"property":"scale","keys":[{"time":0.0,"value":{"__godot_type":"Vector2","x":1,"y":1}},{"time":duration*0.5,"value":{"__godot_type":"Vector2","x":1+amp,"y":1+amp}},{"time":duration,"value":{"__godot_type":"Vector2","x":1,"y":1}}],"interpolation":"cubic"})
    return U.error("UNKNOWN_PRESET","Unknown animation preset")

static func _prepare_preset_clip(plugin:EditorPlugin,args:Dictionary,duration:float)->Dictionary:
    var player:=_player(plugin,str(args.get("player_path","")))
    if player==null: return U.error("ANIMATION_PLAYER_NOT_FOUND","AnimationPlayer not found")
    var lib:=_ensure_library(plugin,player,_library_name(args))
    var name:=StringName(str(args.get("animation","")))
    if lib.has_animation(name):
        var deleted:=_animation_delete(plugin,args)
        if not bool(deleted.get("ok",false)): return deleted
    var create_args:=args.duplicate(true); create_args["length"]=duration; create_args["loop_mode"]="none"
    return _animation_create(plugin,create_args)

static func _loop_mode(value:String)->int:
    match value:
        "linear": return Animation.LOOP_LINEAR
        "ping_pong": return Animation.LOOP_PINGPONG
        _: return Animation.LOOP_NONE

static func _loop_name(value:int)->String:
    match value:
        Animation.LOOP_LINEAR: return "linear"
        Animation.LOOP_PINGPONG: return "ping_pong"
        _: return "none"

static func _interpolation(value:String)->int:
    match value:
        "nearest": return Animation.INTERPOLATION_NEAREST
        "cubic": return Animation.INTERPOLATION_CUBIC
        "linear_angle": return Animation.INTERPOLATION_LINEAR_ANGLE
        "cubic_angle": return Animation.INTERPOLATION_CUBIC_ANGLE
        _: return Animation.INTERPOLATION_LINEAR