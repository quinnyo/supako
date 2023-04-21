@tool
class_name SpkoEffectShapeCollision extends SpkoEffect
## Module to generate collision shape/body for shape...
## Collision shape/s are based on the shape/brush at the time that the module is invoked.
## (Module order matters!)


const MODULE_NAME := &"Collision"


enum BodyType { STATIC, AREA }

## Which type of physics body to generate...
@export var body_type := BodyType.STATIC:
	set(value):
		body_type = value
		notify_module_changed(false)


func _effect_build(ctx: CallbackContext, brush: SpkoBrush) -> void:
	_clear(ctx)

	var polygons: Array[PackedVector2Array] = []
	for idx in brush.get_island_count():
		var island := brush.get_island_gon(idx)
		polygons.append_array(Geometry2D.decompose_polygon_in_convex(island.points))

	ctx.cache_set("polygons", polygons)
	if ctx.is_visible():
		_render(ctx)


func _effect_update(ctx: CallbackContext) -> void:
	_clear(ctx)
	if ctx.is_visible():
		_render(ctx)


func _effect_stop(ctx: CallbackContext) -> void:
	_clear(ctx)


func _render(ctx: CallbackContext) -> void:
	var polygons: Array[PackedVector2Array] = ctx.cache_get("polygons", [])
	if polygons.is_empty():
		return

	var debug_shapes_visible := Engine.is_editor_hint() || ctx.get_host().get_tree().debug_collisions_hint
	if debug_shapes_visible:
		var ci := ctx.get_canvas_item()
		var color := Color.from_hsv(0.4, 0.5, 0.8, 0.5)
		for polygon in polygons:
			var colors := PackedColorArray()
			colors.resize(polygon.size())
			colors.fill(color)
			RenderingServer.canvas_item_add_polygon(ci, polygon, colors)
			color.h = wrapf(color.h + 0.37, 0.0, 1.0)

	var shapes: Array[RID] = []
	if !Engine.is_editor_hint():
		var phsv := PhysicsServer2D
		for convex in polygons:
			var shape := phsv.convex_polygon_shape_create()
			phsv.shape_set_data(shape, convex)
			shapes.push_back(shape)
		ctx.cache_set("shapes", shapes)

		if body_type == BodyType.STATIC:
			var body := phsv.body_create()
			ctx.cache_set("body", body)
			phsv.body_set_mode(body, phsv.BODY_MODE_STATIC)
			phsv.body_set_state(body, phsv.BODY_STATE_TRANSFORM, ctx.get_host().global_transform)
			phsv.body_attach_object_instance_id(body, ctx.get_host().get_instance_id())
			phsv.body_set_space(body, ctx.get_host().get_viewport().world_2d.space)
			for shape in shapes:
				phsv.body_add_shape(body, shape)
		elif body_type == BodyType.AREA:
			var area := phsv.area_create()
			ctx.cache_set("area", area)
			phsv.area_set_transform(area, ctx.get_host().global_transform)
			phsv.area_attach_object_instance_id(area, ctx.get_host().get_instance_id())
			phsv.area_set_space(area, ctx.get_host().get_viewport().world_2d.space)
			phsv.area_set_monitorable(area, true)
			for shape in shapes:
				phsv.area_add_shape(area, shape)


func _clear(ctx: CallbackContext) -> void:
	RenderingServer.canvas_item_clear(ctx.get_canvas_item())

	# clear all the physics body RIDs (but keep the extracted geometries)
	var body: RID = ctx.cache_get("body", RID())
	var area: RID = ctx.cache_get("area", RID())
	if body:
		PhysicsServer2D.free_rid(body)
	if area:
		PhysicsServer2D.free_rid(area)
	for shape in ctx.cache_get("shapes", []):
		if typeof(shape) == TYPE_RID && shape:
			PhysicsServer2D.free_rid(shape)
	ctx.cache_erase("body")
	ctx.cache_erase("area")
	ctx.cache_erase("shapes")
