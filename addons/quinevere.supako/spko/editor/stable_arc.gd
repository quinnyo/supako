
## Sample a stable arc and return the sampled point positions.
## - "stable" means no twitching/flickering when animating arc properties (other than resolution).
## - this works by using fixed vertex positions for any given resolution
##
## The points are always in a clockwise order. The first point will be in the
## direction of `min(start_angle, start_angle + arc_length)`.
## If `radius` is zero, the array will be empty.
## If `arc_length` is zero, the array will contain a single point.
static func arc_build_points(radius: float, start_angle: float, arc_length: float, resolution: int) -> PackedVector2Array:
	if is_zero_approx(radius):
		return PackedVector2Array()
	resolution = maxi(resolution, 3)

	if arc_length < 0.0:
		start_angle = start_angle + arc_length
		arc_length = absf(arc_length)

	arc_length = clampf(arc_length, 0.0, TAU)
	if is_zero_approx(arc_length):
		return PackedVector2Array([arc_point_at_angle(start_angle, resolution, radius)])

	var points := PackedVector2Array()
	points.push_back(arc_point_at_angle(start_angle, resolution, radius))

	var arc_step := TAU / float(resolution)
	var end_angle := start_angle + arc_length
	var vlast := Vector2.from_angle(start_angle)

	var start_idx := floori(start_angle / arc_step + 1.0)
	var end_idx := floori(end_angle / arc_step)
	for i in range(start_idx, end_idx + 1):
		var angle := float(i) / float(resolution) * TAU
		var v := Vector2.from_angle(angle)
		if vlast.angle_to(v) <= 0.001:
			# avoid ~duplicate points (first|start_angle in particular)
			continue
		points.push_back(v * radius)
		vlast = v

	var v := Vector2.from_angle(end_angle)
	if vlast.angle_to(v) > 0.001:
		points.push_back(arc_point_at_angle(end_angle, resolution, radius))
	return points


## Sample stable arc at `angle` radians from `(1, 0)`. Point is clamped to linear edges of regular polygon with `resolution` sides.
static func arc_point_at_angle(angle: float, resolution: int, radius: float = 1.0) -> Vector2:
	var arc_step := TAU / float(resolution)
	var pre := floorf(angle / arc_step) * arc_step
	var next := ceilf(angle / arc_step) * arc_step
	var frac := angle / arc_step - floorf(angle / arc_step)
	return Vector2.from_angle(pre).lerp(Vector2.from_angle(next), frac) * radius


pass
