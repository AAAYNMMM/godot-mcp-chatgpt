@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const MAX_LIST := 256

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
    _material_tools(registry,plugin)
    _audio_tools(registry,plugin)
    _particle_tools(registry,plugin)
    _camera_tools(registry,plugin)

static func _material_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.material_create","Create and save a Godot Material resource.",{"path":{"type":"string"},"kind":{"type":"string","enum":["standard_3d","canvas_item","shader"]},"properties":{"type":"object"},"shader_path":{"type":"string"},"shader_code":{"type":"string"}},func(a): return _material_create(a),false,["path","kind"])
    _add(registry,"content.material_set_param","Set and save a Material property by Godot property name.",{"path":{"type":"string"},"property":{"type":"string"},"value":{}},func(a): return _material_set(a),false,["path","property","value"])
    _add(registry,"content.material_set_shader_param","Set and save a ShaderMaterial uniform.",{"path":{"type":"string"},"param":{"type":"string"},"value":{}},func(a): return _material_shader_param(a),false,["path","param","value"])
    _add(registry,"content.material_get","Inspect a Material resource with stored properties.",{"path":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":400}},func(a): return _material_get(a),true,["path"])
    _add(registry,"content.material_list","Find Material resources under a project path.",{"root":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":256}},func(a): return _material_list(a),true)
    _add(registry,"content.material_assign","Assign a Material to a material-capable node property using UndoRedo.",{"node_path":{"type":"string"},"material_path":{"type":"string"},"property":{"type":"string"}},func(a): return _material_assign(plugin,a),false,["node_path","material_path"])
    _add(registry,"content.material_apply_preset","Apply a bounded StandardMaterial3D preset.",{"path":{"type":"string"},"preset":{"type":"string","enum":["matte","metallic","emissive","transparent","unshaded"]},"color":{}},func(a): return _material_preset(a),false,["path","preset"])

static func _audio_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.audio_player_create","Create AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D.",{"parent_path":{"type":"string"},"name":{"type":"string"},"dimension":{"type":"string","enum":["global","2d","3d"]}},func(a): return await _audio_create(registry,a),false)
    _add(registry,"content.audio_set_stream","Load and assign an AudioStream resource using UndoRedo.",{"player_path":{"type":"string"},"stream_path":{"type":"string"}},func(a): return _audio_stream(plugin,a),false,["player_path","stream_path"])
    _add(registry,"content.audio_set_playback","Configure bounded playback properties using UndoRedo.",{"player_path":{"type":"string"},"volume_db":{"type":"number"},"pitch_scale":{"type":"number"},"autoplay":{"type":"boolean"},"bus":{"type":"string"}},func(a): return _audio_playback(plugin,a),false,["player_path"])
    _add(registry,"content.audio_play","Play an editor AudioStreamPlayer preview.",{"player_path":{"type":"string"},"from_position":{"type":"number","minimum":0}},func(a): return _audio_play(plugin,a),false,["player_path"])
    _add(registry,"content.audio_stop","Stop an editor AudioStreamPlayer preview.",{"player_path":{"type":"string"}},func(a): return _audio_stop(plugin,a),false,["player_path"])
    _add(registry,"content.audio_list","List audio players in the edited scene.",{},func(_a): return _audio_list(plugin),true)

static func _particle_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.particle_create","Create GPUParticles2D/3D and optionally a ParticleProcessMaterial.",{"parent_path":{"type":"string"},"name":{"type":"string"},"dimension":{"type":"string","enum":["2d","3d"]},"create_process_material":{"type":"boolean"}},func(a): return await _particle_create(registry,plugin,a),false)
    _add(registry,"content.particle_set_main","Set bounded GPUParticles main properties.",{"node_path":{"type":"string"},"properties":{"type":"object"}},func(a): return _particle_main(plugin,a),false,["node_path","properties"])
    _add(registry,"content.particle_set_process","Set ParticleProcessMaterial properties, creating one when missing.",{"node_path":{"type":"string"},"properties":{"type":"object"}},func(a): return _particle_process(plugin,a),false,["node_path","properties"])
    _add(registry,"content.particle_set_draw_pass","Assign GPUParticles3D draw_pass_1 Mesh or GPUParticles2D texture.",{"node_path":{"type":"string"},"resource_path":{"type":"string"}},func(a): return _particle_draw(plugin,a),false,["node_path","resource_path"])
    _add(registry,"content.particle_restart","Restart a GPUParticles node.",{"node_path":{"type":"string"},"keep_seed":{"type":"boolean"}},func(a): return _particle_restart(plugin,a),false,["node_path"])
    _add(registry,"content.particle_get","Inspect a GPUParticles node and process material.",{"node_path":{"type":"string"}},func(a): return _particle_get(plugin,a),true,["node_path"])
    _add(registry,"content.particle_apply_preset","Apply a bounded fire/smoke/sparks/snow preset.",{"node_path":{"type":"string"},"preset":{"type":"string","enum":["fire","smoke","sparks","snow"]}},func(a): return _particle_preset(plugin,a),false,["node_path","preset"])

static func _camera_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.camera_create","Create Camera2D or Camera3D.",{"parent_path":{"type":"string"},"name":{"type":"string"},"dimension":{"type":"string","enum":["2d","3d"]}},func(a): return await _camera_create(registry,a),false)
    _add(registry,"content.camera_configure","Configure common Camera2D/3D properties using UndoRedo.",{"node_path":{"type":"string"},"properties":{"type":"object"}},func(a): return _camera_configure(plugin,a),false,["node_path","properties"])
    _add(registry,"content.camera_set_limits_2d","Set Camera2D limits.",{"node_path":{"type":"string"},"left":{"type":"integer"},"top":{"type":"integer"},"right":{"type":"integer"},"bottom":{"type":"integer"}},func(a): return _camera_limits(plugin,a),false,["node_path"])
    _add(registry,"content.camera_set_damping_2d","Configure Camera2D position/rotation smoothing.",{"node_path":{"type":"string"},"enabled":{"type":"boolean"},"speed":{"type":"number"},"rotation_enabled":{"type":"boolean"},"rotation_speed":{"type":"number"}},func(a): return _camera_damping(plugin,a),false,["node_path"])
    _add(registry,"content.camera_follow_2d","Make a Camera2D follow a Node2D by reparenting while preserving global transform.",{"node_path":{"type":"string"},"target_path":{"type":"string"},"offset":{}},func(a): return _camera_follow(plugin,a),false,["node_path","target_path"])
    _add(registry,"content.camera_get","Inspect a Camera2D/Camera3D.",{"node_path":{"type":"string"}},func(a): return _camera_get(plugin,a),true,["node_path"])
    _add(registry,"content.camera_list","List cameras in the edited scene.",{},func(_a): return _camera_list(plugin),true)
    _add(registry,"content.camera_apply_preset","Apply a bounded camera preset.",{"node_path":{"type":"string"},"preset":{"type":"string","enum":["platformer_2d","top_down_2d","first_person_3d","cinematic_3d"]}},func(a): return _camera_preset(plugin,a),false,["node_path","preset"])

static func _add(registry:RefCounted,name:String,description:String,properties:Dictionary,handler:Callable,read_only:bool,required:Array=[],destructive:bool=false)->void:
    registry.add_command(name,description,{"type":"object","properties":properties,"required":required,"additionalProperties":false},handler,{"readOnlyHint":read_only,"destructiveHint":destructive})

static func _material_create(args:Dictionary)->Dictionary:
    var path:=str(args.get("path",""))
    if not U.valid_res_path(path): return U.error("INVALID_PATH","material path must stay inside res://")
    var material:Material
    match str(args.get("kind","standard_3d")):
        "canvas_item": material=CanvasItemMaterial.new()
        "shader":
            var shader_material:=ShaderMaterial.new(); var shader:=Shader.new(); var shader_path:=str(args.get("shader_path",""))
            if not shader_path.is_empty():
                if not U.valid_res_path(shader_path): return U.error("INVALID_PATH","shader_path must stay inside res://")
                shader=ResourceLoader.load(shader_path,"Shader",ResourceLoader.CACHE_MODE_REPLACE) as Shader
                if shader==null: return U.error("SHADER_LOAD_FAILED","Unable to load Shader")
            elif not str(args.get("shader_code","")).is_empty(): shader.code=str(args.get("shader_code",""))
            shader_material.shader=shader; material=shader_material
        _: material=StandardMaterial3D.new()
    var properties=args.get("properties",{})
    if properties is Dictionary:
        for key in properties.keys():
            if U.property_exists(material,str(key)): material.set(str(key),U.decode_value(properties[key]))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
    var err:=ResourceSaver.save(material,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"class":material.get_class(),"saved":true})

static func _load_material(path:String)->Material:
    if not U.valid_res_path(path): return null
    return ResourceLoader.load(path,"Material",ResourceLoader.CACHE_MODE_REPLACE) as Material

static func _material_set(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var material:=_load_material(path)
    if material==null: return U.error("MATERIAL_LOAD_FAILED","Unable to load Material")
    var property:=str(args.get("property","")); if not U.property_exists(material,property): return U.error("PROPERTY_NOT_FOUND","Material property not found: "+property)
    material.set(property,U.decode_value(args.get("value"))); var err:=ResourceSaver.save(material,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"property":property,"value":U.encode_value(material.get(property))})

static func _material_shader_param(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var material:=_load_material(path) as ShaderMaterial
    if material==null: return U.error("SHADER_MATERIAL_REQUIRED","Material is not a ShaderMaterial")
    var param:=StringName(str(args.get("param",""))); material.set_shader_parameter(param,U.decode_value(args.get("value"))); var err:=ResourceSaver.save(material,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"param":str(param),"value":U.encode_value(material.get_shader_parameter(param))})

static func _material_get(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var material:=_load_material(path); if material==null: return U.error("MATERIAL_LOAD_FAILED","Unable to load Material")
    var limit:=clampi(int(args.get("limit",160)),1,400); var properties:Array=[]
    for info in material.get_property_list():
        if (int(info.get("usage",0)) & PROPERTY_USAGE_STORAGE)==0: continue
        var name:=str(info.get("name","")); properties.append({"name":name,"type":type_string(int(info.get("type",TYPE_NIL))),"value":U.encode_value(material.get(name))})
        if properties.size()>=limit: break
    return U.ok({"path":path,"class":material.get_class(),"properties":properties})

static func _material_list(args:Dictionary)->Dictionary:
    var root:=str(args.get("root","res://")); if root!="res://" and not U.valid_res_path(root): return U.error("INVALID_PATH","root must stay inside res://")
    var limit:=clampi(int(args.get("limit",128)),1,MAX_LIST); var paths:Array[String]=[]; _walk_materials(root,paths,limit); return U.ok({"materials":paths,"count":paths.size(),"truncated":paths.size()>=limit})

static func _walk_materials(root:String,out:Array[String],limit:int)->void:
    if out.size()>=limit: return
    var dir:=DirAccess.open(root); if dir==null: return
    dir.list_dir_begin()
    while true:
        var name:=dir.get_next(); if name.is_empty(): break
        if name in [".",".."]: continue
        var path:=root.path_join(name)
        if dir.current_is_dir():
            if not name.begins_with("."): _walk_materials(path,out,limit)
        elif name.get_extension().to_lower() in ["tres","res"]:
            var resource:=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REUSE); if resource is Material: out.append(path)
        if out.size()>=limit: break
    dir.list_dir_end()

static func _material_assign(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=U.resolve_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("NODE_NOT_FOUND","Node not found")
    var material:=_load_material(str(args.get("material_path",""))); if material==null: return U.error("MATERIAL_LOAD_FAILED","Unable to load Material")
    var property:=str(args.get("property","")); if property.is_empty(): property=_default_material_property(node)
    if property.is_empty() or not U.property_exists(node,property): return U.error("MATERIAL_PROPERTY_NOT_FOUND","No compatible material property found; specify property")
    var old=node.get(property); var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Assign Material",0,node); manager.add_do_property(node,property,material); manager.add_undo_property(node,property,old); manager.add_do_reference(material); manager.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"node_path":str(args.get("node_path","")),"property":property,"material_path":str(args.get("material_path","")),"undoable":true})

static func _default_material_property(node:Node)->String:
    for candidate in ["material_override","material","process_material"]:
        if U.property_exists(node,candidate): return candidate
    return ""

static func _material_preset(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var material:=_load_material(path) as StandardMaterial3D; if material==null: return U.error("STANDARD_MATERIAL_REQUIRED","Preset requires StandardMaterial3D")
    var color=U.decode_value(args.get("color",{"__godot_type":"Color","r":1,"g":1,"b":1,"a":1})); if color is Color: material.albedo_color=color
    match str(args.get("preset","")):
        "matte": material.metallic=0.0; material.roughness=0.85
        "metallic": material.metallic=1.0; material.roughness=0.2
        "emissive": material.emission_enabled=true; material.emission=material.albedo_color; material.emission_energy_multiplier=2.0
        "transparent": material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; var x:=material.albedo_color; x.a=0.45; material.albedo_color=x
        "unshaded": material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        _: return U.error("UNKNOWN_PRESET","Unknown material preset")
    var err:=ResourceSaver.save(material,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"preset":str(args.get("preset","")),"saved":true})

static func _audio_create(registry:RefCounted,args:Dictionary)->Dictionary:
    var cls:="AudioStreamPlayer"
    match str(args.get("dimension","global")):
        "2d": cls="AudioStreamPlayer2D"
        "3d": cls="AudioStreamPlayer3D"
    return await registry.call_command("node.create",{"parent_path":str(args.get("parent_path",".")),"type":cls,"name":str(args.get("name",cls))})

static func _audio_node(plugin:EditorPlugin,path:String)->Node:
    var node:=U.resolve_node(plugin,path); return node if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D else null

static func _audio_stream(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_audio_node(plugin,str(args.get("player_path",""))); if node==null: return U.error("AUDIO_PLAYER_NOT_FOUND","Audio player not found")
    var path:=str(args.get("stream_path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","stream_path must stay inside res://")
    var stream:=ResourceLoader.load(path,"AudioStream",ResourceLoader.CACHE_MODE_REPLACE) as AudioStream; if stream==null: return U.error("AUDIO_STREAM_LOAD_FAILED","Unable to load AudioStream")
    var old=node.get("stream"); var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Set Audio Stream",0,node); manager.add_do_property(node,"stream",stream); manager.add_undo_property(node,"stream",old); manager.add_do_reference(stream); manager.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"player_path":str(args.get("player_path","")),"stream_path":path,"undoable":true})

static func _audio_playback(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_audio_node(plugin,str(args.get("player_path",""))); if node==null: return U.error("AUDIO_PLAYER_NOT_FOUND","Audio player not found")
    var changes:Dictionary={}; for property in ["volume_db","pitch_scale","autoplay","bus"]: if args.has(property): changes[property]=args[property]
    return _undo_properties(plugin,node,changes,"Godot MCP: Configure Audio")

static func _audio_play(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_audio_node(plugin,str(args.get("player_path",""))); if node==null: return U.error("AUDIO_PLAYER_NOT_FOUND","Audio player not found")
    node.call("play",float(args.get("from_position",0.0))); return U.ok({"playing":true,"player_path":str(args.get("player_path",""))})

static func _audio_stop(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_audio_node(plugin,str(args.get("player_path",""))); if node==null: return U.error("AUDIO_PLAYER_NOT_FOUND","Audio player not found")
    node.call("stop"); return U.ok({"playing":false,"player_path":str(args.get("player_path",""))})

static func _audio_list(plugin:EditorPlugin)->Dictionary:
    var root:=plugin.get_editor_interface().get_edited_scene_root(); if root==null: return U.error("NO_SCENE","No edited scene")
    var out:Array=[]; _collect_scene(root,root,func(node): return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D,out); return U.ok({"players":out,"count":out.size()})
static func _particle_create(registry:RefCounted,plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var cls:="GPUParticles3D" if str(args.get("dimension","2d"))=="3d" else "GPUParticles2D"
    var created:Dictionary=await registry.call_command("node.create",{"parent_path":str(args.get("parent_path",".")),"type":cls,"name":str(args.get("name",cls))})
    if not bool(created.get("ok",false)): return created
    var path:=str(created.result.get("node_path","")); var node:=U.resolve_node(plugin,path)
    if node!=null and bool(args.get("create_process_material",true)):
        node.set("process_material",ParticleProcessMaterial.new()); U.mark_unsaved(plugin)
    return U.ok({"node_path":path,"class":cls,"process_material":node!=null and node.get("process_material")!=null,"undoable":created.result.get("undoable",false)})

static func _particle_node(plugin:EditorPlugin,path:String)->Node:
    var node:=U.resolve_node(plugin,path); return node if node is GPUParticles2D or node is GPUParticles3D else null

static func _particle_main(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_particle_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("PARTICLE_NODE_NOT_FOUND","GPUParticles node not found")
    var allowed=["emitting","amount","lifetime","one_shot","preprocess","explosiveness","randomness","speed_scale","fixed_fps","interpolate","fract_delta"]
    var changes:Dictionary={}; var props:Dictionary=args.get("properties",{})
    for key in props.keys():
        if str(key) in allowed and U.property_exists(node,str(key)): changes[str(key)]=props[key]
    return _undo_properties(plugin,node,changes,"Godot MCP: Configure Particles")

static func _particle_process(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_particle_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("PARTICLE_NODE_NOT_FOUND","GPUParticles node not found")
    var material:=node.get("process_material") as ParticleProcessMaterial
    if material==null: material=ParticleProcessMaterial.new(); node.set("process_material",material)
    var changed:Array=[]; var props:Dictionary=args.get("properties",{})
    for key in props.keys():
        var name:=str(key)
        if U.property_exists(material,name): material.set(name,U.decode_value(props[key])); changed.append(name)
    U.mark_unsaved(plugin); return U.ok({"node_path":str(args.get("node_path","")),"changed":changed,"process_material":U.encode_value(material)})

static func _particle_draw(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_particle_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("PARTICLE_NODE_NOT_FOUND","GPUParticles node not found")
    var path:=str(args.get("resource_path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","resource_path must stay inside res://")
    var resource:=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE); if resource==null: return U.error("RESOURCE_LOAD_FAILED","Unable to load particle draw resource")
    var property:="draw_pass_1" if node is GPUParticles3D else "texture"
    if node is GPUParticles3D and not resource is Mesh: return U.error("MESH_REQUIRED","GPUParticles3D draw pass requires Mesh")
    if node is GPUParticles2D and not resource is Texture2D: return U.error("TEXTURE_REQUIRED","GPUParticles2D requires Texture2D")
    var old=node.get(property); var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Set Particle Draw Resource",0,node); manager.add_do_property(node,property,resource); manager.add_undo_property(node,property,old); manager.add_do_reference(resource); manager.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"node_path":str(args.get("node_path","")),"property":property,"resource_path":path,"undoable":true})

static func _particle_restart(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_particle_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("PARTICLE_NODE_NOT_FOUND","GPUParticles node not found")
    node.call("restart",bool(args.get("keep_seed",false))); return U.ok({"restarted":true,"node_path":str(args.get("node_path",""))})

static func _particle_get(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_particle_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("PARTICLE_NODE_NOT_FOUND","GPUParticles node not found")
    var material:=node.get("process_material") as ParticleProcessMaterial; var process:Dictionary={}
    if material!=null:
        for name in ["direction","spread","gravity","initial_velocity_min","initial_velocity_max","scale_min","scale_max","color"]:
            if U.property_exists(material,name): process[name]=U.encode_value(material.get(name))
    return U.ok({"node":U.object_summary(node),"emitting":node.get("emitting"),"amount":node.get("amount"),"lifetime":node.get("lifetime"),"one_shot":node.get("one_shot"),"process":process})

static func _particle_preset(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_particle_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("PARTICLE_NODE_NOT_FOUND","GPUParticles node not found")
    var main:Dictionary={}; var process:Dictionary={}
    match str(args.get("preset","")):
        "fire": main={"amount":96,"lifetime":1.2}; process={"direction":Vector3(0,-1,0),"spread":22.0,"initial_velocity_min":35.0,"initial_velocity_max":70.0,"gravity":Vector3(0,-18,0),"scale_min":0.35,"scale_max":0.9,"color":Color(1.0,0.35,0.05,1.0)}
        "smoke": main={"amount":64,"lifetime":3.0}; process={"direction":Vector3(0,-1,0),"spread":35.0,"initial_velocity_min":10.0,"initial_velocity_max":24.0,"gravity":Vector3(0,-3,0),"scale_min":0.8,"scale_max":1.8,"color":Color(0.35,0.35,0.35,0.75)}
        "sparks": main={"amount":80,"lifetime":0.8,"one_shot":false}; process={"direction":Vector3(0,-1,0),"spread":75.0,"initial_velocity_min":80.0,"initial_velocity_max":160.0,"gravity":Vector3(0,120,0),"scale_min":0.08,"scale_max":0.18,"color":Color(1.0,0.75,0.2,1.0)}
        "snow": main={"amount":220,"lifetime":6.0}; process={"direction":Vector3(0,1,0),"spread":18.0,"initial_velocity_min":12.0,"initial_velocity_max":24.0,"gravity":Vector3(0,10,0),"scale_min":0.08,"scale_max":0.22,"color":Color(1,1,1,0.95)}
        _: return U.error("UNKNOWN_PRESET","Unknown particle preset")
    _particle_main(plugin,{"node_path":args.get("node_path"),"properties":main})
    var result:=_particle_process(plugin,{"node_path":args.get("node_path"),"properties":process})
    if bool(result.get("ok",false)): result.result["preset"]=str(args.get("preset",""))
    return result

static func _camera_create(registry:RefCounted,args:Dictionary)->Dictionary:
    var cls:="Camera3D" if str(args.get("dimension","2d"))=="3d" else "Camera2D"
    return await registry.call_command("node.create",{"parent_path":str(args.get("parent_path",".")),"type":cls,"name":str(args.get("name",cls))})

static func _camera_node(plugin:EditorPlugin,path:String)->Node:
    var node:=U.resolve_node(plugin,path); return node if node is Camera2D or node is Camera3D else null

static func _camera_configure(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_camera_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("CAMERA_NOT_FOUND","Camera2D/3D not found")
    var allowed_2d=["zoom","offset","anchor_mode","ignore_rotation","enabled","position_smoothing_enabled","position_smoothing_speed","rotation_smoothing_enabled","rotation_smoothing_speed","drag_horizontal_enabled","drag_vertical_enabled","drag_left_margin","drag_top_margin","drag_right_margin","drag_bottom_margin"]
    var allowed_3d=["projection","fov","size","near","far","keep_aspect","cull_mask","current","environment","attributes","doppler_tracking"]
    var allowed:Array = allowed_2d if node is Camera2D else allowed_3d; var changes:Dictionary={}; var props:Dictionary=args.get("properties",{})
    for key in props.keys():
        if str(key) in allowed and U.property_exists(node,str(key)): changes[str(key)]=props[key]
    return _undo_properties(plugin,node,changes,"Godot MCP: Configure Camera")

static func _camera_limits(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_camera_node(plugin,str(args.get("node_path",""))) as Camera2D; if node==null: return U.error("CAMERA2D_REQUIRED","Camera2D not found")
    var changes:Dictionary={}
    if args.has("left"): changes["limit_left"]=args.left
    if args.has("top"): changes["limit_top"]=args.top
    if args.has("right"): changes["limit_right"]=args.right
    if args.has("bottom"): changes["limit_bottom"]=args.bottom
    return _undo_properties(plugin,node,changes,"Godot MCP: Set Camera2D Limits")

static func _camera_damping(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_camera_node(plugin,str(args.get("node_path",""))) as Camera2D; if node==null: return U.error("CAMERA2D_REQUIRED","Camera2D not found")
    var changes:Dictionary={}
    if args.has("enabled"): changes["position_smoothing_enabled"]=args.enabled
    if args.has("speed"): changes["position_smoothing_speed"]=args.speed
    if args.has("rotation_enabled"): changes["rotation_smoothing_enabled"]=args.rotation_enabled
    if args.has("rotation_speed"): changes["rotation_smoothing_speed"]=args.rotation_speed
    return _undo_properties(plugin,node,changes,"Godot MCP: Set Camera2D Damping")

static func _camera_follow(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var camera:=_camera_node(plugin,str(args.get("node_path",""))) as Camera2D; if camera==null: return U.error("CAMERA2D_REQUIRED","Camera2D not found")
    var target:=U.resolve_node(plugin,str(args.get("target_path",""))) as Node2D; if target==null: return U.error("NODE2D_TARGET_REQUIRED","Follow target must be Node2D")
    if camera==target or camera.is_ancestor_of(target): return U.error("INVALID_FOLLOW_TARGET","Camera cannot follow itself/descendant")
    camera.reparent(target,true)
    if args.has("offset"):
        var value=U.decode_value(args.offset); if value is Vector2: camera.position=value
    U.mark_unsaved(plugin); return U.ok({"camera_path":str(camera.get_path()),"target_path":str(target.get_path()),"mode":"child_follow"})

static func _camera_get(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_camera_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("CAMERA_NOT_FOUND","Camera2D/3D not found")
    var props:Dictionary={}; var names=["zoom","offset","limit_left","limit_top","limit_right","limit_bottom","position_smoothing_enabled","position_smoothing_speed"] if node is Camera2D else ["current","projection","fov","size","near","far","cull_mask"]
    for name in names:
        if U.property_exists(node,name): props[name]=U.encode_value(node.get(name))
    return U.ok({"node":U.object_summary(node),"properties":props})

static func _camera_list(plugin:EditorPlugin)->Dictionary:
    var root:=plugin.get_editor_interface().get_edited_scene_root(); if root==null: return U.error("NO_SCENE","No edited scene")
    var out:Array=[]; _collect_scene(root,root,func(node): return node is Camera2D or node is Camera3D,out); return U.ok({"cameras":out,"count":out.size()})

static func _camera_preset(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_camera_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("CAMERA_NOT_FOUND","Camera2D/3D not found")
    var changes:Dictionary={}
    match str(args.get("preset","")):
        "platformer_2d":
            if not node is Camera2D: return U.error("CAMERA2D_REQUIRED","Preset requires Camera2D")
            changes={"position_smoothing_enabled":true,"position_smoothing_speed":6.0,"drag_horizontal_enabled":true,"drag_vertical_enabled":true,"drag_left_margin":0.1,"drag_right_margin":0.1,"drag_top_margin":0.2,"drag_bottom_margin":0.15}
        "top_down_2d":
            if not node is Camera2D: return U.error("CAMERA2D_REQUIRED","Preset requires Camera2D")
            changes={"position_smoothing_enabled":true,"position_smoothing_speed":8.0,"drag_horizontal_enabled":false,"drag_vertical_enabled":false}
        "first_person_3d":
            if not node is Camera3D: return U.error("CAMERA3D_REQUIRED","Preset requires Camera3D")
            changes={"fov":75.0,"near":0.05,"far":1000.0,"current":true}
        "cinematic_3d":
            if not node is Camera3D: return U.error("CAMERA3D_REQUIRED","Preset requires Camera3D")
            changes={"fov":50.0,"near":0.1,"far":2000.0,"current":true}
        _: return U.error("UNKNOWN_PRESET","Unknown camera preset")
    return _undo_properties(plugin,node,changes,"Godot MCP: Apply Camera Preset")

static func _undo_properties(plugin:EditorPlugin,object:Object,changes:Dictionary,title:String)->Dictionary:
    if changes.is_empty(): return U.error("NO_CHANGES","No supported properties were supplied")
    var compatible:Array[String]=[]
    for key in changes.keys():
        var name:=str(key)
        if U.property_exists(object,name): compatible.append(name)
    if compatible.is_empty(): return U.error("NO_CHANGES","No compatible properties were supplied")
    var manager:=plugin.get_undo_redo()
    manager.create_action(title,0,object)
    for name in compatible:
        var old=object.get(name)
        var value=U.decode_value(changes[name])
        manager.add_do_property(object,name,value)
        manager.add_undo_property(object,name,old)
    manager.commit_action()
    U.mark_unsaved(plugin)
    var values:Dictionary={}
    for name in compatible: values[name]=U.encode_value(object.get(name))
    return U.ok({"changed":compatible,"values":values,"undoable":true})

static func _collect_scene(node:Node,root:Node,predicate:Callable,out:Array)->void:
    if out.size()>=MAX_LIST: return
    if predicate.call(node): out.append({"name":str(node.name),"class":node.get_class(),"path":U.node_path_relative(root,node)})
    for child in node.get_children():
        if child is Node: _collect_scene(child,root,predicate,out)
        if out.size()>=MAX_LIST: return