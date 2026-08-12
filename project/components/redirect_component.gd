class_name RedirectComponent extends Area2D

## Detects the bullet's proximity and drives bullet aim windows.
## Player-only component; sit on the bullet layer mask.

var _bullet: RigidBody2D = null
var _bullet_in_range: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8  # bullet layer
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# ── Public API ────────────────────────────────────────────────────────────────

func can_redirect() -> bool:
	return _bullet_in_range and is_instance_valid(_bullet) and _bullet.has_method("is_flying") and _bullet.is_flying()


func can_aim() -> bool:
	## True while the bullet is in an aim window (opening or redirect).
	return is_instance_valid(_bullet) and _bullet.has_method("is_aiming") and _bullet.is_aiming()


func begin_opening_aim(duration_seconds: float) -> void:
	if is_instance_valid(_bullet) and _bullet.has_method("begin_opening_aim"):
		_bullet.begin_opening_aim(owner, duration_seconds)


func begin_redirect() -> void:
	if can_redirect() and _bullet.has_method("begin_redirect"):
		_bullet.begin_redirect(1.5)


func set_aim_direction(direction: Vector2) -> void:
	if is_instance_valid(_bullet) and _bullet.has_method("set_aim_direction"):
		_bullet.set_aim_direction(direction)


func confirm_aim() -> void:
	if is_instance_valid(_bullet) and _bullet.has_method("confirm_aim"):
		_bullet.confirm_aim()


func bind_bullet(bullet: RigidBody2D) -> void:
	_bullet = bullet


func get_bullet() -> RigidBody2D:
	return _bullet


# ── Internals ─────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	if body == _bullet:
		_bullet_in_range = true
	elif body.is_in_group("bullet"):
		_bullet = body as RigidBody2D
		_bullet_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body == _bullet:
		_bullet_in_range = false
