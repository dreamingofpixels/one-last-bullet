extends CharacterBody2D

var COMPONENTS: Dictionary = {}

@onready var movement_component: MovementComponent = %MovementComponent
@onready var destroy_component: DestroyComponent = %DestroyComponent
@onready var knockback_component: KnockbackComponent = %KnockbackComponent
@onready var sprite: Sprite2D = %Sprite2D

var _player: Node2D = null


func _ready() -> void:
	add_to_group("enemies")
	_find_player()


func _physics_process(_delta: float) -> void:
	if knockback_component.is_active():
		return

	if not is_instance_valid(_player):
		_find_player()
		movement_component.stop()
		return

	var to_player := _player.global_position - global_position
	if to_player.length_squared() > 0.0001:
		var dir := to_player.normalized()
		movement_component.move(dir)
		if dir.x != 0.0:
			sprite.flip_h = dir.x > 0.0
	else:
		movement_component.stop()


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D
