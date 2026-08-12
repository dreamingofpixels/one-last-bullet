class_name OrbTetherComponent extends Node2D

## Proximity focus + tether capture/release for the bound orb.
## Attack presses are consumed by try_consume_attack_press() so the arc does not swing.

@export var focus_radius: float = 32.0
@export var min_tether_radius: float = 16.0
@export var tether_cooldown: float = 0.25
@export var tether_enabled: bool = true

var _cooldown_until_msec: int = 0


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


## Returns true when the attack press was used for capture or release (no swing).
func try_consume_attack_press() -> bool:
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
	var opening = owner.get("opening_aim_component")
	if opening == null or not opening.has_method("get_bullet"):
		return null
	var bullet = opening.get_bullet()
	if not is_instance_valid(bullet):
		return null
	return bullet as RigidBody2D
