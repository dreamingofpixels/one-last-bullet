class_name OrbTetherComponent extends Node2D

## Proximity focus + tether capture/release for orbs in the `orb` group.
## Also handles remote tether channeling (hold 2s to snap distant orb).
## Opening sling still uses bind_orb(); mid-combat uses closest-in-group targeting.

@export var focus_radius: float = 32.0
@export var min_tether_radius: float = 24.0
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

## Bound only for the opening sling; mid-combat queries the `orb` group.
var _opening_orb: RigidBody2D = null
var _cooldown_until_msec: int = 0
var _channeling: bool = false
var _channel_elapsed: float = 0.0
var _channel_orb: RigidBody2D = null


func _ready() -> void:
	z_index = 10


func bind_orb(orb: RigidBody2D) -> void:
	_opening_orb = orb


func begin_opening_tether(radius: float = -1.0) -> void:
	var orb := _get_opening_orb()
	if orb == null or not orb.has_method("begin_opening_tether"):
		return
	var r: float = min_tether_radius if radius < 0.0 else radius
	orb.begin_opening_tether(owner, r)


func _process(delta: float) -> void:
	var controls: Controls = owner.controls

	# --- Handle channeling state ---
	if _channeling:
		var channel_orb := _get_channel_orb()
		# Cancel: button released, target invalid / not flying, or tether disabled.
		if (
			not controls.is_tether_pressed()
			or channel_orb == null
			or not _is_orb_flying(channel_orb)
			or not tether_enabled
		):
			_cancel_channel()
		else:
			_channel_elapsed += delta
			channel_orb.set_in_focus(true)
			if _channel_elapsed >= remote_tether_hold_duration:
				_complete_remote_tether(channel_orb)
			else:
				queue_redraw()
		return

	# --- Tether input (centralized) — must run before flying guards so release works while tethered ---
	if controls.is_tether_just_pressed():
		if _try_immediate_tether():
			return
		# Out of range — start channel toward closest flying orb.
		var remote_target := _find_closest_flying_orb(false)
		if remote_target != null:
			var distance_for_input: float = owner.global_position.distance_to(
				(remote_target as Node2D).global_position
			)
			if distance_for_input > focus_radius:
				_start_remote_channel(remote_target)

	# --- Focus overlay: every flying orb within focus_radius ---
	_update_focus_overlays()


## Returns true when this player currently owns a tethered orb.
func is_tethering() -> bool:
	if not tether_enabled:
		return false
	return _find_owned_tethered_orb() != null


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
	return _try_immediate_tether()


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

	# Line to locked channel target.
	var orb := _get_channel_orb()
	if orb != null:
		var orb_local: Vector2 = to_local((orb as Node2D).global_position)
		var pulse := 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.008)
		var alpha := channel_line_color.a * progress * pulse
		var col := Color(channel_line_color, alpha)
		draw_line(Vector2.ZERO, orb_local, col, channel_line_width)


# ── Internals ─────────────────────────────────────────────────────────────────

func _try_immediate_tether() -> bool:
	# Release if this player owns a tether (one tether at a time).
	var owned := _find_owned_tethered_orb()
	if owned != null:
		owned.release_tether()
		_cooldown_until_msec = Time.get_ticks_msec() + int(tether_cooldown * 1000.0)
		return true

	if Time.get_ticks_msec() < _cooldown_until_msec:
		return false

	# Capture closest flying orb within focus radius.
	var target := _find_closest_flying_orb(true)
	if target == null:
		return false

	# Always target min_tether_radius; orb spirals from its current capture distance.
	target.begin_tether(owner, min_tether_radius)
	return true


func _update_focus_overlays() -> void:
	if not tether_enabled or Time.get_ticks_msec() < _cooldown_until_msec:
		_clear_all_focus()
		return

	var origin: Vector2 = owner.global_position
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb) or not orb.has_method("set_in_focus"):
			continue
		if not orb.has_method("is_flying") or not orb.is_flying():
			# Tethered orbs keep focus via their own set_in_focus guard.
			continue
		var distance: float = origin.distance_to(orb.global_position)
		orb.set_in_focus(distance <= focus_radius)


func _clear_all_focus() -> void:
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb) or not orb.has_method("set_in_focus"):
			continue
		if orb.has_method("is_tethered") and orb.is_tethered():
			continue
		orb.set_in_focus(false)


## Closest flying orb. If require_in_focus, only consider those within focus_radius.
func _find_closest_flying_orb(require_in_focus: bool) -> RigidBody2D:
	var origin: Vector2 = owner.global_position
	var best: RigidBody2D = null
	var best_dist_sq: float = INF
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not _is_orb_flying(orb):
			continue
		var dist_sq: float = origin.distance_squared_to(orb.global_position)
		if require_in_focus and dist_sq > focus_radius * focus_radius:
			continue
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = orb
	return best


func _find_owned_tethered_orb() -> RigidBody2D:
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not orb.has_method("is_tethered") or not orb.is_tethered():
			continue
		if orb.has_method("get_tether_player") and orb.get_tether_player() == owner:
			return orb
	return null


func _start_remote_channel(orb: RigidBody2D) -> void:
	_channeling = true
	_channel_elapsed = 0.0
	_channel_orb = orb
	queue_redraw()


func _complete_remote_tether(orb: RigidBody2D) -> void:
	var dir: Vector2 = ((orb as Node2D).global_position - owner.global_position).normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2.UP
	# Teleport directly onto the orbit circle so there is no spiral after a remote snap.
	(orb as Node2D).global_position = owner.global_position + dir * min_tether_radius
	orb.begin_tether(owner, min_tether_radius)
	_channeling = false
	_channel_elapsed = 0.0
	_channel_orb = null
	queue_redraw()


func _cancel_channel() -> void:
	_channeling = false
	_channel_elapsed = 0.0
	_channel_orb = null
	queue_redraw()


func _is_orb_flying(orb: RigidBody2D) -> bool:
	return orb.has_method("is_flying") and orb.is_flying()


func _get_opening_orb() -> RigidBody2D:
	if not is_instance_valid(_opening_orb):
		return null
	return _opening_orb


func _get_channel_orb() -> RigidBody2D:
	if not is_instance_valid(_channel_orb):
		return null
	return _channel_orb
