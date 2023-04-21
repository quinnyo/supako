@tool
class_name SpkoBrush extends Resource


const IslandAccess := preload("island_access.gd")


## Extracted Island geometry primitive/thing.
class IslandGon:
	var points := PackedVector2Array()
	var element_id: int
	func _init(p_points: PackedVector2Array, p_element_id: int) -> void:
		points = p_points
		element_id = p_element_id


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
		island.element_id = src_island.element_id
		island.clockwise = src_island.clockwise
		_add_island(island)


func add_island_from_points(p_points: PackedVector2Array, p_element_id: int) -> void:
	var indices := PackedInt32Array()
	indices.resize(p_points.size())
	for i in range(p_points.size()):
		indices[i] = _add_vertex(p_points[i])
	var island := SpkoIsland.new()
	island.points = indices
	island.element_id = p_element_id
	island.clockwise = Geometry2D.is_polygon_clockwise(p_points)
	_add_island(island)


## Call f(IslandAccess) for each island in the brush.
func iter_islands(f: Callable) -> void:
	var removed_points := PackedInt32Array()
	for island in islands:
		var access := IslandAccess.new(self, island)
		f.call(access)
		removed_points.append_array(access._removed_points)
		access.free()

	# process removed points...
#	for island in islands:
#		for i in range(removed_points.size()):
#			if island.points.has(removed_points[i]):
#				removed_points[i] = -1


func get_island_count() -> int:
	return islands.size()


func get_island_gon(p_idx: int) -> IslandGon:
	var island := islands[p_idx]
	return IslandGon.new(get_island_points(p_idx), island.element_id)


## Build point position buffer for island and return it.
func get_island_points(p_idx: int) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	if p_idx >= 0 && p_idx < get_island_count():
		var island := islands[p_idx]
		vertices.resize(island.points.size())
		for i in range(island.points.size()):
			vertices[i] = points[island.points[i]]
	return vertices


## Add (or find) a vertex/point (to the `points` array) and return the index to access it.
func _add_vertex(p_vertex: Vector2) -> int:
	var v := p_vertex.snapped(vertex_merge_distance)
	var idx := int(vertex_map.get(v, -1))
	if idx == -1:
		idx = points.size()
		points.push_back(v)
	return idx


func _add_island(island: SpkoIsland) -> void:
	# HACK
#	if !island.clockwise:
#	 	island.points.reverse()
	islands.push_back(island)

