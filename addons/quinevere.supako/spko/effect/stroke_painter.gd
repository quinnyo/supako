@tool
class_name SpkoStrokePainter extends SpkoEffect
## Painter module that renders shape edges.


const MODULE_NAME := &"StrokePainter"


enum TextureMode {
	TILE,
}


## Mesh build utility / typed mesh arrays
class Meshy:
	var vertex2: PackedVector2Array
	var color: PackedColorArray
	var index: PackedInt32Array
	var uv: PackedVector2Array
	var uv2: PackedVector2Array

	func get_vertex_count() -> int:
		return vertex2.size()

	func as_arrays() -> Array:
		if get_vertex_count() == 0:
			return []
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		if !vertex2.is_empty():
			arrays[Mesh.ARRAY_VERTEX] = vertex2
		if !color.is_empty():
			arrays[Mesh.ARRAY_COLOR] = color
		if !index.is_empty():
			arrays[Mesh.ARRAY_INDEX] = index
		if !uv.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = uv
		if !uv2.is_empty():
			arrays[Mesh.ARRAY_TEX_UV2] = uv2
		return arrays


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

@export var surface_select: SpkoSurfaceSelect:
	set(value):
		if surface_select && surface_select.changed.is_connected(notify_module_changed):
			surface_select.changed.disconnect(notify_module_changed)
		surface_select = value
		if surface_select:
			surface_select.changed.connect(notify_module_changed.bind(true))
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


func _build_polyline_mesh(polyline: PackedInt32Array, ia: SpkoBrush.IslandAccess, meshy: Meshy) -> void:
	if polyline.size() < 2:
		return

	# scale UVs for tiling...
	var uv_scale := Vector2.ONE
	if texture && texture_mode == TextureMode.TILE:
		var tex_size := texture.get_size()
		uv_scale = Vector2.ONE / Vector2(tex_size.aspect() * base_width, 1.0)

	var distance_pos := 0.0
#	var distance_neg := 0.0

	var qypos := _balance(base_width, balance)
	var qyneg := qypos - base_width

	for i in polyline:
		var qpos_x_range := ia.parallel_lerp_range(i, qypos)
		var qpos0 := ia.segment_lerp(i, qpos_x_range[0], qypos)
		var qpos1 := ia.segment_lerp(i, qpos_x_range[1], qypos)
		var qneg_x_range := ia.parallel_lerp_range(i, qyneg)
		var qneg0 := ia.segment_lerp(i, qneg_x_range[0], qyneg)
		var qneg1 := ia.segment_lerp(i, qneg_x_range[1], qyneg)

		var index0 := meshy.get_vertex_count()
		meshy.index.append_array([index0, index0 + 1, index0 + 2, index0 + 3, index0 + 2, index0 + 1])
		meshy.vertex2.append_array([qpos0, qpos1, qneg0, qneg1])
#		var uvpos0 := Vector2(float(i), 0.0)
#		var uvneg0 := Vector2(float(i), 1.0)
#		uvs.append_array([uvpos0, uvpos0 + Vector2(1.0, 0.0), uvneg0, uvneg0 + Vector2(1.0, 0.0)])

		var length_pos := qpos0.distance_to(qpos1)
#		var length_neg := qneg0.distance_to(qneg1)

		# texture U coord is based on outer edge length
		var uv2_pos0 := uv_scale * Vector2(distance_pos, 0.0)
		var uv2_pos1 := uv_scale * Vector2(distance_pos + length_pos, 0.0)
		var uv2_neg0 := uv_scale * Vector2(distance_pos, 1.0)
		var uv2_neg1 := uv_scale * Vector2(distance_pos + length_pos, 1.0)
		meshy.uv.append_array([uv2_pos0, uv2_pos1, uv2_neg0, uv2_neg1])
		distance_pos += length_pos
#		distance_neg += length_neg


func _build_island_mesh_arrays(ia: SpkoBrush.IslandAccess) -> Array:
	if ia.get_vertex_count() < 2:
		return []

	var polylines: Array[PackedInt32Array] = []
	var started := false
	for i in ia.get_vertex_count():
		var surface_normal := ia.get_segment_normal(i)
		if surface_select == null || surface_select.select_normal(surface_normal):
			if started:
				polylines[-1].push_back(i)
			else:
				polylines.push_back(PackedInt32Array([i]))
				started = true
		else:
			started = false

	if polylines.is_empty():
		return []

	var meshy := Meshy.new()

	for polyline in polylines:
		_build_polyline_mesh(polyline, ia, meshy)

	if vertex_colors_enabled:
		meshy.color.resize(meshy.get_vertex_count())
		meshy.color.fill(color)

	return meshy.as_arrays()


func _balance(p_x: float, p_balance: float) -> float:
	return p_balance * p_x / 2.0 + p_x / 2.0
