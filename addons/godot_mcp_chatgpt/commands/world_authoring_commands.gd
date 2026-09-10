@tool
extends RefCounted

const U := preload("res://addons/godot_mcp_chatgpt/core/command_utils.gd")
const ImageUtils := preload("res://addons/godot_mcp_chatgpt/core/image_utils.gd")
const MAX_FILL_CELLS := 4096

const CSG_CLASSES := {
    "box":"CSGBox3D", "sphere":"CSGSphere3D", "cylinder":"CSGCylinder3D",
    "torus":"CSGTorus3D", "polygon":"CSGPolygon3D", "combiner":"CSGCombiner3D"
}
const CSG_OPERATIONS := {
    "union":CSGShape3D.OPERATION_UNION,
    "intersection":CSGShape3D.OPERATION_INTERSECTION,
    "subtraction":CSGShape3D.OPERATION_SUBTRACTION,
}

static func register(registry: RefCounted, plugin: EditorPlugin) -> void:
    _add(registry,"tilemap.set_cell","Set one TileMapLayer cell with UndoRedo.",{"node_path":{"type":"string"},"map_x":{"type":"integer"},"map_y":{"type":"integer"},"source_id":{"type":"integer"},"atlas_col":{"type":"integer"},"atlas_row":{"type":"integer"},"alternative":{"type":"integer"}},func(a): return _tilemap_set_cell(plugin,a),false,["node_path","source_id"])
    _add(registry,"tilemap.set_cells_rect","Fill a bounded TileMapLayer rectangle with one tile using one UndoRedo action.",{"node_path":{"type":"string"},"rect_x":{"type":"integer"},"rect_y":{"type":"integer"},"rect_w":{"type":"integer","minimum":1,"maximum":4096},"rect_h":{"type":"integer","minimum":1,"maximum":4096},"source_id":{"type":"integer"},"atlas_col":{"type":"integer"},"atlas_row":{"type":"integer"},"alternative":{"type":"integer"}},func(a): return _tilemap_fill(plugin,a),false,["node_path","rect_w","rect_h","source_id"])
    _add(registry,"tilemap.clear","Clear a bounded TileMapLayer with UndoRedo.",{"node_path":{"type":"string"}},func(a): return _tilemap_clear(plugin,a),false,["node_path"],true)
    _add(registry,"tilemap.get_used_cells","Read used TileMapLayer cells with tile identity.",{"node_path":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":4096}},func(a): return _tilemap_used(plugin,a),true,["node_path"])
    _add(registry,"tilemap.get_cell","Read one TileMapLayer cell.",{"node_path":{"type":"string"},"map_x":{"type":"integer"},"map_y":{"type":"integer"}},func(a): return _tilemap_cell(plugin,a),true,["node_path"])
    _add(registry,"tilemap.get_cells","Read a bounded selected set of TileMapLayer cells for verification.",{"node_path":{"type":"string"},"cells":{"type":"array","minItems":1,"maxItems":512,"items":{"type":"object","properties":{"x":{"type":"integer"},"y":{"type":"integer"}},"required":["x","y"],"additionalProperties":false}}},func(a): return _tilemap_cells(plugin,a),true,["node_path","cells"])

    _add(registry,"tileset.get_atlas_tiles","List occupied atlas tile coordinates for one TileSetAtlasSource.",{"tileset_path":{"type":"string"},"source_id":{"type":"integer"}},func(a): return _tileset_tiles(a),true,["tileset_path","source_id"])
    _add(registry,"tileset.get_atlas_source","Inspect one TileSetAtlasSource and optionally return its texture as MCP image content.",{"tileset_path":{"type":"string"},"source_id":{"type":"integer"},"include_image":{"type":"boolean"},"max_resolution":{"type":"integer","minimum":64,"maximum":2048}},func(a): return await _tileset_source(a),true,["tileset_path","source_id"])

    _add(registry,"gridmap.set_item","Set one GridMap cell item with UndoRedo.",{"node_path":{"type":"string"},"map_x":{"type":"integer"},"map_y":{"type":"integer"},"map_z":{"type":"integer"},"item":{"type":"integer"},"orientation":{"type":"integer","minimum":0,"maximum":23}},func(a): return _gridmap_set(plugin,a),false,["node_path","item"])
    _add(registry,"gridmap.fill","Fill a bounded GridMap box with one item using one UndoRedo action.",{"node_path":{"type":"string"},"rect_x":{"type":"integer"},"rect_y":{"type":"integer"},"rect_z":{"type":"integer"},"rect_w":{"type":"integer","minimum":1,"maximum":4096},"rect_h":{"type":"integer","minimum":1,"maximum":4096},"rect_d":{"type":"integer","minimum":1,"maximum":4096},"item":{"type":"integer"},"orientation":{"type":"integer","minimum":0,"maximum":23}},func(a): return _gridmap_fill(plugin,a),false,["node_path","rect_w","rect_h","rect_d","item"])
    _add(registry,"gridmap.clear","Clear a bounded GridMap with UndoRedo.",{"node_path":{"type":"string"}},func(a): return _gridmap_clear(plugin,a),false,["node_path"],true)
    _add(registry,"gridmap.get_used_cells","Read used GridMap cells with item/orientation.",{"node_path":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":4096}},func(a): return _gridmap_used(plugin,a),true,["node_path"])
    _add(registry,"gridmap.list_library_items","List MeshLibrary items assigned to a GridMap.",{"node_path":{"type":"string"}},func(a): return _gridmap_library(plugin,a),true,["node_path"])

    _add(registry,"csg.create","Create a common CSG node under a Node3D parent with UndoRedo.",{"parent_path":{"type":"string"},"name":{"type":"string"},"shape":{"type":"string","enum":["box","sphere","cylinder","torus","polygon","combiner"]},"operation":{"type":"string","enum":["union","intersection","subtraction"]}},func(a): return _csg_create(plugin,a),false)
    _add(registry,"csg.set_operation","Set a CSGShape3D boolean operation with UndoRedo.",{"node_path":{"type":"string"},"operation":{"type":"string","enum":["union","intersection","subtraction"]}},func(a): return _csg_operation(plugin,a),false,["node_path","operation"])

static func _add(registry:RefCounted,name:String,description:String,properties:Dictionary,handler:Callable,read_only:bool,required:Array=[],destructive:bool=false)->void:
    registry.add_command(name,description,{"type":"object","properties":properties,"required":required,"additionalProperties":false},handler,{"readOnlyHint":read_only,"destructiveHint":destructive})

static func _tile_layer(plugin:EditorPlugin,path:String)->TileMapLayer:
    return U.resolve_node(plugin,path) as TileMapLayer

static func _cell_state(node:TileMapLayer,pos:Vector2i)->Dictionary:
    var src:=node.get_cell_source_id(pos)
    if src<0: return {"has_tile":false}
    var atlas:=node.get_cell_atlas_coords(pos)
    return {"has_tile":true,"source_id":src,"atlas":atlas,"alternative":node.get_cell_alternative_tile(pos)}

static func _add_tile_undo(undo:EditorUndoRedoManager,node:TileMapLayer,pos:Vector2i,state:Dictionary)->void:
    if bool(state.get("has_tile",false)):
        undo.add_undo_method(node,"set_cell",pos,int(state.source_id),state.atlas,int(state.alternative))
    else:
        undo.add_undo_method(node,"erase_cell",pos)

static func _validate_tile_identity(node:TileMapLayer,source_id:int,atlas:Vector2i,alternative:int)->Dictionary:
    if source_id < 0: return {"ok":true}
    var tileset:=node.tile_set
    if tileset==null: return U.error("TILESET_MISSING","TileMapLayer has no TileSet assigned")
    if not tileset.has_source(source_id): return U.error("TILESET_SOURCE_NOT_FOUND","TileSet source_id does not exist")
    var source:=tileset.get_source(source_id)
    if source is TileSetAtlasSource:
        var atlas_source:=source as TileSetAtlasSource
        if not atlas_source.has_tile(atlas): return U.error("ATLAS_TILE_NOT_FOUND","Atlas tile coordinate does not exist")
        if alternative != 0 and not atlas_source.has_alternative_tile(atlas,alternative): return U.error("ATLAS_ALTERNATIVE_NOT_FOUND","Atlas alternative tile does not exist")
    return {"ok":true}

static func _tilemap_set_cell(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_tile_layer(plugin,str(args.get("node_path",""))); if node==null: return U.error("TILEMAP_LAYER_NOT_FOUND","TileMapLayer not found")
    var pos:=Vector2i(int(args.get("map_x",0)),int(args.get("map_y",0))); var prev:=_cell_state(node,pos)
    var src:=int(args.get("source_id",0)); var atlas:=Vector2i(int(args.get("atlas_col",0)),int(args.get("atlas_row",0))); var alt:=int(args.get("alternative",0))
    var validation:=_validate_tile_identity(node,src,atlas,alt); if not bool(validation.get("ok",false)): return validation
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: TileMap set cell"); undo.add_do_method(node,"set_cell",pos,src,atlas,alt); _add_tile_undo(undo,node,pos,prev); undo.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"position":U.encode_value(pos),"source_id":src,"atlas":U.encode_value(atlas),"alternative":alt,"undoable":true})

static func _tilemap_fill(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_tile_layer(plugin,str(args.get("node_path",""))); if node==null: return U.error("TILEMAP_LAYER_NOT_FOUND","TileMapLayer not found")
    var w:=int(args.get("rect_w",1)); var h:=int(args.get("rect_h",1))
    if w<=0 or h<=0 or w>MAX_FILL_CELLS or h>MAX_FILL_CELLS: return U.error("FILL_LIMIT","TileMap fill dimensions must be in 1..%d" % MAX_FILL_CELLS)
    var total:=w*h
    if total>MAX_FILL_CELLS: return U.error("FILL_LIMIT","TileMap fill must contain at most %d cells" % MAX_FILL_CELLS)
    var x0:=int(args.get("rect_x",0)); var y0:=int(args.get("rect_y",0)); var src:=int(args.get("source_id",0)); var atlas:=Vector2i(int(args.get("atlas_col",0)),int(args.get("atlas_row",0))); var alt:=int(args.get("alternative",0))
    var validation:=_validate_tile_identity(node,src,atlas,alt); if not bool(validation.get("ok",false)): return validation
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: TileMap fill %dx%d" % [w,h])
    for x in range(x0,x0+w):
        for y in range(y0,y0+h):
            var pos:=Vector2i(x,y); var prev:=_cell_state(node,pos); undo.add_do_method(node,"set_cell",pos,src,atlas,alt); _add_tile_undo(undo,node,pos,prev)
    undo.commit_action(); U.mark_unsaved(plugin); return U.ok({"cells_filled":total,"rect":{"x":x0,"y":y0,"w":w,"h":h},"undoable":true})

static func _tilemap_clear(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_tile_layer(plugin,str(args.get("node_path",""))); if node==null: return U.error("TILEMAP_LAYER_NOT_FOUND","TileMapLayer not found")
    var cells:=node.get_used_cells(); if cells.size()>MAX_FILL_CELLS: return U.error("CLEAR_LIMIT","TileMap has too many cells for bounded UndoRedo clear")
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: TileMap clear"); undo.add_do_method(node,"clear")
    for pos in cells: _add_tile_undo(undo,node,pos,_cell_state(node,pos))
    undo.commit_action(); U.mark_unsaved(plugin); return U.ok({"cleared":true,"cells":cells.size(),"undoable":true})

static func _tilemap_used(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_tile_layer(plugin,str(args.get("node_path",""))); if node==null: return U.error("TILEMAP_LAYER_NOT_FOUND","TileMapLayer not found")
    var limit:=clampi(int(args.get("limit",512)),1,4096); var out:Array=[]
    for pos in node.get_used_cells():
        if out.size()>=limit: break
        var s:=_cell_state(node,pos); out.append({"x":pos.x,"y":pos.y,"source_id":s.get("source_id",-1),"atlas":U.encode_value(s.get("atlas",Vector2i(-1,-1))),"alternative":s.get("alternative",0)})
    return U.ok({"cells":out,"count":out.size(),"total":node.get_used_cells().size(),"truncated":node.get_used_cells().size()>out.size()})

static func _tilemap_cell(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_tile_layer(plugin,str(args.get("node_path",""))); if node==null: return U.error("TILEMAP_LAYER_NOT_FOUND","TileMapLayer not found")
    var pos:=Vector2i(int(args.get("map_x",0)),int(args.get("map_y",0))); var s:=_cell_state(node,pos)
    return U.ok(_tile_cell_result(pos,s))

static func _tilemap_cells(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_tile_layer(plugin,str(args.get("node_path",""))); if node==null: return U.error("TILEMAP_LAYER_NOT_FOUND","TileMapLayer not found")
    var requested:Array=args.get("cells",[])
    if requested.is_empty() or requested.size()>512: return U.error("CELL_SELECTION_LIMIT","cells must contain 1..512 coordinates")
    var cells:Array=[]
    for value in requested:
        if not value is Dictionary: return U.error("INVALID_CELL_COORDINATE","Each selected cell must be an object with integer x/y")
        var item:Dictionary=value
        if not item.has("x") or not item.has("y"): return U.error("INVALID_CELL_COORDINATE","Each selected cell must contain integer x/y")
        var x_value=item["x"]; var y_value=item["y"]
        var x_is_integer:=x_value is int or (x_value is float and floorf(float(x_value))==float(x_value))
        var y_is_integer:=y_value is int or (y_value is float and floorf(float(y_value))==float(y_value))
        if not x_is_integer or not y_is_integer: return U.error("INVALID_CELL_COORDINATE","Each selected cell must contain integer x/y")
        var pos:=Vector2i(int(x_value),int(y_value))
        cells.append(_tile_cell_result(pos,_cell_state(node,pos)))
    return U.ok({"cells":cells,"count":cells.size()})

static func _tile_cell_result(pos:Vector2i,state:Dictionary)->Dictionary:
    return {"x":pos.x,"y":pos.y,"has_tile":state.get("has_tile",false),"source_id":state.get("source_id",-1),"atlas":U.encode_value(state.get("atlas",Vector2i(-1,-1))),"alternative":state.get("alternative",0)}

static func _atlas_source(args:Dictionary)->Dictionary:
    var path:=str(args.get("tileset_path","")); if not U.valid_res_path(path): return {"error":U.error("INVALID_PATH","tileset_path must stay inside res://")}
    var ts:=ResourceLoader.load(path,"TileSet",ResourceLoader.CACHE_MODE_REUSE) as TileSet; if ts==null: return {"error":U.error("TILESET_LOAD_FAILED","Unable to load TileSet")}
    var id:=int(args.get("source_id",-1)); if id<0 or not ts.has_source(id): return {"error":U.error("TILESET_SOURCE_NOT_FOUND","TileSet source_id does not exist")}
    var source:=ts.get_source(id) as TileSetAtlasSource; if source==null: return {"error":U.error("TILESET_SOURCE_TYPE","TileSet source is not TileSetAtlasSource")}
    return {"tileset":ts,"source":source,"source_id":id}

static func _tileset_tiles(args:Dictionary)->Dictionary:
    var r:=_atlas_source(args); if r.has("error"): return r.error
    var src:TileSetAtlasSource=r.source; var tiles:Array=[]
    for i in src.get_tiles_count():
        var pos:=src.get_tile_id(i); tiles.append({"col":pos.x,"row":pos.y})
    return U.ok({"tileset_path":str(args.tileset_path),"source_id":r.source_id,"tiles":tiles,"count":tiles.size()})

static func _tileset_source(args:Dictionary)->Dictionary:
    var r:=_atlas_source(args); if r.has("error"): return r.error
    var src:TileSetAtlasSource=r.source; var tex:Texture2D=src.texture
    var result:Dictionary={"tileset_path":str(args.tileset_path),"source_id":r.source_id,"source_class":src.get_class(),"tiles":src.get_tiles_count(),"texture_region_size":U.encode_value(src.texture_region_size),"texture_path":tex.resource_path if tex!=null else "","texture_size":U.encode_value(tex.get_size()) if tex!=null else U.encode_value(Vector2.ZERO)}
    if bool(args.get("include_image",false)):
        if tex==null: return U.error("TILESET_TEXTURE_MISSING","Atlas source has no texture")
        var image:=tex.get_image()
        if image==null:
            var tree:=Engine.get_main_loop() as SceneTree
            if tree==null: return U.error("TILESET_IMAGE_UNAVAILABLE","SceneTree is unavailable while waiting for atlas texture readiness")
            for _attempt in 30:
                await tree.process_frame
                image=tex.get_image()
                if image!=null: break
        if image==null: return U.error("TILESET_IMAGE_UNAVAILABLE","Unable to read atlas texture image after waiting for texture readiness")
        var encoded:=ImageUtils.encode_png(image,int(args.get("max_resolution",1024))); if not bool(encoded.get("ok",false)): return encoded
        result["image_width"]=encoded.width; result["image_height"]=encoded.height; result["__mcp_image"]={"data":encoded.data,"mime_type":encoded.mime_type}
    return U.ok(result)

static func _gridmap(plugin:EditorPlugin,path:String)->GridMap:
    return U.resolve_node(plugin,path) as GridMap

static func _grid_state(node:GridMap,pos:Vector3i)->Dictionary:
    var item:=node.get_cell_item(pos); return {"has_item":item>=0,"item":item,"orientation":node.get_cell_item_orientation(pos) if item>=0 else 0}

static func _grid_undo(undo:EditorUndoRedoManager,node:GridMap,pos:Vector3i,state:Dictionary)->void:
    undo.add_undo_method(node,"set_cell_item",pos,int(state.get("item",-1)),int(state.get("orientation",0)))

static func _validate_grid_item(node:GridMap,item:int,orientation:int)->Dictionary:
    if item < -1: return U.error("GRIDMAP_ITEM_INVALID","GridMap item must be -1 or a MeshLibrary item id")
    if orientation < 0 or orientation > 23: return U.error("GRIDMAP_ORIENTATION_INVALID","GridMap orientation must be in the inclusive range 0..23")
    if item < 0: return {"ok":true}
    var library:=node.mesh_library
    if library==null: return U.error("MESH_LIBRARY_MISSING","GridMap has no MeshLibrary assigned")
    if not Array(library.get_item_list()).has(item): return U.error("MESH_LIBRARY_ITEM_NOT_FOUND","MeshLibrary item does not exist")
    return {"ok":true}

static func _gridmap_set(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_gridmap(plugin,str(args.get("node_path",""))); if node==null: return U.error("GRIDMAP_NOT_FOUND","GridMap not found")
    var pos:=Vector3i(int(args.get("map_x",0)),int(args.get("map_y",0)),int(args.get("map_z",0))); var item:=int(args.get("item",0)); var orientation:=int(args.get("orientation",0)); var prev:=_grid_state(node,pos)
    var validation:=_validate_grid_item(node,item,orientation); if not bool(validation.get("ok",false)): return validation
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: GridMap set item"); undo.add_do_method(node,"set_cell_item",pos,item,orientation); _grid_undo(undo,node,pos,prev); undo.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"position":U.encode_value(pos),"item":item,"orientation":orientation,"undoable":true})

static func _gridmap_fill(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_gridmap(plugin,str(args.get("node_path",""))); if node==null: return U.error("GRIDMAP_NOT_FOUND","GridMap not found")
    var w:=int(args.get("rect_w",1)); var h:=int(args.get("rect_h",1)); var d:=int(args.get("rect_d",1))
    if w<=0 or h<=0 or d<=0 or w>MAX_FILL_CELLS or h>MAX_FILL_CELLS or d>MAX_FILL_CELLS: return U.error("FILL_LIMIT","GridMap fill dimensions must be in 1..%d" % MAX_FILL_CELLS)
    var total:=w*h*d
    if total>MAX_FILL_CELLS: return U.error("FILL_LIMIT","GridMap fill must contain at most %d cells" % MAX_FILL_CELLS)
    var x0:=int(args.get("rect_x",0)); var y0:=int(args.get("rect_y",0)); var z0:=int(args.get("rect_z",0)); var item:=int(args.get("item",0)); var orientation:=int(args.get("orientation",0))
    var validation:=_validate_grid_item(node,item,orientation); if not bool(validation.get("ok",false)): return validation
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: GridMap fill %dx%dx%d" % [w,h,d])
    for x in range(x0,x0+w):
        for y in range(y0,y0+h):
            for z in range(z0,z0+d):
                var pos:=Vector3i(x,y,z); var prev:=_grid_state(node,pos); undo.add_do_method(node,"set_cell_item",pos,item,orientation); _grid_undo(undo,node,pos,prev)
    undo.commit_action(); U.mark_unsaved(plugin); return U.ok({"cells_filled":total,"rect":{"x":x0,"y":y0,"z":z0,"w":w,"h":h,"d":d},"undoable":true})

static func _gridmap_clear(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_gridmap(plugin,str(args.get("node_path",""))); if node==null: return U.error("GRIDMAP_NOT_FOUND","GridMap not found")
    var cells:=node.get_used_cells(); if cells.size()>MAX_FILL_CELLS: return U.error("CLEAR_LIMIT","GridMap has too many cells for bounded UndoRedo clear")
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: GridMap clear"); undo.add_do_method(node,"clear")
    for pos in cells: _grid_undo(undo,node,pos,_grid_state(node,pos))
    undo.commit_action(); U.mark_unsaved(plugin); return U.ok({"cleared":true,"cells":cells.size(),"undoable":true})

static func _gridmap_used(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_gridmap(plugin,str(args.get("node_path",""))); if node==null: return U.error("GRIDMAP_NOT_FOUND","GridMap not found")
    var all:=node.get_used_cells(); var limit:=clampi(int(args.get("limit",512)),1,4096); var out:Array=[]
    for pos in all:
        if out.size()>=limit: break
        out.append({"x":pos.x,"y":pos.y,"z":pos.z,"item":node.get_cell_item(pos),"orientation":node.get_cell_item_orientation(pos)})
    return U.ok({"cells":out,"count":out.size(),"total":all.size(),"truncated":all.size()>out.size()})

static func _gridmap_library(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=_gridmap(plugin,str(args.get("node_path",""))); if node==null: return U.error("GRIDMAP_NOT_FOUND","GridMap not found")
    var lib:=node.mesh_library; if lib==null: return U.ok({"library":"","items":[],"count":0})
    var items:Array=[]; var ids:=lib.get_item_list(); ids.sort()
    for id in ids:
        var mesh:=lib.get_item_mesh(id); items.append({"item":id,"name":lib.get_item_name(id),"mesh":mesh.resource_path if mesh!=null else "","mesh_class":mesh.get_class() if mesh!=null else ""})
    return U.ok({"library":lib.resource_path,"items":items,"count":items.size()})

static func _csg_create(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var root:=plugin.get_editor_interface().get_edited_scene_root(); if root==null: return U.error("NO_SCENE","No edited scene")
    var parent:=U.resolve_node_from_root(root,str(args.get("parent_path","."))); if parent==null: return U.error("NODE_NOT_FOUND","CSG parent not found"); if not parent is Node3D: return U.error("WRONG_TYPE","CSG parent must be Node3D")
    var shape:=str(args.get("shape","box")); var class_name_text:=str(CSG_CLASSES.get(shape,"")); if class_name_text.is_empty(): return U.error("CSG_SHAPE_INVALID","Unknown CSG shape")
    var node:=ClassDB.instantiate(class_name_text) as Node3D; if node==null: return U.error("CSG_CREATE_FAILED","Unable to instantiate CSG node")
    var requested:=str(args.get("name","")); node.name=requested if not requested.is_empty() else class_name_text
    if node is CSGShape3D: (node as CSGShape3D).operation=CSG_OPERATIONS.get(str(args.get("operation","union")),CSGShape3D.OPERATION_UNION)
    var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: Create "+str(node.name)); undo.add_do_method(parent,"add_child",node,true); undo.add_do_method(node,"set_owner",root); undo.add_do_reference(node); undo.add_undo_method(parent,"remove_child",node); undo.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"path":U.node_path_relative(root,node),"class":node.get_class(),"shape":shape,"undoable":true})

static func _csg_operation(plugin:EditorPlugin,args:Dictionary)->Dictionary:
    var node:=U.resolve_node(plugin,str(args.get("node_path",""))) as CSGShape3D; if node==null: return U.error("CSG_NOT_FOUND","CSGShape3D not found")
    var op_name:=str(args.get("operation","")); if not CSG_OPERATIONS.has(op_name): return U.error("CSG_OPERATION_INVALID","Unknown CSG operation")
    var old:=node.operation; var next:int=CSG_OPERATIONS[op_name]; var undo:=plugin.get_undo_redo(); undo.create_action("Godot MCP: CSG operation"); undo.add_do_method(node,"set","operation",next); undo.add_undo_method(node,"set","operation",old); undo.commit_action(); U.mark_unsaved(plugin)
    return U.ok({"operation":op_name,"undoable":true})