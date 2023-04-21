extends Object

var brush: SpkoBrush
var island: SpkoIsland
var _removed_points := PackedInt32Array()


func _init(p_brush: SpkoBrush, p_island: SpkoIsland) -> void:
	brush = p_brush
	island = p_island


func get_vertex_count() -> int:
	return island.points.size()


func get_vertex_position(p_idx: int) -> Vector2:
	var k := wrapi(p_idx, 0, get_vertex_count())
	return brush.points[island.points[k]]


func set_vertex_position(p_idx: int, p_pos: Vector2) -> void:
	brush.points[island.points[p_idx]] = p_pos


func insert_vertex(p_idx: int, p_pos: Vector2) -> void:
	island.points.insert(p_idx, brush._add_vertex(p_pos))


func remove_vertex(p_idx: int) -> void:
	_removed_points.push_back(island.points[p_idx])
	island.points.remove_at(p_idx)


func get_corner_axis(p_idx: int) -> Vector2:
	var a := get_vertex_position(p_idx - 1)
	var b := get_vertex_position(p_idx)
	var c := get_vertex_position(p_idx + 1)

	var ab := b - a
	var bc := c - b
	var mab := ab.length()
	var mbc := bc.length()
	var uab := ab / mab
	var ubc := bc / mbc
	return uab.slerp(ubc, 0.5).orthogonal() * get_winding_signum() * -1.0


func get_winding_signum() -> int:
	return 1 if island.clockwise else -1


func get_element_id() -> int:
	return island.element_id


## Corner turn angle -- angle difference between segment in and segment out.
func get_corner_angle(p_idx: int) -> float:
	var p := get_vertex_position(p_idx)
	var ab := p - get_vertex_position(p_idx - 1)
	var bc := get_vertex_position(p_idx + 1) - p
	return ab.angle_to(bc)


func get_segment_length(p_idx: int) -> float:
	return get_vertex_position(p_idx).distance_to(get_vertex_position(p_idx + 1))


## Returns the normalized direction vector of the given segment. (The direction from point `i` to point `i+1`)
func get_segment_dir(p_idx: int) -> Vector2:
	var a := get_vertex_position(p_idx)
	var b := get_vertex_position(p_idx + 1)
	return (b - a).normalized()


## Returns the vector perpendicular to the segment facing out (adjusted for winding order)
func get_segment_normal(p_idx: int) -> Vector2:
	return get_segment_dir(p_idx).orthogonal() * get_winding_signum() * -1.0


## linear interpolate parallel segment
func segment_lerp(p_idx: int, p_weight: float, p_y: float) -> Vector2:
	var a := get_vertex_position(p_idx)
	var b := get_vertex_position(p_idx + 1)
	return a.lerp(b, p_weight) + get_segment_normal(p_idx) * p_y


## Returns interpolant ('weight') range for the given parallel, clamped between the corner axes at each end.
## result is array, [ min, max ]
## The neutral/identity parallel is [0.0, 1.0]
func parallel_lerp_range(p_idx: int, p_y: float) -> Array[float]:
	var s0 := get_vertex_position(p_idx)
	var s1 := get_vertex_position(p_idx + 1)
	var perp := get_segment_normal(p_idx)
	var lo := _line_intersect(s0 + perp * p_y, s1 - s0, s0, get_corner_axis(p_idx))
	var hi := _line_intersect(s0 + perp * p_y, s1 - s0, s1, get_corner_axis(p_idx + 1))
	return [ lo if is_finite(lo) else 0.0, hi if is_finite(hi) else 1.0 ]


## true if the path loops back on itself
func is_closed_loop() -> bool:
	return true


## true if there is a segment at {p_idx, p_idx+1}
func has_outbound(p_idx: int) -> bool:
	return is_closed_loop() || (p_idx >= 0 && p_idx + 1 < get_vertex_count())


## true if there is a segment {p_idx-1, p_idx}
func has_inbound(p_idx: int) -> bool:
	return is_closed_loop() || (p_idx > 0 && p_idx  < get_vertex_count())


## find intersection of pair of lines. result is scalar 't' -- interpolant for line 'a'.
## Returns NAN if no intersection found. Use is_finite to check result.
func _line_intersect(p_from_a: Vector2, p_dir_a: Vector2, p_from_b: Vector2, p_dir_b: Vector2) -> float:
	var denom := p_dir_b.y * p_dir_a.x - p_dir_b.x * p_dir_a.y
	if is_zero_approx(denom):
		return NAN
	var v := p_from_a - p_from_b
	var t := (p_dir_b.x * v.y - p_dir_b.y * v.x) / denom
	return t

