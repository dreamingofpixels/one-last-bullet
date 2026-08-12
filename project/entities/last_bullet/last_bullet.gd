extends RigidBody2D

signal launched
signal redirected

enum BulletState { HELD, AIMING, FLYING }

const PHYSICS_LAYER_WORLD := 1

var COMPONENTS: Dictionary = {}

@export var speed: float = 180.0
@export var slow_mo_scale: float = 0.15
@export var player_grace_seconds: float = 0.3
@export var arrow_length: float = 28.0
@export var rotate_heading: bool = true

@onready var heading: Node2D = %Heading
@onready var aim_arrow: Node2D = %AimArrow
@onready var damage_component: DamageComponent = %DamageComponent
@onready var hitbox_component: HitboxComponent = %HitboxComponent

var state: BulletState = BulletState.HELD
var aim_direction: Vector2 = Vector2.RIGHT
var aim_deadline_msec: int = 0
var _player: Node2D = null
var _grace_clear_msec: int = 0


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
	collision_layer = 8  # bullet layer
	collision_mask = PHYSICS_LAYER_WORLD
	contact_monitor = true
	max_contacts_reported = 4

	var mat := PhysicsMaterial.new()
	mat.bounce = 1.0
	mat.friction = 0.0
	physics_material_override = mat

	body_entered.connect(_on_body_entered)

	aim_arrow.visible = false
	hitbox_component.monitoring = false
	freeze = true
	_apply_heading()


func _physics_process(_delta: float) -> void:
	match state:
		BulletState.HELD, BulletState.AIMING:
			if is_instance_valid(_player):
				global_position = _player.global_position
			linear_velocity = Vector2.ZERO
			_apply_heading()
		BulletState.FLYING:
			if linear_velocity.length_squared() > 0.0001:
				linear_velocity = linear_velocity.normalized() * speed
				aim_direction = linear_velocity.normalized()
			_apply_heading()
			# Clear instigator once grace window elapses.
			if _grace_clear_msec > 0 and Time.get_ticks_msec() >= _grace_clear_msec:
				damage_component.instigator = null
				_grace_clear_msec = 0


func _process(_delta: float) -> void:
	if state != BulletState.AIMING:
		return
	# Auto-launch when the aim window has elapsed.
	if _aim_window_elapsed():
		_launch()


# ── Aim window API (driven externally by RedirectComponent/player states) ─────

func set_aim_direction(direction: Vector2) -> void:
	if state != BulletState.AIMING:
		return
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()
	_apply_heading()
	aim_arrow.queue_redraw()


func confirm_aim() -> void:
	if state == BulletState.AIMING:
		_launch()


# ── Lifecycle API ─────────────────────────────────────────────────────────────

func begin_held(player: Node2D) -> void:
	_player = player
	state = BulletState.HELD
	freeze = true
	linear_velocity = Vector2.ZERO
	aim_arrow.visible = false
	hitbox_component.monitoring = false
	Engine.time_scale = 1.0
	if is_instance_valid(_player):
		global_position = _player.global_position
	aim_direction = Vector2.RIGHT
	_apply_heading()


func begin_opening_aim(player: Node2D, duration_seconds: float = 3.0) -> void:
	begin_held(player)
	_enter_aiming(duration_seconds, Vector2.UP)


func begin_redirect(duration_seconds: float = 1.5) -> void:
	if state != BulletState.FLYING:
		return
	var start_dir := aim_direction
	if linear_velocity.length_squared() > 0.0001:
		start_dir = linear_velocity.normalized()
	_enter_aiming(duration_seconds, start_dir)
	redirected.emit()


func is_aiming() -> bool:
	return state == BulletState.AIMING


func is_flying() -> bool:
	return state == BulletState.FLYING


# ── Internals ─────────────────────────────────────────────────────────────────

func _enter_aiming(duration_seconds: float, start_direction: Vector2) -> void:
	state = BulletState.AIMING
	freeze = true
	linear_velocity = Vector2.ZERO
	aim_direction = start_direction.normalized() if start_direction.length_squared() > 0.0001 else Vector2.RIGHT
	aim_arrow.visible = true
	hitbox_component.monitoring = false
	aim_deadline_msec = Time.get_ticks_msec() + int(duration_seconds * 1000.0)
	Engine.time_scale = slow_mo_scale
	_apply_heading()
	aim_arrow.queue_redraw()


func _launch() -> void:
	state = BulletState.FLYING
	freeze = false
	aim_arrow.visible = false
	Engine.time_scale = 1.0
	aim_direction = aim_direction.normalized() if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	linear_velocity = aim_direction * speed
	hitbox_component.monitoring = true
	# Instigator grace: the player who aimed is briefly immune.
	if is_instance_valid(_player):
		damage_component.instigator = _player
	_grace_clear_msec = Time.get_ticks_msec() + int(player_grace_seconds * 1000.0)
	_apply_heading()
	launched.emit()


func _aim_window_elapsed() -> bool:
	return Time.get_ticks_msec() >= aim_deadline_msec


func _apply_heading() -> void:
	if rotate_heading:
		heading.rotation = aim_direction.angle() + PI / 2.0
	aim_arrow.rotation = aim_direction.angle()


func _on_body_entered(body: Node) -> void:
	if state != BulletState.FLYING:
		return
	# Breakables: damage via HealthComponent so the bounce resolves first.
	if body.is_in_group("breakables"):
		var comp = body.get("COMPONENTS")
		if comp and comp.has(HealthComponent):
			comp[HealthComponent].take_damage(1.0)
