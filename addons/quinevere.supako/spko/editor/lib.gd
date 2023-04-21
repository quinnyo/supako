extends RefCounted


const Gizmo2 := preload("gizmo2.gd")
const Gizmo := Gizmo2.Gizmo
const HandleState := Gizmo2.HandleState
const SelectInteraction := Gizmo2.SelectInteraction
const MoveEdit := Gizmo2.MoveEdit


enum SnapSpace { LOCAL = 0, PARENT = 1, WORLD = 2, }
enum SnapMode { ABSOLUTE = 0, RELATIVE = 1, }


class SnapCfg:
	signal changed()

	var enabled: bool = true:
		set(value):
			if enabled != value:
				enabled = value
				emit_changed()

	var mode: SnapMode = SnapMode.ABSOLUTE:
		set(value):
			if mode != value:
				mode = value
				emit_changed()

	var space: SnapSpace = SnapSpace.WORLD:
		set(value):
			if space != value:
				space = value
				emit_changed()

	var position_step: Vector2 = Vector2.ONE:
		set(value):
			if !position_step.is_equal_approx(value):
				position_step = value
				emit_changed()


	func reset() -> void:
		_load_defaults()
		emit_changed()


	func dump_state() -> Dictionary:
		return {
			"enabled": enabled,
			"mode": mode,
			"space": space,
			"position_step": position_step,
		}


	func load_state(state: Dictionary, merge: bool = false) -> void:
		if !merge:
			_load_defaults()

		if typeof(state.get("enabled")) == TYPE_BOOL:
			self.enabled = state["enabled"]
		if typeof(state.get("mode")) == TYPE_INT:
			self.mode = state["mode"] as SnapMode
		if typeof(state.get("space")) == TYPE_INT:
			self.space = state["space"] as SnapSpace
		if typeof(state.get("position_step")) == TYPE_VECTOR2:
			self.position_step = state["position_step"]

		emit_changed()


	func emit_changed() -> void:
		changed.emit()


	func _load_defaults() -> void:
		self.enabled = true
		self.mode = SnapMode.ABSOLUTE
		self.space = SnapSpace.WORLD
		self.position_step = Vector2.ONE


	func _to_string() -> String:
		return "<SnapCfg %s: %s/%s %s>" % [
			"ON" if enabled else "OFF",
			SnapMode.keys()[mode],
			SnapSpace.keys()[space],
			position_step,
		]


class SpkoPathGizmo extends Gizmo:
	const HANDLE_INSERT := -1

	var target: SpkoPath
	var hide_insert_handle: bool = false
	var snap: SnapCfg

	var _nearest_edge_idx: int
	var _nearest_edge_u: float
	var _nearest_edge_dist: float


	func get_insert_edge() -> int:
		return _nearest_edge_idx


	func is_nearest_edge_hovered() -> bool:
		return _nearest_edge_dist <= DEFAULT_HANDLE_RADIUS + handle_pointer_margin


	func _gizmo_build() -> void:
		clear_handles()
		for i in range(target.get_vertex_count()):
			add_handle(i, target.get_vertex_position(i))
			handle_set_label(i, "[%d]" % [ i ])

		add_handle(HANDLE_INSERT, Vector2())
		handle_set_hidden(HANDLE_INSERT, true)


	func _gizmo_update() -> void:
		_update_hovered_edge(get_pointer_position())

		var other_hovered := false
		for i in range(target.get_vertex_count()):
			if handle_is_hovered(i):
				other_hovered = true

		if hide_insert_handle || has_active_interaction() || other_hovered:
			handle_set_hidden(HANDLE_INSERT, true)
		elif is_nearest_edge_hovered():
			handle_set_hidden(HANDLE_INSERT, false)
			if target.has_next(_nearest_edge_idx):
				var a := target.get_vertex_position(_nearest_edge_idx)
				var b := target.get_vertex_position(target.next(_nearest_edge_idx))
				handle_set_position(HANDLE_INSERT, a.lerp(b, _nearest_edge_u))


	func _gizmo_constrain_handle(handle: int, mutated: HandleState) -> void:
		if !is_instance_valid(snap) || !snap.enabled:
			return

		var snap_xf := Transform2D()
		match snap.space:
			SnapSpace.LOCAL:
				snap_xf = Transform2D.IDENTITY
			SnapSpace.PARENT:
				snap_xf = target.transform
			SnapSpace.WORLD:
				snap_xf = target.global_transform

		match snap.mode:
			SnapMode.ABSOLUTE:
				var p := (snap_xf * mutated.origin).snapped(snap.position_step)
				mutated.origin = snap_xf.affine_inverse() * p
			SnapMode.RELATIVE:
				var from := snap_xf * handle_get_position(handle)
				var to := snap_xf * mutated.origin
				var p := from + (to - from).snapped(snap.position_step)
				mutated.origin = snap_xf.affine_inverse() * p


	## Perform picking on target's edges, in gizmo space.
	func _update_hovered_edge(p: Vector2) -> void:
		var best_distsq := INF
		_nearest_edge_dist = INF
		_nearest_edge_idx = -1
		_nearest_edge_u = 0.0

		if target.get_vertex_count() < 2:
			return

		for i in range(target.get_vertex_count()):
			if !target.has_next(i):
				continue
			var a := get_handle_state(i).origin
			var b := get_handle_state(target.next(i)).origin
			var ab := b - a
			var u := (p - a).dot(ab) / ab.length_squared()
			if u >= 0.0 && u < 1.0:
				var c := a + u * ab
				var distsq := p.distance_squared_to(c)
				if distsq < best_distsq:
					best_distsq = distsq
					_nearest_edge_idx = i
					_nearest_edge_u = u

		if _nearest_edge_idx != -1:
			_nearest_edge_dist = sqrt(best_distsq)


class EditThing:
	var plugin: EditorPlugin
	var target_object: Object

	func get_undo_redo() -> EditorUndoRedoManager:
		return plugin.get_undo_redo() if Engine.is_editor_hint() else null

	func start(p_plugin: EditorPlugin, p_target: Object) -> void:
		plugin = p_plugin
		target_object = p_target
		_edit_thing_start(p_target)

	func clean() -> void:
		_edit_thing_clean()
		target_object = null

	func update() -> void:
		_edit_thing_update()

	func draw(overlay_ci: RID) -> void:
		_edit_thing_draw(overlay_ci)

	func input(event: InputEvent) -> bool:
		return _edit_thing_input(event)

	func reset() -> void:
		_edit_thing_clean()
		_edit_thing_start(target_object)

	func has_target() -> bool:
		return is_instance_valid(target_object)

	@warning_ignore("unused_parameter")
	func _edit_thing_start(p_target: Object) -> void:
		pass

	func _edit_thing_clean() -> void:
		pass

	@warning_ignore("unused_parameter")
	func _edit_thing_update() -> void:
		pass

	@warning_ignore("unused_parameter")
	func _edit_thing_draw(overlay_ci: RID) -> void:
		pass

	@warning_ignore("unused_parameter")
	func _edit_thing_input(event: InputEvent) -> bool:
		return false

	func _get_state() -> Dictionary:
		return {}

	@warning_ignore("unused_parameter")
	func _set_state(state: Dictionary) -> void:
		pass


class SpkoPathEdit extends EditThing:
	var target: SpkoPath
	var giz: SpkoPathGizmo
	var snap: SnapCfg

	# build mode enabled for new/uninitialised paths.
	var build_mode := false
	var _restore_vposition: PackedVector2Array


	func has_target() -> bool:
		return is_instance_valid(target) && target.is_visible_in_tree()


	func _edit_thing_start(p_target: Object) -> void:
		target = p_target as SpkoPath
		if target.get_vertex_count() < 3:
			build_mode = true

		giz = SpkoPathGizmo.new()
		giz.snap = snap
		giz.target = target
		giz.hide_insert_handle = build_mode
		giz.redraw_requested.connect(plugin.update_overlays)
		giz.interaction_ended.connect(_on_interaction_ended)
		giz.handles_mutated.connect(_on_handles_mutated)
		giz.build()

		var target_xf := target.get_viewport_transform() * target.get_global_transform_with_canvas()
		giz.set_target_transform(target_xf)
		giz.update()


	func _edit_thing_clean() -> void:
		giz = null
		target = null
		build_mode = false
		_restore_vposition = PackedVector2Array()


	func _edit_thing_update() -> void:
		if is_instance_valid(giz):
			giz.snap = snap
		var target_xf := target.get_viewport_transform() * target.get_global_transform_with_canvas()
		giz.set_target_transform(target_xf)
		giz.update()


	func _edit_thing_draw(overlay_ci: RID) -> void:
		giz.draw(overlay_ci)


	func _edit_thing_input(event: InputEvent) -> bool:
		if event is InputEventMouseMotion:
			giz.set_pointer_position(event.position)

		var mkev_mouse_button := func (button_index: MouseButton, button_mask: MouseButtonMask) -> InputEventMouseButton:
			var ev := InputEventMouseButton.new()
			ev.button_index = button_index
			ev.button_mask = button_mask
			return ev
		var mkev_keycode := func (keycode: Key) -> InputEventKey:
			var ev := InputEventKey.new()
			ev.keycode = keycode
			return ev
		var confirm := [
			mkev_keycode.call(KEY_ENTER),
			mkev_keycode.call(KEY_KP_ENTER),
		]
		var abort := [
			mkev_mouse_button.call(MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MASK_RIGHT),
			mkev_keycode.call(KEY_ESCAPE),
		]

		var ev_primary := event.is_match(mkev_mouse_button.call(MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MASK_LEFT))
		var ev_secondary := event.is_match(mkev_mouse_button.call(MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MASK_RIGHT))
		var ev_confirm := confirm.any(func(bound_ev): return event.is_match(bound_ev))
		var ev_abort := abort.any(func(bound_ev): return event.is_match(bound_ev))
		var ev_select := event.is_match(mkev_keycode.call(KEY_B))
		var ev_grab := event.is_match(mkev_keycode.call(KEY_G))
		var ev_delete := event.is_match(mkev_keycode.call(KEY_DELETE))

		if event.is_pressed() && !giz.has_active_interaction():
			var has_selection := giz.get_selection().size() > 0

			var is_hovered := false
			var hovered_handle
			for handle in giz.get_selected_or_hovered_handles():
				if giz.handle_is_hovered(handle):
					is_hovered = true
					hovered_handle = handle
					break

			if ev_select:
				giz.start_interaction(SelectInteraction.new())
			elif ev_primary && build_mode:
				_insert(target.get_vertex_count(), giz.xf_point_to_target(giz.get_pointer_position()))
				return true
			elif ev_primary && giz.handle_is_hovered(giz.HANDLE_INSERT):
				if giz.is_nearest_edge_hovered():
					_start_insert_move(giz.get_insert_edge() + 1, giz.handle_get_position(giz.HANDLE_INSERT))
				else:
					_start_insert_move(target.get_vertex_count(), giz.handle_get_position(giz.HANDLE_INSERT))
			elif is_hovered && ev_primary:
				_start_grab_move(giz.get_selected_or_hovered_handles())
			elif ev_grab && has_selection:
				_start_grab_move(giz.get_selection().get_items())
			elif is_hovered && ev_secondary:
				_delete([ hovered_handle ])
				return true
			elif ev_delete && has_selection:
				_delete(giz.get_selection().get_items())
				return true
		elif !event.is_pressed() && giz.has_active_interaction():
			if ev_confirm || ev_primary:
				giz.end_interaction(true)
				return true
			elif ev_abort:
				giz.end_interaction(false)
				return true

		return giz.has_active_interaction()


	func _delete(sel: Array[int]) -> void:
		var restore := target.get_vertex_position_array()

		var vpos := PackedVector2Array() # filter unselected points
		for i in range(target.get_vertex_count()):
			if !sel.has(i):
				vpos.push_back(target.get_vertex_position(i))

		if Engine.is_editor_hint():
			var unre := get_undo_redo()
			unre.create_action("Delete %d vertices" % [ sel.size() ])
			unre.add_do_method(target, "set_vertex_position_array", vpos)
			unre.add_undo_method(target, "set_vertex_position_array", restore)
			unre.commit_action()
		else:
			target.set_vertex_position_array(vpos)

		giz.get_selection().clear()
		giz.build()


	func _insert(idx: int, pos: Vector2) -> void:
		if Engine.is_editor_hint():
			var unre := get_undo_redo()
			unre.create_action("Insert vertex")
			unre.add_do_method(target, "insert_vertex", idx, pos)
			unre.add_undo_method(target, "remove_vertex", idx)
			unre.commit_action()
		else:
			target.insert_vertex(idx, pos)

		giz.build() # rebuild to include new vertex handle


	func _start_insert_move(idx: int, pos: Vector2) -> void:
		giz.get_selection().clear()
		_insert(idx, pos)
		_start_grab_move([ idx ])


	func _start_grab_move(sel: Array[int]) -> void:
		_restore_vposition = target.get_vertex_position_array()
		var move_edit := MoveEdit.new()
		move_edit.set_selected_handles(sel)
		giz.start_interaction(move_edit)


	func _apply_mutated_handles(handles: Dictionary, base: PackedVector2Array) -> PackedVector2Array:
		var mut := base.duplicate()
		for handle in handles:
			mut[handle] = handles[handle].origin
		return mut


	func _on_interaction_ended() -> void:
		if giz.get_interaction() is MoveEdit:
			if giz.get_interaction().is_accepted():
				var mutated := giz.get_mutated_handles()
				giz.merge_mutated_handles()
				var vpos := _apply_mutated_handles(mutated, _restore_vposition)
				if Engine.is_editor_hint():
					var unre := get_undo_redo()
					unre.create_action("Move vertices")
					unre.add_do_method(target, "set_vertex_position_array", vpos)
					unre.add_undo_method(target, "set_vertex_position_array", _restore_vposition.duplicate())
					unre.commit_action()
				else:
					target.set_vertex_position_array(vpos)
			else:
				giz.clear_mutated_handles()
				target.set_vertex_position_array(_restore_vposition)


	func _on_handles_mutated() -> void:
		var vpos := _apply_mutated_handles(giz.get_mutated_handles(), _restore_vposition)
		target.set_vertex_position_array(vpos)
