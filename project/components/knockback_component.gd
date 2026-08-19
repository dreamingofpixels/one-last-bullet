class_name KnockbackComponent extends Node2D

## Applies a decaying shove to the owner.
## Supports CharacterBody2D (velocity + move_and_slide), RigidBody2D (impulse),
## and plain Node2D (global_position translate) so objects can reuse it later.

@export var deceleration: float = 800.0
@export var min_speed: float = 8.0

var _velocity: Vector2 = Vector2.ZERO
var _active: bool = false


func apply(direction: Vector2, force: float) -> void:
	if direction.length_squared() < 0.0001 or force <= 0.0:
		return
	_velocity = direction.normalized() * force
	_active = true
	set_physics_process(true)

	if owner is RigidBody2D:
		(owner as RigidBody2D).apply_central_impulse(_velocity)


func is_active() -> bool:
	return _active


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _active:
		set_physics_process(false)
		return

	if owner is RigidBody2D:
		# Impulse was applied once in apply(); clear once speed is low.
		var rb := owner as RigidBody2D
		if rb.linear_velocity.length() <= min_speed:
			_velocity = Vector2.ZERO
			_active = false
			set_physics_process(false)
		return

	var speed := _velocity.length()
	if speed <= min_speed:
		_velocity = Vector2.ZERO
		_active = false
		set_physics_process(false)
		if owner is CharacterBody2D:
			(owner as CharacterBody2D).velocity = Vector2.ZERO
		return

	var new_speed := maxf(0.0, speed - deceleration * delta)
	_velocity = _velocity.normalized() * new_speed

	if owner is CharacterBody2D:
		var body := owner as CharacterBody2D
		if not body.is_inside_tree():
			return
		if PhysicsServer2D.body_get_space(body.get_rid()) == RID():
			return
		body.velocity = _velocity
		body.move_and_slide()
	elif owner is Node2D:
		(owner as Node2D).global_position += _velocity * delta
