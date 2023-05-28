@tool
class_name SpkoPath extends SpkoShape


var curve: Curve2D:
	set(value):
		if is_instance_valid(curve) && curve.changed.is_connected(mark_dirty):
			curve.changed.disconnect(mark_dirty)
		curve = value
		if is_instance_valid(curve):
			curve.changed.connect(mark_dirty)
		mark_dirty()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = [
		{
			"name": "curve",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "Curve2D",
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_ALWAYS_DUPLICATE,
		},
	]
	return properties


func get_vertex_count() -> int:
	if !is_instance_valid(curve):
		return 0
	return curve.point_count


func get_vertex_position(p_idx: int) -> Vector2:
	assert(p_idx >= 0 && p_idx < get_vertex_count(), "get_vertex_position: index out of bounds")
	return curve.get_point_position(p_idx)


func set_vertex_position(p_idx: int, p_pos: Vector2) -> void:
	assert(p_idx >= 0 && p_idx < get_vertex_count(), "set_vertex_position: index out of bounds")
	curve.set_point_position(p_idx, p_pos)
	mark_dirty()


func insert_vertex(p_idx: int, p_pos: Vector2) -> void:
	assert(p_idx >= 0 && p_idx <= get_vertex_count(), "insert_vertex: index out of bounds") # note: index == N is allowed
	if !is_instance_valid(curve):
		curve = Curve2D.new()
	curve.add_point(p_pos, Vector2(), Vector2(), p_idx)
	mark_dirty()


func remove_vertex(p_idx: int) -> void:
	assert(p_idx >= 0 && p_idx < get_vertex_count(), "remove_vertex: index out of bounds")
	curve.remove_point(p_idx)
	mark_dirty()


## Return the index of the vertex that `a` has a forward edge to.
## Returns `-1` if vertex `a` does not have a forward edge or if `a` is out of range.
func next(a: int) -> int:
	if a >= 0 && a < get_vertex_count():
		return wrapi(a + 1, 0, get_vertex_count())
	return -1


## Return true if a (forward) edge connects vertex `a` to vertex `b`.
func has_next(a: int) -> bool:
	return a >= 0 && a < get_vertex_count()


## Set vertex positions to values from `array`. Resizes vertex array to size of `array`.
func set_vertex_position_array(array: PackedVector2Array) -> void:
	if !is_instance_valid(curve):
		curve = Curve2D.new()
	curve.clear_points()
	for v in array:
		curve.add_point(v)
	mark_dirty()


func get_vertex_position_array() -> PackedVector2Array:
	var array := PackedVector2Array()
	array.resize(get_vertex_count())
	for i in range(get_vertex_count()):
		array[i] = get_vertex_position(i)
	return array


func _build_brush() -> SpkoBrush:
	var b := SpkoBrush.new()
	if get_vertex_count() > 2:
		var island := b.add_island_from_points(get_vertex_position_array(), get_element_id())
		b.island_add_tag(island, name)
	return b
