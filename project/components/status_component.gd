class_name StatusComponent extends Node2D

enum StatusId { POISON, SHOCK, BURN, CHILL }

const POISON_TICK_INTERVAL := 1.0
const SHOCK_THRESHOLD := 10
const SHOCK_BURST_DAMAGE := 50.0
const STUN_DURATION := 2.0
const CHILL_SLOW_PER_STACK := 0.05
const CHILL_MAX_SLOW := 0.9
const BURN_BASE_RADIUS := 50.0
const BURN_DAMAGE_PER_STACK := 5.0
const BURN_RADIUS_SCALE_PER_STACK := 0.05
const PHYSICS_LAYER_ENEMY := 4

@export var health_component: HealthComponent
@export var navigation_component: NavigationComponent
@export var movement_component: MovementComponent
@export var damage_component: DamageComponent
@export var destroy_component: DestroyComponent

var _poison_stacks: int = 0
var _poison_tick_remaining: float = 0.0
var _shock_stacks: int = 0
var _burn_stacks: int = 0
var _chill_stacks: int = 0
var _stun_remaining: float = 0.0
var _was_chasing_before_stun: bool = true
var _base_move_speed: float = 0.0
var _base_nav_max_speed: float = 0.0
var _base_contact_interval: float = 0.0
var _sources: Dictionary = {}


func _ready() -> void:
	if movement_component:
		_base_move_speed = movement_component.move_speed
	if navigation_component:
		_base_nav_max_speed = navigation_component.max_speed
	if damage_component:
		_base_contact_interval = damage_component.contact_damage_interval
	if destroy_component and not destroy_component.destroyed.is_connected(_on_owner_destroyed):
		destroy_component.destroyed.connect(_on_owner_destroyed)
	set_physics_process(true)


func add_stacks(id: StatusId, amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	if source != null and is_instance_valid(source):
		_sources[id] = source
	match id:
		StatusId.POISON:
			var was_zero: bool = _poison_stacks <= 0
			_poison_stacks += amount
			if was_zero:
				_poison_tick_remaining = POISON_TICK_INTERVAL
		StatusId.SHOCK:
			if is_stunned():
				return
			_shock_stacks += amount
			if _shock_stacks >= SHOCK_THRESHOLD:
				_begin_stun()
		StatusId.BURN:
			_burn_stacks += amount
		StatusId.CHILL:
			_chill_stacks += amount
			_apply_chill_slow()


func get_stacks(id: StatusId) -> int:
	match id:
		StatusId.POISON:
			return _poison_stacks
		StatusId.SHOCK:
			return _shock_stacks
		StatusId.BURN:
			return _burn_stacks
		StatusId.CHILL:
			return _chill_stacks
	return 0


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func _physics_process(delta: float) -> void:
	_tick_poison(delta)
	_tick_stun(delta)


func _tick_poison(delta: float) -> void:
	if _poison_stacks <= 0:
		_poison_tick_remaining = 0.0
		return

	_poison_tick_remaining -= delta
	if _poison_tick_remaining > 0.0:
		return

	if health_component:
		var source: Node = _sources.get(StatusId.POISON, null)
		health_component.take_damage(
			float(_poison_stacks),
			HealthComponent.DamageKind.POISON,
			source
		)
	_poison_tick_remaining = POISON_TICK_INTERVAL


func _tick_stun(delta: float) -> void:
	if _stun_remaining <= 0.0:
		return

	_stun_remaining -= delta
	if movement_component:
		movement_component.stop()
	if _stun_remaining > 0.0:
		return

	_stun_remaining = 0.0
	if navigation_component and _was_chasing_before_stun:
		navigation_component.set_chasing(true)


func _begin_stun() -> void:
	if health_component:
		var source: Node = _sources.get(StatusId.SHOCK, null)
		health_component.take_damage(SHOCK_BURST_DAMAGE, HealthComponent.DamageKind.STANDARD, source)
	_shock_stacks = 0
	_stun_remaining = STUN_DURATION
	if navigation_component:
		_was_chasing_before_stun = true
		navigation_component.set_chasing(false)
	if movement_component:
		movement_component.stop()


func _apply_chill_slow() -> void:
	var slow: float = minf(float(_chill_stacks) * CHILL_SLOW_PER_STACK, CHILL_MAX_SLOW)
	var speed_mult: float = 1.0 - slow
	if movement_component:
		movement_component.move_speed = _base_move_speed * speed_mult
	if navigation_component:
		navigation_component.max_speed = _base_nav_max_speed * speed_mult
	if damage_component and _base_contact_interval > 0.0:
		var attack_mult: float = maxf(speed_mult, 0.1)
		damage_component.contact_damage_interval = _base_contact_interval / attack_mult


func _on_owner_destroyed(_node: Node) -> void:
	if _burn_stacks <= 0:
		return
	if owner == null or not (owner is Node2D):
		return

	var explosion_damage: float = BURN_DAMAGE_PER_STACK * float(_burn_stacks)
	var explosion_radius: float = BURN_BASE_RADIUS * (1.0 + BURN_RADIUS_SCALE_PER_STACK * float(_burn_stacks))
	var source: Node = _sources.get(StatusId.BURN, null)
	_trigger_burn_explosion((owner as Node2D).global_position, explosion_damage, explosion_radius, source)


func _trigger_burn_explosion(
	origin: Vector2,
	amount: float,
	radius: float,
	source: Node
) -> void:
	if amount <= 0.0 or radius <= 0.0:
		return
	if owner == null or not owner.is_inside_tree():
		return

	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	params.shape = circle
	params.transform = Transform2D(0.0, origin)
	params.collision_mask = PHYSICS_LAYER_ENEMY
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var damaged_ids: Dictionary = {}
	for hit in space.intersect_shape(params, 32):
		var collider: Object = hit.get("collider")
		if collider == null:
			continue
		var victim_root: Node = _resolve_entity_root(collider as Node)
		if victim_root == null or not victim_root.is_in_group("enemies"):
			continue
		var victim_id: int = victim_root.get_instance_id()
		if damaged_ids.has(victim_id):
			continue
		damaged_ids[victim_id] = true

		var comp = victim_root.get("COMPONENTS")
		if comp == null or not comp.has(HealthComponent):
			continue
		(comp[HealthComponent] as HealthComponent).take_damage(
			amount,
			HealthComponent.DamageKind.BURN,
			source
		)


func _resolve_entity_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null

	var node: Node = collider
	while node != null and node.get("COMPONENTS") == null:
		node = node.get_parent()
	return node
