@tool
extends RefCounted
## SpkoEffect Database

const EFFECT_ICON := preload("../icon/effect.svg")

class ScriptModule:
	var module_name: String:
		get:
			if !module_name.is_empty():
				return module_name
			elif !_const_module_name.is_empty():
				return _const_module_name
			elif !global_class.is_empty():
				return global_class
			else:
				return script_path.get_file()

	var global_class: String
	var script_path: String
	var icon_path: String

	var _const_module_name: String


	func script_exists() -> bool:
		return ResourceLoader.exists(script_path, "Script")


	func icon_exists() -> bool:
		return ResourceLoader.exists(icon_path, "Texture2D")


	func refresh() -> void:
		var script: Script = load(script_path) if script_exists() else null
		if script:
			var constant_map := script.get_script_constant_map()
			_const_module_name = str(constant_map.get("MODULE_NAME", ""))


	static func from_global_class_dict(classinfo: Dictionary) -> ScriptModule:
		var module := ScriptModule.new()
		module.global_class = classinfo["class"]
		module.script_path = classinfo["path"]
		module.icon_path = classinfo["icon"]
		module.refresh()
		return module


var _effects: Array[ScriptModule]

var _by_name: Dictionary
var _by_path: Dictionary
var _maps_dirty: bool


func add_effect_module(module: ScriptModule) -> void:
	_effects.push_back(module)
	_maps_dirty = true


## Return true if `script` extends SpkoEffect (doesn't include SpkoEffect itself)
func is_script_effect(script: Script) -> bool:
	if is_instance_valid(script):
		var base := script.get_base_script()
		while base:
			if base == SpkoEffect:
				return true
			base = base.get_base_script()
	return false


func refresh() -> void:
	_effects.clear()
	_gather_global_classes()
	_update_maps()


func load_effect_script(script_path: String) -> SpkoEffect:
	if ResourceLoader.exists(script_path, "Script"):
		var script: Script = load(script_path)
		if is_instance_valid(script) && script.has_method(&"new"):
			@warning_ignore("unsafe_method_access")
			return script.new()
	return null


func get_effect_count() -> int:
	return _effects.size()


func effect_get_name(module: int) -> String:
	var m := _get_module(module)
	if is_instance_valid(m):
		return m.module_name
	return "ERROR"


func effect_get_script_path(module: int) -> String:
	var m := _get_module(module)
	if is_instance_valid(m):
		return m.script_path
	return "ERROR"


func effect_get_script_class(module: int) -> String:
	var m := _get_module(module)
	if is_instance_valid(m):
		return m.global_class
	return "ERROR"


func effect_load_script(module: int) -> Script:
	var m := _get_module(module)
	if is_instance_valid(m):
		return load(m.script_path)
	return null


func effect_script_exists(module: int) -> bool:
	var m := _get_module(module)
	if is_instance_valid(m):
		return m.script_exists()
	return false


func effect_load_icon(module: int) -> Texture2D:
	var m := _get_module(module)
	if is_instance_valid(m) && m.icon_exists():
		return load(m.icon_path)
	return EFFECT_ICON


func _get_module(module: int) -> ScriptModule:
	if module >= 0 && module < _effects.size():
		return _effects[module]
	return null


func _update_maps() -> void:
	_by_name.clear()
	_by_path.clear()
	for e in _effects:
		if _by_name.has(e.module_name):
			push_warning("EffectsDB: shadowing module name '%s'" % [ e.module_name ])
		_by_name[e.module_name] = e
		if _by_path.has(e.script_path):
			push_warning("EffectsDB: shadowing script path '%s'" % [ e.script_path ])
		_by_path[e.script_path] = e
	_maps_dirty = false


func _gather_global_classes() -> void:
	for classinfo in ProjectSettings.get_global_class_list():
		var script_path: String = classinfo["path"]
		var script: Script = load(script_path)
		if is_script_effect(script):
			add_effect_module(ScriptModule.from_global_class_dict(classinfo))
