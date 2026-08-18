class_name MovementComponent extends Node2D

@export var move_speed: float = 90.0
## 1.0 = instant direction change (matches original CharacterBody2D behaviour).
@export var acceleration: float = 1.0
@export var friction: float = 1.0
## Optional: flips the sprite when moving left/right.
@export var sprite: Sprite2D
@export var sprite_flip_inverted: bool = false


func move(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		move_velocity(direction.normalized() * move_speed)
	else:
		stop()


func move_velocity(target_velocity: Vector2) -> void:
	owner.velocity = owner.velocity.lerp(target_velocity, acceleration)
	if sprite and target_velocity.x != 0.0:
		sprite.flip_h = target_velocity.x < 0.0
		if sprite_flip_inverted:
			sprite.flip_h = not sprite.flip_h
	owner.move_and_slide()


func stop() -> void:
	owner.velocity = owner.velocity.lerp(Vector2.ZERO, friction)
	owner.move_and_slide()
