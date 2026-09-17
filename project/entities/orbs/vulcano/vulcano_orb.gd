class_name VulcanoOrb
extends BlankOrb

## Rooted orb: slides to a stop after launch/vault, then spews lava globes.

const STOP_SPEED := 10.0
const SLIDE_DAMP := 1.6
const SPEW_INTERVAL := 2.5
const SPEW_RADIUS_MIN := 28.0
const SPEW_RADIUS_MAX := 72.0
const LAVA_GLOBE_SCENE: PackedScene = preload("res://entities/orbs/vulcano/lava_globe.tscn")

var _parked: bool = false
var _spew_remaining: float = 0.0


func _keeps_constant_flight_speed() -> bool:
	return false


func begin_flight(direction: Vector2, instigator: Node = null) -> void:
	super.begin_flight(direction, instigator)
	_begin_slide()


func deflect(new_velocity: Vector2, instigator: Node) -> void:
	super.deflect(new_velocity, instigator)
	_begin_slide()


func begin_vault_hold(player: Node2D) -> bool:
	_clear_park()
	return super.begin_vault_hold(player)


func begin_circle_capture(center: Vector2, suck_speed: float, on_finished: Callable) -> void:
	_clear_park()
	super.begin_circle_capture(center, suck_speed, on_finished)


func assume_circle_capture(center: Vector2) -> void:
	_clear_park()
	super.assume_circle_capture(center)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _circle_captured or _vault_hold:
		return
	if state != OrbState.FLYING:
		return

	if _parked:
		_update_spew(delta)
		return

	if freeze:
		return

	# Tether release (and any non-begin_flight launch) can leave damp at 0.
	if linear_damp != SLIDE_DAMP:
		linear_damp = SLIDE_DAMP

	if linear_velocity.length() <= STOP_SPEED:
		_park()


func _begin_slide() -> void:
	_parked = false
	_spew_remaining = 0.0
	freeze = false
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = SLIDE_DAMP
	if linear_velocity.length_squared() < 0.0001 and aim_direction.length_squared() > 0.0001:
		linear_velocity = aim_direction * maxf(speed, 0.001)


func _park() -> void:
	_parked = true
	freeze = true
	linear_velocity = Vector2.ZERO
	linear_damp = 0.0
	aim_direction = Vector2.ZERO
	_spew_remaining = SPEW_INTERVAL * 0.35
	trail_particles.emitting = false


func _clear_park() -> void:
	_parked = false
	_spew_remaining = 0.0
	linear_damp = 0.0


func _update_spew(delta: float) -> void:
	_spew_remaining -= delta
	if _spew_remaining > 0.0:
		return
	_spew_remaining = SPEW_INTERVAL
	_spawn_lava_globe()


func _spawn_lava_globe() -> void:
	var parent_node: Node = _resolve_y_sort_parent()
	if parent_node == null:
		return
	var angle: float = randf() * TAU
	var radius: float = randf_range(SPEW_RADIUS_MIN, SPEW_RADIUS_MAX)
	var land_at: Vector2 = global_position + Vector2.from_angle(angle) * radius
	var globe: LavaGlobe = LAVA_GLOBE_SCENE.instantiate() as LavaGlobe
	parent_node.add_child(globe)
	globe.setup(global_position, land_at, self)


func _resolve_y_sort_parent() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return get_parent()
	var y_sort: Node = scene.get_node_or_null("WorldYSort")
	if y_sort == null:
		y_sort = scene.get_node_or_null("%WorldYSort")
	if y_sort != null:
		return y_sort
	return get_parent()
