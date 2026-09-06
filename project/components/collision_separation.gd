class_name CollisionSeparation

## Shared shape-query helpers for clearing CharacterBody2D / CollisionObject2D
## overlaps against world (and optional wall) geometry.

const STEP_PX := 2.0
const MAX_PUSH_PX := 16.0
const SEPARATE_MAX_ITERS := 8


## True when `shape` placed at `pos` overlaps nothing on `mask`.
static func is_clear(
	body: CollisionObject2D,
	shape: CollisionShape2D,
	pos: Vector2,
	mask: int
) -> bool:
	if body == null or shape == null or shape.shape == null:
		return true
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var params := _make_params(body, shape, pos, mask)
	var overlaps: Array[Dictionary] = space.intersect_shape(params, 1)
	return overlaps.is_empty()


## First clear point scanning `direction` up to `forward_limit`, then `-direction`
## up to `back_limit`. Forward candidates whose sweep crosses `blocked_mask` are
## rejected. Returns `from_pos` when nothing is clear.
static func resolve_along(
	body: CollisionObject2D,
	shape: CollisionShape2D,
	from_pos: Vector2,
	direction: Vector2,
	forward_limit: float,
	back_limit: float,
	mask: int,
	blocked_mask: int
) -> Vector2:
	if body == null or shape == null or shape.shape == null:
		return from_pos
	if is_clear(body, shape, from_pos, mask):
		return from_pos

	var dir: Vector2 = direction
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var forward: Vector2 = _scan_clear(body, shape, from_pos, dir, forward_limit, mask)
	if forward != from_pos and not _sweep_hits_mask(body, shape, from_pos, forward, blocked_mask):
		return forward

	var backward: Vector2 = _scan_clear(body, shape, from_pos, -dir, back_limit, mask)
	if backward != from_pos:
		return backward

	return from_pos


## Last-resort push out along the rest normal, capped at `max_push`.
static func separate(
	body: CollisionObject2D,
	shape: CollisionShape2D,
	mask: int,
	max_push: float = MAX_PUSH_PX
) -> void:
	if body == null or shape == null or shape.shape == null:
		return
	if not body is Node2D:
		return

	var node: Node2D = body as Node2D
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var pushed: float = 0.0

	for _i in SEPARATE_MAX_ITERS:
		if pushed >= max_push:
			return
		var params := _make_params(body, shape, node.global_position, mask)
		var overlaps: Array[Dictionary] = space.intersect_shape(params, 4)
		if overlaps.is_empty():
			return

		var escape: Vector2 = Vector2.ZERO
		var rest: Dictionary = space.get_rest_info(params)
		if not rest.is_empty():
			escape = rest.get("normal", Vector2.ZERO)
		if escape.length_squared() < 0.0001:
			var collider: Object = overlaps[0].get("collider")
			if collider is Node2D:
				var from_collider: Vector2 = node.global_position - (collider as Node2D).global_position
				if from_collider.length_squared() > 0.0001:
					escape = from_collider.normalized()
		if escape.length_squared() < 0.0001:
			escape = Vector2.UP
		escape = escape.normalized()

		var step_px: float = minf(STEP_PX, max_push - pushed)
		node.global_position += escape * step_px
		pushed += step_px


static func _scan_clear(
	body: CollisionObject2D,
	shape: CollisionShape2D,
	from_pos: Vector2,
	direction: Vector2,
	limit: float,
	mask: int
) -> Vector2:
	if limit <= 0.0:
		return from_pos
	var travelled: float = 0.0
	while travelled < limit:
		var step_px: float = minf(STEP_PX, limit - travelled)
		travelled += step_px
		var candidate: Vector2 = from_pos + direction * travelled
		if is_clear(body, shape, candidate, mask):
			return candidate
	return from_pos


static func _sweep_hits_mask(
	body: CollisionObject2D,
	shape: CollisionShape2D,
	from_pos: Vector2,
	to_pos: Vector2,
	blocked_mask: int
) -> bool:
	if blocked_mask == 0:
		return false
	var motion: Vector2 = to_pos - from_pos
	if motion.length_squared() < 0.0001:
		return false
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	var params := _make_params(body, shape, from_pos, blocked_mask)
	params.motion = motion
	var cast: PackedFloat32Array = space.cast_motion(params)
	if cast.size() < 2:
		return false
	return cast[0] < 1.0


static func _make_params(
	body: CollisionObject2D,
	shape: CollisionShape2D,
	pos: Vector2,
	mask: int
) -> PhysicsShapeQueryParameters2D:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape.shape
	params.transform = Transform2D(0.0, pos + shape.position)
	params.collision_mask = mask
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = [body.get_rid()]
	return params
