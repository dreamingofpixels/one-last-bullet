class_name OpeningAimComponent extends Node2D

## Drives the level-start aim window on the bound bullet.
## Mid-combat steering is handled by OrbTetherComponent (arc deflect is parked).

var _bullet: RigidBody2D = null


func bind_bullet(bullet: RigidBody2D) -> void:
	_bullet = bullet


func get_bullet() -> RigidBody2D:
	return _bullet


func begin_opening_aim(duration_seconds: float) -> void:
	if is_instance_valid(_bullet) and _bullet.has_method("begin_opening_aim"):
		_bullet.begin_opening_aim(owner, duration_seconds)


func can_aim() -> bool:
	return is_instance_valid(_bullet) and _bullet.has_method("is_aiming") and _bullet.is_aiming()


func set_aim_direction(direction: Vector2) -> void:
	if is_instance_valid(_bullet) and _bullet.has_method("set_aim_direction"):
		_bullet.set_aim_direction(direction)


func confirm_aim() -> void:
	if is_instance_valid(_bullet) and _bullet.has_method("confirm_aim"):
		_bullet.confirm_aim()
