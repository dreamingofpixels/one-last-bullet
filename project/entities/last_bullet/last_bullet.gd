extends RigidBody2D

signal launched
signal redirected

enum State { HELD, AIMING, FLYING }

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_ENEMY := 4
const PHYSICS_LAYER_BULLET := 8

@export var speed: float = 200.0
@export var slow_mo_scale: float = 0.15
@export var aim_rotate_speed: float = 3.0
@export var player_grace_seconds: float = 0.3
@export var arrow_length: float = 28.0

@onready var heading: Node2D = %Heading
@onready var hitbox: Area2D = %Hitbox
@onready var aim_arrow: Node2D = %AimArrow

var state: State = State.HELD
var aim_direction: Vector2 = Vector2.RIGHT
var using_mouse_aim: bool = false
var aim_deadline_msec: int = 0
var player_grace_until_msec: int = 0
var _player: Node2D = null
var _ignore_confirm_until_msec: int = 0
var _last_aim_tick_msec: int = 0


func _ready() -> void:
	add_to_group("bullet")
	gravity_scale = 0.0
	lock_rotation = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	collision_layer = PHYSICS_LAYER_BULLET
	collision_mask = PHYSICS_LAYER_WORLD
	contact_monitor = true
	max_contacts_reported = 4

	var mat := PhysicsMaterial.new()
	mat.bounce = 1.0
	mat.friction = 0.0
	physics_material_override = mat

	hitbox.collision_layer = 0
	hitbox.collision_mask = PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_ENEMY
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	body_entered.connect(_on_body_entered)

	aim_arrow.visible = false
	freeze = true
	_apply_heading()


func _physics_process(_delta: float) -> void:
	match state:
		State.HELD, State.AIMING:
			if is_instance_valid(_player):
				global_position = _player.global_position
			linear_velocity = Vector2.ZERO
			_apply_heading()
		State.FLYING:
			if linear_velocity.length_squared() > 0.0001:
				linear_velocity = linear_velocity.normalized() * speed
				aim_direction = linear_velocity.normalized()
			_apply_heading()


func _process(_delta: float) -> void:
	if state != State.AIMING:
		return
	_update_aim()
	if _aim_window_elapsed() or _wants_confirm():
		_launch()


func begin_held(player: Node2D) -> void:
	_player = player
	state = State.HELD
	freeze = true
	linear_velocity = Vector2.ZERO
	hitbox.monitoring = false
	aim_arrow.visible = false
	Engine.time_scale = 1.0
	if is_instance_valid(_player):
		global_position = _player.global_position
	aim_direction = Vector2.RIGHT
	_apply_heading()


func begin_opening_aim(player: Node2D, duration_seconds: float = 3.0) -> void:
	begin_held(player)
	_enter_aiming(duration_seconds, Vector2.UP)


func begin_redirect(duration_seconds: float = 1.5) -> void:
	if state != State.FLYING:
		return
	var start_dir := aim_direction
	if linear_velocity.length_squared() > 0.0001:
		start_dir = linear_velocity.normalized()
	_enter_aiming(duration_seconds, start_dir)
	redirected.emit()


func is_aiming() -> bool:
	return state == State.AIMING


func is_flying() -> bool:
	return state == State.FLYING


func _enter_aiming(duration_seconds: float, start_direction: Vector2) -> void:
	state = State.AIMING
	freeze = true
	linear_velocity = Vector2.ZERO
	hitbox.monitoring = false
	aim_direction = start_direction.normalized() if start_direction.length_squared() > 0.0001 else Vector2.RIGHT
	using_mouse_aim = false
	aim_arrow.visible = true
	var now := Time.get_ticks_msec()
	aim_deadline_msec = now + int(duration_seconds * 1000.0)
	_last_aim_tick_msec = now
	# Prevent the same SPACE press that started redirect from instantly confirming.
	_ignore_confirm_until_msec = now + 200
	Engine.time_scale = slow_mo_scale
	_apply_heading()
	aim_arrow.queue_redraw()


func _launch() -> void:
	state = State.FLYING
	freeze = false
	aim_arrow.visible = false
	Engine.time_scale = 1.0
	linear_velocity = aim_direction.normalized() * speed
	player_grace_until_msec = Time.get_ticks_msec() + int(player_grace_seconds * 1000.0)
	hitbox.monitoring = true
	_apply_heading()
	launched.emit()


func _aim_window_elapsed() -> bool:
	return Time.get_ticks_msec() >= aim_deadline_msec


func _wants_confirm() -> bool:
	if Time.get_ticks_msec() < _ignore_confirm_until_msec:
		return false
	return Input.is_action_just_pressed("aim_confirm") or Input.is_action_just_pressed("redirect")


func _update_aim() -> void:
	var now := Time.get_ticks_msec()
	var real_delta := clampf(float(now - _last_aim_tick_msec) / 1000.0, 0.0, 0.05)
	_last_aim_tick_msec = now

	if Input.get_last_mouse_velocity().length_squared() > 4.0:
		using_mouse_aim = true

	var key_rotate := 0.0
	if Input.is_action_pressed("aim_ccw"):
		key_rotate -= 1.0
		using_mouse_aim = false
	if Input.is_action_pressed("aim_cw"):
		key_rotate += 1.0
		using_mouse_aim = false

	if using_mouse_aim:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 0.0001:
			aim_direction = to_mouse.normalized()
	elif key_rotate != 0.0:
		aim_direction = aim_direction.rotated(key_rotate * aim_rotate_speed * real_delta)

	_apply_heading()
	aim_arrow.queue_redraw()


func _apply_heading() -> void:
	heading.rotation = aim_direction.angle() + PI / 2.0
	aim_arrow.rotation = aim_direction.angle()


func _on_hitbox_body_entered(body: Node2D) -> void:
	_resolve_hit(body)


func _on_hitbox_area_entered(area: Area2D) -> void:
	_resolve_hit(area.get_parent())


func _on_body_entered(body: Node) -> void:
	if state != State.FLYING:
		return
	if body.is_in_group("breakables") and body.has_method("destroy"):
		body.destroy()


func _resolve_hit(target: Node) -> void:
	if state != State.FLYING or target == null:
		return
	if target.is_in_group("player"):
		if Time.get_ticks_msec() < player_grace_until_msec:
			return
		if target.has_method("die"):
			target.die()
		return
	if target.is_in_group("enemies"):
		if target.has_method("die"):
			target.die()
