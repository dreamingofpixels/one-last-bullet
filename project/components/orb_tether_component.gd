class_name OrbTetherComponent extends Node2D

## Proximity focus + tether capture/release for the bound orb.
## Also handles remote tether channeling (hold 2s to snap distant orb).

@export var focus_radius: float = 32.0
@export var min_tether_radius: float = 16.0
@export var tether_cooldown: float = 0.25
@export var tether_enabled: bool = true
@export var remote_tether_hold_duration: float = 2.0

## Channel visual tuning.
@export var channel_ring_offset: Vector2 = Vector2(0, -18)
@export var channel_ring_radius: float = 3.0
@export var channel_ring_width: float = 1.0
@export var channel_ring_bg_color: Color = Color(0.95, 0.4, 0.15, 0.4)
@export var channel_ring_fill_color: Color = Color(0.95, 0.4, 0.15, 0.9)
@export var channel_line_color: Color = Color(0.95, 0.4, 0.15, 0.7)
@export var channel_line_width: float = 1.0

var _orb: RigidBody2D = null
var _cooldown_until_msec: int = 0
var _channeling: bool = false
var _channel_elapsed: float = 0.0


func _ready() -> void:
	z_index = 10


func bind_orb(orb: RigidBody2D) -> void:
	_orb = orb


func begin_opening_tether(radius: float = -1.0) -> void:
	var orb := _get_orb()
	if orb == null or not orb.has_method("begin_opening_tether"):
		return
	var r: float = focus_radius if radius < 0.0 else radius
	orb.begin_opening_tether(owner, r)


func _process(delta: float) -> void:
	var orb := _get_orb()
	if orb == null or not orb.has_method("set_in_focus"):
		return

	var controls: Controls = owner.controls

	# --- Handle channeling state ---
	if _channeling:
		# Cancel conditions: button released, orb no longer flying, tether disabled.
		if not controls.is_tether_pressed() or not _is_orb_flying(orb) or not tether_enabled:
			_cancel_channel()
		else:
			_channel_elapsed += delta
			orb.set_in_focus(true)
			if _channel_elapsed >= remote_tether_hold_duration:
				_complete_remote_tether(orb)
			else:
				queue_redraw()
		return

	# --- Tether input (centralized) — must run before the flying guard so release works while tethered ---
	if controls.is_tether_just_pressed():
		var distance_for_input: float = owner.global_position.distance_to((orb as Node2D).global_position)
		if _try_immediate_tether(orb, distance_for_input):
			return
		# Out of range — start channel if flying.
		if _is_orb_flying(orb) and distance_for_input > focus_radius:
			_start_remote_channel()

	# --- Normal focus overlay ---
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


func is_channeling() -> bool:
	return _channeling


func get_channel_progress() -> float:
	if not _channeling or remote_tether_hold_duration <= 0.0:
		return 0.0
	return clampf(_channel_elapsed / remote_tether_hold_duration, 0.0, 1.0)


## Legacy entry point kept for player states that may still call it (release path).
func try_tether_press() -> bool:
	if not tether_enabled:
		return false
	var orb := _get_orb()
	if orb == null:
		return false
	var distance: float = owner.global_position.distance_to((orb as Node2D).global_position)
	return _try_immediate_tether(orb, distance)


# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _channeling:
		return

	var progress := get_channel_progress()

	# Progress ring.
	draw_arc(channel_ring_offset, channel_ring_radius, 0.0, TAU, 24, channel_ring_bg_color, channel_ring_width)
	if progress > 0.0:
		var start_angle := -PI / 2.0
		draw_arc(channel_ring_offset, channel_ring_radius, start_angle, start_angle + TAU * progress, 24, channel_ring_fill_color, channel_ring_width)

	# Line to orb.
	var orb := _get_orb()
	if orb != null:
		var orb_local: Vector2 = to_local((orb as Node2D).global_position)
		var pulse := 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.008)
		var alpha := channel_line_color.a * progress * pulse
		var col := Color(channel_line_color, alpha)
		draw_line(Vector2.ZERO, orb_local, col, channel_line_width)


# ── Internals ─────────────────────────────────────────────────────────────────

func _try_immediate_tether(orb: RigidBody2D, distance: float) -> bool:
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
	if distance > focus_radius:
		return false

	var radius: float = clampf(distance, min_tether_radius, focus_radius)
	orb.begin_tether(owner, radius)
	return true


func _start_remote_channel() -> void:
	_channeling = true
	_channel_elapsed = 0.0
	queue_redraw()


func _complete_remote_tether(orb: RigidBody2D) -> void:
	var dir: Vector2 = ((orb as Node2D).global_position - owner.global_position).normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.UP
	(orb as Node2D).global_position = owner.global_position + dir * focus_radius
	orb.begin_tether(owner, focus_radius)
	_channeling = false
	_channel_elapsed = 0.0
	queue_redraw()


func _cancel_channel() -> void:
	_channeling = false
	_channel_elapsed = 0.0
	queue_redraw()


func _is_orb_flying(orb: RigidBody2D) -> bool:
	return orb.has_method("is_flying") and orb.is_flying()


func _get_orb() -> RigidBody2D:
	if not is_instance_valid(_orb):
		return null
	return _orb
