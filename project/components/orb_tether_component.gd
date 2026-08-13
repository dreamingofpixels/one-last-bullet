class_name OrbTetherComponent extends Node2D

## Proximity focus + tether capture/release for the bound orb.
## Driven by the tether input via try_tether_press().

@export var focus_radius: float = 32.0
@export var min_tether_radius: float = 16.0
@export var tether_cooldown: float = 0.25
@export var tether_enabled: bool = true

var _orb: RigidBody2D = null
var _cooldown_until_msec: int = 0


func bind_orb(orb: RigidBody2D) -> void:
	_orb = orb


func begin_opening_tether(radius: float = -1.0) -> void:
	var orb := _get_orb()
	if orb == null or not orb.has_method("begin_opening_tether"):
		return
	var r: float = focus_radius if radius < 0.0 else radius
	orb.begin_opening_tether(owner, r)


func _process(_delta: float) -> void:
	var orb := _get_orb()
	if orb == null or not orb.has_method("set_in_focus"):
		return

	if not tether_enabled or not orb.has_method("is_flying") or not orb.is_flying():
		orb.set_in_focus(false)
		return

	if Time.get_ticks_msec() < _cooldown_until_msec:
		orb.set_in_focus(false)
		return

	var distance: float = owner.global_position.distance_to((orb as Node2D).global_position)
	orb.set_in_focus(distance <= focus_radius)


## Returns true when this player currently owns a tethered orb.
func is_tethering() -> bool:
	if not tether_enabled:
		return false
	var orb := _get_orb()
	if orb == null or not orb.has_method("is_tethered") or not orb.is_tethered():
		return false
	return orb.has_method("get_tether_player") and orb.get_tether_player() == owner


## Returns true when capture or release succeeded.
func try_tether_press() -> bool:
	if not tether_enabled:
		return false

	var orb := _get_orb()
	if orb == null:
		return false

	# Release if this player owns the tether.
	if orb.has_method("is_tethered") and orb.is_tethered():
		if orb.has_method("get_tether_player") and orb.get_tether_player() == owner:
			orb.release_tether()
			_cooldown_until_msec = Time.get_ticks_msec() + int(tether_cooldown * 1000.0)
			return true
		return false

	# Capture when flying and within focus radius (and not on cooldown).
	if not orb.has_method("is_flying") or not orb.is_flying():
		return false
	if Time.get_ticks_msec() < _cooldown_until_msec:
		return false

	var distance: float = owner.global_position.distance_to((orb as Node2D).global_position)
	if distance > focus_radius:
		return false

	var radius: float = clampf(distance, min_tether_radius, focus_radius)
	orb.begin_tether(owner, radius)
	return true


func _get_orb() -> RigidBody2D:
	if not is_instance_valid(_orb):
		return null
	return _orb
