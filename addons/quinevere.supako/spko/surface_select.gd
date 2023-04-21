@tool
class_name SpkoSurfaceSelect extends Resource


## Surface normal angle ranges data storage -- this isn't meant to be edited directly.
## You can edit the angle ranges visually in the inspector.
## The extents of each range are exported as numbered properties of this resource.
## Surface normal angle ranges stored as `PackedFloat64Array([START, END])`.
var angles: Array[PackedFloat64Array]:
	set(value):
		angles = value
		emit_changed()
		notify_property_list_changed()


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = [
		{
			"name": "angles",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_ALWAYS_DUPLICATE,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%s:" % [ TYPE_PACKED_FLOAT64_ARRAY ],
		}
	]

	for i in range(angle_range_count()):
		properties.push_back({
			"name": get_angle_range_start_property_name(i),
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR,
		})
		properties.push_back({
			"name": get_angle_range_end_property_name(i),
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR,
		})

	return properties


func _get(property: StringName):
	var angr_match := _angle_range_property_search(property)
	if angr_match:
		var index := angr_match.get_string("index").to_int()
		var field := angr_match.get_string("field")
		if index >= 0 && index < angle_range_count():
			match field:
				"start": return angle_range_get_start(index)
				"end": return angle_range_get_end(index)


func _set(property: StringName, value) -> bool:
	var angr_match := _angle_range_property_search(property)
	if angr_match:
		var index := angr_match.get_string("index").to_int()
		var field := angr_match.get_string("field")
		if index >= 0 && index < angle_range_count():
			match field:
				"start": return angle_range_set_start(index, value)
				"end": return angle_range_set_end(index, value)

	return false


func angle_range_count() -> int:
	return angles.size()


## Return the name that an indexed angle range's `start` would be exported as.
func get_angle_range_start_property_name(index: int) -> StringName:
	return "angle_range_%d/start" % index


## Return the name that an indexed angle range's `end` would be exported as.
func get_angle_range_end_property_name(index: int) -> StringName:
	return "angle_range_%d/end" % index


## Getter for indexed angle range `start`
func angle_range_get_start(index: int) -> float:
	if index >= 0 && index < angle_range_count():
		var angr := angles[index]
		if angr.size() == 2:
			return angr[0]
	return 0.0


## Getter for indexed angle range `end`
func angle_range_get_end(index: int) -> float:
	if index >= 0 && index < angle_range_count():
		var angr := angles[index]
		if angr.size() == 2:
			return angr[1]
	return 0.0


## Setter for indexed angle range `start`
func angle_range_set_start(index: int, x: float) -> bool:
	if index >= 0 && index < angle_range_count():
		var angr := angles[index]
		if angr.size() == 2:
			angr[0] = x
			emit_changed()
			return true
	return false


## Setter for indexed angle range `end`
func angle_range_set_end(index: int, x: float) -> bool:
	if index >= 0 && index < angle_range_count():
		var angr := angles[index]
		if angr.size() == 2:
			angr[1] = x
			emit_changed()
			return true
	return false


## Returns the interval (from start to end) of the angle range at `index`.
func angle_range_get_interval(index: int) -> float:
	return _angle_sub(angle_range_get_end(index), angle_range_get_start(index))


## Returns true if `angle` is equal to or between the bounds of the angle range at `index`.
func angle_range_contains(index: int, angle: float) -> bool:
	return is_angle_in_range(angle, angle_range_get_start(index), angle_range_get_end(index))


## Returns true if normal `v` should be selected.
func select_normal(v: Vector2) -> bool:
	var vangle := v.angle()
	for i in range(angle_range_count()):
		if angle_range_contains(i, vangle):
			return true
	return false


## Returns true if `angle` is equal to `angr_start`
func is_angle_in_range(angle: float, angr_start: float, angr_end: float) -> bool:
	var r := _angle_sub(angle, angr_start)
	return r <= _angle_sub(angr_end, angr_start)


static func create_angle_range(angr_start: float = PI, angr_end: float = 0.0) -> PackedFloat64Array:
	return PackedFloat64Array([angr_start, angr_end])


func _angle_range_property_search(property: StringName) -> RegExMatch:
	var regexp := RegEx.create_from_string("^angle_range_(?<index>\\d+)/(?<field>.*)$")
	return regexp.search(property)


## Return the angle in the range (0..TAU) that is equivalent to `a`.
func _angle_wrap(a: float) -> float:
	return fposmod(a, TAU)


## Subtract `b` from `a`, keeping all angles in the range (0..TAU)
func _angle_sub(a: float, b: float) -> float:
	return _angle_wrap(_angle_wrap(a) - _angle_wrap(b))


pass
