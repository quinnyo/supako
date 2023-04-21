@tool
@icon("../icon/effect.svg")
class_name SpkoEffect extends Resource
## Base class for Supako Shape Effects/Modules.

### The name of the constant that effects can define to set their 'Effect Type'.
#const MODULE_NAME_CONSTANT_NAME := "MODULE_NAME"


## Provides EffectInstance Context to Effect callback methods.
## There can be many shapes with any number of instances of a given Effect.
## As the Effect is implemented in a shared Resource type, the callback context
## is provided to access Shape & EffectInstance data/state.
class CallbackContext:
	func get_host() -> SpkoShape:
		return null

	## Return the host shape's geometry state / brush.
	func get_brush() -> SpkoBrush:
		return null

	func is_visible() -> bool:
		return true

	@warning_ignore("unused_parameter")
	func cache_get(key: StringName, default: Variant = null) -> Variant:
		return null

	@warning_ignore("unused_parameter")
	func cache_set(key: StringName, value: Variant) -> void:
		return

	@warning_ignore("unused_parameter")
	func cache_erase(key: StringName) -> bool:
		return false

	func cache_clear() -> void:
		return

	@warning_ignore("unused_parameter")
	func cache_has(key: StringName) -> bool:
		return false

	func request_update() -> void:
		return

	## Return the RID of the canvas item allocated for this effect (instance) to draw to.
	## Each EffectInstance has a canvas item automatically created (and freed).
	## The canvas item is a child of the host's canvas item.
	## Effect canvas items will be drawn in the order of the effects in the host.
	func get_canvas_item() -> RID:
		return RID()


## Emitted whenever module properties are written to.
## `requires_rebuild` will be true if the edited parameter will cause geometry output to differ.
signal parameters_changed(requires_rebuild: bool)


## override this method to clean up any allocated resources, free RIDs from Servers, etc.
@warning_ignore("unused_parameter")
func _effect_stop(ctx: CallbackContext) -> void:
	pass


## Make contributions to host shape's geometry. In other words, "apply the effect".
## Called when host shape is being (re)built.
@warning_ignore("unused_parameter")
func _effect_build(ctx: CallbackContext, brush: SpkoBrush) -> void:
	pass


## Produce side-effects, e.g. render canvas items.
## Called when host thinks it's a good idea, usually when effect instance configuration has changed.
## The host's geometry has been built / is up to date.
@warning_ignore("unused_parameter")
func _effect_update(ctx: CallbackContext) -> void:
	pass


func notify_module_changed(requires_rebuild: bool) -> void:
	parameters_changed.emit(requires_rebuild)
	emit_changed()


## Return this effect module's type/name.
## If the derived class hasn't defined a name, the script filename will be returned instead.
func get_module_name() -> StringName:
	var script := get_script() as Script
	var constant_map := script.get_script_constant_map()
	var value: String = str(constant_map.get("MODULE_NAME", ""))
	if value.is_empty():
		return script.resource_path.get_file()
	return value
