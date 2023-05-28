@tool
class_name SpkoBrush extends Resource


const IslandAccess := preload("island_access.gd")


@export var points := PackedVector2Array()
@export var vertex_map: Dictionary
@export var islands: Array[SpkoIsland] = []

## Vertices closer than this distance will be merged.
var vertex_merge_distance := Vector2.ONE


func clear() -> void:
	islands.clear()


func copy_from(brush: SpkoBrush, xf: Transform2D) -> void:
	clear()
	add_from(brush, xf)


func add_from(brush: SpkoBrush, xf: Transform2D) -> void:
	var idxmap := PackedInt32Array()
	idxmap.resize(brush.points.size())
	for i in range(brush.points.size()):
		idxmap[i] = _add_vertex(xf * brush.points[i])

	for src_island in brush.islands:
		var indices := src_island.points.duplicate()
		for i in range(indices.size()):
			indices[i] = idxmap[indices[i]]
		var island := SpkoIsland.new()
		island.points = indices
		island.clockwise = src_island.clockwise
		_add_island(island)


func add_island_from_points(p_points: PackedVector2Array) -> void:
	var indices := PackedInt32Array()
	indices.resize(p_points.size())
	for i in range(p_points.size()):
		indices[i] = _add_vertex(p_points[i])
	var island := SpkoIsland.new()
	island.points = indices
	island.clockwise = Geometry2D.is_polygon_clockwise(p_points)
	_add_island(island)


## Call f(IslandAccess) for each island in the brush.
func iter_islands(f: Callable) -> void:
	for island_id in islands.size():
		var access := IslandAccess.new(self, island_id)
		f.call(access)
		access.free()
	# TODO: remove unreferenced vertices?


func get_island_count() -> int:
	return islands.size()


## Build point position buffer for island and return it.
func get_island_points(p_idx: int) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	if p_idx >= 0 && p_idx < get_island_count():
		var island := islands[p_idx]
		vertices.resize(island.points.size())
		for i in range(island.points.size()):
			vertices[i] = points[island.points[i]]
	return vertices


func get_vertex_count() -> int:
	return points.size()


func get_vertex_position(p_idx: int) -> Vector2:
	return points[p_idx]


func set_vertex_position(p_idx: int, p_pos: Vector2) -> void:
	points[p_idx] = p_pos


func island_get_vertex_count(p_island: int) -> int:
	assert(_has_island(p_island))
	return _get_island(p_island).points.size()


func island_get_vertex_position(p_island: int, p_idx: int) -> Vector2:
	assert(_has_island(p_island))
	var island := _get_island(p_island)
	var k := island.points[wrapi(p_idx, 0, island.points.size())]
	return get_vertex_position(k)


func island_set_vertex_position(p_island: int, p_idx: int, p_pos: Vector2) -> void:
	assert(_has_island(p_island))
	var k := _get_island(p_island).points[p_idx]
	set_vertex_position(k, p_pos)


func island_insert_vertex(p_island: int, p_idx: int, p_pos: Vector2) -> void:
	assert(_has_island(p_island))
	_get_island(p_island).points.insert(p_idx, _add_vertex(p_pos))


func island_remove_vertex(p_island: int, p_idx: int) -> void:
	assert(_has_island(p_island))
	_get_island(p_island).points.remove_at(p_idx)


func island_is_clockwise(p_island: int) -> bool:
	assert(_has_island(p_island))
	return _get_island(p_island).clockwise


func _has_island(p_island: int) -> bool:
	return p_island >= 0 && p_island < islands.size() && is_instance_valid(islands[p_island])


func _get_island(p_island: int) -> SpkoIsland:
	assert(p_island >= 0 && p_island < islands.size() && is_instance_valid(islands[p_island]))
	return islands[p_island]


## Add (or find) a vertex/point (to the `points` array) and return the index to access it.
func _add_vertex(p_vertex: Vector2) -> int:
	var v := p_vertex.snapped(vertex_merge_distance)
	var idx := int(vertex_map.get(v, -1))
	if idx == -1:
		idx = points.size()
		points.push_back(v)
		vertex_map[v] = idx
	return idx


func _add_island(island: SpkoIsland) -> void:
	islands.push_back(island)

