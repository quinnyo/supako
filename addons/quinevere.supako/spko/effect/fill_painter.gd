@tool
class_name SpkoFillPainter extends SpkoEffect


const MODULE_NAME := &"FillPainter"


enum TexCoordMode {
	LOCAL_POSITION,
	WORLD_POSITION,
}

enum TextureFilter {
	DEFAULT = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_DEFAULT,
	NEAREST = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
	LINEAR = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR,
	NEAREST_WITH_MIPMAPS = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,
	LINEAR_WITH_MIPMAPS = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
	NEAREST_WITH_MIPMAPS_ANISOTROPIC = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC,
	LINEAR_WITH_MIPMAPS_ANISOTROPIC = RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
}

enum TextureRepeat {
	DEFAULT = RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_DEFAULT,
	DISABLED = RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_DISABLED,
	ENABLED = RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED,
	MIRROR = RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_MIRROR,
}


@export var color: Color = Color.WHITE:
	set(value):
		color = value
		notify_module_changed(false)

# @export var dilate: float = 0.0:
# 	set(value):
# 		dilate = value
# 		notify_module_changed(false)

# @export_group("texture")
@export var texture: Texture2D:
	set(value):
		texture = value
		notify_module_changed(false)
@export var uv_mode: TexCoordMode = TexCoordMode.LOCAL_POSITION:
	set(value):
		uv_mode = value
		notify_module_changed(false)
@export var texture_offset: Vector2 = Vector2.ZERO:
	set(value):
		texture_offset = value
		notify_module_changed(false)
@export var texture_scale: Vector2 = Vector2.ONE:
	set(value):
		texture_scale = value
		notify_module_changed(false)
@export_range(-180, 180, 0.1, "radians") var texture_rotation: float = 0.0:
	set(value):
		texture_rotation = value
		notify_module_changed(false)
@export var texture_filter: TextureFilter = TextureFilter.DEFAULT:
	set(value):
		texture_filter = value
		notify_module_changed(false)
@export var texture_repeat: TextureRepeat = TextureRepeat.DEFAULT:
	set(value):
		texture_repeat = value
		notify_module_changed(false)
# @export_group("")


func _effect_build(ctx: CallbackContext, brush: SpkoBrush) -> void:
	ctx.cache_erase("polygons")
	var polygons: Array[PackedVector2Array] = []
	brush.iter_islands(func (ia: SpkoBrush.IslandAccess) -> void:
		if ia.get_vertex_count() < 2:
			return

		var points := PackedVector2Array()
		points.resize(ia.get_vertex_count())
		for i in range(ia.get_vertex_count()):
			points[i] = ia.get_vertex_position(i)

		polygons.push_back(points)
		)

	ctx.cache_set("polygons", polygons)

	var ci := ctx.get_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	if ctx.is_visible():
		_render(ci, ctx.cache_get("polygons"), ctx.get_host().global_transform)


func _effect_update(ctx: CallbackContext) -> void:
	var ci := ctx.get_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	if ctx.is_visible():
		_render(ci, ctx.cache_get("polygons"), ctx.get_host().global_transform)


func _render(ci: RID, polygons: Array[PackedVector2Array], host_transform: Transform2D) -> void:
	var rsv := RenderingServer

	for points in polygons:
		var uv_transform := Transform2D.IDENTITY
		match uv_mode:
			TexCoordMode.LOCAL_POSITION:
				uv_transform = Transform2D.IDENTITY
			TexCoordMode.WORLD_POSITION:
				uv_transform = host_transform
			_:
				push_error("fill_painter.gd: unhandled TexCoordMode (%s)" % [ uv_mode ])

		uv_transform *= Transform2D(texture_rotation, texture_scale, 0.0, texture_offset)
		var tex_size := texture.get_size() if texture else Vector2.ONE

		var uvs := PackedVector2Array()
		uvs.resize(points.size())
		for i in range(points.size()):
			var tex_pos := uv_transform * points[i]
			uvs[i] = tex_pos / tex_size
		var colors := PackedColorArray()
		colors.resize(points.size())
		colors.fill(color)

		if texture:
			rsv.canvas_item_add_polygon(ci, points, colors, uvs, texture.get_rid())
			rsv.canvas_item_set_default_texture_filter(ci, int(texture_filter))
			rsv.canvas_item_set_default_texture_repeat(ci, int(texture_repeat))
		else:
			rsv.canvas_item_add_polygon(ci, points, colors, uvs)
