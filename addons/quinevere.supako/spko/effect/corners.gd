@tool
class_name SpkoEffectCorners extends SpkoEffect


const MODULE_NAME := &"Corners"


## Corner angle threshold for adding chamfer.
## Chamfer will be added to corners with an (outer) angle greater than this value.
@export_range(0.0, 180.0, 0.1, "radians") var sharp_threshold: float = PI / 6.0:
	set(value):
		if !is_equal_approx(value, sharp_threshold):
			sharp_threshold = value
			notify_module_changed(true)

@export_range(0.0, 200.0, 0.1) var sharp_chamfer_depth: float = 12.0:
	set(value):
		if !is_equal_approx(value, sharp_chamfer_depth):
			sharp_chamfer_depth = value
			notify_module_changed(true)

## Corner angle threshold for adding fillet.
## Fillet will be added to corners with an (inner) angle greater than this value.
@export_range(0.0, 180.0, 0.1, "radians") var fillet_threshold: float = PI / 3.0:
	set(value):
		if !is_equal_approx(value, fillet_threshold):
			fillet_threshold = value
			notify_module_changed(true)

@export_range(0.0, 200.0, 0.1) var fillet_depth: float = 12.0:
	set(value):
		if !is_equal_approx(value, fillet_depth):
			fillet_depth = value
			notify_module_changed(true)

@export var minimum_segment_length: float = 4.0:
	set(value):
		minimum_segment_length = value
		notify_module_changed(true)


func _effect_build(ctx: CallbackContext, brush: SpkoBrush) -> void:
	if ctx.is_visible():
		brush.iter_islands(_process_island)


func _process_island(ia: SpkoBrush.IslandAccess) -> void:
	if ia.get_vertex_count() < 3:
		return

	var fillet_enable := fillet_depth >= minimum_segment_length && fillet_threshold < PI
	var chamfer_enable := sharp_chamfer_depth >= minimum_segment_length && sharp_threshold < PI
	if !fillet_enable && !chamfer_enable:
		return

	var k := 0
	while k < ia.get_vertex_count():
		var b := ia.get_vertex_position(k)
		var ab := b - ia.get_vertex_position(k - 1)
		var bc := ia.get_vertex_position(k + 1) - b
		var angle := ab.angle_to(bc) * -ia.get_winding_signum()

		var cut_depth := 0.0
		if fillet_enable && angle < -fillet_threshold:
			cut_depth = fillet_depth
		elif chamfer_enable && angle > sharp_threshold:
			cut_depth = sharp_chamfer_depth

		var mab := ab.length()
		var mbc := bc.length()
		var max_depth := minf(mab, mbc) - minimum_segment_length
		cut_depth = minf(cut_depth, max_depth)
		if cut_depth >= minimum_segment_length:
			var p := b - (ab / mab) * cut_depth
			b = b + (bc / mbc) * cut_depth
			ia.set_vertex_position(k, b)
			ia.insert_vertex(k, p)
			k += 2
			continue

		k += 1
