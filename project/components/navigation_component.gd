class_name NavigationComponent extends NavigationAgent2D

@export var movement_component: MovementComponent
@export var knockback_component: KnockbackComponent
@export var target_group: String = "player"
@export var repath_interval: float = 0.1
@export var stuck_speed_threshold: float = 8.0
@export var stuck_distance_threshold: float = 3.0
@export var stuck_timeout: float = 0.25

var _target: Node2D = null
var _repath_cooldown: float = 0.0
var _stuck_anchor_position: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0
var _chasing: bool = true
var _saved_avoidance: bool = true


func set_chasing(enabled: bool) -> void:
	_chasing = enabled
	set_physics_process(enabled)
	if enabled:
		avoidance_enabled = _saved_avoidance
		_acquire_target()
	else:
		_saved_avoidance = avoidance_enabled
		avoidance_enabled = false
		velocity = Vector2.ZERO


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

	if not is_instance_valid(_target):
		_acquire_target()
		movement_component.stop()
		_reset_stuck_state(body.global_position)
		return

	_repath_cooldown -= delta
	if _repath_cooldown <= 0.0:
		_repath_cooldown = repath_interval
		target_position = _target.global_position

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

	if is_target_reachable():
		if not is_navigation_finished():
			var next_path_position := get_next_path_position()
			if next_path_position.distance_squared_to(origin) > 0.0001:
				target_position_to_use = next_path_position
				has_target_position = true
		elif _target.global_position.distance_squared_to(origin) > 0.0001:
			target_position_to_use = _target.global_position
			has_target_position = true
	elif _repath_cooldown > 0.0 and _target.global_position.distance_squared_to(origin) > 0.0001:
		target_position_to_use = _target.global_position
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


func _acquire_target() -> void:
	var targets := get_tree().get_nodes_in_group(target_group)
	if targets.is_empty():
		_target = null
		return

	_target = targets[0] as Node2D
	_repath_cooldown = 0.0


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
		target_position = _target.global_position


func _reset_stuck_state(current_position: Vector2) -> void:
	_stuck_anchor_position = current_position
	_stuck_time = 0.0
