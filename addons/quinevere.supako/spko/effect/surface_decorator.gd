@tool
class_name SpkoSurfaceDecorator extends SpkoEffect


const MODULE_NAME := &"SurfaceDecorator"


## The Deco (Resource) to use
@export var deco: SpkoDeco:
	set(value):
		if deco && deco.changed.is_connected(notify_module_changed):
			deco.changed.disconnect(notify_module_changed)
		deco = value
		if deco:
			deco.changed.connect(notify_module_changed.bind(false))
		notify_module_changed(false)


## Minimum gap between two placed decorations
@export_range(1.0, 500.0, 0.1) var spacing_min: float = 8.0:
	set(value):
		spacing_min = value
		notify_module_changed(false)


@export var surface_select: SpkoSurfaceSelect:
	set(value):
		if surface_select && surface_select.changed.is_connected(notify_module_changed):
			surface_select.changed.disconnect(notify_module_changed)
		surface_select = value
		if surface_select:
			surface_select.changed.connect(notify_module_changed.bind(false))
		notify_module_changed(false)


# Private exported property (see `_get_property_list()`).
# Flexible storage for spawn (variant) parameters.
var spawn := {}


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = [
		{ "name": "spawn", "type": TYPE_DICTIONARY, "usage": PROPERTY_USAGE_NO_EDITOR },
		{
			"name": "spawn/surface_aligned",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR,
		},
		{
			"name": "spawn/rotation",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-180,180,0.1,or_greater,or_less,radians"
		},
		{
			"name": "spawn/rotation_deviation",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,360,0.1,or_greater,radians"
		},
		{
			"name": "spawn/flip_x",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,1,0.01"
		},
		{
			"name": "spawn/flip_y",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,1,0.01"
		},
		{
			"name": "spawn/scale_min",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_LINK,
		},
		{
			"name": "spawn/scale_max",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_LINK,
		},
	]
	return properties


func _set(property: StringName, value) -> bool:
	if property.begins_with("spawn/"):
		var sub := property.trim_prefix("spawn/")
		spawn[sub] = value
		notify_module_changed(false)
		return true
	return false


func _get(property: StringName):
	if property.begins_with("spawn/"):
		var sub := property.trim_prefix("spawn/")
		if spawn.has(sub):
			return spawn[sub]
		return _property_get_revert(property)


func _property_can_revert(property: StringName) -> bool:
	if property.begins_with("spawn/"):
		return true
	return false


func _property_get_revert(property: StringName):
	match property:
		"spawn/surface_aligned": return true
		"spawn/rotation": return 0.0
		"spawn/rotation_deviation": return 0.0
		"spawn/flip_x": return 0.0
		"spawn/flip_y": return 0.0
		"spawn/scale_min": return Vector2.ONE
		"spawn/scale_max": return Vector2.ONE


func _effect_build(ctx: CallbackContext, brush: SpkoBrush) -> void:
	# extract surfaces
	var surfaces: Array[Dictionary] = []
	brush.iter_islands(func (ia: SpkoBrush.IslandAccess) -> void:
		if ia.get_vertex_count() >= 2:
			for i in range(ia.get_vertex_count() if ia.is_closed_loop() else (ia.get_vertex_count() - 1)):
				surfaces.push_back({
					"index": i,
					"s0": ia.get_vertex_position(i),
					"s1": ia.get_vertex_position(i + 1),
					"surface_normal": ia.get_segment_normal(i),
				})
		)

	ctx.cache_set("surfaces", surfaces)
	ctx.cache_set("surfaces_changed", true)
	ctx.request_update()


func _effect_update(ctx: CallbackContext) -> void:
	var ci := ctx.get_canvas_item()
	RenderingServer.canvas_item_clear(ci)

	if deco == null:
		return

	if ctx.cache_get("surfaces_changed", false):
		ctx.cache_set("surfaces_changed", false)
		var placements: Array[Dictionary] = []
		var surfaces: Array[Dictionary] = ctx.cache_get("surfaces", Array([], TYPE_DICTIONARY, "", null))
		for surface in surfaces:
			_build_surface_placements(surface["s0"], surface["s1"], surface["surface_normal"], surface["index"], placements)
		ctx.cache_set("placements", placements)

	if ctx.is_visible():
		_render(ci, ctx.cache_get("placements", Array([], TYPE_DICTIONARY, "", null)))


func _render(ci: RID, placements: Array[Dictionary]) -> void:
	var flip_chance := Vector2(get("spawn/flip_x"), get("spawn/flip_y"))
	var scale_min: Vector2 = get("spawn/scale_min")
	var scale_max: Vector2 = get("spawn/scale_max")
	for population in placements:
		# RNG with cached seed
		var spawn_rng := RandomNumberGenerator.new()
		spawn_rng.seed = population["pop_seed"]
		var surface_normal: Vector2 = population["surface_normal"]
		var individuals: Array[Dictionary] = population["individuals"]
		var base_rotation := Vector2.UP.angle_to(surface_normal) if get("spawn/surface_aligned") else 0.0
		for ind in individuals:
			var origin: Vector2 = ind["origin"]
			var rotation = spawn_rng.randfn(base_rotation + get("spawn/rotation"), get("spawn/rotation_deviation"))
			var scale := scale_min.lerp(scale_max, spawn_rng.randf())
			if flip_chance.x > 0.0 && flip_chance.x > spawn_rng.randf():
				scale.x *= -1.0
			if flip_chance.y > 0.0 && flip_chance.y > spawn_rng.randf():
				scale.y *= -1.0
			var pose := Transform2D(rotation, origin).scaled_local(scale)
			var vari := deco.get_variant(spawn_rng.randi())
			vari.spawn_instance(ci, pose)


func _build_surface_placements(s0: Vector2, s1: Vector2, surface_normal: Vector2, surface_index: int, placements: Array[Dictionary]) -> void:
	if surface_select == null || surface_select.select_normal(surface_normal):
		var score := 1.0
		var pop_seed := hash([ surface_index, snappedf(rad_to_deg(s0.angle_to(s1)), 0.1), score ])
		var individuals: Array[Dictionary] = []
		for pos in _populate_segment(s0, s1, score, spacing_min, pop_seed):
			individuals.push_back({
				"origin": pos,
			})
		var population := {
			"surface_score": score,
			"surface_normal": surface_normal,
			"pop_seed": pop_seed,
			"individuals": individuals,
		}
		placements.push_back(population)


func _populate_segment(s0: Vector2, s1: Vector2, field_condition: float, ent_size: float, pop_seed: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = pop_seed
	var field_size := s0.distance_to(s1)
	if ent_size < 0.001 || field_size < ent_size:
		return []
	var count := floori(field_size / ent_size * field_condition)
	var ents: Array[Vector2] = []
	ents.resize(count)
	for i in range(count):
		ents[i] = s0.lerp(s1, rng.randf())
	return ents
