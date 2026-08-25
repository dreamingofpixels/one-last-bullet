class_name StatusComponent extends Node2D

enum StatusId { POISON, SHOCK }

const POISON_TICK_INTERVAL := 2.0
const SHOCK_THRESHOLD := 10
const STUN_DURATION := 2.0

@export var health_component: HealthComponent
@export var navigation_component: NavigationComponent
@export var movement_component: MovementComponent

var _poison_stacks: int = 0
var _poison_tick_remaining: float = 0.0
var _shock_stacks: int = 0
var _stun_remaining: float = 0.0
var _was_chasing_before_stun: bool = true


func _ready() -> void:
	set_physics_process(true)


func add_stacks(id: StatusId, amount: int) -> void:
	if amount <= 0:
		return
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


func get_stacks(id: StatusId) -> int:
	match id:
		StatusId.POISON:
			return _poison_stacks
		StatusId.SHOCK:
			return _shock_stacks
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
		health_component.take_damage(float(_poison_stacks), HealthComponent.DamageKind.POISON)
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
	_shock_stacks = 0
	_stun_remaining = STUN_DURATION
	if navigation_component:
		_was_chasing_before_stun = true
		navigation_component.set_chasing(false)
	if movement_component:
		movement_component.stop()
