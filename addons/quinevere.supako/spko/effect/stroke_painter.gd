@tool
class_name SpkoStrokePainter extends SpkoEffect
## Painter module that renders shape edges.


const MODULE_NAME := &"StrokePainter"


enum TextureMode {
	TILE,
}


## Width of the stroke in pixels.
@export var base_width: float = 8.0:
	set(value):
		base_width = value
		notify_module_changed(true)

## Stroke balance factor. 0.0 is centered, with half of the stroke width on either side of the segment.
## 1.0: 100% outset, -1.0: 100% inset
@export var balance: float = 0.0:
	set(value):
		balance = value
		notify_module_changed(true)

## Segments will be rendered with this material by default.
@export var default_material: Material:
	set(value):
		default_material = value
		notify_module_changed(true)

@export var texture_mode: TextureMode = TextureMode.TILE:
	set(value):
		texture_mode = value
		notify_module_changed(true)

@export var texture: Texture2D:
	set(value):
		texture = value
		notify_module_changed(true)

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		notify_module_changed(true)

@export var vertex_colors_enabled: bool = true:
	set(value):
		vertex_colors_enabled = value
		notify_module_changed(true)


func _effect_build(ctx: CallbackContext, brush: SpkoBrush) -> void:
	_clear(ctx)

	if base_width > 0.0:
		var meshes: Array[RID] = []
		brush.iter_islands(func (ia: SpkoBrush.IslandAccess) -> void:
			var arrays := _build_island_mesh_arrays(ia)
			if arrays.size() == RenderingServer.ARRAY_MAX:
				var mesh := RenderingServer.mesh_create()
				meshes.push_back(mesh)
				RenderingServer.mesh_add_surface_from_arrays(mesh, RenderingServer.PRIMITIVE_TRIANGLES, arrays)
			)

		ctx.cache_set("meshes", meshes)

	var ci := ctx.get_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	if ctx.is_visible():
		_render(ci, ctx.cache_get("meshes"))


func _effect_update(ctx: CallbackContext) -> void:
	var ci := ctx.get_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	if ctx.is_visible():
		_render(ci, ctx.cache_get("meshes"))


func _effect_stop(ctx: CallbackContext) -> void:
	_clear(ctx)


func _render(ci: RID, meshes: Array[RID]) -> void:
	var rsv := RenderingServer

	for mesh in meshes:
		if texture:
			rsv.canvas_item_add_mesh(ci, mesh, Transform2D.IDENTITY, Color.WHITE, texture.get_rid())
		else:
			rsv.canvas_item_add_mesh(ci, mesh)

	if texture:
		rsv.canvas_item_set_default_texture_repeat(ci, rsv.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED)

	if default_material:
		rsv.canvas_item_set_material(ci, default_material.get_rid())


func _clear(ctx: CallbackContext) -> void:
	for mesh in ctx.cache_get("meshes", []):
		if mesh:
			RenderingServer.free_rid(mesh)
	ctx.cache_clear()


func _build_island_mesh_arrays(ia: SpkoBrush.IslandAccess) -> Array:
	if ia.get_vertex_count() < 2:
		return []

	# scale UVs for tiling...
	var uv_scale := Vector2.ONE
	if texture && texture_mode == TextureMode.TILE:
		var tex_size := texture.get_size()
		uv_scale = Vector2.ONE / Vector2(tex_size.aspect() * base_width, 1.0)

	var distance_pos := 0.0
#	var distance_neg := 0.0

	var vertices := PackedVector2Array()
	var indices := PackedInt32Array()
	var uvs := PackedVector2Array()
	var uvs2 := PackedVector2Array() # UV2 is tiled

	var qypos := _balance(base_width, balance)
	var qyneg := qypos - base_width

	for i in range(ia.get_vertex_count()):
		var qpos_x_range := ia.parallel_lerp_range(i, qypos)
		var qpos0 := ia.segment_lerp(i, qpos_x_range[0], qypos)
		var qpos1 := ia.segment_lerp(i, qpos_x_range[1], qypos)
		var qneg_x_range := ia.parallel_lerp_range(i, qyneg)
		var qneg0 := ia.segment_lerp(i, qneg_x_range[0], qyneg)
		var qneg1 := ia.segment_lerp(i, qneg_x_range[1], qyneg)

		var index0 := vertices.size()
		# {0 1 2}, {3 2 1}
		indices.append_array([index0, index0 + 1, index0 + 2, index0 + 3, index0 + 2, index0 + 1])
		vertices.append_array([qpos0, qpos1, qneg0, qneg1])
		var uvpos0 := Vector2(float(i), 0.0)
		var uvneg0 := Vector2(float(i), 1.0)
		uvs.append_array([uvpos0, uvpos0 + Vector2(1.0, 0.0), uvneg0, uvneg0 + Vector2(1.0, 0.0)])

		var length_pos := qpos0.distance_to(qpos1)
#		var length_neg := qneg0.distance_to(qneg1)

		# texture U coord is based on outer edge length
		var uv2_pos0 := uv_scale * Vector2(distance_pos, 0.0)
		var uv2_pos1 := uv_scale * Vector2(distance_pos + length_pos, 0.0)
		var uv2_neg0 := uv_scale * Vector2(distance_pos, 1.0)
		var uv2_neg1 := uv_scale * Vector2(distance_pos + length_pos, 1.0)
		uvs2.append_array([uv2_pos0, uv2_pos1, uv2_neg0, uv2_neg1])
		distance_pos += length_pos
#		distance_neg += length_neg


	var rsv := RenderingServer
	var arrays := []
	arrays.resize(rsv.ARRAY_MAX)
	arrays[rsv.ARRAY_VERTEX] = vertices
	if vertex_colors_enabled:
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		colors.fill(color)
		arrays[rsv.ARRAY_COLOR] = colors
	arrays[rsv.ARRAY_TEX_UV] = uvs2
	arrays[rsv.ARRAY_INDEX] = indices
	return arrays


func _balance(p_x: float, p_balance: float) -> float:
	return p_balance * p_x / 2.0 + p_x / 2.0
