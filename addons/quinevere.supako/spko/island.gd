@tool
class_name SpkoIsland extends Resource
## Brush primitive -- contiguous set of points from a brush/path/shape.
## Points are stored as index into brush vertex buffer.

@export var points := PackedInt32Array()
@export var clockwise: bool

var owner_id: int
var tags := {}
