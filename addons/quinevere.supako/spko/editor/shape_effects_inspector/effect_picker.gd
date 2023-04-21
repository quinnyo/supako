@tool
extends PopupMenu


func populate(effect_db: SpkoLib.EffectDB) -> void:
	clear()
	for i in range(effect_db.get_effect_count()):
		add_icon_item(effect_db.effect_load_icon(i), effect_db.effect_get_name(i))
		var tooltip := "%s (%s)\n%s" % [ effect_db.effect_get_name(i), effect_db.effect_get_script_class(i), effect_db.effect_get_script_path(i) ]
		set_item_tooltip(-1, tooltip)
		var has_script := effect_db.effect_script_exists(i)
		set_item_disabled(-1, !has_script)
		set_item_metadata(-1, effect_db.effect_get_script_path(i))
