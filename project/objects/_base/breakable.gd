class_name Breakable
extends LevelObject

signal destroyed(at: Vector2)

var _is_destroyed: bool = false


func _ready() -> void:
	add_to_group("breakables")
	super._ready()


func destroy() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	destroyed.emit(global_position)
	queue_free()
