class_name VulcanoOrb
extends BlankOrb

## Rooted orb: slides to a stop after launch/vault, then spews lava globes.

const STOP_SPEED := 10.0
const SLIDE_DAMP := 1.6
const SPEW_INTERVAL := 2.5
const SPEW_RADIUS_MIN := 28.0
const SPEW_RADIUS_MAX := 72.0
const SPEW_MIN_SEPARATION := 22.0
const SPEW_LANDING_TRIES := 12
const SPEW_WORLD_CLEAR_RADIUS := 10.0
const LAVA_GLOBE_SCENE: PackedScene = preload("res://entities/orbs/vulcano/lava_globe.tscn")

var _parked: bool = false
var _spew_remaining: float = 0.0
var _world_clear_shape: CircleShape2D = CircleShape2D.new()


func _ready() -> void:
	super._ready()
	_world_clear_shape.radius = SPEW_WORLD_CLEAR_RADIUS


func _keeps_constant_flight_speed() -> bool:
	return false


func _prepare_for_level_clear_recall() -> void:
	_clear_park()
	super._prepare_for_level_clear_recall()


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
	_set_parked_hitbox_inert(false)
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
	# Parked Vulcano is a turret only — puddles handle Burn; no contact damage/status.
	_set_parked_hitbox_inert(true)


func _clear_park() -> void:
	_parked = false
	_spew_remaining = 0.0
	linear_damp = 0.0
	_set_parked_hitbox_inert(false)


## Victims poll our Area2D — must clear monitorable too (monitoring alone is not enough).
## Deferred: _park() runs from _physics_process.
## Body joins the world layer while parked so player/enemy move_and_slide treat it like a prop.
func _set_parked_hitbox_inert(inert: bool) -> void:
	hitbox_component.set_deferred("monitoring", not inert)
	hitbox_component.set_deferred("monitorable", not inert)
	if inert:
		set_deferred("collision_layer", PHYSICS_LAYER_WORLD | PHYSICS_LAYER_ORB)
	else:
		call_deferred("_restore_flying_collision")


func _restore_flying_collision() -> void:
	collision_layer = PHYSICS_LAYER_ORB
	_apply_collision_mask()


func should_apply_hitbox_damage(victim: Node) -> bool:
	if _parked:
		return false
	return super.should_apply_hitbox_damage(victim)


func on_hitbox_hit(victim: Node) -> void:
	if _parked:
		return
	super.on_hitbox_hit(victim)


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
	var land_at: Vector2 = Vector2.ZERO
	var found: bool = false
	for _i in SPEW_LANDING_TRIES:
		var angle: float = randf() * TAU
		var radius: float = randf_range(SPEW_RADIUS_MIN, SPEW_RADIUS_MAX)
		var candidate: Vector2 = global_position + Vector2.from_angle(angle) * radius
		if _is_landing_clear(candidate):
			land_at = candidate
			found = true
			break
	if not found:
		return
	var globe: LavaGlobe = LAVA_GLOBE_SCENE.instantiate() as LavaGlobe
	parent_node.add_child(globe)
	globe.setup(global_position, land_at, self)


func _is_landing_clear(pos: Vector2) -> bool:
	if _is_world_blocked(pos):
		return false
	var min_dist_sq: float = SPEW_MIN_SEPARATION * SPEW_MIN_SEPARATION
	for node in get_tree().get_nodes_in_group(LavaGlobe.GROUP_NAME):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is LavaGlobe):
			continue
		var other: LavaGlobe = node as LavaGlobe
		if not other.blocks_landing():
			continue
		if other.get_landing_position().distance_squared_to(pos) < min_dist_sq:
			return false
	return true


func _is_world_blocked(pos: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _world_clear_shape
	params.transform = Transform2D(0.0, pos)
	params.collision_mask = PHYSICS_LAYER_WORLD
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	return not space.intersect_shape(params, 1).is_empty()


func _resolve_y_sort_parent() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return get_parent()
	var y_sort: Node = scene.get_node_or_null("%WorldYSort")
	if y_sort == null:
		y_sort = scene.get_node_or_null("WorldYSort")
	if y_sort != null:
		return y_sort
	return get_parent()
