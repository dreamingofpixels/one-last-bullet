class_name Breakable
extends LevelObject

var COMPONENTS: Dictionary = {}


func _ready() -> void:
	add_to_group("breakables")
	super._ready()
	_compensate_sort_bias()


func _compensate_sort_bias() -> void:
	if Engine.is_editor_hint() or not _sort_bias_applied:
		return
	var health_bar: HealthBarComponent = COMPONENTS.get(HealthBarComponent)
	if health_bar != null:
		health_bar.position.y += SORT_BIAS_Y
	var hitbox: HitboxComponent = COMPONENTS.get(HitboxComponent)
	if hitbox != null:
		hitbox.position.y += SORT_BIAS_Y
