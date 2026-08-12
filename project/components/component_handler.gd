extends Node2D

func _ready() -> void:
	for component in get_children():
		owner.COMPONENTS[component.get_script()] = component
