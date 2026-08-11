extends CharacterBody2D

signal died

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_ENEMY := 4

@export var move_speed: float = 55.0

@onready var sprite: Sprite2D = %Sprite2D
@onready var contact_area: Area2D = %ContactArea

var is_dead: bool = false
var _player: Node2D = null


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = PHYSICS_LAYER_ENEMY
	collision_mask = PHYSICS_LAYER_WORLD | PHYSICS_LAYER_ENEMY

	contact_area.collision_layer = 0
	contact_area.collision_mask = PHYSICS_LAYER_PLAYER
	contact_area.monitoring = true
	contact_area.monitorable = false
	contact_area.body_entered.connect(_on_contact_area_body_entered)

	_find_player()


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(_player):
		_find_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := _player.global_position - global_position
	if to_player.length_squared() > 0.0001:
		var dir := to_player.normalized()
		velocity = dir * move_speed
		sprite.flip_h = dir.x < 0.0
	else:
		velocity = Vector2.ZERO

	move_and_slide()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	contact_area.set_deferred("monitoring", false)
	died.emit()
	DestructionEffect.play_from_sprite(sprite)
	queue_free()


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0] as Node2D


func _on_contact_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("die"):
		body.die()
