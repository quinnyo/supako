@tool
extends RefCounted


class HandleState:
	var origin: Vector2

	func _init(p_origin: Vector2) -> void:
		self.origin = p_origin


	func cmp_eq(other: HandleState) -> bool:
		return other && origin.is_equal_approx(other.origin)


	func xformed_by(xf: Transform2D) -> HandleState:
		return with_origin(xf * origin)


	func with_origin(p_origin: Vector2) -> HandleState:
		var inst := clone()
		inst.origin = p_origin
		return inst


	func clone() -> HandleState:
		var inst := HandleState.new(origin)
		return inst


class HandleBox:
	var id: int
	var hidden: bool = false
	var label_fmt: String
	var state: HandleState


class Handles:
	var _handles := {}


	func add_handle(id: int, origin: Vector2) -> void:
		var box := HandleBox.new()
		box.id = id
		box.state = HandleState.new(origin)
		_add_handle_boxed(box)


	func get_handle_ids() -> Array[int]:
		return Array(_handles.keys(), TYPE_INT, "", null)


	func has(handle: int) -> bool:
		return _handles.get(handle) is HandleBox


	func clear() -> void:
		_handles.clear()


	func get_handle_state(handle: int) -> HandleState:
		return _get_handle(handle).state


	func set_handle_state(handle: int, state: HandleState) -> void:
		_get_handle(handle).state = state


	func handle_set_label(handle: int, fmt: String) -> void:
		_get_handle(handle).label_fmt = fmt


	func handle_get_label(handle: int) -> String:
		return _get_handle(handle).label_fmt


	func handle_set_hidden(handle: int, hidden: bool) -> void:
		_get_handle(handle).hidden = hidden


	func handle_get_hidden(handle: int) -> bool:
		return _get_handle(handle).hidden


	func _get_handle(handle: int) -> HandleBox:
		return _handles[handle]


	func _add_handle_boxed(box: HandleBox) -> void:
		_handles[box.id] = box


## A (pointer-driven) modal gizmo interaction...
class Interaction:
	enum EndState { NONE, ACCEPT, CANCEL }
	var _activated: bool
	var _end_state: EndState = EndState.NONE


	func start(gizmo: Gizmo) -> void:
		if is_ended():
			print("ERROR: ", "Trying to start an Interaction that's already ended.")
		elif is_started():
			print("ERROR: ", "Trying to start an Interaction that's already started.")
		else:
			_activated = _activate(gizmo)


	## Request to end the interaction. `accept = false` to abort/cancel
	## NOTE: END != APPLY. `apply` will be called after `end` if `is_accepted()` returns true...
	func end(accept: bool) -> void:
		if is_ended():
			print("ERROR: ", "Trying to end an Interaction that's already ended.")
		else:
			_end_state = _end(accept)


	func update(gizmo: Gizmo) -> void:
		_update(gizmo)


	## Apply changes to/via gizmo...
	func apply(gizmo: Gizmo) -> void:
		_apply(gizmo)


	func draw(gizmo: Gizmo, ci: RID) -> void:
		_draw(gizmo, ci)


	func is_started() -> bool:
		return _activated


	func is_ended() -> bool:
		return _end_state != EndState.NONE


	func is_active() -> bool:
		return is_started() && !is_ended()


	func is_accepted() -> bool:
		return _end_state == EndState.ACCEPT


	func is_cancelled() -> bool:
		return _end_state == EndState.CANCEL


	@warning_ignore("unused_parameter")
	func get_handle_highlight(handle: int) -> int:
		return 0


	## Called when starting the interaction. Returns true if OK to activate.
	## derived class must impl this
	@warning_ignore("unused_parameter")
	func _activate(gizmo: Gizmo) -> bool:
		return true


	## override this.
	## Return new end state...
	func _end(accept: bool) -> EndState:
		return EndState.ACCEPT if accept else EndState.CANCEL


	@warning_ignore("unused_parameter")
	func _update(gizmo: Gizmo) -> void:
		pass


	@warning_ignore("unused_parameter")
	func _apply(gizmo: Gizmo) -> void:
		pass


	@warning_ignore("unused_parameter")
	func _draw(gizmo: Gizmo, ci: RID) -> void:
		pass


## Perform a selection operation with handles that intersect some envelope...
class SelectInteraction extends Interaction:
	enum Operation {
		REPLACE,
		INCLUDE,
		EXCLUDE,
		INVERT,
	}

	# Handle parts considered
	enum TargetPart {
		## Target handle's origin only
		ORIGIN,
		## envelope(target) == true if there is none of target shape outside
		ALL,
		## Target any part of handle -- any intersection/overlap
		ANY,
	}

	var operation: Operation = Operation.REPLACE

	var _pos_from: Vector2
	var _pos_to: Vector2
	var _box: Rect2
	var _detected: Array[int]


	func get_handle_highlight(handle: int) -> int:
		if _detected.has(handle):
			return 1
		else:
			return 0


	func _activate(gizmo: Gizmo) -> bool:
		_pos_from = gizmo.get_pointer_position()
		_pos_to = _pos_from
		return true


	func _update(gizmo: Gizmo) -> void:
		_pos_to = gizmo.get_pointer_position()
		_box = Rect2(_pos_from, _pos_to - _pos_from).abs()
		_detected.clear()
		for handle in gizmo.get_handle_ids():
			if gizmo.handle_intersects_rect(handle, _box):
				_detected.push_back(handle)


	func _apply(gizmo: Gizmo) -> void:
		var sel := gizmo.get_selection()
		match operation:
			Operation.REPLACE:
				sel.assign(_detected)
			Operation.INCLUDE:
				sel.add_array(_detected)
			Operation.EXCLUDE:
				sel.remove_array(_detected)
			Operation.INVERT:
				sel.invert_array(_detected)


	func _draw(_gizmo: Gizmo, ci: RID) -> void:
		var rsv := RenderingServer
		var color := Color.ORANGE

		# draw selection envelope
		rsv.canvas_item_add_rect(ci, _box, Color(color, 0.2))
		rsv.canvas_item_add_line(ci, _pos_from, _pos_to, color)


## Move (drag) some things
class MoveEdit extends Interaction:
	## Minimum distance the pointer must move before actually moving any handles.
	var threshold_distance: float = 1.0

	var _selection: Array[int]
	var _pos_from: Vector2 # Position of the POINTER when the edit started.
	var _pos_to: Vector2
	var _mutated: Dictionary
	var _drag_threshold_exceeded: bool = false


	func get_handle_highlight(handle: int) -> int:
		return 1 if _selection.has(handle) else 0


	func _activate(gizmo: Gizmo) -> bool:
		assert(!_selection.is_empty(), "Trying to start MoveEdit with no selection.")
		_pos_from = gizmo.get_pointer_position()
		_pos_to = _pos_from
		return !_selection.is_empty()


	func set_selected_handles(sel: Array[int]) -> void:
		_selection = sel


	func _update(gizmo: Gizmo) -> void:
		_pos_to = gizmo.get_pointer_position()
		_mutated.clear()

		var move_delta := _pos_to - _pos_from
		if move_delta.length_squared() >= threshold_distance * threshold_distance:
			_drag_threshold_exceeded = true

		if _drag_threshold_exceeded:
			for handle in _selection:
				var initial := gizmo.get_handle_state(handle)
				var pos := initial.origin + move_delta
				var mut := initial.with_origin(pos)
				_mutated[handle] = mut
				gizmo.set_handle_mutated_state(handle, mut)


	func _draw(gizmo: Gizmo, ci: RID) -> void:
		var rsv := RenderingServer

		for handle in _mutated:
			var initial := gizmo.get_handle_state(handle)
			var mut: HandleState = _mutated[handle]
			rsv.canvas_item_add_line(ci, initial.origin, mut.origin, Color.RED)


class Selection:
	signal changed()

	var _items: Array[int]

	## Return a copy of the selection's items
	func get_items() -> Array[int]:
		return _items.duplicate()

	func has(x: int) -> bool:
		return _items.has(x)

	func size() -> int:
		return _items.size()

	func clear() -> void:
		if _items.size():
			_items.clear()
			changed.emit()

	func add(x: int) -> void:
		_add([x])

	func add_array(arr: Array[int]) -> void:
		_add(arr)

	func remove(x: int) -> void:
		_remove([x])

	func remove_array(arr: Array[int]) -> void:
		_remove(arr)

	func invert(x: int) -> void:
		_invert([x])

	func invert_array(arr: Array[int]) -> void:
		_invert(arr)

	func assign(arr: Array[int]) -> void:
		if _items == arr:
			return
		_items.clear()
		for x in arr:
			if _items.has(x):
				continue
			_items.push_back(x)
		changed.emit()

	func _add(arr: Array[int]) -> void:
		var n := 0
		for x in arr:
			if _items.has(x):
				continue
			_items.push_back(x)
			n += 1
		if n:
			changed.emit()

	func _remove(arr: Array[int]) -> void:
		var n := size()
		_items = _items.filter(func(x:int)->bool: return !arr.has(x))
		if size() != n:
			changed.emit()

	func _invert(arr: Array[int]) -> void:
		if arr.is_empty():
			return
		for x in arr:
			var idx := _items.find(x)
			if idx == -1:
				_items.push_back(x)
			else:
				_items.remove_at(idx)
		changed.emit()


##
## OVERVIEW
##
## *Gizmo* manages a set of *Handles* that can be manipulated to edit an object.
##
## *Interactions* are modal edit operations that manipulate (mutate) handles
##
## *Target* refers to the edited object, but there aren't any concrete requirements to define what
## the target actually is, as Gizmo doesn't interact with it directly.
##
## *Transforms*:
## - *Gizmo Space* is the native space of the gizmo, which is usually the plugin's overlay space.
## - *Target Space* is usually the edited object's local space, but it can be any `Transform2D`.
##   - This transform is used to convert Handles from *Target Space* to *Gizmo Space* (and back).
##   - The target transform must be set from outside the Gizmo (`set_target_transform`)
## - *Handles* are posed in *Target Space*, but rendered and interacted with in *Gizmo Space*.
##   - This allows handles to appear with a consistent size and clickable area on screen
##
## HINT: If your target is a CanvasItem target, a reasonable target transform might be:
##     : `target.get_viewport_transform() * target.get_global_transform_with_canvas()`
##
class Gizmo:
	signal redraw_requested()
	signal interaction_started()
	signal interaction_ended()

	## Emitted after any change to mutated handles state. Signal is fired at most once per `update()`.
	signal handles_mutated()

	const DEFAULT_HANDLE_RADIUS := 8.0
	const DEFAULT_HANDLE_LINE_WIDTH := 2.0
	const DEFAULT_COLOR_FILL := Color(0.918, 0.871, 0.788)
	const DEFAULT_COLOR_OUTLINE := Color(0.110, 0.106, 0.098)
	const DEFAULT_COLOR_ACCENT := Color(0.408, 0.659, 0.894)
	const DEFAULT_COLOR_SELECT := Color(0.894, 0.659, 0.408)
	const DEFAULT_COLOR_MUT := Color(0.969, 0.325, 0.255)


	## Margin added to each handle's shape for mouse picking.
	var handle_pointer_margin: float = 2.0

	var _handles: Handles = Handles.new()
	var _selection: Selection = Selection.new()
	var _interaction: Interaction = null
	var _mutated: Dictionary
	var _mutated_changed: int

	var _target_xf: Transform2D = Transform2D.IDENTITY
	var _pointer_pos: Vector2

	var rsv := RenderingServer


	func xf_handle_from_target(state: HandleState) -> HandleState:
		return state.xformed_by(_target_xf)


	func xf_handle_to_target(state: HandleState) -> HandleState:
		return state.xformed_by(_target_xf.affine_inverse())


	func xf_point_to_target(p: Vector2) -> Vector2:
		return _target_xf.affine_inverse() * p


	func get_handle_ids() -> Array[int]:
		return _handles.get_handle_ids()


	## Set the target transform, which converts *Target/Handle Space* to *Gizmo Space*.
	## With a CanvasItem target, this might be:
	##   `target.get_viewport_transform() * target.get_global_transform_with_canvas()`
	func set_target_transform(target_xf: Transform2D) -> void:
		_target_xf = target_xf


	## Set the pointer position. `pos` is the new position of the pointer in Gizmo/Editor space.
	func set_pointer_position(pos: Vector2) -> void:
		_pointer_pos = pos


	func get_pointer_position() -> Vector2:
		return _pointer_pos


	func get_selection() -> Selection:
		return _selection


	## Return currently selected handles if any are selected.
	## Otherwise, return first handle that is hovered (array with one element).
	func get_selected_or_hovered_handles() -> Array[int]:
		if _selection.size() > 0:
			return _selection.get_items()

		for handle in _handles.get_handle_ids():
			if handle_is_hovered(handle):
				return [ handle ]

		return []


	## Set interaction` as the current interaction & activates/starts it.
	## interaction` must be initialised before passing it here.
	func start_interaction(interaction: Interaction) -> void:
		if _mutated.size():
			print("WARNING: ", "Discarding %d mutated handle states" % _mutated.size())
			_mutated.clear()
		_interaction = interaction
		_interaction.start(self)
		interaction_started.emit()


	func end_interaction(accept: bool) -> void:
		if get_interaction() && get_interaction().is_active():
			get_interaction().end(accept)
			if get_interaction().is_accepted():
				for handle in _mutated.keys():
					var mut: HandleState = _mutated[handle]
					if mut.cmp_eq(_handles.get_handle_state(handle)):
						_mutated.erase(handle)
				get_interaction().apply(self)

			interaction_ended.emit()
			_mutated.clear()


	## Return the current or most recent edit
	func get_interaction() -> Interaction:
		return _interaction


	func has_active_interaction() -> bool:
		return get_interaction() && get_interaction().is_active()


	## Add a new handle. Handle can be referred to by `id`.
	## `origin` is the position of the handle, in Target space.
	func add_handle(id: int, origin: Vector2) -> void:
		_handles.add_handle(id, origin)


	## Set handle position quietly. `origin` is handle position in Target space.
	func handle_set_position(handle: int, origin: Vector2) -> void:
		_handles.get_handle_state(handle).origin = origin


	## Return handle's position in Target space.
	func handle_get_position(handle: int) -> Vector2:
		return _handles.get_handle_state(handle).origin


	func handle_set_hidden(handle: int, hidden: bool) -> void:
		_handles.handle_set_hidden(handle, hidden)


	func handle_get_hidden(handle: int) -> bool:
		return _handles.handle_get_hidden(handle)


	func handle_set_label(handle: int, fmt: String) -> void:
		_handles.handle_set_label(handle, fmt)


	## Return handle in Gizmo coordinates
	func get_handle_state(handle: int) -> HandleState:
		return xf_handle_from_target(_handles.get_handle_state(handle))


	## Set handle state via mutated handles buffer. `state` is in Gizmo coordinates.
	func set_handle_mutated_state(handle: int, state: HandleState) -> void:
		assert(_handles.has(handle) && is_instance_valid(state))
		var constrained := xf_handle_to_target(state)
		_gizmo_constrain_handle(handle, constrained)
		var current: HandleState = _mutated[handle] if _mutated.has(handle) else _handles.get_handle_state(handle)
		if constrained.cmp_eq(current):
			return
		_mutated[handle] = constrained
		_mutated_changed += 1


	func get_mutated_handles() -> Dictionary:
		return _mutated.duplicate()


	func clear_mutated_handles() -> void:
		_mutated.clear()
		_mutated_changed += 1


	func merge_mutated_handles() -> void:
		for handle in _mutated:
			_handles.set_handle_state(handle, _mutated[handle])
		_mutated.clear()
		_mutated_changed += 1


	## Return true if handle's shape contains `point`.
	## `point` is in gizmo coordinate space.
	func handle_has_point(handle: int, point: Vector2, margin: float = 0.0) -> bool:
		if handle_get_hidden(handle):
			return false
		return _handle_sd_point(handle, point) - margin <= 0.0


	## Handle-Rect collision test. Returns true if the handle is touching or inside `rect`.
	func handle_intersects_rect(handle: int, rect: Rect2) -> bool:
		if handle_get_hidden(handle):
			return false
		var state := get_handle_state(handle)
		return rect.grow(DEFAULT_HANDLE_RADIUS).has_point(state.origin)


	func handle_is_hovered(handle: int) -> bool:
		return handle_has_point(handle, _pointer_pos, handle_pointer_margin)


	func clear_handles() -> void:
		_handles.clear()


	func build() -> void:
		_gizmo_build()


	func update() -> void:
		var mutated_a := _mutated_changed
		_gizmo_update()
		if get_interaction() && get_interaction().is_active():
			get_interaction().update(self)
		if mutated_a != _mutated_changed:
			handles_mutated.emit()


	func draw(ci: RID) -> void:
		_gizmo_draw(ci)
		if get_interaction() && get_interaction().is_active():
			get_interaction().draw(self, ci)


	func request_redraw() -> void:
		redraw_requested.emit()


	## Return shortest signed distance between handle & `point`. `point` is in gizmo coordinate space.
	## This function & the returned value does not take handle_pointer_margin into account.
	func _handle_sd_point(handle: int, point: Vector2) -> float:
		var state := get_handle_state(handle)
		return point.distance_to(state.origin) - DEFAULT_HANDLE_RADIUS


	func _gizmo_build() -> void:
		return


	func _gizmo_update() -> void:
		return


	## Override to apply constraints to edited handles.
	## `mutated` is the edited handle in target-space.
	@warning_ignore("unused_parameter")
	func _gizmo_constrain_handle(handle: int, mutated: HandleState) -> void:
		return


	func _gizmo_draw_handle(ci: RID, handle: int) -> void:
		var line_width := DEFAULT_HANDLE_LINE_WIDTH
		var state := get_handle_state(handle)
		var fill_color := DEFAULT_COLOR_SELECT if get_selection().has(handle) else DEFAULT_COLOR_FILL
		_draw_handle_shape(ci, state.origin, DEFAULT_HANDLE_RADIUS, fill_color, line_width * 1.5, DEFAULT_COLOR_OUTLINE)

		if handle_is_hovered(handle):
			_draw_handle_shape_outline(ci, state.origin, DEFAULT_HANDLE_RADIUS + line_width * 3.0, DEFAULT_COLOR_ACCENT, line_width)
			var text := _handles.handle_get_label(handle)
			if !text.is_empty():
				_draw_handle_tooltip(ci, state.origin, DEFAULT_HANDLE_RADIUS + line_width * 3.0, text)

		if has_active_interaction():
			var highlight := get_interaction().get_handle_highlight(handle)
			if highlight:
				var hlcol := DEFAULT_COLOR_SELECT
				_draw_handle_shape_outline(ci, state.origin, DEFAULT_HANDLE_RADIUS + line_width * 4.0, hlcol, line_width)

		if _mutated.has(handle):
			var mutstate := xf_handle_from_target(_mutated[handle])
			_draw_handle_shape(ci, mutstate.origin, DEFAULT_HANDLE_RADIUS, Color(DEFAULT_COLOR_MUT, 0.25), 2.0, DEFAULT_COLOR_MUT.darkened(0.5))


	func _gizmo_draw(ci: RID) -> void:
		for handle in _handles.get_handle_ids():
			if handle_get_hidden(handle):
				continue
			_gizmo_draw_handle(ci, handle)


	func _draw_handle_shape(ci: RID, origin: Vector2, radius: float, color: Color, outline_width: float = 0.0, outline_color: Color = Color.BLACK) -> void:
		var scale := Vector2.ONE * radius
		var shape := PackedVector2Array([ Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT ])
		if outline_width > 0.0:
			rsv.canvas_item_add_polygon(ci, Transform2D(0.0, origin).scaled_local(scale + Vector2.ONE * outline_width) * shape, [outline_color])
		var xf := Transform2D(0.0, origin).scaled_local(scale)
		rsv.canvas_item_add_polygon(ci, xf * shape, [color])


	func _draw_handle_shape_outline(ci: RID, origin: Vector2, radius: float, color: Color, line_width: float = DEFAULT_HANDLE_LINE_WIDTH) -> void:
		var scale := Vector2.ONE * radius
		var shape := PackedVector2Array([ Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP ])
		var scale_offset := (Vector2.ONE * line_width / 2.0) if line_width > 0.0 else Vector2.ZERO
		var xf := Transform2D(0.0, origin).scaled_local(scale + scale_offset)
		rsv.canvas_item_add_polyline(ci, xf * shape, [color], line_width)


	func _draw_handle_tooltip(ci: RID, handle_origin: Vector2, handle_radius: float, text: String) -> void:
		var font := ThemeDB.fallback_font
		var text_color := Color.WHITE
		var outline_color := Color.BLACK
		var font_size := 13
		font.draw_string_outline(ci, handle_origin + Vector2(-1, -1) * handle_radius, text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, 3, outline_color)
		font.draw_string(ci, handle_origin + Vector2(-1, -1) * handle_radius, text, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, text_color)
