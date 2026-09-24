class_name RunicOrb
extends BlankOrb

## Seeks floor glyphs with HomingComponent, carries one at a time, drops near the circle.

const CARRY_OFFSET := Vector2(0, -10)
const DROP_RING_RADIUS := 34.0
const DROP_ARRIVE_DISTANCE := 10.0
## Glyphs already this close to the circle are treated as delivered (skip re-fetch).
const DELIVERED_MIN_RADIUS := 28.0
const DELIVERED_MAX_RADIUS := 48.0
const DROP_CLEAR_RADIUS := 8.0
const DROP_LANDING_TRIES := 12
const RETARGET_INTERVAL := 0.25

@onready var homing: HomingComponent = %HomingComponent

var _carried_glyph: Glyph = null
var _drop_point: Vector2 = Vector2.ZERO
var _has_drop_point: bool = false
var _retarget_cooldown: float = 0.0
var _drop_clear_shape: CircleShape2D = CircleShape2D.new()


func _ready() -> void:
	super._ready()
	_drop_clear_shape.radius = DROP_CLEAR_RADIUS
	homing.use_pathing = true
	homing.set_enabled(false)


func _should_bounce_off_hurtbox(victim: Node) -> bool:
	# Always bounce off enemies for pathing; player only when the playtest toggle is on.
	if victim != null and is_instance_valid(victim) and victim.is_in_group("enemies"):
		return true
	return super._should_bounce_off_hurtbox(victim)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _circle_captured or _vault_hold or state != OrbState.FLYING or freeze:
		_pause_homing()
		return

	if is_carrying_item():
		_update_deliver()
	else:
		_update_seek(delta)

	if homing.is_enabled() and homing.has_target():
		aim_direction = homing.steer(aim_direction, delta)
		if aim_direction.length_squared() < 0.0001:
			aim_direction = Vector2.RIGHT
		linear_velocity = aim_direction * speed
		_apply_heading()


func begin_circle_capture(center: Vector2, suck_speed: float, on_finished: Callable) -> void:
	_drop_carried_before_capture()
	super.begin_circle_capture(center, suck_speed, on_finished)


func assume_circle_capture(center: Vector2) -> void:
	_drop_carried_before_capture()
	super.assume_circle_capture(center)


func should_apply_hitbox_damage(victim: Node) -> bool:
	if victim is Glyph or (victim != null and victim.is_in_group("glyphs")):
		return false
	return super.should_apply_hitbox_damage(victim)


func on_hitbox_hit(victim: Node) -> void:
	if _circle_captured:
		return
	if victim is Glyph:
		var glyph: Glyph = victim as Glyph
		if not is_carrying_item() and glyph.can_be_picked_up():
			pick_up_item(glyph)
		return
	super.on_hitbox_hit(victim)


func is_carrying_item() -> bool:
	return is_instance_valid(_carried_glyph) and _carried_glyph.is_carried()


func get_carried_item() -> Glyph:
	if is_carrying_item():
		return _carried_glyph
	return null


func pick_up_item(item: Glyph) -> bool:
	if is_carrying_item() or item == null or not is_instance_valid(item):
		return false
	if not item.pickup(self, CARRY_OFFSET):
		return false
	_carried_glyph = item
	_has_drop_point = false
	_cache_drop_point()
	homing.set_enabled(true)
	homing.set_target_position(_drop_point)
	return true


func clear_carried_item(item: Glyph = null) -> void:
	if item != null and _carried_glyph != item:
		return
	_carried_glyph = null
	_has_drop_point = false


func _update_seek(delta: float) -> void:
	_retarget_cooldown -= delta
	var current: Glyph = null
	var target_node: Node2D = homing.get_target_node()
	if target_node is Glyph:
		current = target_node as Glyph
		if not current.can_be_picked_up() or _is_near_circle(current.global_position):
			current = null

	if current == null or _retarget_cooldown <= 0.0:
		_retarget_cooldown = RETARGET_INTERVAL
		current = _find_nearest_field_glyph()

	if current == null:
		_pause_homing()
		return

	homing.set_enabled(true)
	homing.set_target_node(current)


func _update_deliver() -> void:
	if not is_carrying_item():
		clear_carried_item()
		_pause_homing()
		return

	if not _has_drop_point:
		_cache_drop_point()

	homing.set_enabled(true)
	homing.set_target_position(_drop_point)

	if global_position.distance_squared_to(_drop_point) <= DROP_ARRIVE_DISTANCE * DROP_ARRIVE_DISTANCE:
		_drop_carried_glyph(_drop_point)


func _pause_homing() -> void:
	homing.clear_target()
	homing.set_enabled(false)


func _find_nearest_field_glyph() -> Glyph:
	if not is_inside_tree():
		return null
	var best: Glyph = null
	var best_dist_sq: float = INF
	for node in get_tree().get_nodes_in_group("glyphs"):
		var glyph := node as Glyph
		if glyph == null or not is_instance_valid(glyph):
			continue
		if not glyph.can_be_picked_up():
			continue
		if _is_near_circle(glyph.global_position):
			continue
		var dist_sq: float = global_position.distance_squared_to(glyph.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = glyph
	return best


func _is_near_circle(pos: Vector2) -> bool:
	var circle: Node2D = _find_summoning_circle()
	if circle == null:
		return false
	var center: Vector2 = _circle_center(circle)
	var dist: float = pos.distance_to(center)
	return dist >= DELIVERED_MIN_RADIUS and dist <= DELIVERED_MAX_RADIUS


func _cache_drop_point() -> void:
	var circle: Node2D = _find_summoning_circle()
	if circle == null:
		_drop_point = global_position
		_has_drop_point = true
		return

	var center: Vector2 = _circle_center(circle)
	var from_center: Vector2 = global_position - center
	if from_center.length_squared() < 0.0001:
		from_center = aim_direction if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	from_center = from_center.normalized()

	var candidate: Vector2 = center + from_center * DROP_RING_RADIUS
	if _is_world_blocked(candidate):
		candidate = _find_clear_drop_point(center, from_center)
	_drop_point = candidate
	_has_drop_point = true


func _find_clear_drop_point(center: Vector2, preferred_dir: Vector2) -> Vector2:
	var base_angle: float = preferred_dir.angle()
	for i in DROP_LANDING_TRIES:
		var angle: float = base_angle + (float(i) / float(DROP_LANDING_TRIES)) * TAU
		var candidate: Vector2 = center + Vector2.from_angle(angle) * DROP_RING_RADIUS
		if not _is_world_blocked(candidate):
			return candidate
	return center + preferred_dir * DROP_RING_RADIUS


func _drop_carried_before_capture() -> void:
	if not is_carrying_item():
		return
	if not _has_drop_point:
		_cache_drop_point()
	_drop_carried_glyph(_drop_point)


func _drop_carried_glyph(world_pos: Vector2) -> void:
	if not is_carrying_item():
		return
	var glyph: Glyph = _carried_glyph
	var items_parent: Node = _resolve_items_parent()
	if items_parent == null:
		items_parent = get_parent()
	_carried_glyph = null
	_has_drop_point = false
	_pause_homing()
	if not glyph.drop_at(world_pos, items_parent):
		# Fallback if drop failed mid-state — clear carrier ref only.
		clear_carried_item(glyph)


func _resolve_items_parent() -> Node:
	if not is_inside_tree():
		return null
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var items: Node = scene.get_node_or_null("%Items")
	if items != null:
		return items
	return scene.get_node_or_null("Items")


func _find_summoning_circle() -> Node2D:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("summoning_circle"):
		if node is Node2D and is_instance_valid(node):
			return node as Node2D
	return null


func _circle_center(circle: Node2D) -> Vector2:
	if circle.has_method("get_launch_origin"):
		return circle.call("get_launch_origin") as Vector2
	return circle.global_position


func _is_world_blocked(pos: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space == null:
		return false
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _drop_clear_shape
	params.transform = Transform2D(0.0, pos)
	params.collision_mask = PHYSICS_LAYER_WORLD
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.exclude = [get_rid()]
	return not space.intersect_shape(params, 1).is_empty()
