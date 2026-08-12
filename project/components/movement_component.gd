class_name MovementComponent extends Node2D

@export var move_speed: float = 90.0
## 1.0 = instant direction change (matches original CharacterBody2D behaviour).
@export var acceleration: float = 1.0
@export var friction: float = 1.0
## Optional: flips the sprite when moving left/right.
@export var sprite: Sprite2D


func move(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		owner.velocity = owner.velocity.lerp(direction.normalized() * move_speed, acceleration)
		if sprite and direction.x != 0.0:
			sprite.flip_h = direction.x < 0.0
	else:
		stop()
	owner.move_and_slide()


func stop() -> void:
	owner.velocity = owner.velocity.lerp(Vector2.ZERO, friction)
	owner.move_and_slide()
