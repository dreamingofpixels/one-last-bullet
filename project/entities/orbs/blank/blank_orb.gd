class_name BlankOrb extends RigidBody2D

signal launched
signal deflected(by: Node)
signal tethered(by: Node)
signal tether_released(by: Node)

enum OrbState { FLYING, TETHERED, POSSESSED }

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_ENEMY := 4
const SPLASH_RADIUS := 50.0
## Body / tether probe / depenetrate default to world solids (walls, rocks, breakables).
## When bounce_off_entities is true, flying orbs also bounce off player/enemy bodies.
## Entity damage still comes from HitboxComponent overlap.
const SEPARATE_STEP_PX := 2.0
const SEPARATE_MAX_ITERS := 4
const SEPARATE_MAX_PUSH_PX := 8.0
const OUTBOUND_DOT_MIN := 0.05
const STALL_TRAVEL_FRACTION := 0.25
const STALL_TICKS_BEFORE_UNSTICK := 12

var COMPONENTS: Dictionary = {}

## Playtest toggle: when true, flying orbs bounce off player/enemy bodies instead of punching through.
static var bounce_off_entities: bool = false

@export var orb_id: StringName = &"blank"
@export var damage: float = 10.0
@export var self_damage: float = 8.0
@export var splash: float = 0.0
@export var speed: float = 180.0
@export var weight: float = 10.0
@export var crit_chance: float = 0.01
@export var crit_damage: float = 2.0
@export var glyph_drop: float = 0.1
@export var burn: int = 0
@export var chill: int = 0
@export var shock: int = 0
@export var poison: int = 0
@export var glyph_slots: int = 3

const GLYPH_RARITY_COMMON := 0
const GLYPH_RARITY_RARE := 1
const GLYPH_RARITY_UNIQUE := 2
const CIRCLE_CAPTURE_MIN_DURATION := 0.12

@export var max_speed: float = 1500.0
@export var player_grace_seconds: float = 1.0
## Resting sprite modulate when not in post-launch grace (typed orbs tint here).
@export var base_modulate: Color = Color.WHITE
@export var grace_tint: Color = Color(0.7, 0.85, 1.0, 0.55)
@export var grace_ring_radius: float = 12.0
@export var grace_ring_width: float = 1.5
@export var grace_ring_bg_color: Color = Color(0.7, 0.85, 1.0, 0.35)
@export var grace_ring_fill_color: Color = Color(0.75, 0.9, 1.0, 0.9)
@export var arrow_length: float = 7.0
@export var rotate_heading: bool = true
@export var tether_speed_scale: float = 1.0
@export var tether_auto_release_turns: float = 2.0
## Radial pull-in speed when spiraling to the target orbit radius (px/s, game time).
@export var tether_radius_align_speed: float = 320.0
## Multiplier applied to speed and damage on Attack redirect and tether release (1.1 = +10%).
@export var tether_release_boost: float = 1.1
@export var bounce_sound: SoundEvent
@export var begin_tether_sound: SoundEvent
@export var release_tether_sound: SoundEvent

var socketed_glyphs: Array[Dictionary] = []

@onready var body_collision_shape: CollisionShape2D = %CollisionShape2D
@onready var heading: Node2D = %Heading
@onready var aim_arrow: Node2D = %AimArrow
@onready var damage_component: DamageComponent = %DamageComponent
@onready var hitbox_component: HitboxComponent = %HitboxComponent
@onready var orb_sprite: Sprite2D = %OrbSprite
@onready var orb_in_focus: Sprite2D = %OrbInFocus
@onready var trail_particles: GPUParticles2D = %TrailParticles

var state: OrbState = OrbState.FLYING
var aim_direction: Vector2 = Vector2.RIGHT
var _player: Node2D = null
var _grace_clear_msec: int = 0
var _in_focus: bool = false
## Per-player focus requests (instance_id → requester). Co-op: one player leaving range must not clear another's focus.
var _focus_requests: Dictionary = {}
## Player currently owning the redirect chevron preview (null = free).
var _redirect_preview_owner: Node = null
var _tether_player: Node2D = null
var _tether_radius: float = 32.0
var _tether_target_radius: float = 32.0
var _tether_angle: float = 0.0
var _tether_dir: float = 1.0
var _tether_swept: float = 0.0
var _opening_tether: bool = false
var _tether_broke_this_frame: bool = false
var _last_impact_frame: int = -1
var _last_fly_position: Vector2 = Vector2.ZERO
var _has_last_fly_position: bool = false
var _stall_ticks: int = 0
var _tether_damage_frame: int = -1
var _tether_damaged_ids: Dictionary = {}
var _resolved_hit_frame: int = -1
var _resolved_hit_cache: Dictionary = {}
var _grace_exception_body: CollisionObject2D = null
var _circle_captured: bool = false
var _capture_tween: Tween


func _ready() -> void:
	_load_stats_from_gamedata()
	_init_glyph_slots()
	add_to_group("orb")
	gravity_scale = 0.0
	lock_rotation = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	collision_layer = 8  # orb layer
	_apply_collision_mask()
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false

	var mat := PhysicsMaterial.new()
	# Script owns reflection via _integrate_forces; solver bounce would fight it.
	mat.bounce = 0.0
	mat.friction = 0.0
	physics_material_override = mat

	body_entered.connect(_on_body_entered)

	orb_in_focus.visible = false
	orb_sprite.visible = false
	aim_arrow.visible = false
	hitbox_component.monitoring = false
	freeze = true
	trail_particles.emitting = false
	set_process(false)
	_sync_damage_component()
	_apply_heading()


func _init_glyph_slots() -> void:
	socketed_glyphs.resize(glyph_slots)
	for i in glyph_slots:
		socketed_glyphs[i] = {}


## Apply the current bounce_off_entities flag to every live orb (HUD checkbox).
static func set_bounce_off_entities(value: bool) -> void:
	bounce_off_entities = value
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("orb"):
		if node is BlankOrb:
			(node as BlankOrb)._apply_collision_mask()


func _integrate_forces(physics_state: PhysicsDirectBodyState2D) -> void:
	if state != OrbState.FLYING or _circle_captured:
		return
	if aim_direction.length_squared() < 0.0001:
		aim_direction = Vector2.RIGHT

	var blocked_normal := Vector2.ZERO
	var contact_count: int = physics_state.get_contact_count()
	for i in contact_count:
		var normal: Vector2 = physics_state.get_contact_local_normal(i)
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		# Only count surfaces we are moving into (avoids sticky re-reflect jitter).
		if aim_direction.dot(normal) >= 0.0:
			continue
		blocked_normal += normal

		var collider: Object = physics_state.get_contact_collider_object(i)
		if _is_world_surface(collider):
			_spawn_world_impact(physics_state.get_contact_collider_position(i), normal)

	if blocked_normal.length_squared() > 0.0001:
		aim_direction = _safe_exit_direction(aim_direction, blocked_normal.normalized())

	physics_state.linear_velocity = aim_direction * speed


func _physics_process(delta: float) -> void:
	_tether_broke_this_frame = false
	_update_trail()

	match state:
		OrbState.FLYING:
			if _circle_captured:
				linear_velocity = Vector2.ZERO
				return
			# Keep constant speed; direction is owned by aim_direction / _integrate_forces.
			if aim_direction.length_squared() < 0.0001:
				aim_direction = Vector2.RIGHT
			linear_velocity = aim_direction * speed
			_apply_heading()
			# Clear instigator once grace window elapses.
			if _grace_clear_msec > 0 and Time.get_ticks_msec() >= _grace_clear_msec:
				_end_grace_visual()
			_update_never_still_watchdog(delta)
		OrbState.TETHERED:
			_update_tether(delta)
		OrbState.POSSESSED:
			pass


# ── Lifecycle API ─────────────────────────────────────────────────────────────

func begin_opening_tether(player: Node2D, radius: float = 32.0) -> void:
	if not is_instance_valid(player):
		return

	_opening_tether = true
	_tether_player = player
	_player = player
	_tether_radius = maxf(radius, 1.0)
	_tether_target_radius = _tether_radius  # opening: already on circle, no spiral
	_tether_angle = Vector2.UP.angle()  # spawn above player
	_tether_dir = 1.0  # CCW when starting from rest
	_tether_swept = 0.0

	state = OrbState.TETHERED
	freeze = true
	linear_velocity = Vector2.ZERO
	orb_sprite.visible = true
	clear_redirect_preview()
	damage_component.instigator = player
	_clear_grace_countdown()
	_clear_grace_exception()
	_apply_collision_mask()
	hitbox_component.monitoring = true
	set_in_focus(true)
	_update_tether_pose()
	if begin_tether_sound:
		AudioManager.play_at(begin_tether_sound, global_position)
	tethered.emit(player)


## Spawn already flying (opening volley extras). Skips opening tether; applies grace.
func begin_flight(direction: Vector2, instigator: Node = null) -> void:
	_opening_tether = false
	_clear_tether_vars()
	if direction.length_squared() > 0.0001:
		aim_direction = direction.normalized()
	elif aim_direction.length_squared() < 0.0001:
		aim_direction = Vector2.RIGHT

	state = OrbState.FLYING
	freeze = false
	orb_sprite.visible = true
	clear_redirect_preview()
	_apply_collision_mask()
	hitbox_component.monitoring = true
	set_in_focus(false)
	_separate_from_overlaps()
	linear_velocity = aim_direction * maxf(speed, 0.001)
	_reset_stall_tracker()
	_apply_heading()

	if is_instance_valid(instigator):
		damage_component.instigator = instigator
		_player = instigator as Node2D
		_begin_grace()
	else:
		damage_component.instigator = null
		_player = null
		_end_grace_visual()


func deflect(new_velocity: Vector2, instigator: Node) -> void:
	if state != OrbState.FLYING:
		return
	aim_direction = new_velocity.normalized() if new_velocity.length_squared() > 0.0001 else Vector2.RIGHT
	_apply_tether_release_boost()
	linear_velocity = aim_direction * speed
	if is_instance_valid(instigator):
		damage_component.instigator = instigator
		_player = instigator as Node2D
	_begin_grace()
	_apply_collision_mask()
	hitbox_component.monitoring = true
	_apply_heading()
	deflected.emit(instigator)


func begin_tether(player: Node2D, radius: float) -> void:
	if state != OrbState.FLYING:
		return
	if not is_instance_valid(player):
		return

	_opening_tether = false
	_tether_player = player
	_player = player

	var radial: Vector2 = global_position - player.global_position
	if radial.length_squared() < 0.0001:
		radial = Vector2.RIGHT * maxf(radius, 1.0)
	# Start orbiting at the actual capture distance; spiral to the target radius.
	_tether_radius = maxf(radial.length(), 1.0)
	_tether_target_radius = maxf(radius, 1.0)
	_tether_angle = radial.angle()

	# Preserve travel sense: positive cross means counterclockwise (dir = +1).
	var cross_z: float = radial.x * linear_velocity.y - radial.y * linear_velocity.x
	_tether_dir = 1.0 if cross_z >= 0.0 else -1.0
	_tether_swept = 0.0

	state = OrbState.TETHERED
	freeze = true
	linear_velocity = Vector2.ZERO
	damage_component.instigator = player
	_clear_grace_countdown()
	_clear_grace_exception()
	_apply_collision_mask()
	hitbox_component.monitoring = true
	set_in_focus(true)
	clear_redirect_preview()
	# Do NOT call _update_tether_pose() here — the orb is already at the correct position;
	# teleporting to _tether_target_radius on frame 0 would be a snap, not a spiral.
	aim_direction = _tether_tangent()
	_apply_heading()
	if begin_tether_sound:
		AudioManager.play_at(begin_tether_sound, global_position)
	tethered.emit(player)


func release_tether() -> void:
	if state != OrbState.TETHERED:
		return

	var was_opening := _opening_tether
	var tangent := _tether_tangent()
	_finish_tether_release(tangent, was_opening, _safe_tether_player(), true)


## Forced break from collision or dealing damage. Applies boost (unless opening).
func break_tether(exit_velocity: Vector2) -> void:
	if state != OrbState.TETHERED or _tether_broke_this_frame:
		return

	_tether_broke_this_frame = true
	var was_opening := _opening_tether
	var exit_dir := exit_velocity
	if exit_dir.length_squared() < 0.0001:
		exit_dir = _tether_tangent()
	if exit_dir.length_squared() < 0.0001:
		exit_dir = aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	_finish_tether_release(exit_dir, was_opening, _safe_tether_player(), false)


## Co-op focus: each player requests independently. Visible while tethered or any valid requester remains.
func set_focus_requested_by(requester: Node, value: bool) -> void:
	if requester == null:
		return
	var requester_id: int = requester.get_instance_id()
	if value:
		_focus_requests[requester_id] = requester
	else:
		_focus_requests.erase(requester_id)
	_refresh_focus_visual()


## Clears all requests, then optionally forces focus on (tethered) or off.
func set_in_focus(value: bool) -> void:
	_focus_requests.clear()
	# While tethered the focus indicator stays on regardless of caller requests.
	if state == OrbState.TETHERED:
		value = true
	_in_focus = value
	orb_in_focus.visible = _in_focus


func _refresh_focus_visual() -> void:
	_prune_focus_requests()
	if state == OrbState.TETHERED:
		_in_focus = true
	else:
		_in_focus = not _focus_requests.is_empty()
	orb_in_focus.visible = _in_focus


func _prune_focus_requests() -> void:
	var stale: Array = []
	for requester_id in _focus_requests:
		var requester: Node = _focus_requests[requester_id]
		if requester == null or not is_instance_valid(requester):
			stale.append(requester_id)
	for requester_id in stale:
		_focus_requests.erase(requester_id)


## Show chevrons along `direction` (player aim). Only while flying.
## `by` claims ownership so co-op players do not fight over rotation; null accepts any (legacy).
func set_redirect_preview(direction: Vector2, by: Node = null) -> void:
	if state != OrbState.FLYING:
		clear_redirect_preview()
		return
	if by != null:
		if (
			_redirect_preview_owner != null
			and is_instance_valid(_redirect_preview_owner)
			and _redirect_preview_owner != by
		):
			return
		_redirect_preview_owner = by
	var dir: Vector2 = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	aim_arrow.rotation = dir.angle()
	aim_arrow.modulate = base_modulate
	aim_arrow.visible = true
	aim_arrow.queue_redraw()


## Clear chevrons. With `by`, only clears if that player owns the preview; null always clears (state changes).
func clear_redirect_preview(by: Node = null) -> void:
	if by != null:
		if (
			_redirect_preview_owner != null
			and is_instance_valid(_redirect_preview_owner)
			and _redirect_preview_owner != by
		):
			return
	_redirect_preview_owner = null
	aim_arrow.visible = false


func is_flying() -> bool:
	return state == OrbState.FLYING and not _circle_captured


func get_display_name() -> String:
	var row: Variant = GameData.get_row(&"orbs", orb_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return String(orb_id)
	return String((row as Dictionary).get("name", orb_id))


func get_stat_snapshot() -> Dictionary:
	return {
		"damage": damage,
		"self_damage": self_damage,
		"splash": splash,
		"speed": speed,
		"weight": weight,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"glyph_drop": glyph_drop,
		"burn": burn,
		"chill": chill,
		"shock": shock,
		"poison": poison,
	}


func get_open_glyph_slots() -> int:
	return maxi(glyph_slots - socketed_count(), 0)


func socketed_count() -> int:
	var count: int = 0
	for entry in socketed_glyphs:
		if not entry.is_empty():
			count += 1
	return count


func has_glyph_at(index: int) -> bool:
	if index < 0 or index >= socketed_glyphs.size():
		return false
	return not socketed_glyphs[index].is_empty()


## Socket into the first empty slot. Prefer apply_glyph_at when the target index matters.
func apply_glyph(id: StringName, rarity: int) -> bool:
	for i in socketed_glyphs.size():
		if socketed_glyphs[i].is_empty():
			return apply_glyph_at(i, id, rarity)
	return false


func apply_glyph_at(index: int, id: StringName, rarity: int) -> bool:
	if index < 0 or index >= socketed_glyphs.size():
		return false
	if not socketed_glyphs[index].is_empty():
		return false

	var row: Variant = GameData.get_row(&"glyphs", id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return false

	var data: Dictionary = row
	var attr: StringName = StringName(String(data.get("attribute", "")))
	if attr.is_empty():
		return false

	var value: float = 0.0
	match rarity:
		GLYPH_RARITY_RARE:
			value = float(data.get("rarity_rare", 0.0))
		GLYPH_RARITY_UNIQUE:
			value = float(data.get("rarity_unique", 0.0))
		_:
			value = float(data.get("rarity_common", 0.0))

	if not _apply_glyph_attribute(attr, value):
		return false

	socketed_glyphs[index] = {"id": String(id), "rarity": rarity}
	return true


## Reverse a socketed glyph's stat and clear the slot (leaves a gap). Returns the entry, or {} on failure.
func remove_glyph(slot_index: int) -> Dictionary:
	if not has_glyph_at(slot_index):
		return {}

	var entry: Dictionary = socketed_glyphs[slot_index]
	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", GLYPH_RARITY_COMMON))
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row != null and typeof(row) == TYPE_DICTIONARY:
		var data: Dictionary = row
		var attr: StringName = StringName(String(data.get("attribute", "")))
		var value: float = 0.0
		match rarity:
			GLYPH_RARITY_RARE:
				value = float(data.get("rarity_rare", 0.0))
			GLYPH_RARITY_UNIQUE:
				value = float(data.get("rarity_unique", 0.0))
			_:
				value = float(data.get("rarity_common", 0.0))
		if not attr.is_empty():
			_apply_glyph_attribute(attr, -value)

	socketed_glyphs[slot_index] = {}
	return entry


func _apply_glyph_attribute(attr: StringName, value: float) -> bool:
	var key: String = String(attr)
	var sync_damage: bool = false

	match key:
		"damage":
			damage = maxf(damage + value, 0.0)
			sync_damage = true
		"self_damage":
			self_damage = maxf(self_damage + value, 0.0)
		"splash":
			splash = clampf(splash + value, 0.0, 1.0)
		"speed":
			speed = maxf(speed + value, 0.0)
		"weight":
			weight = maxf(weight + value, 0.0)
		"crit_chance":
			crit_chance = clampf(crit_chance + value, 0.0, 1.0)
		"crit_damage":
			crit_damage = crit_damage + value
		"glyph_drop":
			glyph_drop = clampf(glyph_drop + value, 0.0, 1.0)
		"burn":
			burn += int(value)
		"chill":
			chill += int(value)
		"shock":
			shock += int(value)
		"poison":
			poison += int(value)
		_:
			return false

	if sync_damage:
		_sync_damage_component()
	return true


func begin_circle_capture(center: Vector2, suck_speed: float, on_finished: Callable) -> void:
	if state != OrbState.FLYING or _circle_captured:
		return

	_circle_captured = true
	linear_velocity = Vector2.ZERO
	trail_particles.emitting = false
	clear_redirect_preview()
	set_in_focus(false)
	_focus_requests.clear()
	orb_in_focus.visible = false
	# DepositArea body/area_entered runs while physics queries flush; freeze and
	# Area2D monitoring cannot change until that flush finishes.
	call_deferred("_begin_circle_capture_deferred", center, suck_speed, on_finished)


func _begin_circle_capture_deferred(center: Vector2, suck_speed: float, on_finished: Callable) -> void:
	if not is_inside_tree() or not _circle_captured:
		return

	freeze = true
	hitbox_component.monitoring = false

	if _capture_tween != null and _capture_tween.is_valid():
		_capture_tween.kill()

	var distance: float = global_position.distance_to(center)
	var duration: float = maxf(CIRCLE_CAPTURE_MIN_DURATION, distance / maxf(suck_speed, 1.0))
	_capture_tween = create_tween()
	_capture_tween.set_trans(Tween.TRANS_CUBIC)
	_capture_tween.set_ease(Tween.EASE_IN)
	_capture_tween.tween_property(self, "global_position", center, duration)
	_capture_tween.tween_callback(func() -> void:
		_capture_tween = null
		if on_finished.is_valid():
			on_finished.call()
	)


func release_from_circle(direction: Vector2) -> void:
	_circle_captured = false
	if _capture_tween != null and _capture_tween.is_valid():
		_capture_tween.kill()
		_capture_tween = null

	var exit_dir: Vector2 = direction
	if exit_dir.length_squared() < 0.0001:
		exit_dir = Vector2.RIGHT
	begin_flight(exit_dir, null)


## Park this orb at the circle as if it had just finished a capture suck-in (used by Transform swap).
func assume_circle_capture(center: Vector2) -> void:
	_circle_captured = true
	if _capture_tween != null and _capture_tween.is_valid():
		_capture_tween.kill()
		_capture_tween = null
	state = OrbState.FLYING
	freeze = true
	linear_velocity = Vector2.ZERO
	global_position = center
	orb_sprite.visible = true
	trail_particles.emitting = false
	clear_redirect_preview()
	set_in_focus(false)
	_focus_requests.clear()
	orb_in_focus.visible = false
	hitbox_component.monitoring = false
	_apply_heading()


func is_tethered() -> bool:
	return state == OrbState.TETHERED


func is_possessed() -> bool:
	return state == OrbState.POSSESSED


func get_tether_player() -> Node2D:
	return _safe_tether_player()


## Optional hook for typed orbs: return false to skip HealthComponent damage on hitbox poll.
func should_apply_hitbox_damage(_victim: Node) -> bool:
	return true


## Optional hook for typed orbs: called after a successful hitbox hit (HP applied or skipped).
func on_hitbox_hit(victim: Node) -> void:
	if victim == null or not is_instance_valid(victim):
		return

	var resolved: Dictionary = resolve_hitbox_damage(victim)
	if victim.is_in_group("enemies"):
		_apply_weight_knockback(victim)
		_apply_status_stacks(victim)
	_apply_splash(victim, resolved)


func resolve_hitbox_damage(victim: Node) -> Dictionary:
	var frame: int = Engine.get_physics_frames()
	if frame != _resolved_hit_frame:
		_resolved_hit_cache.clear()
		_resolved_hit_frame = frame

	var victim_id: int = victim.get_instance_id()
	if _resolved_hit_cache.has(victim_id):
		return _resolved_hit_cache[victim_id]

	var base_amount: float = damage
	if victim.is_in_group("player"):
		base_amount = self_damage

	var kind: HealthComponent.DamageKind = HealthComponent.DamageKind.STANDARD
	var amount: float = base_amount
	if crit_chance > 0.0 and randf() < crit_chance:
		amount *= crit_damage
		kind = HealthComponent.DamageKind.CRIT

	var result: Dictionary = {"amount": amount, "kind": kind}
	_resolved_hit_cache[victim_id] = result
	return result


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
	state = OrbState.FLYING
	freeze = false
	_apply_collision_mask()
	_separate_from_overlaps()
	# Always launch at full speed — never leave the orb parked.
	linear_velocity = aim_direction * maxf(speed, 0.001)
	_reset_stall_tracker()
	hitbox_component.monitoring = true
	if is_instance_valid(by):
		damage_component.instigator = by
		_player = by as Node2D
		_begin_grace()
	else:
		damage_component.instigator = null
		_player = null
		_end_grace_visual()
	_opening_tether = false
	_clear_tether_vars()
	set_in_focus(false)
	clear_redirect_preview()
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


func _begin_grace() -> void:
	_grace_clear_msec = Time.get_ticks_msec() + int(player_grace_seconds * 1000.0)
	_set_grace_exception(_player)
	set_process(true)
	_update_grace_visual()
	queue_redraw()


## Clear countdown visual/timer but keep instigator (used while tethered).
func _clear_grace_countdown() -> void:
	_grace_clear_msec = 0
	orb_sprite.modulate = base_modulate
	set_process(false)
	queue_redraw()


## Clear instigator and stop the post-release grace visual.
func _end_grace_visual() -> void:
	damage_component.instigator = null
	_clear_grace_exception()
	_clear_grace_countdown()


func _set_grace_exception(body: Node) -> void:
	_clear_grace_exception()
	if body is CollisionObject2D and is_instance_valid(body):
		_grace_exception_body = body as CollisionObject2D
		add_collision_exception_with(_grace_exception_body)


func _clear_grace_exception() -> void:
	if _grace_exception_body != null and is_instance_valid(_grace_exception_body):
		remove_collision_exception_with(_grace_exception_body)
	_grace_exception_body = null


func _apply_collision_mask() -> void:
	if state == OrbState.FLYING and bounce_off_entities:
		collision_mask = PHYSICS_LAYER_WORLD | PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_ENEMY
	else:
		collision_mask = PHYSICS_LAYER_WORLD


func _get_grace_remaining_fraction() -> float:
	if _grace_clear_msec <= 0 or player_grace_seconds <= 0.0:
		return 0.0
	var remaining_msec: int = _grace_clear_msec - Time.get_ticks_msec()
	if remaining_msec <= 0:
		return 0.0
	return clampf(float(remaining_msec) / (player_grace_seconds * 1000.0), 0.0, 1.0)


func _update_grace_visual() -> void:
	var fraction: float = _get_grace_remaining_fraction()
	if fraction <= 0.0:
		orb_sprite.modulate = base_modulate
		return
	orb_sprite.modulate = grace_tint.lerp(base_modulate, 1.0 - fraction)


func _process(_delta: float) -> void:
	if _grace_clear_msec <= 0:
		set_process(false)
		return
	if Time.get_ticks_msec() >= _grace_clear_msec:
		_end_grace_visual()
		return
	_update_grace_visual()
	queue_redraw()


func _draw() -> void:
	var fraction: float = _get_grace_remaining_fraction()
	if fraction <= 0.0:
		return
	var bg := Color(grace_ring_bg_color, grace_ring_bg_color.a * fraction)
	var fill := Color(grace_ring_fill_color, grace_ring_fill_color.a * fraction)
	draw_arc(Vector2.ZERO, grace_ring_radius, 0.0, TAU, 32, bg, grace_ring_width)
	var start_angle: float = -PI / 2.0
	draw_arc(
		Vector2.ZERO,
		grace_ring_radius,
		start_angle,
		start_angle + TAU * fraction,
		32,
		fill,
		grace_ring_width
	)


func _update_tether(delta: float) -> void:
	if not is_instance_valid(_tether_player):
		# Owner freed (e.g. player died) — launch along last tangent; do not pass freed refs.
		release_tether()
		return

	# Spiral: move current radius toward the target orbit radius each tick.
	var next_radius: float = move_toward(_tether_radius, _tether_target_radius, tether_radius_align_speed * delta)

	var angular_speed: float = (speed * tether_speed_scale) / maxf(_tether_radius, 1.0)
	var step: float = angular_speed * delta
	var next_angle: float = _tether_angle + step * _tether_dir
	var next_pos: Vector2 = (
		_tether_player.global_position + Vector2.RIGHT.rotated(next_angle) * next_radius
	)

	if _probe_tether_collision(global_position, next_pos, next_angle):
		return

	_tether_radius = next_radius
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
	params.collision_mask = PHYSICS_LAYER_WORLD
	var excludes: Array[RID] = [get_rid()]
	if is_instance_valid(_tether_player) and _tether_player is CollisionObject2D:
		excludes.append((_tether_player as CollisionObject2D).get_rid())
	params.exclude = excludes
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
	var damage_target: Node = entity_root if entity_root != null else body
	_try_apply_orb_damage(damage_target)

	var tangent: Vector2 = _tether_tangent_at(next_angle)
	var normal: Vector2 = _rest_normal_at(global_position)
	if normal.length_squared() < 0.0001:
		normal = (global_position - _collider_global_position(body)).normalized()
	if normal.length_squared() < 0.0001:
		normal = -tangent

	var exit_velocity: Vector2 = _safe_exit_direction(tangent, normal)

	if _is_world_surface(body):
		_spawn_world_impact(global_position, normal)

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


## Apply orb damage once per victim per physics frame (flying body + tether probe/hitbox can both fire).
func _try_apply_orb_damage(victim_root: Node) -> bool:
	if not is_instance_valid(victim_root):
		return false
	if damage_component.damage <= 0.0:
		return false
	if is_instance_valid(damage_component.instigator) and damage_component.instigator == victim_root:
		return false

	var comp = victim_root.get("COMPONENTS")
	if comp == null or not comp.has(HealthComponent):
		return false

	var frame: int = Engine.get_physics_frames()
	if frame != _tether_damage_frame:
		_tether_damage_frame = frame
		_tether_damaged_ids.clear()

	var victim_id: int = victim_root.get_instance_id()
	if _tether_damaged_ids.has(victim_id):
		return false

	var amount: float = damage_component.damage * (1.0 + 0.05 * weight)
	var applied: bool = comp[HealthComponent].take_damage(
		amount,
		damage_component.damage_kind,
		self
	)
	if applied:
		_tether_damaged_ids[victim_id] = true
	return applied


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
	_tether_target_radius = 32.0
	_tether_angle = 0.0
	_tether_dir = 1.0
	_tether_swept = 0.0


func _apply_tether_release_boost() -> void:
	speed = minf(speed * tether_release_boost, max_speed)
	damage *= tether_release_boost
	self_damage *= tether_release_boost
	_sync_damage_component()


func _apply_heading() -> void:
	if rotate_heading:
		heading.rotation = aim_direction.angle() + PI / 2.0
	# AimArrow rotation is owned by set_redirect_preview (player aim), not flight direction.


func _update_trail() -> void:
	var moving := (
		state == OrbState.TETHERED
		or (state == OrbState.FLYING and not freeze and not _circle_captured)
	)
	trail_particles.emitting = moving
	if not moving:
		return

	var travel_dir: Vector2 = _tether_tangent() if state == OrbState.TETHERED else aim_direction
	if travel_dir.length_squared() > 0.0001:
		trail_particles.rotation = travel_dir.angle() + PI

	trail_particles.amount_ratio = clampf(speed / 180.0, 0.5, 2.5)


func _is_world_surface(collider: Object) -> bool:
	var collision_object := _resolve_collision_object(collider)
	if collision_object == null:
		return false
	return (collision_object.collision_layer & PHYSICS_LAYER_WORLD) != 0


func _resolve_collision_object(collider: Object) -> CollisionObject2D:
	if collider is CollisionObject2D:
		return collider as CollisionObject2D
	if collider is Node:
		var node: Node = collider as Node
		while node != null:
			if node is CollisionObject2D:
				return node as CollisionObject2D
			node = node.get_parent()
	return null


func _make_body_query_params(at_pos: Vector2) -> PhysicsShapeQueryParameters2D:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = body_collision_shape.shape
	params.transform = Transform2D(0.0, at_pos)
	params.collision_mask = PHYSICS_LAYER_WORLD
	params.exclude = [get_rid()]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return params


func _safe_exit_direction(travel_dir: Vector2, normal: Vector2) -> Vector2:
	var travel: Vector2 = travel_dir
	if travel.length_squared() < 0.0001:
		travel = Vector2.RIGHT
	else:
		travel = travel.normalized()

	if normal.length_squared() < 0.0001:
		return travel
	var n: Vector2 = normal.normalized()

	var exit: Vector2 = travel
	if travel.dot(n) < 0.0:
		exit = travel.bounce(n)
		if exit.length_squared() < 0.0001:
			exit = -travel

	if exit.length_squared() < 0.0001:
		exit = n
	else:
		exit = exit.normalized()

	if exit.dot(n) <= OUTBOUND_DOT_MIN:
		var slid: Vector2 = exit.slide(n)
		if slid.length_squared() > 0.0001:
			exit = (slid.normalized() + n).normalized()
		else:
			exit = n

	if exit.length_squared() < 0.0001:
		return Vector2.RIGHT
	return exit.normalized()


func _rest_normal_at(pos: Vector2) -> Vector2:
	if body_collision_shape.shape == null:
		return Vector2.ZERO
	var rest: Dictionary = get_world_2d().direct_space_state.get_rest_info(_make_body_query_params(pos))
	if rest.is_empty():
		return Vector2.ZERO
	var n: Vector2 = rest.get("normal", Vector2.ZERO)
	if n.length_squared() < 0.0001:
		return Vector2.ZERO
	return n.normalized()


func _separate_from_overlaps() -> void:
	if body_collision_shape.shape == null:
		return

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var pushed: float = 0.0
	for _i in SEPARATE_MAX_ITERS:
		if pushed >= SEPARATE_MAX_PUSH_PX:
			return
		var params := _make_body_query_params(global_position)
		var overlaps: Array[Dictionary] = space.intersect_shape(params, 4)
		if overlaps.is_empty():
			return

		var escape: Vector2 = Vector2.ZERO
		var rest: Dictionary = space.get_rest_info(params)
		if not rest.is_empty():
			escape = rest.get("normal", Vector2.ZERO)
		if escape.length_squared() < 0.0001:
			for hit in overlaps:
				var collider: Object = hit.get("collider")
				if collider is Node2D:
					var from_c: Vector2 = global_position - (collider as Node2D).global_position
					if from_c.length_squared() > 0.0001:
						escape += from_c.normalized()
		if escape.length_squared() < 0.0001:
			escape = aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
		escape = escape.normalized()

		var step_px: float = minf(SEPARATE_STEP_PX, SEPARATE_MAX_PUSH_PX - pushed)
		global_position += escape * step_px
		pushed += step_px


func _reset_stall_tracker() -> void:
	_has_last_fly_position = false
	_stall_ticks = 0
	_last_fly_position = Vector2.ZERO


func _update_never_still_watchdog(delta: float) -> void:
	if not _has_last_fly_position:
		_last_fly_position = global_position
		_has_last_fly_position = true
		_stall_ticks = 0
		return

	var expected: float = speed * delta
	var traveled: float = global_position.distance_to(_last_fly_position)
	_last_fly_position = global_position

	if expected > 0.0001 and traveled < expected * STALL_TRAVEL_FRACTION:
		_stall_ticks += 1
	else:
		_stall_ticks = 0
		return

	if _stall_ticks < STALL_TICKS_BEFORE_UNSTICK:
		return

	_stall_ticks = 0
	_separate_from_overlaps()
	var escape: Vector2 = _rest_normal_at(global_position)
	if escape.length_squared() > 0.0001:
		aim_direction = _safe_exit_direction(aim_direction, escape)
	else:
		aim_direction = -aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	if aim_direction.length_squared() < 0.0001:
		aim_direction = Vector2.RIGHT
	linear_velocity = aim_direction * speed
	_last_fly_position = global_position


func _spawn_world_impact(position: Vector2, normal: Vector2) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _last_impact_frame:
		return
	_last_impact_frame = frame

	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	OrbImpactEffect.play_at(parent, position, normal)


func _on_body_entered(body: Node) -> void:
	if state != OrbState.FLYING:
		return
	if bounce_sound:
		AudioManager.play_at(bounce_sound, global_position)

	# Bounce direction is owned by _integrate_forces (true contact normals).
	# World solids (walls / rocks / breakables) take body-contact damage.
	# Player / enemies use hitbox poll only (skip here to avoid double-hit when bouncing).
	if body.is_in_group("player") or body.is_in_group("enemies"):
		return
	var victim_root: Node = _resolve_entity_root(body)
	if victim_root != null:
		if victim_root.is_in_group("player") or victim_root.is_in_group("enemies"):
			return
		_try_apply_orb_damage(victim_root)


func _load_stats_from_gamedata() -> void:
	var row: Variant = GameData.get_row(&"orbs", orb_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return

	var data: Dictionary = row
	if data.has("damage"):
		damage = float(data["damage"])
	if data.has("self_damage"):
		self_damage = float(data["self_damage"])
	if data.has("splash"):
		splash = float(data["splash"])
	if data.has("speed"):
		speed = float(data["speed"])
	if data.has("weight"):
		weight = float(data["weight"])
	if data.has("crit_chance"):
		crit_chance = float(data["crit_chance"])
	if data.has("crit_damage"):
		crit_damage = float(data["crit_damage"])
	if data.has("glyph_drop"):
		glyph_drop = float(data["glyph_drop"])
	if data.has("burn"):
		burn = int(data["burn"])
	if data.has("chill"):
		chill = int(data["chill"])
	if data.has("shock"):
		shock = int(data["shock"])
	if data.has("poison"):
		poison = int(data["poison"])


func _sync_damage_component() -> void:
	if damage_component:
		damage_component.damage = damage


func _apply_splash(direct_victim: Node, resolved: Dictionary) -> void:
	if splash <= 0.0:
		return

	var splash_amount: float = splash * float(resolved.get("amount", 0.0))
	if splash_amount <= 0.0:
		return
	if not is_inside_tree():
		return

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SPLASH_RADIUS
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collision_mask = PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_ENEMY
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var damaged_ids: Dictionary = {}
	var direct_id: int = direct_victim.get_instance_id()
	damaged_ids[direct_id] = true

	for hit in space.intersect_shape(params, 32):
		var collider: Object = hit.get("collider")
		if collider == null:
			continue
		var victim_root: Node = _resolve_entity_root(collider as Node)
		if victim_root == null or not is_instance_valid(victim_root):
			continue
		var victim_id: int = victim_root.get_instance_id()
		if damaged_ids.has(victim_id):
			continue
		damaged_ids[victim_id] = true

		var comp = victim_root.get("COMPONENTS")
		if comp == null or not comp.has(HealthComponent):
			continue

		var amount: float = splash_amount
		var kind: HealthComponent.DamageKind = HealthComponent.DamageKind.STANDARD
		if victim_root.is_in_group("player"):
			amount = splash * self_damage
		(comp[HealthComponent] as HealthComponent).take_damage(amount, kind, self)


func _apply_weight_knockback(victim: Node) -> void:
	if weight <= 0.0:
		return

	var comp = victim.get("COMPONENTS")
	if comp == null or not comp.has(KnockbackComponent):
		return

	var direction: Vector2 = Vector2.ZERO
	if victim is Node2D:
		direction = (victim as Node2D).global_position - global_position
	if direction.length_squared() < 0.0001:
		direction = aim_direction
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	var collision_damage: float = weight
	(comp[KnockbackComponent] as KnockbackComponent).push_distance(
		direction,
		weight,
		collision_damage
	)


func _apply_status_stacks(victim: Node) -> void:
	var comp = victim.get("COMPONENTS")
	if comp == null or not comp.has(StatusComponent):
		return

	var status: StatusComponent = comp[StatusComponent] as StatusComponent
	if poison > 0:
		status.add_stacks(StatusComponent.StatusId.POISON, poison, self)
	if burn > 0:
		status.add_stacks(StatusComponent.StatusId.BURN, burn, self)
	if chill > 0:
		status.add_stacks(StatusComponent.StatusId.CHILL, chill, self)
	if shock > 0:
		status.add_stacks(StatusComponent.StatusId.SHOCK, shock, self)
