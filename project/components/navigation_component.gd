class_name NavigationComponent extends NavigationAgent2D

enum SlotPreference { ANY, FORWARD }

const ENEMY_GROUP := &"enemies"
const MOVE_SPEED_FOR_ANCHOR := 10.0
const HEADING_SWING_RESET := TAU / 3.0 ## 120 degrees

@export var movement_component: MovementComponent
@export var knockback_component: KnockbackComponent
@export var target_group: String = "player"
@export var repath_interval: float = 0.1
## How often to re-pick the nearest player (co-op). Separate from path refresh.
@export var retarget_interval: float = 0.5
## Prefer keeping the current target unless another player is this many px closer.
@export var retarget_hysteresis: float = 32.0
@export var stuck_speed_threshold: float = 8.0
@export var stuck_distance_threshold: float = 3.0
@export var stuck_timeout: float = 0.25
## Packs of 2+ path to ring slots around the target instead of stacking on their feet.
@export var surround_enabled: bool = true
## Distance from the player to each surround slot (keep inside attack_range).
@export var slot_radius: float = 28.0
## How long an enemy keeps its slot before it may be reassigned.
@export var slot_stick_time: float = 1.5
## FORWARD prefers the cutoff slot ahead of the player's movement.
@export var slot_preference: SlotPreference = SlotPreference.ANY

## player instance_id -> last pack refresh msec
static var _pack_refresh_msec: Dictionary = {}
## player instance_id -> ring forward angle (radians)
static var _ring_anchor_angle: Dictionary = {}

var _target: Node2D = null
var _repath_cooldown: float = 0.0
var _retarget_cooldown: float = 0.0
var _stuck_anchor_position: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _chasing: bool = true
var _saved_avoidance: bool = true
var _slot_index: int = -1
var _slot_angle: float = 0.0
var _slot_assigned_msec: int = 0


func set_chasing(enabled: bool) -> void:
	if enabled and not _has_group_target():
		enabled = false
	_chasing = enabled
	set_physics_process(enabled)
	if enabled:
		avoidance_enabled = _saved_avoidance
		_retarget_cooldown = 0.0
		_acquire_target()
	else:
		_saved_avoidance = avoidance_enabled
		avoidance_enabled = false
		velocity = Vector2.ZERO
		_clear_slot()
		if owner is CharacterBody2D:
			(owner as CharacterBody2D).velocity = Vector2.ZERO


func _ready() -> void:
	assert(owner is CharacterBody2D, "NavigationComponent owner must be CharacterBody2D")
	var body := owner as CharacterBody2D
	var parent_node := get_parent() as Node2D
	assert(parent_node != null, "NavigationComponent parent must be Node2D")
	assert(
		parent_node.global_position.is_equal_approx(body.global_position),
		"NavigationComponent parent must sit at the entity origin"
	)
	velocity_computed.connect(_on_velocity_computed)
	max_speed = movement_component.move_speed
	_stuck_anchor_position = body.global_position
	_saved_avoidance = avoidance_enabled

	await get_tree().physics_frame
	if _chasing:
		_acquire_target()


func _physics_process(delta: float) -> void:
	if not _chasing:
		return
	var body := owner as CharacterBody2D
	if knockback_component.is_active():
		_reset_stuck_state(body.global_position)
		return

	_retarget_cooldown -= delta
	if not is_instance_valid(_target) or _retarget_cooldown <= 0.0:
		_retarget_cooldown = retarget_interval
		_acquire_target()

	if not is_instance_valid(_target):
		_reset_stuck_state(body.global_position)
		set_chasing(false)
		return

	_repath_cooldown -= delta
	if _repath_cooldown <= 0.0:
		_repath_cooldown = repath_interval
		target_position = _goal_position()

	var desired_velocity := _desired_velocity()
	if _update_stuck_state(body.global_position, desired_velocity, delta):
		_force_repath()
		movement_component.stop()
		return

	if avoidance_enabled:
		velocity = desired_velocity
	else:
		movement_component.move_velocity(desired_velocity)


func _desired_velocity() -> Vector2:
	var body := owner as CharacterBody2D
	var origin: Vector2 = body.global_position
	var target_position_to_use := Vector2.ZERO
	var has_target_position := false
	var goal: Vector2 = _goal_position()

	if is_target_reachable():
		if not is_navigation_finished():
			var next_path_position := get_next_path_position()
			if next_path_position.distance_squared_to(origin) > 0.0001:
				target_position_to_use = next_path_position
				has_target_position = true
		elif not _has_slot() and goal.distance_squared_to(origin) > 0.0001:
			# Lone chase: close the last few px onto the player's feet.
			target_position_to_use = goal
			has_target_position = true
		# Surround: navigation finished on the slot — hold position (zero velocity).
	elif _repath_cooldown > 0.0 and goal.distance_squared_to(origin) > 0.0001:
		target_position_to_use = goal
		has_target_position = true

	if not has_target_position:
		return Vector2.ZERO

	var desired_direction := target_position_to_use - origin
	if desired_direction.length_squared() <= 0.0001:
		return Vector2.ZERO

	return desired_direction.normalized() * movement_component.move_speed


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if not _chasing:
		return
	movement_component.move_velocity(safe_velocity)


func _has_group_target() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group(target_group):
		if node is Node2D and is_instance_valid(node):
			return true
	return false


func _acquire_target() -> void:
	var body := owner as CharacterBody2D
	var origin: Vector2 = body.global_position
	var closest: Node2D = null
	var best_dist: float = INF

	for node in get_tree().get_nodes_in_group(target_group):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var candidate: Node2D = node as Node2D
		var dist: float = origin.distance_to(candidate.global_position)
		if dist < best_dist:
			best_dist = dist
			closest = candidate

	if closest == null:
		_target = null
		_clear_slot()
		return

	# Hysteresis: keep current target unless another is meaningfully closer.
	if is_instance_valid(_target) and _target != closest:
		var current_dist: float = origin.distance_to(_target.global_position)
		if best_dist + retarget_hysteresis >= current_dist:
			_repath_cooldown = 0.0
			_maybe_refresh_surround()
			return

	_target = closest
	_repath_cooldown = 0.0
	_maybe_refresh_surround()


func _update_stuck_state(current_position: Vector2, desired_velocity: Vector2, delta: float) -> bool:
	if desired_velocity.length() < stuck_speed_threshold:
		_reset_stuck_state(current_position)
		return false

	if current_position.distance_to(_stuck_anchor_position) > stuck_distance_threshold:
		_reset_stuck_state(current_position)
		return false

	_stuck_time += delta
	if _stuck_time < stuck_timeout:
		return false

	_reset_stuck_state(current_position)
	return true


func _force_repath() -> void:
	_repath_cooldown = 0.0
	if is_instance_valid(_target):
		target_position = _goal_position()


func _reset_stuck_state(current_position: Vector2) -> void:
	_stuck_anchor_position = current_position
	_stuck_time = 0.0


func _has_slot() -> bool:
	return _slot_index >= 0 and surround_enabled


func _goal_position() -> Vector2:
	if not is_instance_valid(_target):
		return Vector2.ZERO
	if _has_slot():
		return _target.global_position + Vector2.from_angle(_slot_angle) * slot_radius
	return _target.global_position


func _clear_slot() -> void:
	_slot_index = -1
	_slot_angle = 0.0
	_slot_assigned_msec = 0


func _maybe_refresh_surround() -> void:
	if not surround_enabled or not is_instance_valid(_target) or not _chasing:
		_clear_slot()
		return
	if not is_inside_tree():
		return

	var player_id: int = _target.get_instance_id()
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(_pack_refresh_msec.get(player_id, -1_000_000_000))
	var interval_msec: int = int(retarget_interval * 1000.0)
	if now_msec - last_msec < interval_msec:
		return
	_pack_refresh_msec[player_id] = now_msec
	_assign_pack_slots(_target)


func _assign_pack_slots(player: Node2D) -> void:
	var pack: Array[NavigationComponent] = []
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if not is_instance_valid(node):
			continue
		var nav: NavigationComponent = _navigation_from_enemy(node)
		if nav == null:
			continue
		if not nav.surround_enabled or not nav._chasing:
			continue
		if not is_instance_valid(nav._target) or nav._target != player:
			continue
		pack.append(nav)

	var pack_size: int = pack.size()
	if pack_size < 2:
		for nav in pack:
			nav._clear_slot()
		return

	var player_id: int = player.get_instance_id()
	var new_anchor: float = _compute_ring_anchor(player, player_id, pack)
	var old_anchor: float = float(_ring_anchor_angle.get(player_id, new_anchor))
	var swung: bool = absf(angle_difference(old_anchor, new_anchor)) > HEADING_SWING_RESET
	_ring_anchor_angle[player_id] = new_anchor

	if swung:
		for nav in pack:
			nav._clear_slot()

	var slot_angles: PackedFloat32Array = PackedFloat32Array()
	slot_angles.resize(pack_size)
	var step: float = TAU / float(pack_size)
	for i in pack_size:
		slot_angles[i] = new_anchor + step * float(i)

	var taken: Array[bool] = []
	taken.resize(pack_size)
	taken.fill(false)
	var assigned: Dictionary = {} ## NavigationComponent -> true
	var now_msec: int = Time.get_ticks_msec()

	# FORWARD claimers take slot 0 (cutoff): sticky holder first, else closest by angle.
	var forward_claimers: Array[NavigationComponent] = []
	for nav in pack:
		if nav.slot_preference == SlotPreference.FORWARD:
			forward_claimers.append(nav)

	var forward_assigned: bool = false
	for nav in forward_claimers:
		if nav._slot_index == 0 and _is_slot_sticky(nav, pack_size, now_msec):
			_apply_slot(nav, 0, slot_angles[0], now_msec, true)
			taken[0] = true
			assigned[nav] = true
			forward_assigned = true
			break

	if not forward_assigned and not forward_claimers.is_empty():
		var best_forward: NavigationComponent = null
		var best_delta: float = INF
		for nav in forward_claimers:
			var delta_ang: float = absf(angle_difference(nav._angle_around(player), slot_angles[0]))
			if delta_ang < best_delta:
				best_delta = delta_ang
				best_forward = nav
		if best_forward != null:
			_apply_slot(best_forward, 0, slot_angles[0], now_msec, false)
			taken[0] = true
			assigned[best_forward] = true

	# Sticky keeps for remaining enemies.
	for nav in pack:
		if assigned.has(nav):
			continue
		# Pack may have shrunk since this slot was assigned (index no longer valid).
		if nav._slot_index < 0 or nav._slot_index >= pack_size:
			continue
		if taken[nav._slot_index]:
			continue
		if not _is_slot_sticky(nav, pack_size, now_msec):
			continue
		_apply_slot(nav, nav._slot_index, slot_angles[nav._slot_index], now_msec, true)
		taken[nav._slot_index] = true
		assigned[nav] = true

	# Remaining: nearest free slot by angle around the player.
	for nav in pack:
		if assigned.has(nav):
			continue
		var enemy_angle: float = nav._angle_around(player)
		var best_i: int = -1
		var best_delta: float = INF
		for i in pack_size:
			if taken[i]:
				continue
			var delta_ang: float = absf(angle_difference(enemy_angle, slot_angles[i]))
			if delta_ang < best_delta:
				best_delta = delta_ang
				best_i = i
		if best_i >= 0:
			_apply_slot(nav, best_i, slot_angles[best_i], now_msec, false)
			taken[best_i] = true
			assigned[nav] = true
		else:
			nav._clear_slot()


func _is_slot_sticky(nav: NavigationComponent, pack_size: int, now_msec: int) -> bool:
	if nav._slot_index < 0 or nav._slot_index >= pack_size:
		return false
	var stick_msec: int = int(nav.slot_stick_time * 1000.0)
	return now_msec - nav._slot_assigned_msec < stick_msec


func _apply_slot(
	nav: NavigationComponent,
	index: int,
	angle: float,
	now_msec: int,
	keep_assign_time: bool
) -> void:
	nav._slot_index = index
	nav._slot_angle = angle
	if not keep_assign_time or nav._slot_assigned_msec <= 0:
		nav._slot_assigned_msec = now_msec
	nav._repath_cooldown = 0.0


func _angle_around(player: Node2D) -> float:
	var origin: Vector2 = (owner as Node2D).global_position
	var delta: Vector2 = origin - player.global_position
	if delta.length_squared() < 0.0001:
		return 0.0
	return delta.angle()


func _compute_ring_anchor(
	player: Node2D,
	player_id: int,
	pack: Array[NavigationComponent]
) -> float:
	var velocity: Vector2 = Vector2.ZERO
	if player is CharacterBody2D:
		velocity = (player as CharacterBody2D).velocity
	if velocity.length() >= MOVE_SPEED_FOR_ANCHOR:
		return velocity.angle()
	if _ring_anchor_angle.has(player_id):
		return float(_ring_anchor_angle[player_id])
	# Standing player, first surround: face from the densest approach (first pack member).
	if not pack.is_empty():
		return pack[0]._angle_around(player)
	return 0.0


func _navigation_from_enemy(enemy: Node) -> NavigationComponent:
	var raw: Variant = enemy.get("COMPONENTS")
	if raw == null or not (raw is Dictionary):
		return null
	var components: Dictionary = raw as Dictionary
	return components.get(NavigationComponent) as NavigationComponent
