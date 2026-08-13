class_name DashComponent extends Node2D

## Fixed-distance dash with i-frames. Self-driven via _physics_process.
## While dashing, body collision is cleared so the player phases through
## props, enemies, and walls for the full distance.

@export var dash_distance: float = 50.0
@export var dash_speed: float = 400.0
@export var dash_cooldown: float = 0.5
@export var sprite: Sprite2D
@export var hitbox_component: HitboxComponent
@export var dash_sound: SoundEvent = preload("res://entities/player/dash.tres")

var _direction: Vector2 = Vector2.RIGHT
var _remaining_distance: float = 0.0
var _dashing: bool = false
var _cooldown_until_msec: int = 0
var _saved_collision_mask: int = 0
var _saved_collision_layer: int = 0


func _ready() -> void:
	set_physics_process(false)


func start(direction: Vector2) -> void:
	if not can_dash():
		return
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	_remaining_distance = dash_distance
	_dashing = true
	if sprite and _direction.x != 0.0:
		sprite.flip_h = _direction.x < 0.0
	if hitbox_component:
		hitbox_component.set_invulnerable(true)
	if dash_sound and owner is Node2D:
		AudioManager.play_at(dash_sound, (owner as Node2D).global_position)
	_begin_phase()
	set_physics_process(true)


func is_dashing() -> bool:
	return _dashing


func can_dash() -> bool:
	return not _dashing and Time.get_ticks_msec() >= _cooldown_until_msec


func _physics_process(_delta: float) -> void:
	if not _dashing:
		set_physics_process(false)
		return

	var body := owner as CharacterBody2D
	var start_pos: Vector2 = body.global_position
	body.velocity = _direction * dash_speed
	body.move_and_slide()

	var moved: float = start_pos.distance_to(body.global_position)
	_remaining_distance -= moved

	if _remaining_distance <= 0.0:
		_end_dash()


func _end_dash() -> void:
	_dashing = false
	_remaining_distance = 0.0
	var body := owner as CharacterBody2D
	body.velocity = Vector2.ZERO
	_end_phase()
	if hitbox_component:
		hitbox_component.set_invulnerable(false)
	_cooldown_until_msec = Time.get_ticks_msec() + int(dash_cooldown * 1000.0)
	set_physics_process(false)


func _begin_phase() -> void:
	var body := owner as CharacterBody2D
	_saved_collision_mask = body.collision_mask
	_saved_collision_layer = body.collision_layer
	body.collision_mask = 0
	body.collision_layer = 0


func _end_phase() -> void:
	var body := owner as CharacterBody2D
	body.collision_mask = _saved_collision_mask
	body.collision_layer = _saved_collision_layer
