extends EditorInspectorPlugin


const SurfaceSelectEditor := preload("surface_select_editor.gd")


var surface_select_editor: SurfaceSelectEditor


func _can_handle(object: Object) -> bool:
	if object is SpkoSurfaceSelect:
		return true
	return false


func _parse_begin(object: Object) -> void:
	if object is SpkoSurfaceSelect:
		var target := object as SpkoSurfaceSelect
		var properties := PackedStringArray()
		for i in range(target.angle_range_count()):
			properties.push_back(target.get_angle_range_start_property_name(i))
			properties.push_back(target.get_angle_range_end_property_name(i))
		surface_select_editor = SurfaceSelectEditor.new()
		add_property_editor_for_multiple_properties("Match Surface Normal (Angle Ranges)", properties, surface_select_editor)


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if object is SpkoSurfaceSelect && name == "angles" && surface_select_editor:
		return true # hide default editor
	return false

pass
