extends RigidBody2D

signal launched
signal deflected(by: Node)
signal tethered(by: Node)
signal tether_released(by: Node)

enum BulletState { FLYING, TETHERED }

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_ENEMY := 4
const PHYSICS_MASK_PROBE := PHYSICS_LAYER_WORLD | PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_ENEMY

var COMPONENTS: Dictionary = {}

@export var speed: float = 180.0
@export var max_speed: float = 1500.0
@export var player_grace_seconds: float = 0.3
@export var arrow_length: float = 28.0
@export var rotate_heading: bool = true
@export var tether_speed_scale: float = 1.0
@export var tether_auto_release_turns: float = 1.0
## Multiplier applied to speed and damage on every tether release (1.1 = +10%).
@export var tether_release_boost: float = 1.1
@export var bounce_sound: SoundEvent
@export var begin_tether_sound: SoundEvent
@export var release_tether_sound: SoundEvent

@onready var body_collision_shape: CollisionShape2D = %CollisionShape2D
@onready var heading: Node2D = %Heading
@onready var aim_arrow: Node2D = %AimArrow
@onready var damage_component: DamageComponent = %DamageComponent
@onready var hitbox_component: HitboxComponent = %HitboxComponent
@onready var orb_in_focus: Sprite2D = %OrbInFocus

var state: BulletState = BulletState.FLYING
var aim_direction: Vector2 = Vector2.RIGHT
var _player: Node2D = null
var _grace_clear_msec: int = 0
var _in_focus: bool = false
var _tether_player: Node2D = null
var _tether_radius: float = 32.0
var _tether_angle: float = 0.0
var _tether_dir: float = 1.0
var _tether_swept: float = 0.0
var _opening_tether: bool = false
var _tether_broke_this_frame: bool = false


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
	collision_mask = PHYSICS_MASK_PROBE
	contact_monitor = true
	max_contacts_reported = 4

	var mat := PhysicsMaterial.new()
	# Script owns reflection via _integrate_forces; solver bounce would fight it.
	mat.bounce = 0.0
	mat.friction = 0.0
	physics_material_override = mat

	body_entered.connect(_on_body_entered)
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)

	orb_in_focus.visible = false
	aim_arrow.visible = false
	hitbox_component.monitoring = false
	freeze = true
	_apply_heading()


func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	if state != BulletState.FLYING:
		return
	if aim_direction.length_squared() < 0.0001:
		aim_direction = Vector2.RIGHT

	var contact_count: int = physics_state.get_contact_count()
	for i in contact_count:
		var normal: Vector2 = physics_state.get_contact_local_normal(i)
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		# Only reflect when moving into the surface (avoids sticky re-reflect jitter).
		if aim_direction.dot(normal) >= 0.0:
			continue
		var bounced: Vector2 = aim_direction.bounce(normal)
		if bounced.length_squared() < 0.0001:
			bounced = -aim_direction
		if bounced.length_squared() < 0.0001:
			bounced = Vector2.RIGHT
		aim_direction = bounced.normalized()

	physics_state.linear_velocity = aim_direction * speed


func _physics_process(delta: float) -> void:
	_tether_broke_this_frame = false
	match state:
		BulletState.FLYING:
			# Keep constant speed; direction is owned by aim_direction / _integrate_forces.
			if aim_direction.length_squared() < 0.0001:
				aim_direction = Vector2.RIGHT
			linear_velocity = aim_direction * speed
			_apply_heading()
			# Clear instigator once grace window elapses.
			if _grace_clear_msec > 0 and Time.get_ticks_msec() >= _grace_clear_msec:
				damage_component.instigator = null
				_grace_clear_msec = 0
		BulletState.TETHERED:
			_update_tether(delta)


# ── Lifecycle API ─────────────────────────────────────────────────────────────

func begin_opening_tether(player: Node2D, radius: float = 32.0) -> void:
	if not is_instance_valid(player):
		return

	_opening_tether = true
	_tether_player = player
	_player = player
	_tether_radius = maxf(radius, 1.0)
	_tether_angle = Vector2.UP.angle()  # spawn above player
	_tether_dir = 1.0  # CCW when starting from rest
	_tether_swept = 0.0

	state = BulletState.TETHERED
	freeze = true
	linear_velocity = Vector2.ZERO
	aim_arrow.visible = false
	damage_component.instigator = player
	_grace_clear_msec = 0
	hitbox_component.monitoring = true
	set_in_focus(true)
	_update_tether_pose()
	if begin_tether_sound:
		AudioManager.play_at(begin_tether_sound, global_position)
	tethered.emit(player)


func deflect(new_velocity: Vector2, instigator: Node) -> void:
	if state != BulletState.FLYING:
		return
	aim_direction = new_velocity.normalized() if new_velocity.length_squared() > 0.0001 else Vector2.RIGHT
	linear_velocity = aim_direction * speed
	if is_instance_valid(instigator):
		damage_component.instigator = instigator
		_player = instigator as Node2D
	_grace_clear_msec = Time.get_ticks_msec() + int(player_grace_seconds * 1000.0)
	_apply_heading()
	deflected.emit(instigator)


func begin_tether(player: Node2D, radius: float) -> void:
	if state != BulletState.FLYING:
		return
	if not is_instance_valid(player):
		return

	_opening_tether = false
	_tether_player = player
	_player = player
	_tether_radius = maxf(radius, 1.0)

	var radial: Vector2 = global_position - player.global_position
	if radial.length_squared() < 0.0001:
		radial = Vector2.RIGHT * _tether_radius
	_tether_angle = radial.angle()

	# Preserve travel sense: positive cross means counterclockwise (dir = +1).
	var cross_z: float = radial.x * linear_velocity.y - radial.y * linear_velocity.x
	_tether_dir = 1.0 if cross_z >= 0.0 else -1.0
	_tether_swept = 0.0

	state = BulletState.TETHERED
	freeze = true
	linear_velocity = Vector2.ZERO
	damage_component.instigator = player
	_grace_clear_msec = 0
	hitbox_component.monitoring = true
	set_in_focus(true)
	_update_tether_pose()
	if begin_tether_sound:
		AudioManager.play_at(begin_tether_sound, global_position)
	tethered.emit(player)


func release_tether() -> void:
	if state != BulletState.TETHERED:
		return

	var was_opening := _opening_tether
	var tangent := _tether_tangent()
	_finish_tether_release(tangent, was_opening, _safe_tether_player(), true)


## Forced break from collision or dealing damage. Applies boost (unless opening).
func break_tether(exit_velocity: Vector2) -> void:
	if state != BulletState.TETHERED or _tether_broke_this_frame:
		return

	_tether_broke_this_frame = true
	var was_opening := _opening_tether
	var exit_dir := exit_velocity
	if exit_dir.length_squared() < 0.0001:
		exit_dir = _tether_tangent()
	if exit_dir.length_squared() < 0.0001:
		exit_dir = aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	_finish_tether_release(exit_dir, was_opening, _safe_tether_player(), false)


func set_in_focus(value: bool) -> void:
	# While tethered the focus indicator stays on regardless of caller requests.
	if state == BulletState.TETHERED:
		value = true
	_in_focus = value
	orb_in_focus.visible = _in_focus


func is_flying() -> bool:
	return state == BulletState.FLYING


func is_tethered() -> bool:
	return state == BulletState.TETHERED


func get_tether_player() -> Node2D:
	return _safe_tether_player()


# ── Internals ─────────────────────────────────────────────────────────────────

## Freed/invalid tether owners must never be passed as typed Node args.
func _safe_tether_player() -> Node2D:
	if is_instance_valid(_tether_player):
		return _tether_player
	return null


func _finish_tether_release(
	exit_dir: Vector2,
	was_opening: bool,
	by: Node,
	play_release_sound: bool
) -> void:
	if exit_dir.length_squared() > 0.0001:
		aim_direction = exit_dir.normalized()
	elif aim_direction.length_squared() < 0.0001:
		aim_direction = Vector2.RIGHT
	if not was_opening:
		_apply_tether_release_boost()
	state = BulletState.FLYING
	freeze = false
	# Always launch at full speed — never leave the orb parked.
	linear_velocity = aim_direction * maxf(speed, 0.001)
	hitbox_component.monitoring = true
	if is_instance_valid(by):
		damage_component.instigator = by
		_player = by as Node2D
		_grace_clear_msec = Time.get_ticks_msec() + int(player_grace_seconds * 1000.0)
	else:
		damage_component.instigator = null
		_player = null
		_grace_clear_msec = 0
	_opening_tether = false
	_clear_tether_vars()
	set_in_focus(false)
	_apply_heading()
	if play_release_sound:
		if release_tether_sound:
			AudioManager.play_at(release_tether_sound, global_position)
	elif bounce_sound:
		AudioManager.play_at(bounce_sound, global_position)
	if was_opening:
		launched.emit()
	else:
		tether_released.emit(by)


func _update_tether(delta: float) -> void:
	if not is_instance_valid(_tether_player):
		# Owner freed (e.g. player died) — launch along last tangent; do not pass freed refs.
		release_tether()
		return

	var angular_speed: float = (speed * tether_speed_scale) / _tether_radius
	var step: float = angular_speed * delta
	var next_angle: float = _tether_angle + step * _tether_dir
	var next_pos: Vector2 = (
		_tether_player.global_position + Vector2.RIGHT.rotated(next_angle) * _tether_radius
	)

	if _probe_tether_collision(global_position, next_pos, next_angle):
		return

	_tether_angle = next_angle
	_tether_swept += step
	_update_tether_pose()

	if _tether_swept >= TAU * tether_auto_release_turns:
		release_tether()


func _probe_tether_collision(from_pos: Vector2, next_pos: Vector2, next_angle: float) -> bool:
	var shape: Shape2D = body_collision_shape.shape
	if shape == null:
		return false

	var motion: Vector2 = next_pos - from_pos
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, from_pos)
	params.motion = motion
	params.collision_mask = PHYSICS_MASK_PROBE
	params.exclude = [get_rid()]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var cast: PackedFloat32Array = space.cast_motion(params)
	# cast_motion returns [safe, unsafe] fractions; both 1.0 means no hit.
	if cast.size() < 2 or cast[0] >= 1.0:
		# Also catch already-overlapping solids at the destination (teleport case).
		params.transform = Transform2D(0.0, next_pos)
		params.motion = Vector2.ZERO
		var overlaps: Array[Dictionary] = space.intersect_shape(params, 1)
		if overlaps.is_empty():
			return false
		return _break_tether_from_collision(overlaps[0], next_angle)

	var hit_fraction: float = cast[0]
	var hit_pos: Vector2 = from_pos + motion * hit_fraction
	params.transform = Transform2D(0.0, hit_pos)
	params.motion = Vector2.ZERO
	var hits: Array[Dictionary] = space.intersect_shape(params, 1)
	if hits.is_empty():
		# Nudge slightly past the unsafe fraction to find the collider.
		var unsafe_pos: Vector2 = from_pos + motion * minf(cast[1], 1.0)
		params.transform = Transform2D(0.0, unsafe_pos)
		hits = space.intersect_shape(params, 1)
		if hits.is_empty():
			return false
	return _break_tether_from_collision(hits[0], next_angle)


func _break_tether_from_collision(hit: Dictionary, next_angle: float) -> bool:
	var collider: Object = hit.get("collider")
	if collider == null or not is_instance_valid(collider):
		return false

	var body: Node = collider as Node
	var entity_root: Node = _resolve_entity_root(body)

	# Damage breakables on contact (same as flying body_entered).
	if body.is_in_group("breakables") or (entity_root != null and entity_root.is_in_group("breakables")):
		var breakable: Node = entity_root if entity_root != null and entity_root.is_in_group("breakables") else body
		var comp = breakable.get("COMPONENTS")
		if comp and comp.has(HealthComponent):
			comp[HealthComponent].take_damage(damage_component.damage if damage_component.damage > 0.0 else 1.0)

	var collider_pos: Vector2 = _collider_global_position(body)
	var normal: Vector2 = (global_position - collider_pos).normalized()
	if normal.length_squared() < 0.0001:
		normal = -_tether_tangent_at(next_angle)

	var tangent: Vector2 = _tether_tangent_at(next_angle)
	var exit_velocity: Vector2 = tangent.bounce(normal)
	if exit_velocity.length_squared() < 0.0001:
		exit_velocity = -tangent
	if exit_velocity.length_squared() < 0.0001:
		exit_velocity = -aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT

	break_tether(exit_velocity)
	return true


func _collider_global_position(body: Node) -> Vector2:
	if body is Node2D:
		return (body as Node2D).global_position
	return global_position


func _resolve_entity_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null

	var node: Node = collider
	while node != null and node.get("COMPONENTS") == null:
		node = node.get_parent()
	return node


func _update_tether_pose() -> void:
	global_position = _tether_player.global_position + Vector2.RIGHT.rotated(_tether_angle) * _tether_radius
	aim_direction = _tether_tangent()
	_apply_heading()


func _tether_tangent() -> Vector2:
	return _tether_tangent_at(_tether_angle)


func _tether_tangent_at(angle: float) -> Vector2:
	# Perpendicular to radial; dir = +1 is counterclockwise.
	return Vector2.RIGHT.rotated(angle + PI / 2.0 * _tether_dir)


func _clear_tether_vars() -> void:
	_tether_player = null
	_tether_radius = 32.0
	_tether_angle = 0.0
	_tether_dir = 1.0
	_tether_swept = 0.0


func _apply_tether_release_boost() -> void:
	speed = minf(speed * tether_release_boost, max_speed)
	damage_component.damage *= tether_release_boost


func _apply_heading() -> void:
	if rotate_heading:
		heading.rotation = aim_direction.angle() + PI / 2.0
	aim_arrow.rotation = aim_direction.angle()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if state != BulletState.TETHERED or _tether_broke_this_frame:
		return
	if damage_component.damage <= 0.0:
		return

	var victim_root: Node = _resolve_entity_root(area)
	if victim_root == null:
		return

	var comp = victim_root.get("COMPONENTS")
	if comp == null or not comp.has(HealthComponent):
		return

	# Friendly-fire: instigator is immune — physical probe still breaks on body contact.
	if is_instance_valid(damage_component.instigator) and damage_component.instigator == victim_root:
		return

	break_tether(_tether_tangent())


func _on_body_entered(body: Node) -> void:
	if state != BulletState.FLYING:
		return
	if bounce_sound:
		AudioManager.play_at(bounce_sound, global_position)

	# Bounce direction is owned by _integrate_forces (true contact normals).
	# Breakables: damage via HealthComponent so the bounce resolves first.
	if body.is_in_group("breakables"):
		var comp = body.get("COMPONENTS")
		if comp and comp.has(HealthComponent):
			comp[HealthComponent].take_damage(1.0)
