extends EditorProperty
## Graphical Inspector/Editor widget for SpkoSurfaceSelect.
## Presents all of the edited SurfaceSelect's angle ranges as arc segments on a circle.

const StableArc := preload("stable_arc.gd")

var selected_angr: int = 0:
	set(i):
		if get_edited_surface_select():
			i = clampi(i, 0, get_edited_surface_select().angle_range_count() - 1)
		selected_angr = i
		_refresh()


var gap := 10.0
var radius := 100.0
var resolution := 36
var line_width := 3.0
var selected_line_width := 5.0
var point_size := 4.0

var canvas := Panel.new()
var toolbar := VBoxContainer.new()
var angr_picker := SpinBox.new()
var angr_add := Button.new()
var angr_remove := Button.new()

## Local copy of the SpkoSurfaceSelect `angles`
var current_value: Array[PackedFloat64Array]

var _updating: bool = false
var _dragidx: int = MOUSE_BUTTON_NONE


func _init() -> void:
	angr_picker.rounded = true
	angr_picker.value_changed.connect(func(x: float): selected_angr = floori(x))
	toolbar.add_child(angr_picker)

	angr_add.text = "+"
	angr_add.pressed.connect(func():
		current_value.push_back(SpkoSurfaceSelect.create_angle_range())
		emit_changed(&"angles", current_value)
		_refresh()
		)
	toolbar.add_child(angr_add)

	angr_remove.text = "-"
	angr_remove.pressed.connect(func():
		if selected_angr >= 0 && selected_angr < current_value.size():
			current_value.remove_at(selected_angr)
			emit_changed(&"angles", current_value)
			_refresh()
		)
	toolbar.add_child(angr_remove)

	canvas.add_child(toolbar)

	add_child(canvas)
	add_focusable(canvas)
	set_bottom_editor(canvas)
	canvas.focus_mode = Control.FOCUS_CLICK
	canvas.draw.connect(_canvas_draw.bind(canvas))
	canvas.gui_input.connect(_canvas_gui_input)
	_refresh()


func _update_property() -> void:
	var new_value := get_edited_surface_select().angles
	if new_value == current_value:
		return
	_updating = true
	current_value = new_value.duplicate(true)
	_refresh()
	_updating = false


func get_edited_surface_select() -> SpkoSurfaceSelect:
	return get_edited_object() as SpkoSurfaceSelect


func _refresh() -> void:
	angr_picker.set_value_no_signal(selected_angr)
	angr_picker.max_value = current_value.size() - 1
	canvas.custom_minimum_size = Vector2.ONE * 2.0 * (radius + gap)
	canvas.queue_redraw()


func _update_drag() -> void:
	if selected_angr >= 0 && selected_angr < current_value.size():
		var pointer_offset := canvas.get_local_mouse_position() - canvas.size / 2.0
		var pointer_angle := fposmod(pointer_offset.angle(), TAU)
		var angr := current_value[selected_angr]
		match _dragidx:
			MOUSE_BUTTON_LEFT:
				angr[0] = pointer_angle
			MOUSE_BUTTON_RIGHT:
				angr[1] = pointer_angle
			_:
				return

		_refresh()


func _canvas_draw(control: Control) -> void:
	var centre := control.size / 2.0

	control.draw_set_transform(centre)

	var circle_points := StableArc.arc_build_points(radius, 0.0, TAU, resolution)
	control.draw_polyline(circle_points, Color(0.4, 0.4, 0.4), line_width * 2.0)
	circle_points.push_back(Vector2())
	control.draw_polygon(circle_points, [Color(0.75, 0.75, 0.75)])

	for i in range(current_value.size()):
		var angr := current_value[i]
		if angr.size() == 2:
			var angr_radius := maxf(absf(line_width), radius - i * absf(line_width) * 2.0)
			var color := Color.from_hsv(fposmod(float(hash(i)) * 0.033, 1.0), 0.7, 0.95)
			var fill_color := Color.from_hsv(color.h, color.s - 0.05, color.v - 0.05, 0.7)
			if i == selected_angr:
				angr_radius = radius + absf(line_width)
				color.v = 0.85
			var interval := fposmod(fposmod(angr[1], TAU) - fposmod(angr[0], TAU), TAU)
			var points := StableArc.arc_build_points(angr_radius, angr[0], interval, resolution)
			if points.size() >= 2:
				var fill_points := points.duplicate()
				fill_points.push_back(Vector2())
				control.draw_polygon(fill_points, [fill_color])
				control.draw_polyline(points, color, selected_line_width if i == selected_angr else line_width)

			if i == selected_angr:
				var start := StableArc.arc_point_at_angle(angr[0], resolution)
				var end := StableArc.arc_point_at_angle(angr[1], resolution)
				control.draw_rect(Rect2(start * angr_radius - Vector2(point_size, point_size) / 2.0, Vector2(point_size, point_size)), Color.WHITE)
				control.draw_rect(Rect2(end * angr_radius - Vector2(point_size, point_size) / 2.0, Vector2(point_size, point_size)), Color.WHITE)

				var active_size := Vector2(point_size, point_size) * 5.0
				if _dragidx == MOUSE_BUTTON_LEFT:
					control.draw_rect(Rect2(start * angr_radius - active_size / 2.0, active_size), Color.WHITE, false, 1.0)
				elif _dragidx == MOUSE_BUTTON_RIGHT:
					control.draw_rect(Rect2(end * angr_radius - active_size / 2.0, active_size), Color.WHITE, false, 1.0)

	control.draw_set_transform(Vector2())


func _canvas_gui_input(event: InputEvent) -> void:
	if _updating:
		return

	if event is InputEventMouseMotion:
		if _dragidx != MOUSE_BUTTON_NONE:
			_update_drag()
	elif event is InputEventMouseButton:
		var mbev := event as InputEventMouseButton
		if mbev.pressed:
			if mbev.button_index == MOUSE_BUTTON_WHEEL_UP:
				angr_picker.value += 1
#				selected_angr += 1
			elif mbev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				angr_picker.value -= 1
#				selected_angr -= 1
			elif _dragidx == MOUSE_BUTTON_NONE && (mbev.button_index == MOUSE_BUTTON_LEFT || mbev.button_index == MOUSE_BUTTON_RIGHT):
				_dragidx = mbev.button_index
				_update_drag()
		elif !mbev.pressed && mbev.button_index == _dragidx:
			var angr := current_value[selected_angr]
			match _dragidx:
				MOUSE_BUTTON_LEFT:
					emit_changed(get_edited_surface_select().get_angle_range_start_property_name(selected_angr), angr[0])
				MOUSE_BUTTON_RIGHT:
					emit_changed(get_edited_surface_select().get_angle_range_end_property_name(selected_angr), angr[1])
			_dragidx = MOUSE_BUTTON_NONE
			_refresh()


pass
