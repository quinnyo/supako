@tool
extends Control

const Lib := preload("lib.gd")
const SnapSpace := Lib.SnapSpace
const SnapMode := Lib.SnapMode

signal snap_cfg_changed(property: StringName, new_value: Variant)

## Set to true when plugin adds the toolbar to the editor.
## Set to false (default) to try to avoid @tool shenanigans when editing toolbar scene.
var plugin_active: bool = false:
	set(value):
		plugin_active = value
		if plugin_active:
			_ctl_connect(ctl_enabled, "toggled")
			_ctl_connect(ctl_relative, "toggled")
			_ctl_connect(ctl_space_local, "toggled")
			_ctl_connect(ctl_space_parent, "toggled")
			_ctl_connect(ctl_space_world, "toggled")
			_ctl_connect(ctl_pos_step_x, "value_changed")
			_ctl_connect(ctl_pos_step_y, "value_changed")

var pos_step_uniform: bool:
	set(value):
		pos_step_uniform = value
		_snap_cfg_changed(&"position_step", position_step)

var ctl_enabled: CheckButton:
	get: return %enabled
var ctl_relative: CheckBox:
	get: return %relative
var ctl_space_local: Button:
	get: return %space_local
var ctl_space_parent: Button:
	get: return %space_parent
var ctl_space_world: Button:
	get: return %space_world
var ctl_pos_step_x: SpinBox:
	get: return %pos_step_x
var ctl_pos_step_y: SpinBox:
	get: return %pos_step_y
var ctl_debug_label: Label:
	get: return %debug_label

var debug_label_text: String:
	set(value):
		ctl_debug_label.text = value
	get:
		return ctl_debug_label.text

var enabled: bool:
	set(value):
		ctl_enabled.set_pressed_no_signal(value)
	get:
		return ctl_enabled.button_pressed
var mode: SnapMode:
	set(value):
		ctl_relative.set_pressed_no_signal(value == SnapMode.RELATIVE)
	get:
		return SnapMode.RELATIVE if ctl_relative.button_pressed else SnapMode.ABSOLUTE
var space: SnapSpace:
	set(value):
		ctl_space_local.set_pressed_no_signal(value == SnapSpace.LOCAL)
		ctl_space_parent.set_pressed_no_signal(value == SnapSpace.PARENT)
		ctl_space_world.set_pressed_no_signal(value == SnapSpace.WORLD)
	get:
		if ctl_space_local.button_pressed:
			return SnapSpace.LOCAL
		if ctl_space_parent.button_pressed:
			return SnapSpace.PARENT
		if ctl_space_world.button_pressed:
			return SnapSpace.WORLD
		return SnapSpace.LOCAL
var position_step: Vector2:
	set(value):
		if !value.is_equal_approx(position_step):
			_pos_step_x = value.x
			_pos_step_y = value.y
			_dirty_spin_boxes = true
	get:
		var x := _pos_step_x if _dirty_spin_boxes else ctl_pos_step_x.value
		var y := _pos_step_y if _dirty_spin_boxes else ctl_pos_step_y.value
		if pos_step_uniform:
			y = x
		return Vector2(x, y)

var _pos_step_x: float
var _pos_step_y: float
var _dirty_spin_boxes: bool = false
var _changed := {}


func _ready() -> void:
	plugin_active = false


func _process(_delta: float) -> void:
	if !plugin_active:
		return

	if _dirty_spin_boxes:
		_dirty_spin_boxes = false
		ctl_pos_step_x.set_value_no_signal(_pos_step_x)
		ctl_pos_step_y.set_value_no_signal(_pos_step_y)

	if !_changed.is_empty():
		for p in _changed:
			snap_cfg_changed.emit(p, _changed[p])
		_changed.clear()

	# tell people the truth about SpinBoxes
	debug_label_text = "(%s, %s)" % [ ctl_pos_step_x.value, ctl_pos_step_y.value ]


func wake() -> void:
	plugin_active = true


func sleep() -> void:
	plugin_active = false


func _snap_cfg_changed(property: StringName, new_value: Variant) -> void:
	_changed[property] = new_value


func _ctl_connect(ctl: Node, signal_name: String) -> void:
	var fn := Callable(self, "_on_%s_%s" % [ ctl.name, signal_name ])
	if !ctl.is_connected(signal_name, fn):
		ctl.connect(signal_name, fn)


func _on_enabled_toggled(button_pressed: bool) -> void:
	_snap_cfg_changed(&"enabled", button_pressed)


func _on_relative_toggled(button_pressed: bool) -> void:
	_snap_cfg_changed(&"mode", SnapMode.RELATIVE if button_pressed else SnapMode.ABSOLUTE)


func _on_space_local_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_snap_cfg_changed(&"space", SnapSpace.LOCAL)


func _on_space_parent_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_snap_cfg_changed(&"space", SnapSpace.PARENT)


func _on_space_world_toggled(button_pressed: bool) -> void:
	if button_pressed:
		_snap_cfg_changed(&"space", SnapSpace.WORLD)


func _on_pos_step_x_value_changed(_value: float) -> void:
	_snap_cfg_changed(&"position_step", position_step)


func _on_pos_step_y_value_changed(_value: float) -> void:
	_snap_cfg_changed(&"position_step", position_step)
