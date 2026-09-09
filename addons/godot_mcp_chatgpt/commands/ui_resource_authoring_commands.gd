@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const MAX_UI_CHILDREN := 64

static func register(registry:RefCounted,plugin:EditorPlugin)->void:
    _theme_tools(registry,plugin)
    _ui_tools(registry,plugin)
    _resource_helper_tools(registry,plugin)

static func _theme_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.theme_create","Create and save a Theme resource.",{"path":{"type":"string"}},func(a): return _theme_create(a),false,["path"])
    _add(registry,"content.theme_set_color","Set a Theme color entry.",{"path":{"type":"string"},"name":{"type":"string"},"theme_type":{"type":"string"},"color":{}},func(a): return _theme_color(a),false,["path","name","theme_type","color"])
    _add(registry,"content.theme_set_constant","Set a Theme integer constant.",{"path":{"type":"string"},"name":{"type":"string"},"theme_type":{"type":"string"},"value":{"type":"integer"}},func(a): return _theme_constant(a),false,["path","name","theme_type","value"])
    _add(registry,"content.theme_set_font_size","Set a Theme font-size entry.",{"path":{"type":"string"},"name":{"type":"string"},"theme_type":{"type":"string"},"size":{"type":"integer","minimum":1,"maximum":512}},func(a): return _theme_font_size(a),false,["path","name","theme_type","size"])
    _add(registry,"content.theme_set_stylebox_flat","Create/apply bounded StyleBoxFlat values to a Theme entry.",{"path":{"type":"string"},"name":{"type":"string"},"theme_type":{"type":"string"},"background":{},"border_color":{},"border_width":{"type":"integer","minimum":0,"maximum":128},"corner_radius":{"type":"integer","minimum":0,"maximum":256},"content_margin":{"type":"number","minimum":0,"maximum":512}},func(a): return _theme_stylebox(a),false,["path","name","theme_type"])
    _add(registry,"content.theme_apply","Assign a Theme resource to a Control node using UndoRedo.",{"node_path":{"type":"string"},"theme_path":{"type":"string"}},func(a): return _theme_apply(plugin,a),false,["node_path","theme_path"])

static func _ui_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.ui_set_anchor_preset","Apply a common Control anchor/layout preset with UndoRedo.",{"node_path":{"type":"string"},"preset":{"type":"string","enum":["top_left","top_right","bottom_left","bottom_right","center_left","center_top","center_right","center_bottom","center","left_wide","top_wide","right_wide","bottom_wide","vcenter_wide","hcenter_wide","full_rect"]},"margin":{"type":"integer"}},func(a): return _ui_anchor(plugin,a),false,["node_path","preset"])
    _add(registry,"content.ui_set_text","Set text on a text-bearing Control using UndoRedo.",{"node_path":{"type":"string"},"text":{"type":"string"}},func(a): return _ui_text(plugin,a),false,["node_path","text"])
    _add(registry,"content.ui_build_layout","Build a bounded editable Control/container hierarchy from a declarative child list.",{"parent_path":{"type":"string"},"layout":{"type":"string","enum":["vbox","hbox","grid","margin","panel","center"]},"name":{"type":"string"},"columns":{"type":"integer","minimum":1,"maximum":32},"children":{"type":"array","maxItems":64}},func(a): return await _ui_build(registry,plugin,a),false)
    _add(registry,"content.ui_draw_recipe","Build a bounded common UI recipe from normal Godot Control nodes.",{"parent_path":{"type":"string"},"recipe":{"type":"string","enum":["panel_card","centered_message","hud_bar","button_row"]},"name":{"type":"string"},"text":{"type":"string"},"buttons":{"type":"array","maxItems":12}},func(a): return await _ui_recipe(registry,plugin,a),false,["recipe"])

static func _resource_helper_tools(registry:RefCounted,plugin:EditorPlugin)->void:
    _add(registry,"content.resource_assign","Load and assign a Resource to a node property using UndoRedo.",{"node_path":{"type":"string"},"property":{"type":"string"},"resource_path":{"type":"string"}},func(a): return _resource_assign(plugin,a),false,["node_path","property","resource_path"])
    _add(registry,"content.curve_set_points","Create/update and save a Curve resource from bounded points.",{"path":{"type":"string"},"points":{"type":"array","maxItems":256},"min_value":{"type":"number"},"max_value":{"type":"number"}},func(a): return _curve_points(a),false,["path","points"])
    _add(registry,"content.environment_create","Create/update and save an Environment resource with supported properties.",{"path":{"type":"string"},"properties":{"type":"object"}},func(a): return _environment_create(a),false,["path"])
    _add(registry,"content.physics_shape_autofit","Auto-fit RectangleShape2D/BoxShape3D from a Control/Sprite2D/MeshInstance3D and optionally assign/save it.",{"source_node_path":{"type":"string"},"shape_node_path":{"type":"string"},"save_path":{"type":"string"},"padding":{"type":"number","minimum":0,"maximum":10000}},func(a): return _physics_autofit(plugin,a),false,["source_node_path"])
    _add(registry,"content.physics_shape_generate","Generate and save a common 2D/3D Shape resource.",{"path":{"type":"string"},"kind":{"type":"string","enum":["rectangle_2d","circle_2d","capsule_2d","box_3d","sphere_3d","capsule_3d","cylinder_3d"]},"size":{},"radius":{"type":"number","minimum":0},"height":{"type":"number","minimum":0}},func(a): return _physics_generate(a),false,["path","kind"])
    _add(registry,"content.gradient_texture_create","Create and save GradientTexture1D/2D with bounded color points.",{"path":{"type":"string"},"dimension":{"type":"string","enum":["1d","2d"]},"points":{"type":"array","maxItems":64},"width":{"type":"integer","minimum":1,"maximum":4096},"height":{"type":"integer","minimum":1,"maximum":4096}},func(a): return _gradient_texture(a),false,["path","points"])
    _add(registry,"content.noise_texture_create","Create and save NoiseTexture2D backed by FastNoiseLite.",{"path":{"type":"string"},"width":{"type":"integer","minimum":1,"maximum":2048},"height":{"type":"integer","minimum":1,"maximum":2048},"seed":{"type":"integer"},"frequency":{"type":"number","minimum":0.000001,"maximum":10},"noise_type":{"type":"string","enum":["simplex","simplex_smooth","cellular","perlin","value_cubic","value"]}},func(a): return _noise_texture(a),false,["path"])

static func _add(registry:RefCounted,name:String,description:String,properties:Dictionary,handler:Callable,read_only:bool,required:Array=[],destructive:bool=false)->void:
    registry.add_command(name,description,{"type":"object","properties":properties,"required":required,"additionalProperties":false},handler,{"readOnlyHint":read_only,"destructiveHint":destructive})

static func _theme_create(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","theme path must stay inside res://")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); var theme:=Theme.new(); var err:=ResourceSaver.save(theme,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"created":true})

static func _load_theme(path:String)->Theme:
    if not U.valid_res_path(path): return null
    return ResourceLoader.load(path,"Theme",ResourceLoader.CACHE_MODE_REPLACE) as Theme

static func _save_theme(theme:Theme,path:String,result:Dictionary)->Dictionary:
    var err:=ResourceSaver.save(theme,path)
    if err!=OK:
        return U.error("SAVE_FAILED",error_string(err))
    return U.ok(result)

static func _theme_color(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var theme:=_load_theme(path); if theme==null: return U.error("THEME_LOAD_FAILED","Unable to load Theme")
    var color=U.decode_value(args.get("color")); if not color is Color: return U.error("COLOR_REQUIRED","color must be encoded Color")
    theme.set_color(StringName(str(args.get("name",""))),StringName(str(args.get("theme_type",""))),color)
    return _save_theme(theme,path,{"path":path,"name":str(args.get("name","")),"theme_type":str(args.get("theme_type","")),"color":U.encode_value(color)})

static func _theme_constant(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var theme:=_load_theme(path); if theme==null: return U.error("THEME_LOAD_FAILED","Unable to load Theme")
    theme.set_constant(StringName(str(args.get("name",""))),StringName(str(args.get("theme_type",""))),int(args.get("value",0)))
    return _save_theme(theme,path,{"path":path,"value":int(args.get("value",0))})

static func _theme_font_size(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var theme:=_load_theme(path); if theme==null: return U.error("THEME_LOAD_FAILED","Unable to load Theme")
    theme.set_font_size(StringName(str(args.get("name",""))),StringName(str(args.get("theme_type",""))),clampi(int(args.get("size",16)),1,512))
    return _save_theme(theme,path,{"path":path,"size":int(args.get("size",16))})

static func _theme_stylebox(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); var theme:=_load_theme(path); if theme==null: return U.error("THEME_LOAD_FAILED","Unable to load Theme")
    var box:=StyleBoxFlat.new(); var bg=U.decode_value(args.get("background",{"__godot_type":"Color","r":0.15,"g":0.15,"b":0.18,"a":1})); var border=U.decode_value(args.get("border_color",{"__godot_type":"Color","r":0.35,"g":0.35,"b":0.4,"a":1}))
    if bg is Color: box.bg_color=bg
    if border is Color: box.border_color=border
    var bw:=clampi(int(args.get("border_width",0)),0,128); box.border_width_left=bw; box.border_width_top=bw; box.border_width_right=bw; box.border_width_bottom=bw
    var radius:=clampi(int(args.get("corner_radius",6)),0,256); box.corner_radius_top_left=radius; box.corner_radius_top_right=radius; box.corner_radius_bottom_left=radius; box.corner_radius_bottom_right=radius
    var margin:=clampf(float(args.get("content_margin",8.0)),0.0,512.0); box.content_margin_left=margin; box.content_margin_top=margin; box.content_margin_right=margin; box.content_margin_bottom=margin
    theme.set_stylebox(StringName(str(args.get("name","panel"))),StringName(str(args.get("theme_type","Panel"))),box)
    return _save_theme(theme,path,{"path":path,"stylebox":str(args.get("name","panel")),"theme_type":str(args.get("theme_type","Panel"))})

static func _theme_apply(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=U.resolve_node(plugin,str(args.get("node_path",""))) as Control; if node==null: return U.error("CONTROL_REQUIRED","node_path must resolve to Control")
    var theme:=_load_theme(str(args.get("theme_path",""))); if theme==null: return U.error("THEME_LOAD_FAILED","Unable to load Theme")
    var old:=node.theme; var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Apply Theme",0,node); manager.add_do_property(node,"theme",theme); manager.add_undo_property(node,"theme",old); manager.add_do_reference(theme); manager.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"node_path":str(args.get("node_path","")),"theme_path":str(args.get("theme_path","")),"undoable":true})

static func _ui_anchor(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=U.resolve_node(plugin,str(args.get("node_path",""))) as Control; if node==null: return U.error("CONTROL_REQUIRED","node_path must resolve to Control")
    var before:=_control_layout_state(node); node.set_anchors_and_offsets_preset(_layout_preset(str(args.get("preset","full_rect"))),Control.PRESET_MODE_MINSIZE,int(args.get("margin",0))); var after:=_control_layout_state(node)
    var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Set UI Anchor Preset",0,node)
    for key in after.keys(): manager.add_do_property(node,str(key),after[key]); manager.add_undo_property(node,str(key),before[key])
    manager.commit_action(false); U.mark_unsaved(plugin); return U.ok({"node_path":str(args.get("node_path","")),"preset":str(args.get("preset","")),"layout":_encode_layout_state(after),"undoable":true})

static func _control_layout_state(node:Control)->Dictionary:
    return {"anchor_left":node.anchor_left,"anchor_top":node.anchor_top,"anchor_right":node.anchor_right,"anchor_bottom":node.anchor_bottom,"offset_left":node.offset_left,"offset_top":node.offset_top,"offset_right":node.offset_right,"offset_bottom":node.offset_bottom}

static func _encode_layout_state(state:Dictionary)->Dictionary:
    return state.duplicate(true)

static func _layout_preset(name:String)->int:
    var map={"top_left":Control.PRESET_TOP_LEFT,"top_right":Control.PRESET_TOP_RIGHT,"bottom_left":Control.PRESET_BOTTOM_LEFT,"bottom_right":Control.PRESET_BOTTOM_RIGHT,"center_left":Control.PRESET_CENTER_LEFT,"center_top":Control.PRESET_CENTER_TOP,"center_right":Control.PRESET_CENTER_RIGHT,"center_bottom":Control.PRESET_CENTER_BOTTOM,"center":Control.PRESET_CENTER,"left_wide":Control.PRESET_LEFT_WIDE,"top_wide":Control.PRESET_TOP_WIDE,"right_wide":Control.PRESET_RIGHT_WIDE,"bottom_wide":Control.PRESET_BOTTOM_WIDE,"vcenter_wide":Control.PRESET_VCENTER_WIDE,"hcenter_wide":Control.PRESET_HCENTER_WIDE,"full_rect":Control.PRESET_FULL_RECT}
    return int(map.get(name,Control.PRESET_FULL_RECT))

static func _ui_text(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=U.resolve_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("NODE_NOT_FOUND","Node not found")
    if not U.property_exists(node,"text"): return U.error("TEXT_PROPERTY_NOT_FOUND","Node does not expose text")
    var old=node.get("text"); var value:=str(args.get("text","")); var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Set UI Text",0,node); manager.add_do_property(node,"text",value); manager.add_undo_property(node,"text",old); manager.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"node_path":str(args.get("node_path","")),"text":value,"undoable":true})

static func _ui_build(registry:RefCounted,plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var type_map={"vbox":"VBoxContainer","hbox":"HBoxContainer","grid":"GridContainer","margin":"MarginContainer","panel":"PanelContainer","center":"CenterContainer"}; var kind:=str(args.get("layout","vbox")); var cls:=str(type_map.get(kind,"VBoxContainer"))
    var created:Dictionary=await registry.call_command("node.create",{"parent_path":str(args.get("parent_path",".")),"type":cls,"name":str(args.get("name","MCPLayout"))}); if not bool(created.get("ok",false)): return created
    var root_path:=str(created.result.get("node_path","")); var root:=U.resolve_node(plugin,root_path)
    if root is GridContainer and args.has("columns"): root.columns=clampi(int(args.columns),1,32)
    var children:Array=args.get("children",[]); var made:Array=[]
    for i in mini(children.size(),MAX_UI_CHILDREN):
        var spec=children[i]; if not spec is Dictionary: continue
        var child_type:=str(spec.get("type","Label")); if not ClassDB.class_exists(child_type) or not ClassDB.is_parent_class(child_type,"Control"): child_type="Label"
        var child:Dictionary=await registry.call_command("node.create",{"parent_path":root_path,"type":child_type,"name":str(spec.get("name",child_type+str(i)))}); if not bool(child.get("ok",false)): continue
        var child_path:=str(child.result.get("node_path","")); var properties=spec.get("properties",{})
        if properties is Dictionary:
            for key in properties.keys(): await registry.call_command("node.set_property",{"node_path":child_path,"property":str(key),"value":properties[key]})
        made.append({"path":child_path,"type":child_type})
    U.mark_unsaved(plugin); return U.ok({"root_path":root_path,"layout":kind,"children":made,"count":made.size()})

static func _ui_recipe(registry:RefCounted,plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var parent:=str(args.get("parent_path",".")); var name:=str(args.get("name","MCPRecipe")); var text:=str(args.get("text","")); var recipe:=str(args.get("recipe","")); var children:Array=[]; var layout:="vbox"
    match recipe:
        "panel_card": children=[{"type":"Label","name":"Title","properties":{"text":text}},{"type":"Label","name":"Body","properties":{"text":"Content"}}]; layout="panel"
        "centered_message": children=[{"type":"Label","name":"Message","properties":{"text":text,"horizontal_alignment":1,"vertical_alignment":1}}]; layout="center"
        "hud_bar": children=[{"type":"Label","name":"Status","properties":{"text":text}},{"type":"ProgressBar","name":"Value","properties":{"value":100.0}}]; layout="hbox"
        "button_row":
            layout="hbox"; var buttons:Array=args.get("buttons",[]); if buttons.is_empty(): buttons=["OK","Cancel"]
            for i in mini(buttons.size(),12): children.append({"type":"Button","name":"Button"+str(i+1),"properties":{"text":str(buttons[i])}})
        _: return U.error("UNKNOWN_RECIPE","Unknown UI recipe")
    return await _ui_build(registry,plugin,{"parent_path":parent,"layout":layout,"name":name,"children":children})
static func _resource_assign(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=U.resolve_node(plugin,str(args.get("node_path",""))); if node==null: return U.error("NODE_NOT_FOUND","Node not found")
    var property:=str(args.get("property","")); if not U.property_exists(node,property): return U.error("PROPERTY_NOT_FOUND","Node property not found: "+property)
    var path:=str(args.get("resource_path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","resource_path must stay inside res://")
    var resource:=ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_REPLACE); if resource==null: return U.error("RESOURCE_LOAD_FAILED","Unable to load Resource")
    var old=node.get(property); var manager:=plugin.get_undo_redo(); manager.create_action("Godot MCP: Assign Resource",0,node); manager.add_do_property(node,property,resource); manager.add_undo_property(node,property,old); manager.add_do_reference(resource); manager.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"node_path":str(args.get("node_path","")),"property":property,"resource_path":path,"class":resource.get_class(),"undoable":true})

static func _curve_points(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","curve path must stay inside res://")
    var curve:=ResourceLoader.load(path,"Curve",ResourceLoader.CACHE_MODE_REPLACE) as Curve if FileAccess.file_exists(path) else Curve.new()
    if curve==null: curve=Curve.new()
    if args.has("min_value"): curve.min_value=float(args.min_value)
    if args.has("max_value"): curve.max_value=float(args.max_value)
    curve.clear_points(); var points:Array=args.get("points",[])
    for raw in points:
        if not raw is Dictionary: return U.error("INVALID_CURVE_POINT","Curve points must be objects")
        var point:Dictionary=raw; var position:=Vector2(float(point.get("x",0.0)),float(point.get("y",0.0))); curve.add_point(position,float(point.get("left_tangent",0.0)),float(point.get("right_tangent",0.0)),int(point.get("left_mode",Curve.TANGENT_FREE)),int(point.get("right_mode",Curve.TANGENT_FREE)))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); var err:=ResourceSaver.save(curve,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"points":curve.point_count,"min_value":curve.min_value,"max_value":curve.max_value})

static func _environment_create(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","environment path must stay inside res://")
    var env:=ResourceLoader.load(path,"Environment",ResourceLoader.CACHE_MODE_REPLACE) as Environment if FileAccess.file_exists(path) else Environment.new(); if env==null: env=Environment.new()
    var changed:Array=[]; var props=args.get("properties",{})
    if props is Dictionary:
        for key in props.keys():
            var name:=str(key)
            if U.property_exists(env,name): env.set(name,U.decode_value(props[key])); changed.append(name)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); var err:=ResourceSaver.save(env,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"changed":changed,"saved":true})

static func _physics_autofit(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var source:=U.resolve_node(plugin,str(args.get("source_node_path",""))); if source==null: return U.error("NODE_NOT_FOUND","source_node_path not found")
    var padding:=float(args.get("padding",0.0)); var shape:Shape2D=null; var shape3:Shape3D=null
    if source is Control:
        var s:=(source as Control).size+Vector2.ONE*padding*2.0; var rect:=RectangleShape2D.new(); rect.size=Vector2(maxf(0.001,s.x),maxf(0.001,s.y)); shape=rect
    elif source is Sprite2D:
        var s:=(source as Sprite2D).get_rect().size*(source as Sprite2D).scale.abs()+Vector2.ONE*padding*2.0; var rect:=RectangleShape2D.new(); rect.size=Vector2(maxf(0.001,s.x),maxf(0.001,s.y)); shape=rect
    elif source is MeshInstance3D:
        var s:=(source as MeshInstance3D).get_aabb().size*(source as MeshInstance3D).scale.abs()+Vector3.ONE*padding*2.0; var box:=BoxShape3D.new(); box.size=Vector3(maxf(0.001,s.x),maxf(0.001,s.y),maxf(0.001,s.z)); shape3=box
    else:
        return U.error("AUTOFIT_SOURCE_UNSUPPORTED","Auto-fit supports Control, Sprite2D, and MeshInstance3D")
    var resource:Resource=shape if shape!=null else shape3
    var shape_path:=str(args.get("shape_node_path",""))
    if not shape_path.is_empty():
        var collision:=U.resolve_node(plugin,shape_path)
        if shape!=null and collision is CollisionShape2D: collision.shape=shape
        elif shape3!=null and collision is CollisionShape3D: collision.shape=shape3
        else: return U.error("COLLISION_SHAPE_TYPE_MISMATCH","shape_node_path is not a compatible CollisionShape")
        U.mark_unsaved(plugin)
    var save_path:=str(args.get("save_path",""))
    if not save_path.is_empty():
        if not U.valid_res_path(save_path): return U.error("INVALID_PATH","save_path must stay inside res://")
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir())); var err:=ResourceSaver.save(resource,save_path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"source_node_path":str(args.get("source_node_path","")),"shape_class":resource.get_class(),"shape":U.encode_value(resource),"assigned":not shape_path.is_empty(),"save_path":save_path})

static func _physics_generate(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","shape path must stay inside res://")
    var resource:Resource; var kind:=str(args.get("kind","")); var size=U.decode_value(args.get("size")); var radius:=maxf(0.001,float(args.get("radius",0.5))); var height:=maxf(0.001,float(args.get("height",1.0)))
    match kind:
        "rectangle_2d": var v:Vector2=size if size is Vector2 else Vector2(1,1); var x:=RectangleShape2D.new(); x.size=v; resource=x
        "circle_2d": var x:=CircleShape2D.new(); x.radius=radius; resource=x
        "capsule_2d": var x:=CapsuleShape2D.new(); x.radius=radius; x.height=maxf(height,radius*2.0); resource=x
        "box_3d": var v:Vector3=size if size is Vector3 else Vector3.ONE; var x:=BoxShape3D.new(); x.size=v; resource=x
        "sphere_3d": var x:=SphereShape3D.new(); x.radius=radius; resource=x
        "capsule_3d": var x:=CapsuleShape3D.new(); x.radius=radius; x.height=maxf(height,radius*2.0); resource=x
        "cylinder_3d": var x:=CylinderShape3D.new(); x.radius=radius; x.height=height; resource=x
        _: return U.error("UNKNOWN_SHAPE_KIND","Unknown physics shape kind")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); var err:=ResourceSaver.save(resource,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"kind":kind,"class":resource.get_class(),"saved":true})

static func _gradient_texture(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","gradient texture path must stay inside res://")
    var gradient:=Gradient.new(); var points:Array=args.get("points",[])
    if points.is_empty(): return U.error("GRADIENT_POINTS_REQUIRED","points must not be empty")
    gradient.offsets=PackedFloat32Array(); gradient.colors=PackedColorArray()
    for raw in points:
        if not raw is Dictionary: return U.error("INVALID_GRADIENT_POINT","Gradient points must be objects")
        var point:Dictionary=raw; var color=U.decode_value(point.get("color")); if not color is Color: return U.error("COLOR_REQUIRED","Gradient point color must be encoded Color")
        gradient.add_point(clampf(float(point.get("offset",0.0)),0.0,1.0),color)
    var texture:Texture2D
    if str(args.get("dimension","1d"))=="2d":
        var t:=GradientTexture2D.new(); t.gradient=gradient; t.width=clampi(int(args.get("width",256)),1,4096); t.height=clampi(int(args.get("height",256)),1,4096); texture=t
    else:
        var t:=GradientTexture1D.new(); t.gradient=gradient; t.width=clampi(int(args.get("width",256)),1,4096); texture=t
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); var err:=ResourceSaver.save(texture,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"class":texture.get_class(),"points":gradient.get_point_count(),"saved":true})

static func _noise_texture(args:Dictionary)->Dictionary:
    var path:=str(args.get("path","")); if not U.valid_res_path(path): return U.error("INVALID_PATH","noise texture path must stay inside res://")
    var noise:=FastNoiseLite.new(); noise.seed=int(args.get("seed",0)); noise.frequency=clampf(float(args.get("frequency",0.01)),0.000001,10.0)
    var types={"simplex":FastNoiseLite.TYPE_SIMPLEX,"simplex_smooth":FastNoiseLite.TYPE_SIMPLEX_SMOOTH,"cellular":FastNoiseLite.TYPE_CELLULAR,"perlin":FastNoiseLite.TYPE_PERLIN,"value_cubic":FastNoiseLite.TYPE_VALUE_CUBIC,"value":FastNoiseLite.TYPE_VALUE}; noise.noise_type=int(types.get(str(args.get("noise_type","simplex_smooth")),FastNoiseLite.TYPE_SIMPLEX_SMOOTH))
    var texture:=NoiseTexture2D.new(); texture.width=clampi(int(args.get("width",256)),1,2048); texture.height=clampi(int(args.get("height",256)),1,2048); texture.noise=noise
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())); var err:=ResourceSaver.save(texture,path); if err!=OK: return U.error("SAVE_FAILED",error_string(err))
    return U.ok({"path":path,"width":texture.width,"height":texture.height,"seed":noise.seed,"frequency":noise.frequency,"noise_type":str(args.get("noise_type","simplex_smooth")),"saved":true})