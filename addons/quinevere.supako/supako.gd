@tool
extends EditorPlugin

const EditorLib := preload("spko/editor/lib.gd")
const SpkoPathEdit := EditorLib.SpkoPathEdit
const SnapCfg := EditorLib.SnapCfg

const SnapCfgToolbar := preload("spko/editor/snap_cfg_toolbar.gd")

var inspector_plugins: Array[EditorInspectorPlugin] = []
var container_controls: Array[Dictionary] = []

var _edit_thing: SpkoPathEdit
var snap: SnapCfg
var snap_cfg_toolbar: SnapCfgToolbar

var status_label: Label


func _enter_tree() -> void:
	status_label = Label.new()
	status_label.hide()
	var monospace := SystemFont.new()
	monospace.font_names = PackedStringArray([ "monospace" ])
	status_label.label_settings = LabelSettings.new()
	status_label.label_settings.font = monospace
	add_container_control(CONTAINER_CANVAS_EDITOR_BOTTOM, status_label)

	snap = SnapCfg.new()
	snap.changed.connect(_on_snap_cfg_changed)
	_edit_thing = SpkoPathEdit.new()
	_edit_thing.snap = snap

	get_undo_redo().version_changed.connect(_on_undo_redo_version_changed)

	inspector_plugins = [
		instance_inspector_plugin_script("spko/editor/shape_inspector_plugin.gd"),
		instance_inspector_plugin_script("spko/editor/surface_select_inspector_plugin.gd"),
	]

	for plugin in inspector_plugins:
		if plugin:
			add_inspector_plugin(plugin)

	var scn: PackedScene = load_relative("spko/editor/snap_cfg_toolbar.tscn")
	if scn && scn.can_instantiate():
		snap_cfg_toolbar = scn.instantiate()
		if is_instance_valid(snap_cfg_toolbar):
			add_container_control(CONTAINER_CANVAS_EDITOR_MENU, snap_cfg_toolbar)
			snap_cfg_toolbar.visible = false

	if is_instance_valid(snap_cfg_toolbar):
		snap_cfg_toolbar.snap_cfg_changed.connect(_on_snap_toolbar_snap_cfg_changed)


func _exit_tree() -> void:
	get_undo_redo().version_changed.disconnect(_on_undo_redo_version_changed)

	for plugin in inspector_plugins:
		if plugin:
			remove_inspector_plugin(plugin)

	for concon in container_controls:
		var control = concon.get("control")
		var container = concon.get("container")
		if is_instance_valid(control) && control is Control && container is CustomControlContainer:
			remove_control_from_container(container, control)
			@warning_ignore("unsafe_method_access")
			control.queue_free()

	snap_cfg_toolbar = null
	_edit_thing = null
	snap = null
	status_label = null


func _clear() -> void:
	if is_instance_valid(_edit_thing):
		_edit_thing.clean()
	if is_instance_valid(snap_cfg_toolbar):
		snap_cfg_toolbar.hide()
		snap_cfg_toolbar.sleep()
	if is_instance_valid(snap):
		snap.reset()


func _edit(object: Object) -> void:
	var wake_snap_cfg := false
	_edit_thing.clean()
	if object is SpkoPath:
		_edit_thing.start(self, object)
		wake_snap_cfg = true

	if is_instance_valid(snap_cfg_toolbar):
		if wake_snap_cfg:
			snap_cfg_toolbar.wake()
		else:
			snap_cfg_toolbar.sleep()
		snap_cfg_toolbar.visible = wake_snap_cfg
		snap_cfg_toolbar.enabled = snap.enabled
		snap_cfg_toolbar.mode = snap.mode
		snap_cfg_toolbar.space = snap.space
		snap_cfg_toolbar.position_step = snap.position_step

	update_overlays()


func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	if is_instance_valid(_edit_thing) && _edit_thing.has_target():
		_edit_thing.update()
		_edit_thing.draw(viewport_control.get_canvas_item())


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if is_instance_valid(_edit_thing) && _edit_thing.has_target():
		var handled := _edit_thing.input(event)
		update_overlays()
		return handled
	return false


func _handles(object: Object) -> bool:
	return object is SpkoPath


func _get_plugin_icon() -> Texture2D:
	return preload("icon/plugin.svg")


func _get_plugin_name() -> String:
	return "Supako"


func _get_state() -> Dictionary:
	return {
		"snap": snap.dump_state(),
	}


func _set_state(state: Dictionary) -> void:
	if typeof(state.get("snap")) == TYPE_DICTIONARY:
		snap.load_state(state["snap"])
	else:
		snap.reset()

	snap_cfg_toolbar.enabled = snap.enabled
	snap_cfg_toolbar.mode = snap.mode
	snap_cfg_toolbar.space = snap.space
	snap_cfg_toolbar.position_step = snap.position_step


func add_container_control(container: CustomControlContainer, control: Control) -> void:
	if !is_instance_valid(control):
		push_error("add_container_control failed. 'control' is null.")
		return

	container_controls.push_back({
		"control": control,
		"container": container,
	})

	add_control_to_container(container, control)


func load_relative(relpath: String) -> Resource:
	var plugin_path := "res://addons/quinevere.supako"
	var plugin_script := get_script() as Script
	if plugin_script:
		plugin_path = plugin_script.resource_path.get_base_dir()
	var res := load(plugin_path.path_join(relpath))
	if is_instance_valid(res):
		return res
	push_error("failed to load (%s/)%s" % [ plugin_path, relpath ])
	return null


func instance_inspector_plugin_script(path: String) -> EditorInspectorPlugin:
	var script := load(path) if path.is_absolute_path() else load_relative(path) as Script
	if !is_instance_valid(script):
		push_error("failed to load inspector plugin script '%s'" % [ path ])
		return null
	if script.has_method(&"new"):
		@warning_ignore("unsafe_method_access")
		var inst: EditorInspectorPlugin = script.new()
		if is_instance_valid(inst):
			inst.set("plugin", self) # let inspector plugin know about the editor plugin that owns it
			return inst
	push_error("error instancing inspector plugin script '%s'" % [ path ])
	return null


func _on_snap_cfg_changed():
	if is_instance_valid(status_label):
		status_label.text = str(snap)


func _on_snap_toolbar_snap_cfg_changed(property: StringName, value: Variant) -> void:
	snap.set(property, value)


func _on_undo_redo_version_changed() -> void:
	if is_instance_valid(_edit_thing) && _edit_thing.has_target():
		_edit_thing.reset()
