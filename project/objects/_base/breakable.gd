class_name Breakable
extends LevelObject

var COMPONENTS: Dictionary = {}


func _ready() -> void:
	add_to_group("breakables")
	super._ready()
