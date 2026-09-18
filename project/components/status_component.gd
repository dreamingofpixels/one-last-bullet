class_name StatusComponent extends Node2D

signal statuses_changed

enum StatusId { BLIGHT, SHOCK, BURN, CHILL, DISEASE }

const ICON_STUN := &"stun"
const ICON_DISEASE := &"disease"
const MAX_VISIBLE_ICONS := 4

const BURN_TICK_INTERVAL := 1.0
const SHOCK_THRESHOLD := 10
const SHOCK_BURST_DAMAGE := 50.0
const STUN_DURATION := 2.0
const CHILL_SLOW_PER_STACK := 0.05
const CHILL_MAX_SLOW := 0.9
const BLIGHT_PER_STACK := 0.05
const BLIGHT_MAX := 0.9
const DISEASE_SPREAD_RADIUS := 100.0
const DISEASE_TINT := Color(0.6, 0.9, 0.55, 1.0)
const PHYSICS_LAYER_ENEMY := 4
const PARTICLE_AMOUNT_CAP := 8
const BASIC_INTENSITY_STACKS := 12.0
const SHOCK_INTENSITY_STACKS := 10.0

const LIGHTNING_STRIKE_SCENE: PackedScene = preload(
	"res://effects/lightning_strike/lightning_strike.tscn"
)

@export var health_component: HealthComponent
@export var navigation_component: NavigationComponent
@export var movement_component: MovementComponent
@export var damage_component: DamageComponent
@export var destroy_component: DestroyComponent
@export var attack_component: EnemyAttackComponent

@onready var burn_particles: GPUParticles2D = %BurnParticles
@onready var chill_particles: GPUParticles2D = %ChillParticles
@onready var shock_particles: GPUParticles2D = %ShockParticles
@onready var blight_particles: GPUParticles2D = %BlightParticles

var _blight_stacks: int = 0
var _shock_stacks: int = 0
var _burn_stacks: int = 0
var _burn_tick_remaining: float = 0.0
var _chill_stacks: int = 0
var _disease_stacks: int = 0
var _stun_remaining: float = 0.0
var _was_chasing_before_stun: bool = true
var _base_move_speed: float = 0.0
var _base_nav_max_speed: float = 0.0
var _base_contact_interval: float = 0.0
var _sources: Dictionary = {}
## Recency-ordered icon statuses (newest last). Basics never appear here.
var _icon_recency: Array[StringName] = []


func _ready() -> void:
	if movement_component:
		_base_move_speed = movement_component.move_speed
	if navigation_component:
		_base_nav_max_speed = navigation_component.max_speed
	if damage_component:
		_base_contact_interval = damage_component.contact_damage_interval
	if destroy_component and not destroy_component.destroyed.is_connected(_on_owner_destroyed):
		destroy_component.destroyed.connect(_on_owner_destroyed)
	_refresh_all_particles()
	set_physics_process(true)


func add_stacks(id: StatusId, amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	if source != null and is_instance_valid(source):
		_sources[id] = source
	match id:
		StatusId.BLIGHT:
			_blight_stacks += amount
			_refresh_particle(StatusId.BLIGHT)
		StatusId.SHOCK:
			if is_stunned():
				return
			_shock_stacks += amount
			if _shock_stacks >= SHOCK_THRESHOLD:
				_begin_stun()
			else:
				_refresh_particle(StatusId.SHOCK)
				statuses_changed.emit()
			return
		StatusId.BURN:
			var was_zero: bool = _burn_stacks <= 0
			_burn_stacks += amount
			if was_zero:
				_burn_tick_remaining = BURN_TICK_INTERVAL
			_refresh_particle(StatusId.BURN)
		StatusId.CHILL:
			_chill_stacks += amount
			_apply_chill_slow()
			_refresh_particle(StatusId.CHILL)
		StatusId.DISEASE:
			var was_clear: bool = _disease_stacks <= 0
			_disease_stacks += amount
			if was_clear:
				_apply_disease_tint()
				_push_icon(ICON_DISEASE)
	statuses_changed.emit()


func get_stacks(id: StatusId) -> int:
	match id:
		StatusId.BLIGHT:
			return _blight_stacks
		StatusId.SHOCK:
			return _shock_stacks
		StatusId.BURN:
			return _burn_stacks
		StatusId.CHILL:
			return _chill_stacks
		StatusId.DISEASE:
			return _disease_stacks
	return 0


func is_stunned() -> bool:
	return _stun_remaining > 0.0


func is_diseased() -> bool:
	return _disease_stacks > 0


## Newest-first list of non-basic status icons (max MAX_VISIBLE_ICONS).
func get_visible_icon_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var start: int = maxi(0, _icon_recency.size() - MAX_VISIBLE_ICONS)
	for i in range(_icon_recency.size() - 1, start - 1, -1):
		result.append(_icon_recency[i])
	return result


func incoming_orb_multiplier() -> float:
	return 1.0 + minf(float(_blight_stacks) * BLIGHT_PER_STACK, BLIGHT_MAX)


func outgoing_damage_multiplier() -> float:
	return 1.0 - minf(float(_blight_stacks) * BLIGHT_PER_STACK, BLIGHT_MAX)


func _physics_process(delta: float) -> void:
	_tick_burn(delta)
	_tick_stun(delta)


func _tick_burn(delta: float) -> void:
	if _burn_stacks <= 0:
		_burn_tick_remaining = 0.0
		return

	_burn_tick_remaining -= delta
	if _burn_tick_remaining > 0.0:
		return

	if health_component:
		var source: Node = _sources.get(StatusId.BURN, null)
		health_component.take_damage(
			float(_burn_stacks),
			HealthComponent.DamageKind.BURN,
			source
		)
	_burn_tick_remaining = BURN_TICK_INTERVAL


func _tick_stun(delta: float) -> void:
	if _stun_remaining <= 0.0:
		return

	_stun_remaining -= delta
	if movement_component:
		movement_component.stop()
	if _stun_remaining > 0.0:
		return

	_stun_remaining = 0.0
	_pop_icon(ICON_STUN)
	if navigation_component and _was_chasing_before_stun and Players.count(get_tree()) > 0:
		navigation_component.set_chasing(true)
	statuses_changed.emit()


func _begin_stun() -> void:
	if health_component:
		var source: Node = _sources.get(StatusId.SHOCK, null)
		health_component.take_damage(SHOCK_BURST_DAMAGE, HealthComponent.DamageKind.STANDARD, source)
	_shock_stacks = 0
	_stun_remaining = STUN_DURATION
	_refresh_particle(StatusId.SHOCK)
	_push_icon(ICON_STUN)
	_spawn_lightning_strike()
	if attack_component:
		attack_component.cancel()
	if navigation_component:
		_was_chasing_before_stun = true
		navigation_component.set_chasing(false)
	if movement_component:
		movement_component.stop()
	statuses_changed.emit()


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
	if attack_component:
		attack_component.speed_multiplier = maxf(speed_mult, 0.1)


func _apply_disease_tint() -> void:
	if health_component:
		health_component.set_rest_modulate(DISEASE_TINT)


func _push_icon(icon_id: StringName) -> void:
	_pop_icon(icon_id)
	_icon_recency.append(icon_id)


func _pop_icon(icon_id: StringName) -> void:
	var idx: int = _icon_recency.find(icon_id)
	if idx >= 0:
		_icon_recency.remove_at(idx)


func _refresh_all_particles() -> void:
	_refresh_particle(StatusId.BURN)
	_refresh_particle(StatusId.CHILL)
	_refresh_particle(StatusId.SHOCK)
	_refresh_particle(StatusId.BLIGHT)


func _refresh_particle(id: StatusId) -> void:
	var particles: GPUParticles2D = _particles_for(id)
	if particles == null:
		return
	var stacks: int = get_stacks(id)
	if stacks <= 0:
		particles.emitting = false
		return
	particles.emitting = true
	var denom: float = SHOCK_INTENSITY_STACKS if id == StatusId.SHOCK else BASIC_INTENSITY_STACKS
	particles.amount_ratio = clampf(float(stacks) / denom, 0.25, 1.0)


func _particles_for(id: StatusId) -> GPUParticles2D:
	match id:
		StatusId.BURN:
			return burn_particles
		StatusId.CHILL:
			return chill_particles
		StatusId.SHOCK:
			return shock_particles
		StatusId.BLIGHT:
			return blight_particles
		_:
			return null


func _spawn_lightning_strike() -> void:
	if owner == null or not (owner is Node2D) or not owner.is_inside_tree():
		return

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var fx_parent: Node = owner.get_parent()
	if not (fx_parent is Node2D and (fx_parent as Node2D).y_sort_enabled):
		fx_parent = scene.get_node_or_null("%WorldYSort")
	if fx_parent == null:
		fx_parent = scene.get_node_or_null("WorldYSort")
	if fx_parent == null:
		fx_parent = scene

	var strike: Node2D = LIGHTNING_STRIKE_SCENE.instantiate() as Node2D
	fx_parent.add_child(strike)
	strike.global_position = (owner as Node2D).global_position


func _on_owner_destroyed(_node: Node) -> void:
	if owner == null or not (owner is Node2D):
		return

	var origin: Vector2 = (owner as Node2D).global_position

	if _disease_stacks > 0 and _blight_stacks >= 2:
		var spread_amount: int = int(_blight_stacks / 2)
		var blight_source: Node = _sources.get(StatusId.DISEASE, null)
		if blight_source == null:
			blight_source = _sources.get(StatusId.BLIGHT, null)
		_spread_blight(origin, spread_amount, blight_source)


func _spread_blight(origin: Vector2, amount: int, source: Node) -> void:
	if amount <= 0:
		return

	for victim_root in _nearby_enemies(origin, DISEASE_SPREAD_RADIUS):
		var comp = victim_root.get("COMPONENTS")
		if comp == null or not comp.has(StatusComponent):
			continue
		(comp[StatusComponent] as StatusComponent).add_stacks(
			StatusId.BLIGHT,
			amount,
			source
		)


func _nearby_enemies(origin: Vector2, radius: float) -> Array[Node]:
	var results: Array[Node] = []
	if radius <= 0.0:
		return results
	if owner == null or not owner.is_inside_tree():
		return results

	var space: PhysicsDirectSpaceState2D = owner.get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	params.shape = circle
	params.transform = Transform2D(0.0, origin)
	params.collision_mask = PHYSICS_LAYER_ENEMY
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var seen_ids: Dictionary = {}
	var owner_id: int = owner.get_instance_id()
	for hit in space.intersect_shape(params, 32):
		var collider: Object = hit.get("collider")
		if collider == null:
			continue
		var victim_root: Node = _resolve_entity_root(collider as Node)
		if victim_root == null or not victim_root.is_in_group("enemies"):
			continue
		var victim_id: int = victim_root.get_instance_id()
		if victim_id == owner_id or seen_ids.has(victim_id):
			continue
		seen_ids[victim_id] = true
		results.append(victim_root)
	return results


func _resolve_entity_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null

	var node: Node = collider
	while node != null and node.get("COMPONENTS") == null:
		node = node.get_parent()
	return node
