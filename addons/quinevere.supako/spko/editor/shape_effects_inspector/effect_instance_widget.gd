@tool
extends PanelContainer


#signal collapse_toggled(new_value: bool)

signal effect_name_changed(new_value: String)
signal effect_enabled_toggled(new_value: bool)
signal effect_move_pressed(dir: int)
signal effect_delete_pressed()


@export var effect_name: String = "EffectInstance":
	set(value):
		effect_name = value
		_controls_dirty = true
@export var effect_type: String = "AnEffect":
	set(value):
		effect_type = value
		_controls_dirty = true
@export var effect_icon: Texture2D:
	set(value):
		effect_icon = value
		_controls_dirty = true
@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_controls_dirty = true
@export var effect_index: int = 0:
	set(value):
		effect_index = value
		_controls_dirty = true
@export var move_up_disabled: bool = false:
	set(value):
		move_up_disabled = value
		_controls_dirty = true
@export var move_down_disabled: bool = false:
	set(value):
		move_down_disabled = value
		_controls_dirty = true
@export var effect_delete_disabled: bool = false:
	set(value):
		effect_delete_disabled = value
		_controls_dirty = true


@onready var widget_name: LineEdit = %widget_name
@onready var widget_type: Label = %widget_type
@onready var widget_index: Label = %widget_index
@onready var widget_icon: TextureRect = %widget_icon
@onready var widget_enabled: CheckBox = %widget_enabled
@onready var widget_up: Button = %widget_up
@onready var widget_down: Button = %widget_down
@onready var widget_delete: Button = %widget_delete


var _controls_dirty := false
var _has_controls := false


func _ready() -> void:
	var controls := [ widget_name, widget_icon, widget_index, widget_enabled, widget_up, widget_down, widget_delete ]
	_has_controls = controls.all(func(w: Control): return is_instance_valid(w))

	_refresh_controls()


func _process(_delta: float) -> void:
	if _controls_dirty:
		_refresh_controls()


func force_refresh() -> void:
	_refresh_controls()


func _refresh_controls() -> void:
	if !_has_controls:
		return

	var tip_lines: Array[String] = []
	if !effect_name.is_empty():
		tip_lines.push_back(effect_name)
	tip_lines.push_back("Type: %s" % [ effect_type ])

	widget_name.text = effect_name
	widget_name.tooltip_text = "\n".join(tip_lines)
	widget_type.text = "(%s)" % [ effect_type ]
	widget_index.text = "#%d" % [ effect_index ]
	widget_icon.texture = effect_icon
	widget_enabled.button_pressed = effect_enabled

	widget_up.disabled = move_up_disabled
	widget_down.disabled = move_down_disabled
	widget_delete.disabled = effect_delete_disabled

	_controls_dirty = false


func _on_widget_name_text_submitted(new_text: String) -> void:
	self.effect_name = new_text
	effect_name_changed.emit(effect_name)


func _on_widget_name_focus_exited() -> void:
	if widget_name.text != effect_name:
		self.effect_name = widget_name.text
		effect_name_changed.emit(effect_name)


func _on_widget_name_gui_input(event: InputEvent) -> void:
	if widget_name.has_focus() && event is InputEventKey:
		var kev := event as InputEventKey
		if !kev.pressed && kev.keycode == KEY_ESCAPE:
			widget_name.text = effect_name
			widget_name.release_focus()


func _on_widget_enabled_toggled(button_pressed: bool) -> void:
	effect_enabled = button_pressed
	effect_enabled_toggled.emit(effect_enabled)


func _on_widget_up_pressed() -> void:
	effect_move_pressed.emit(-1)


func _on_widget_down_pressed() -> void:
	effect_move_pressed.emit(1)


func _on_widget_delete_pressed() -> void:
	effect_delete_pressed.emit()
