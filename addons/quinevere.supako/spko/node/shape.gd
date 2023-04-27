@tool
class_name SpkoShape extends Node2D

## Emitted when the shape/brush is (re)built
signal updated()


## The boolean merge operators. Different ways to combine/merge two shapes.
enum MergeOp {
	## `C = A` -- No-op: result will not include B in any way.
	IGNORE,
	## `C = A .. B` -- Result will be all of A with all of B appended.
	APPEND,
	## `C = A | B` -- Result will include A and B,
	UNION,
	## `C = A & B` -- Result will include areas common to both A and B.
	INTERSECT,
	## `C = A & !B` -- Keep A where B is not.
	SUBTRACT,
}


enum EfctProperty { MODULE, ENABLED, NAME, INVALID }


class EfctPropertyMatch:
	var index: int
	var property: EfctProperty
	## If true, an effect instance actually exists at `index`
	var exists: bool
	func _init(p_index: int, p_property: EfctProperty, p_exists: bool) -> void:
		index = p_index
		property = p_property
		exists = p_exists


class EffectContext extends SpkoEffect.CallbackContext:
	var _host: SpkoShape
	var _index: int
	var _canvas_item: RID

	func _notification(what: int) -> void:
		match what:
			NOTIFICATION_PREDELETE:
				if _canvas_item != RID():
					RenderingServer.free_rid(_canvas_item)
					_canvas_item = RID()

	func get_cache() -> Dictionary:
		return _host._get_effect_cache(_index)

	func get_host() -> SpkoShape:
		return _host

	func get_brush() -> SpkoBrush:
		return get_host()._get_brush()

	func is_visible() -> bool:
		return get_host().efct_get_enabled(_index)

	func cache_get(key: StringName, default: Variant = null) -> Variant:
		return get_cache().get(key, default)

	func cache_set(key: StringName, value: Variant) -> void:
		get_cache()[key] = value

	func cache_erase(key: StringName) -> bool:
		return get_cache().erase(key)

	func cache_clear() -> void:
		get_cache().clear()

	func cache_has(key: StringName) -> bool:
		return get_cache().has(key)

	func request_update() -> void:
		_host.request_effects_update()

	func get_canvas_item() -> RID:
		if _canvas_item == RID():
			_canvas_item = RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(_canvas_item, get_host().get_canvas_item())
		RenderingServer.canvas_item_set_draw_index(_canvas_item, _index)
		return _canvas_item


	func effect_stop() -> void:
		var effect := _host.efct_get_module(_index)
		if effect:
			effect._effect_stop(self)
		if _canvas_item:
			RenderingServer.free_rid(_canvas_item)
			_canvas_item = RID()
		cache_clear()


	func effect_build(brush: SpkoBrush) -> void:
		var effect := _host.efct_get_module(_index)
		if effect:
			effect._effect_build(self, brush)


	func effect_update() -> void:
		var effect := _host.efct_get_module(_index)
		if effect:
			effect._effect_update(self)


## How this shape should be merged with its parent.
@export var merge_op: MergeOp = MergeOp.IGNORE:
	set(value):
		merge_op = value
		update_configuration_warnings()
		mark_dirty()


## Effects & configuration. A set of effects applied to this shape.
## Each element is a dictionary with the following keys:
## `"module": SpkoEffect, # the (configured) effect itself, an SpkoEffect Resource`
## `"enabled": bool,`
## `"id": int, # unique ID assigned by the host shape`
var effects_data: Array[Dictionary]:
	set(value):
		for i in range(get_effects_count()):
			_detach_effect(i)

		effects_data = value

		for i in range(get_effects_count()):
			_attach_effect(i)

		notify_property_list_changed()
		mark_dirty()


## Effect Instance runtime data (non-persistent) storage.
var effects_state: Dictionary

## Effect Instance
var effects_cache: Dictionary


## Element ID thing that doesn't really work -- is exported for storage but is not visible in editor
var _elemid: int = -1

var _parent_shape: SpkoShape
var _brush: SpkoBrush
var _rebuild: bool
var _is_update_effects_queued: bool = false
var _merge_hole_error: bool = false
var _debug_ci: RID


func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = [
		{
			"name": "_elemid",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_NO_EDITOR,
		},
		{
			"name": "effects_data",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_STORAGE,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%s:" % [ TYPE_DICTIONARY ],
		},
	]

	# Effects group continues for the rest (no group prefix)
	properties.push_back({
		"name": "Effects",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})

	# The properties of each effect instance is exported with its index number in the name.
	for i in range(get_effects_count()):
		properties.push_back({
			"name": get_efct_property_name(i, EfctProperty.MODULE),
			"type": TYPE_OBJECT,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "SpkoEffect",
		})
		properties.push_back({
			"name": get_efct_property_name(i, EfctProperty.ENABLED),
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR,
		})
		properties.push_back({
			"name": get_efct_property_name(i, EfctProperty.NAME),
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR,
		})

	properties.push_back({
		"name": "Effects_end",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_INTERNAL | PROPERTY_USAGE_READ_ONLY,
	})

	return properties


func _get(property: StringName) -> Variant:
	var efct_match := parse_efct_property(property)
	if efct_match && efct_match.exists:
		return efct_get(efct_match.index, efct_match.property)
	return null


func _set(property: StringName, value) -> bool:
	var efct_match := parse_efct_property(property)
	if efct_match && efct_match.exists:
		efct_set(efct_match.index, efct_match.property, value)
		return true
	return false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			_rebuild = true
			set_notify_local_transform(true)
			set_process(true)
		NOTIFICATION_EXIT_TREE:
			for i in range(get_effects_count()):
				_detach_effect(i)
			if _debug_ci:
				RenderingServer.free_rid(_debug_ci)
				_debug_ci = RID()
		NOTIFICATION_PROCESS:
			if _rebuild:
				_update_shape()
		NOTIFICATION_PARENTED:
			_parent_shape = get_parent() as SpkoShape
			mark_dirty()
		NOTIFICATION_UNPARENTED:
			if _parent_shape:
				_parent_shape.mark_dirty()
				_parent_shape = null
			mark_dirty(true)
		NOTIFICATION_MOVED_IN_PARENT:
			mark_dirty()
		NOTIFICATION_VISIBILITY_CHANGED:
			mark_dirty()
		NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			if !is_root_shape():
				get_parent_shape().mark_dirty()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if merge_op in [ MergeOp.UNION, MergeOp.INTERSECT, MergeOp.SUBTRACT ]:
		warnings.push_back("MergeOp.%s is not supported for all input shapes. Merging this shape may result in a hole, which is not supported." % [ MergeOp.keys()[merge_op] ])
	return warnings


func get_parent_shape() -> SpkoShape:
	if Engine.is_editor_hint():
		_parent_shape = get_parent() as SpkoShape
	return _parent_shape


func is_root_shape() -> bool:
	return _parent_shape == null


func get_element_id() -> int:
	if _elemid == -1:
		_elemid = randi()
	return _elemid


func mark_dirty(parent_changed: bool = false) -> void:
	if (parent_changed || is_root_shape()) && !_rebuild:
		call_deferred("_update_shape")

	if !is_root_shape():
		get_parent_shape().mark_dirty()
	elif !_rebuild:
		call_deferred("_update_shape")

	_rebuild = true


func request_effects_update() -> void:
	if !_is_update_effects_queued:
		_is_update_effects_queued = true
		call_deferred("_update_effects")


func get_effects_count() -> int:
	return effects_data.size()


func efct_get_module(index: int) -> SpkoEffect:
	return efct_get(index, EfctProperty.MODULE)


func efct_set_module(index: int, module: SpkoEffect) -> void:
	var efct := _get_effect_data(index)
	if efct.is_empty():
		return

	_detach_effect(index)
	efct[efct_property_to_string(EfctProperty.MODULE)] = module
	_attach_effect(index)

	notify_property_list_changed()
	mark_dirty()


## Return true if effect instance is enabled
func efct_get_enabled(index: int) -> bool:
	return efct_get(index, EfctProperty.ENABLED)


func efct_set_enabled(index: int, enabled: bool) -> void:
	var efct := _get_effect_data(index)
	if efct.is_empty():
		return

	efct[efct_property_to_string(EfctProperty.ENABLED)] = enabled

	mark_dirty()


## Return (the name of) the type of effect module at `index` as a string.
func efct_get_type_name(index: int) -> String:
	var module := efct_get(index, EfctProperty.MODULE) as SpkoEffect
	if is_instance_valid(module):
		return module.get_module_name()
	return "None"


## Return the user-set name of the `index` effect instance.
func efct_get_name(index: int) -> String:
	var efct := _get_effect_data(index)
	var key := efct_property_to_string(EfctProperty.NAME)
	var value = efct.get(key)
	if value == null:
		return ""
	elif typeof(value) == TYPE_STRING || typeof(value) == TYPE_STRING_NAME:
		return value
	else:
		return str(value)


func efct_set_name(index: int, efct_name: String) -> void:
	var efct := _get_effect_data(index)
	if efct.is_empty():
		return

	efct[efct_property_to_string(EfctProperty.NAME)] = efct_name
	notify_property_list_changed()
#	efct_set(index, EfctProperty.NAME, efct_name)


func efct_get_id(index: int) -> int:
	if index >= 0 && index < get_effects_count():
		return _get_effect_data(index).get("id")
	return 0


## Search for an effect instance with ID `id` and return its index if found.
## If no match is found, return -1.
func find_efct_by_id(id: int) -> int:
	for i in range(get_effects_count()):
		if efct_get_id(i) == id:
			return i
	return -1


func generate_efct_id() -> int:
	for i in range(100):
		var x := randi()
		if !effects_state.has(x):
			return x
	return 0


func create_effect_instance(effect: SpkoEffect = null, enabled: bool = true) -> Dictionary:
	return {
		"module": effect,
		"enabled": enabled,
		"id": generate_efct_id(),
	}


func efct_property_from_string(s: String) -> EfctProperty:
	match s.to_lower():
		"module": return EfctProperty.MODULE
		"enabled": return EfctProperty.ENABLED
		"name": return EfctProperty.NAME
		_: return EfctProperty.INVALID


func efct_property_to_string(property: EfctProperty) -> String:
	match property:
		EfctProperty.MODULE: return "module"
		EfctProperty.ENABLED: return "enabled"
		EfctProperty.NAME: return "name"
		_: return ""


## Get the exported name of the property for the effect instance at index `index`.
func get_efct_property_name(index: int, property: EfctProperty) -> StringName:
	return _build_indexed_property_name(&"efct", index, efct_property_to_string(property))


## If `property` is an indexed effect instance property, returns a EfctPropertyMatch
## with the effect instance index and property extracted. Otherwise, returns null.
## Note: the result can be a valid match even if the index or property is invalid.
##     The returned object property `exists` will be true if the index and property are valid.
func parse_efct_property(property: StringName) -> EfctPropertyMatch:
	var regexp := RegEx.create_from_string("^efct_(?<index>\\d+)_(?<field>.*)$")
	var rematch := regexp.search(property)
	if rematch:
		var index := rematch.get_string("index").to_int()
		var efct_property := efct_property_from_string(rematch.get_string("field"))
		var exists := index >= 0 && index < get_effects_count() && efct_property != EfctProperty.INVALID
		return EfctPropertyMatch.new(index, efct_property, exists)
	return null


func efct_get(index: int, property: EfctProperty, default: Variant = null) -> Variant:
	var efct := _get_effect_data(index)
	if efct.is_empty():
		return default
	if property == EfctProperty.MODULE:
		var effect := efct.get("effect") as SpkoEffect
		var module := efct.get("module") as SpkoEffect
		if is_instance_valid(effect) && !is_instance_valid(module):
			return effect
	return efct.get(efct_property_to_string(property), default)


func efct_set(index: int, property: EfctProperty, value: Variant) -> void:
	match property:
		EfctProperty.MODULE:
			efct_set_module(index, value)
		EfctProperty.ENABLED:
			efct_set_enabled(index, value)
		_:
			var efct := _get_effect_data(index)
			if efct.is_empty():
				return
			efct[efct_property_to_string(property)] = value


func get_debug_canvas_item() -> RID:
	if _debug_ci == RID():
		_debug_ci = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_debug_ci, get_canvas_item())
	RenderingServer.canvas_item_set_draw_index(_debug_ci, get_child_count(true))
	return _debug_ci


func _get_brush() -> SpkoBrush:
	if _rebuild:
		_brush = null
		var n := _build_brush()

		# boolean merge child shapes...
		for node in get_children():
			var child := node as SpkoShape
			if !child || !child.visible || !child._get_brush() || child.merge_op == MergeOp.IGNORE:
				continue
			if n == null:
				n = child._get_brush()
			else:
				var b := SpkoBrush.new() # transformed copy of child brush
				b.copy_from(child._get_brush(), child.transform)
				var c := SpkoBrush.new()
				_merge_hole_error = false
				_merge(child.merge_op, n, b, c)
				if _merge_hole_error:
					push_warning("%s: Merging %s resulted in a hole, which was discarded. Holes are not currently supported." % [ self, child ])
				n = c

		for i in range(get_effects_count()):
			var context := _get_effect_context(i)
			context.effect_build(n)

		_brush = n
		_rebuild = false
		if Engine.is_editor_hint():
			_debug_draw()

	return _brush


## [virtual] "Self-build" -- Build & return own shape brush.
func _build_brush() -> SpkoBrush:
	return SpkoBrush.new()


func _update_shape() -> void:
	if !is_root_shape():
		return
	_get_brush()
	_update_effects()
	updated.emit()


func _merge(op: MergeOp, a: SpkoBrush, b: SpkoBrush, out: SpkoBrush) -> void:
	if op == MergeOp.IGNORE || b.get_island_count() == 0:
		out.add_from(a, Transform2D.IDENTITY)
	elif op == MergeOp.APPEND:
		out.add_from(a, Transform2D.IDENTITY)
		out.add_from(b, Transform2D.IDENTITY)
	elif op == MergeOp.UNION && a.get_island_count() == 0:
		out.add_from(b, Transform2D.IDENTITY)
	else:
		for aidx in range(a.get_island_count()):
			var apoints := a.get_island_points(aidx)
			for bidx in range(b.get_island_count()):
				var bpoints := b.get_island_points(bidx)

				var merged: Array[PackedVector2Array]
				match op:
					MergeOp.UNION:
						merged = Geometry2D.merge_polygons(apoints, bpoints)
					MergeOp.INTERSECT:
						merged = Geometry2D.intersect_polygons(apoints, bpoints)
					MergeOp.SUBTRACT:
						merged = Geometry2D.clip_polygons(apoints, bpoints)
					_:
						push_error("unexpected MergeOp (%s)" % [ op ])
						return

				for gon in merged:
					var is_hole := Geometry2D.is_polygon_clockwise(gon)
					if is_hole:
						_merge_hole_error = true
						continue
					out.add_island_from_points(gon)


func _get_effect_context(index: int) -> EffectContext:
	var inst := _get_effect_data(index)
	if inst.is_empty():
		return null
	var id: int = inst["id"]
	var ctx: EffectContext = effects_state.get(id)
	if ctx == null:
		ctx = EffectContext.new()
		effects_state[id] = ctx
	ctx._host = self
	ctx._index = index
	return ctx


func _get_effect_cache(index: int) -> Dictionary:
	var inst := _get_effect_data(index)
	if inst.is_empty():
		return {}
	var id: int = inst["id"]
	if !effects_cache.has(id):
		var cache := {}
		effects_cache[id] = cache
		return cache
	return effects_cache.get(id)


func _get_effect_data(index: int) -> Dictionary:
	if index >= 0 && index < get_effects_count():
		var data = effects_data[index]
		if data == null || typeof(data) != TYPE_DICTIONARY:
			data = create_effect_instance()
		if data.get("id", 0) == 0:
			data["id"] = generate_efct_id()
		return data
	return {}


func _update_effects() -> void:
	if _is_update_effects_queued:
		_is_update_effects_queued = false

		for i in range(get_effects_count()):
			var context := _get_effect_context(i)
			context.effect_update()


func _attach_effect(index: int) -> void:
	var e := efct_get_module(index)
	if e && !e.changed.is_connected(mark_dirty):
		e.changed.connect(mark_dirty)


func _detach_effect(index: int) -> void:
	var e := efct_get_module(index)
	if is_instance_valid(e) && e.changed.is_connected(mark_dirty):
		e.changed.disconnect(mark_dirty)

	var context := _get_effect_context(index)
	if context:
		context.effect_stop()


func _build_indexed_property_name(base: StringName, index: int, field: StringName) -> StringName:
	return "%s_%d_%s" % [ base, index, field ]


func _get_debug_color() -> Color:
	var hue := float(get_element_id() % 65535) / 65535.0
	return Color.from_hsv(hue, 0.55, 0.8)


func _debug_draw() -> void:
	if !is_visible_in_tree():
		return
	var ci := get_debug_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	var brush := _get_brush()
	if brush:
		brush.iter_islands(_debug_draw_island.bind(ci))


func _debug_draw_island(ia: SpkoBrush.IslandAccess, ci: RID) -> void:
	if ia.get_vertex_count() >= 2:
		var base_color := _get_debug_color()
		var j := ia.get_vertex_count() - 1
		for i in range(ia.get_vertex_count()):
			var p := ia.get_vertex_position(i)
			var q := ia.get_vertex_position(j)
			RenderingServer.canvas_item_add_line(ci, q, p, base_color)

			j = i # j follows i
