@tool
class_name SpkoDecoGroup extends SpkoDeco


@export var things: Array[SpkoDeco] = []:
	set(value):
		for thing in things:
			if thing && !value.has(thing):
				if thing.changed.is_connected(_on_thing_changed):
					thing.changed.disconnect(_on_thing_changed)
		things = value
		for thing in things:
			if thing && !thing.changed.is_connected(_on_thing_changed):
				thing.changed.connect(_on_thing_changed.bind(thing))
		emit_changed()


func get_variant(vari: int) -> SpkoDeco:
	return things[wrapi(vari, 0, things.size())]


func _on_thing_changed(_thing: SpkoDeco) -> void:
	emit_changed()
