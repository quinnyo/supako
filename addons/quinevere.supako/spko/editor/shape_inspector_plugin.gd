@tool
extends EditorInspectorPlugin


const EffectChainToolbar := preload("shape_effects_inspector/effect_chain_toolbar.gd")
const EffectChainToolbarScn := preload("shape_effects_inspector/effect_chain_toolbar.tscn")
const EffectInstanceEditor := preload("shape_effects_inspector/effect_instance_editor.gd")


class ShapeEditTool:
	var effect_db: SpkoLib.EffectDB
	var edited_object: SpkoShape
	var unre: EditorUndoRedoManager

	func add_effect(script_path: String) -> void:
		var state := edited_object.effects_data.duplicate()
		var restore := state.duplicate()
		var effect := effect_db.load_effect_script(script_path)
		var inst := edited_object.create_effect_instance(effect)
		state.push_back(inst)
		if unre:
			unre.create_action("add effect", UndoRedo.MERGE_DISABLE)
			unre.add_do_property(edited_object, &"effects_data", state)
			unre.add_undo_property(edited_object, &"effects_data", restore)
			unre.commit_action()


var plugin: EditorPlugin
var effect_db := SpkoLib.EffectDB.new()
var shape_edit_tool := ShapeEditTool.new()


func _can_handle(object: Object) -> bool:
	if object is SpkoShape:
		if !is_instance_valid(plugin):
			print("shape_inspector_plugin.gd: not initialised correctly, plugin not set.")
			return false
		return true
	return false


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var shape := object as SpkoShape
	if shape:
		var efct_match := shape.parse_efct_property(name)
		if efct_match:
			if efct_match.property == SpkoShape.EfctProperty.MODULE:
				if efct_match.index == 0:
					_add_effect_chain_toolbar(shape)

				var properties := PackedStringArray([
					"effects_data",
					shape.get_efct_property_name(efct_match.index, SpkoShape.EfctProperty.MODULE),
					shape.get_efct_property_name(efct_match.index, SpkoShape.EfctProperty.ENABLED),
					shape.get_efct_property_name(efct_match.index, SpkoShape.EfctProperty.NAME),
				])
				var editor := EffectInstanceEditor.new()
				editor.efct_id = shape.efct_get_id(efct_match.index)
				add_property_editor_for_multiple_properties("Effect %d" % [ efct_match.index ], properties, editor)
			else:
				# Hide builtin editors for properties other than effect module
				return true
		elif name == "Effects_end":
			_add_effect_chain_toolbar(shape)
			return true

	return false


func _add_effect_chain_toolbar(shape: SpkoShape) -> void:
	if !is_instance_valid(effect_db):
		effect_db = SpkoLib.EffectDB.new()
	effect_db.refresh()

	shape_edit_tool.unre = plugin.get_undo_redo()
	shape_edit_tool.effect_db = effect_db
	shape_edit_tool.edited_object = shape

	var toolbar_widget := EffectChainToolbarScn.instantiate()
	var toolbar: EffectChainToolbar = toolbar_widget
	toolbar.populate_effect_picker(effect_db)
	toolbar.add_effect_pressed.connect(shape_edit_tool.add_effect)
	add_custom_control(toolbar_widget)
