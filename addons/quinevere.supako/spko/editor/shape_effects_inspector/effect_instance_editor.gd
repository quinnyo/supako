@tool
extends EditorProperty


const EffectInstanceWidget := preload("effect_instance_widget.gd")
const EffectInstanceWidgetScn := preload("effect_instance_widget.tscn")

const PROP_EFFECTS_DATA := &"effects_data"


var efct_id: int
var current_index: int
var current_module: SpkoEffect
var current_enabled: bool
var current_name: String
var current_effects_data: Array[Dictionary]
var current_is_first: bool
var current_is_last: bool

var efct_widget: EffectInstanceWidget

# A guard against internal changes when the property is updated.
var updating = false


func _init():
	var widget := EffectInstanceWidgetScn.instantiate()
	efct_widget = widget
	efct_widget.effect_name_changed.connect(_on_widget_effect_name_changed)
	efct_widget.effect_enabled_toggled.connect(_on_widget_effect_enabled_toggled)
	efct_widget.effect_move_pressed.connect(_on_widget_effect_move_pressed)
	efct_widget.effect_delete_pressed.connect(_on_widget_effect_delete_pressed)
	add_child(efct_widget)
	add_focusable(efct_widget)
	set_bottom_editor(efct_widget)


func _update_property():
	var efct_index := get_edited_shape().find_efct_by_id(efct_id)
	var new_module := get_edited_shape().efct_get_module(efct_index)
	var new_enabled := get_edited_shape().efct_get_enabled(efct_index)
	var new_name := get_edited_shape().efct_get_name(efct_index)
	var new_effects_data := get_edited_shape().effects_data

	var new_is_first := efct_index == 0
	var new_is_last := efct_index == get_edited_shape().get_effects_count() - 1

	var props_changed := new_module != current_module || new_enabled != current_enabled || new_name != current_name || new_effects_data != current_effects_data
	var meta_changed := new_is_first != current_is_first || new_is_last != current_is_last
	var need_update := props_changed || efct_index != current_index || meta_changed
	if !need_update:
		return

	# Update the control with the new value.
	updating = true
	current_index = efct_index
	current_module = new_module
	current_enabled = new_enabled
	current_name = new_name
	current_effects_data = new_effects_data.duplicate()
	current_is_first = new_is_first
	current_is_last = new_is_last
	_refresh()
	updating = false


func get_edited_shape() -> SpkoShape:
	return get_edited_object() as SpkoShape


func _refresh() -> void:
#	print("#%d <%s:%s> widget refresh" % [ current_index, current_name, get_edited_shape().efct_get_type_name(current_index) ])
	if current_is_first:
		pass

	efct_widget.effect_index = current_index
	efct_widget.effect_name = current_name
	efct_widget.effect_enabled = current_enabled
	efct_widget.effect_type = get_edited_shape().efct_get_type_name(current_index)
	efct_widget.move_up_disabled = current_index == 0
	efct_widget.move_down_disabled = current_index >= current_effects_data.size() - 1
	efct_widget.force_refresh()

	if current_is_last:
		pass


func _property_changed(property: SpkoShape.EfctProperty, value: Variant) -> void:
	_refresh()
	var property_name := get_edited_shape().get_efct_property_name(current_index, property)
	emit_changed(property_name, value)


func _on_widget_effect_name_changed(new_value: String) -> void:
	if updating:
		return

	current_name = new_value
	_property_changed(SpkoShape.EfctProperty.NAME, current_name)


func _on_widget_effect_enabled_toggled(new_value: bool) -> void:
	if updating:
		return

	current_enabled = new_value
	_property_changed(SpkoShape.EfctProperty.ENABLED, current_enabled)


func _on_widget_effect_move_pressed(dir: int) -> void:
	if updating:
		return

	var dest := clampi(current_index + dir, 0, current_effects_data.size() - 1)
	if dest == current_index:
		# don't allow moving to current position
		return

	var other := current_effects_data[dest]
	current_effects_data[dest] = current_effects_data[current_index]
	current_effects_data[current_index] = other

	_refresh()
	emit_changed(PROP_EFFECTS_DATA, current_effects_data.duplicate())


func _on_widget_effect_delete_pressed() -> void:
	current_effects_data.remove_at(current_index)

	_refresh()
	emit_changed(PROP_EFFECTS_DATA, current_effects_data.duplicate())

