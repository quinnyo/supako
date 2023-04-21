@tool
class_name SpkoDecoSprite extends SpkoDeco

## texture to draw...
@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
## Enable output size override (using `dest_size` value) if true.
@export var dest_size_enabled: bool = false:
	set(value):
		if value && dest_size == Vector2.ZERO && is_instance_valid(texture):
			dest_size = texture.get_size()
		dest_size_enabled = value
		emit_changed()
## Output (render) size -- overrides texture size. `dest_size_enabled` must be true.
@export var dest_size: Vector2 = Vector2.ZERO:
	set(value):
		dest_size = value
		emit_changed()
## if true, draw the sprite centered. If false, the top-left corner will be at the origin.
@export var centered: bool = true:
	set(value):
		centered = value
		emit_changed()
## Offset render position, in `texture` pixel coordinates.
@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		offset = value
		emit_changed()
## Enables source rect override (`region_rect`) if true.
@export var region_enabled: bool = false:
	set(value):
		region_enabled = value
		emit_changed()
## sub-rect region of `texture` to sample from. Only used if `region_enabled` is true.
@export var region_rect: Rect2 = Rect2():
	set(value):
		region_rect = value
		emit_changed()

var rsv := RenderingServer


## Create instance of deco with given pose
func spawn_instance(ci: RID, pose: Transform2D) -> void:
	if texture == null:
		return
	var tex_size := texture.get_size()
	var src_rect := region_rect if region_enabled else Rect2(Vector2.ZERO, tex_size)
	var dest_rect := Rect2(offset, tex_size)
	if dest_size_enabled:
		dest_rect.position = offset * dest_size / tex_size
		dest_rect.size = dest_size
	if centered:
		dest_rect.position -= dest_rect.size / 2.0

	var points := pose * _rect_corners(dest_rect)
	var color := Color.WHITE
	var colors := PackedColorArray([color, color, color, color])
	var uvs := _rect_corners(Rect2(src_rect.position / tex_size, src_rect.size / tex_size))
	rsv.canvas_item_add_primitive(ci, points, colors, uvs, texture)


func _rect_corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

