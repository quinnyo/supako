@tool
class_name SpkoIsland extends Resource
## Brush primitive -- contiguous set of points from a brush/path/shape.
## Points are stored as index into brush vertex buffer.

@export var points := PackedInt32Array()
@export var element_id: int = -1
@export var clockwise: bool

