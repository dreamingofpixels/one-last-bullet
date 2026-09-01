class_name KnockbackComponent extends Node2D

## Applies a decaying shove to the owner.
## Supports CharacterBody2D (velocity + move_and_slide), RigidBody2D (impulse),
## and plain Node2D (global_position translate) so objects can reuse it later.

@export var deceleration: float = 800.0
@export var min_speed: float = 8.0

var _velocity: Vector2 = Vector2.ZERO
var _active: bool = false
var _collision_damage: float = 0.0
var _damaged_this_push: Dictionary = {}


func apply(direction: Vector2, force: float) -> void:
	if direction.length_squared() < 0.0001 or force <= 0.0:
		return
	_velocity = direction.normalized() * force
	_active = true
	set_physics_process(true)

	if owner is RigidBody2D:
		(owner as RigidBody2D).apply_central_impulse(_velocity)


## Push the owner a fixed distance along `direction`, optionally bowling damage on enemy collisions.
func push_distance(direction: Vector2, distance: float, collision_damage: float = 0.0) -> void:
	if direction.length_squared() < 0.0001 or distance <= 0.0:
		return
	_collision_damage = maxf(collision_damage, 0.0)
	_damaged_this_push.clear()
	var initial_speed: float = sqrt(2.0 * deceleration * distance)
	apply(direction, initial_speed)


func is_active() -> bool:
	return _active


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _active:
		set_physics_process(false)
		return

	if owner is RigidBody2D:
		# Impulse was applied once in apply(); clear once speed is low.
		var rb := owner as RigidBody2D
		if rb.linear_velocity.length() <= min_speed:
			_velocity = Vector2.ZERO
			_active = false
			_collision_damage = 0.0
			_damaged_this_push.clear()
			set_physics_process(false)
		return

	var speed := _velocity.length()
	if speed <= min_speed:
		_velocity = Vector2.ZERO
		_active = false
		_collision_damage = 0.0
		_damaged_this_push.clear()
		set_physics_process(false)
		if owner is CharacterBody2D:
			(owner as CharacterBody2D).velocity = Vector2.ZERO
		return

	var new_speed := maxf(0.0, speed - deceleration * delta)
	_velocity = _velocity.normalized() * new_speed

	if owner is CharacterBody2D:
		var body := owner as CharacterBody2D
		if not body.is_inside_tree():
			return
		if PhysicsServer2D.body_get_space(body.get_rid()) == RID():
			return
		body.velocity = _velocity
		body.move_and_slide()
		_apply_bowling_collisions(body)
	elif owner is Node2D:
		(owner as Node2D).global_position += _velocity * delta


func _apply_bowling_collisions(body: CharacterBody2D) -> void:
	if _collision_damage <= 0.0:
		return

	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var collider: Object = collision.get_collider()
		if collider == null:
			continue
		var other_root: Node = _resolve_entity_root(collider as Node)
		if other_root == null or not other_root.is_in_group("enemies"):
			continue
		_apply_bowling_damage_between(body, other_root)


func _apply_bowling_damage_between(shoved: Node, other: Node) -> void:
	var shoved_id: int = shoved.get_instance_id()
	var other_id: int = other.get_instance_id()

	if not _damaged_this_push.has(shoved_id):
		_damaged_this_push[shoved_id] = true
		_deal_bowling_damage(shoved)

	if not _damaged_this_push.has(other_id):
		_damaged_this_push[other_id] = true
		_deal_bowling_damage(other)


func _deal_bowling_damage(entity: Node) -> void:
	var comp = entity.get("COMPONENTS")
	if comp == null or not comp.has(HealthComponent):
		return
	(comp[HealthComponent] as HealthComponent).take_damage(_collision_damage)


func _resolve_entity_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null

	var node: Node = collider
	while node != null and node.get("COMPONENTS") == null:
		node = node.get_parent()
	return node
