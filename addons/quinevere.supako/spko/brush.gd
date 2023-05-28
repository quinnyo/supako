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
		island.tags = src_island.tags.duplicate()
		island.owner_id = src_island.owner_id
		_add_island(island)


## Create a new island using the path p_points.
## Returns the index of the newly created island.
func add_island_from_points(p_points: PackedVector2Array, p_owner_id: int = 0) -> int:
	var indices := PackedInt32Array()
	indices.resize(p_points.size())
	for i in range(p_points.size()):
		indices[i] = _add_vertex(p_points[i])
	var island := SpkoIsland.new()
	island.owner_id = p_owner_id
	island.points = indices
	island.clockwise = Geometry2D.is_polygon_clockwise(p_points)
	return _add_island(island)


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


func island_get_owner(p_island: int) -> int:
	return _get_island(p_island).owner_id


func island_add_tag(p_island: int, p_tag: String) -> void:
	_get_island(p_island).tags[p_tag] = ""


func island_has_tag(p_island: int, p_tag: String) -> bool:
	return _get_island(p_island).tags.has(p_tag)


func island_get_segs(p_island: int) -> PackedInt32Array:
	return _get_island(p_island).points.duplicate()


func island_has_seg(p_island: int, p_a: int, p_b: int) -> bool:
	var island := _get_island(p_island)
	var isl_a := island.points[island.points.size() - 1] # assumes closed shapes
	for i in island.points.size():
		var isl_b := island.points[i]
		if isl_a == p_a && isl_b == p_b:
			return true
		isl_a = isl_b

	return false


## Look up user/s of the segment (a, b)
## Returns an array containing indices of all islands that include this segment.
func find_seg_users(a:int, b:int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in get_island_count():
		if island_has_seg(i, a, b):
			result.push_back(i)
	return result


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


func _add_island(island: SpkoIsland) -> int:
	islands.push_back(island)
	return get_island_count() - 1

