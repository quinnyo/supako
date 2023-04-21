@tool
extends PanelContainer


signal add_effect_pressed(script_path: String)


const EffectPicker := preload("effect_picker.gd")

#var edited_object: SpkoShape
#var undo_redo = UndoRedo.new()

#@onready var tool_add: Button = %tool_add
#@onready var tool_remove: Button = %tool_remove
#@onready var tool_duplicate: Button = %tool_duplicate

var effect_picker: EffectPicker = EffectPicker.new()


func _init() -> void:
	add_child(effect_picker)
	effect_picker.index_pressed.connect(_on_effect_picker_index_pressed)


func populate_effect_picker(effect_db: SpkoLib.EffectDB) -> void:
	effect_picker.populate(effect_db)


func _on_effect_picker_index_pressed(index: int) -> void:
	var script_path: String = effect_picker.get_item_metadata(index)
	add_effect_pressed.emit(script_path)


func _on_tool_add_pressed() -> void:
	if effect_picker:
		effect_picker.popup(get_global_rect())
