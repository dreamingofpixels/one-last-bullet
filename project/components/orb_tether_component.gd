class_name OrbTetherComponent extends Node2D

## Proximity focus + tether capture/release for orbs in the `orb` group.
## Also handles remote tether channeling (hold 2s to snap distant orb).
## Opening sling still uses bind_orb(); mid-combat uses closest-in-group targeting.
## When dash_vault_enabled, mid-combat steer is dash-into-orb vault instead of proximity Attack.

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_WALL := 16

@export var focus_radius: float = 32.0
@export var min_tether_radius: float = 24.0
@export var tether_cooldown: float = 0.25
@export var tether_enabled: bool = true
## When false, skip orb capture and remote channel; keep glyph pickup, focus, and Attack redirect.
@export var capture_enabled: bool = true
@export var remote_tether_hold_duration: float = 2.0
## When true, dash-into-orb vault replaces proximity Attack redirect (code for both kept).
@export var dash_vault_enabled: bool = false
@export var vault_catch_radius: float = 28.0
@export var vault_hold_duration: float = 0.5
@export var vault_landing_gap: float = 2.0
## Half-angle of the vault aim cone (90 = 180° total, away from the player through the orb).
@export var vault_aim_half_angle_degrees: float = 90.0
## After releasing a vaulted orb, ignore that same orb for vault catch (stops dash-away re-grab).
@export var vault_recatch_cooldown: float = 0.35

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
## Last non-zero aim so a released gamepad stick does not snap the redirect arrow to +X.
var _last_redirect_aim: Vector2 = Vector2.RIGHT
## Closest in-range flying orb currently showing the redirect arrow (or null).
var _redirect_preview_orb: RigidBody2D = null
## Dash-vault: orb held for aim window (one at a time).
var _vault_orb: RigidBody2D = null
var _vault_elapsed: float = 0.0
var _vaulting: bool = false
## Default / fallback forward for the vault aim cone (player → orb at catch).
var _vault_forward: Vector2 = Vector2.RIGHT
## Orb the current dash is committed to reach (far-side landing); cleared when dash ends.
var _vault_commit_orb: RigidBody2D = null
var _vault_commit_dir: Vector2 = Vector2.RIGHT
## Same orb cannot be vault-caught again until this wall-clock time (dash-away re-grab guard).
var _vault_recatch_orb: RigidBody2D = null
var _vault_recatch_until_msec: int = 0


func _ready() -> void:
	z_index = 10
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)


func _on_tree_exiting() -> void:
	if _vaulting:
		_fire_vault(false)
	_clear_redirect_preview()
	_clear_this_player_focus()


func _clear_this_player_focus() -> void:
	if owner == null:
		return
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if orb.has_method("set_focus_requested_by"):
			orb.set_focus_requested_by(owner, false)


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

	# --- Dash-vault aim window ---
	if _vaulting:
		_update_vault(delta)
		return

	# --- Handle channeling state ---
	if _channeling:
		_clear_redirect_preview()
		var channel_orb := _get_channel_orb()
		# Cancel: button released, target invalid / not flying, or tether disabled.
		if (
			not controls.is_pickup_pressed()
			or channel_orb == null
			or not _is_orb_flying(channel_orb)
			or not tether_enabled
		):
			_cancel_channel()
		else:
			_channel_elapsed += delta
			if channel_orb.has_method("set_focus_requested_by"):
				channel_orb.set_focus_requested_by(owner, true)
			else:
				channel_orb.set_in_focus(true)
			if _channel_elapsed >= remote_tether_hold_duration:
				_complete_remote_tether(channel_orb)
			else:
				queue_redraw()
		return

	# --- Tether input (centralized) — must run before flying guards so release works while tethered ---
	if controls.is_pickup_just_pressed():
		if _try_immediate_tether():
			_clear_redirect_preview()
			return
		# Out of range — start channel toward closest flying orb (orb capture only).
		if capture_enabled:
			var remote_target := _find_closest_flying_orb(false)
			if remote_target != null:
				var distance_for_input: float = owner.global_position.distance_to(
					(remote_target as Node2D).global_position
				)
				if distance_for_input > focus_radius:
					_start_remote_channel(remote_target)

	# --- Focus overlay + redirect aim arrow on closest in-range flying orb ---
	_update_focus_overlays()
	_update_redirect_preview()


## Returns true when this player currently owns a tethered orb.
func is_tethering() -> bool:
	if not tether_enabled:
		return false
	return _find_owned_tethered_orb() != null


func is_channeling() -> bool:
	return _channeling


func is_vaulting() -> bool:
	return _vaulting


func get_channel_progress() -> float:
	if not _channeling or remote_tether_hold_duration <= 0.0:
		return 0.0
	return clampf(_channel_elapsed / remote_tether_hold_duration, 0.0, 1.0)


## True when Attack will redirect (proximity target, or vault-held orb).
func has_redirect_target() -> bool:
	if not tether_enabled or is_tethering() or _channeling:
		return false
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		return false
	if dash_vault_enabled:
		return _vaulting and is_instance_valid(_vault_orb)
	return _find_closest_flying_orb(true) != null


## Legacy entry point kept for player states that may still call it (release path).
func try_tether_press() -> bool:
	if not tether_enabled:
		return false
	return _try_immediate_tether()


## Redirect: vault early-fire when dash_vault_enabled, else closest in-range flying orb.
## Independent of the tether recapture cooldown. Returns true if a redirect happened.
func try_redirect_attack() -> bool:
	if not tether_enabled or is_tethering() or _channeling:
		return false
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		return false

	if dash_vault_enabled:
		return _fire_vault(true)

	var target := _find_closest_flying_orb(true)
	if target == null or not target.has_method("deflect"):
		return false

	var aim: Vector2 = _get_redirect_aim()
	target.deflect(aim, owner)
	_clear_redirect_preview()

	owner.dash_component.reset_cooldown()
	owner.attack_component.consume_cooldown()
	if owner.has_method("play_attack_visual"):
		owner.play_attack_visual(aim)

	return true


## While dashing: commit to the soonest orb on the remaining ray and clamp remaining
## distance to the far-side landing so the dash walks there (no teleport).
## Returns the remaining distance to use this frame.
func prepare_vault_dash(from: Vector2, dash_dir: Vector2, remaining_distance: float) -> float:
	if not dash_vault_enabled or not tether_enabled or _vaulting or _channeling:
		return remaining_distance
	if is_tethering():
		return remaining_distance

	var dir: Vector2 = dash_dir
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	if not is_instance_valid(_vault_commit_orb) or not _is_orb_flying(_vault_commit_orb):
		_vault_commit_orb = null
		var orb := _find_vault_catch_orb_on_ray(from, dir, remaining_distance)
		if orb == null:
			return remaining_distance
		_vault_commit_orb = orb
		_vault_commit_dir = dir

	var landing: Vector2 = _vault_landing_position(_vault_commit_orb, _vault_commit_dir)
	var along: float = (landing - from).dot(_vault_commit_dir)
	# Already at / past landing — finish this frame via try_finish_vault_dash.
	if along <= 0.0:
		return 0.0
	return along


## After a dash step (or when remaining hits 0): if committed and at/past the far side,
## abort dash and start the redirect window at the current position.
func try_finish_vault_dash(player_pos: Vector2, dash_dir: Vector2) -> bool:
	if not dash_vault_enabled or _vaulting:
		return false
	if not is_instance_valid(_vault_commit_orb) or not _is_orb_flying(_vault_commit_orb):
		_vault_commit_orb = null
		return false

	var dir: Vector2 = _vault_commit_dir
	if dir.length_squared() < 0.0001:
		dir = dash_dir.normalized() if dash_dir.length_squared() > 0.0001 else Vector2.RIGHT

	var landing: Vector2 = _vault_landing_position(_vault_commit_orb, dir)
	var along_to_landing: float = (landing - player_pos).dot(dir)
	# Not yet behind the orb.
	if along_to_landing > 1.0:
		return false

	var orb: RigidBody2D = _vault_commit_orb
	_vault_commit_orb = null

	owner.dash_component.end_and_clear_cooldown()
	_place_player_at_vault_landing(landing)

	if not orb.has_method("begin_vault_hold") or not orb.begin_vault_hold(owner):
		return true

	_vaulting = true
	_vault_orb = orb
	_vault_elapsed = 0.0
	_vault_forward = _compute_vault_forward(orb, dir)
	_last_redirect_aim = _vault_forward
	_redirect_preview_orb = orb
	if orb.has_method("set_focus_requested_by"):
		orb.set_focus_requested_by(owner, true)
	orb.set_redirect_preview(_get_vault_aim(), owner)
	return true


func clear_vault_dash_commit() -> void:
	_vault_commit_orb = null


## Legacy name kept for callers; prefer prepare_vault_dash + try_finish_vault_dash.
func try_vault_catch(from: Vector2, dash_dir: Vector2, remaining_distance: float) -> bool:
	var _adjusted: float = prepare_vault_dash(from, dash_dir, remaining_distance)
	return try_finish_vault_dash(from, dash_dir)


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

func _update_vault(delta: float) -> void:
	var orb := _get_vault_orb()
	if orb == null or not orb.has_method("is_vault_held") or not orb.is_vault_held():
		# Hold already cleared (circle capture / possess) — do not re-deflect.
		_clear_vault_state()
		_clear_redirect_preview()
		return
	if not is_instance_valid(owner):
		_fire_vault(false)
		return

	var holder: Node = null
	if orb.has_method("get_vault_holder"):
		holder = orb.get_vault_holder()
	if holder != owner:
		_clear_vault_state()
		_clear_redirect_preview()
		return

	_vault_elapsed += delta
	var aim: Vector2 = _get_vault_aim()
	orb.set_redirect_preview(aim, owner)

	# Dash-again: fire early along aim, then start a real dash (starts cooldown).
	# Prefer move stick / WASD for dash direction; facing stays as inbound fallback.
	var controls: Controls = owner.controls
	if controls.is_dash_just_pressed():
		_fire_vault(false)
		if is_instance_valid(owner) and owner.state_machine != null:
			var move: Vector2 = controls.get_move_vector()
			if move.length_squared() > 0.0001:
				owner.directional_sprite.face(move)
			owner.state_machine.force_state("dash")
		return

	if _vault_elapsed >= vault_hold_duration:
		_fire_vault(false)


func _fire_vault(consume_attack: bool) -> bool:
	if not _vaulting:
		return false

	var orb := _get_vault_orb()
	var still_held: bool = (
		orb != null and orb.has_method("is_vault_held") and orb.is_vault_held()
	)
	var aim: Vector2 = _get_vault_aim_for_orb(orb) if still_held else _vault_forward
	_clear_vault_state()

	if not still_held or orb == null or not orb.has_method("deflect"):
		_clear_redirect_preview()
		return false

	_begin_vault_recatch_cooldown(orb)

	var instigator: Node = owner if is_instance_valid(owner) else null
	orb.deflect(aim, instigator)
	_clear_redirect_preview()

	if consume_attack and is_instance_valid(owner):
		owner.attack_component.consume_cooldown()
		if owner.has_method("play_attack_visual"):
			owner.play_attack_visual(aim)

	return true


func _begin_vault_recatch_cooldown(orb: RigidBody2D) -> void:
	if orb == null or not is_instance_valid(orb) or vault_recatch_cooldown <= 0.0:
		_vault_recatch_orb = null
		_vault_recatch_until_msec = 0
		return
	_vault_recatch_orb = orb
	_vault_recatch_until_msec = Time.get_ticks_msec() + int(vault_recatch_cooldown * 1000.0)


func _is_vault_recatch_blocked(orb: RigidBody2D) -> bool:
	if orb == null or not is_instance_valid(_vault_recatch_orb):
		return false
	if orb != _vault_recatch_orb:
		return false
	if Time.get_ticks_msec() >= _vault_recatch_until_msec:
		_vault_recatch_orb = null
		_vault_recatch_until_msec = 0
		return false
	return true


func _clear_vault_state() -> void:
	_vaulting = false
	_vault_orb = null
	_vault_elapsed = 0.0


## First flying orb along the remaining dash ray within vault_catch_radius.
func _find_vault_catch_orb_on_ray(from: Vector2, dir: Vector2, length: float) -> RigidBody2D:
	var ray_len: float = maxf(length, 0.0)
	var best: RigidBody2D = null
	var best_along: float = INF
	var catch_r_sq: float = vault_catch_radius * vault_catch_radius

	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not _is_orb_flying(orb):
			continue
		if orb.has_method("is_vault_held") and orb.is_vault_held():
			continue
		if _is_vault_recatch_blocked(orb):
			continue

		var orb_pos: Vector2 = (orb as Node2D).global_position
		var offset: Vector2 = orb_pos - from
		var along: float = offset.dot(dir)
		# Behind the dash start (with catch-radius slack) or past the remaining ray.
		if along < -vault_catch_radius:
			continue
		if along > ray_len + vault_catch_radius:
			continue

		var clamped_along: float = clampf(along, 0.0, ray_len)
		var closest_on_ray: Vector2 = from + dir * clamped_along
		var dist_sq: float = orb_pos.distance_squared_to(closest_on_ray)
		if dist_sq > catch_r_sq:
			continue
		# Prefer the soonest orb along the path.
		if along < best_along:
			best_along = along
			best = orb

	return best


func _snap_player_opposite(orb: RigidBody2D, dash_dir: Vector2) -> void:
	_place_player_at_vault_landing(_vault_landing_position(orb, dash_dir))


func _vault_landing_position(orb: RigidBody2D, dash_dir: Vector2) -> Vector2:
	var dir: Vector2 = dash_dir
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var orb_radius: float = 8.0
	if orb.has_method("get_collision_radius"):
		orb_radius = orb.get_collision_radius()
	var player_radius: float = _get_player_body_radius()
	return (orb as Node2D).global_position + dir * (orb_radius + player_radius + vault_landing_gap)


func _place_player_at_vault_landing(landing: Vector2) -> void:
	var body := owner as CharacterBody2D
	if body == null:
		return
	body.global_position = landing
	var shape: CollisionShape2D = owner.body_collision_shape
	if shape == null or shape.shape == null:
		return
	var mask: int = PHYSICS_LAYER_WORLD | PHYSICS_LAYER_WALL
	if not CollisionSeparation.is_clear(body, shape, body.global_position, mask):
		CollisionSeparation.separate(body, shape, mask, CollisionSeparation.MAX_PUSH_PX)


func _get_player_body_radius() -> float:
	var shape: CollisionShape2D = owner.body_collision_shape
	if shape != null and shape.shape is CapsuleShape2D:
		return (shape.shape as CapsuleShape2D).radius
	if shape != null and shape.shape is CircleShape2D:
		return (shape.shape as CircleShape2D).radius
	return 6.0


## Live player → orb forward for the vault aim cone.
func _compute_vault_forward(orb: RigidBody2D, fallback: Vector2) -> Vector2:
	if not is_instance_valid(owner) or orb == null or not is_instance_valid(orb):
		return fallback if fallback.length_squared() > 0.0001 else Vector2.RIGHT
	var to_orb: Vector2 = (orb as Node2D).global_position - owner.global_position
	if to_orb.length_squared() > 0.0001:
		return to_orb.normalized()
	if fallback.length_squared() > 0.0001:
		return fallback.normalized()
	if _vault_forward.length_squared() > 0.0001:
		return _vault_forward
	return Vector2.RIGHT


## Aim during vault: clamp input to the cone around live player → orb.
func _get_vault_aim() -> Vector2:
	return _get_vault_aim_for_orb(_get_vault_orb())


func _get_vault_aim_for_orb(orb: RigidBody2D) -> Vector2:
	var raw: Vector2 = _get_redirect_aim()
	var forward: Vector2 = _compute_vault_forward(orb, _vault_forward)
	return _clamp_aim_to_vault_cone(raw, forward)


func _clamp_aim_to_vault_cone(aim: Vector2, forward: Vector2) -> Vector2:
	var fwd: Vector2 = forward
	if fwd.length_squared() < 0.0001:
		fwd = Vector2.RIGHT
	else:
		fwd = fwd.normalized()

	var half_rad: float = deg_to_rad(clampf(vault_aim_half_angle_degrees, 0.0, 180.0))
	if half_rad >= PI - 0.0001:
		return aim if aim.length_squared() > 0.0001 else fwd

	var desired: Vector2 = aim
	if desired.length_squared() < 0.0001:
		return fwd
	desired = desired.normalized()

	var min_dot: float = cos(half_rad)
	if desired.dot(fwd) >= min_dot - 0.0001:
		return desired

	# Nearest cone edge (± half_angle from forward).
	var cross_z: float = fwd.x * desired.y - fwd.y * desired.x
	var side: float = 1.0 if cross_z >= 0.0 else -1.0
	return fwd.rotated(side * half_rad)


func _try_immediate_tether() -> bool:
	# Release if this player owns a tether (one tether at a time).
	var owned := _find_owned_tethered_orb()
	if owned != null:
		owned.release_tether()
		_cooldown_until_msec = Time.get_ticks_msec() + int(tether_cooldown * 1000.0)
		return true

	if Time.get_ticks_msec() < _cooldown_until_msec:
		return false

	# Throw carried glyph on second pickup press.
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		if owner.has_method("try_throw_item"):
			return owner.try_throw_item()
		return false

	# Activate summoning circle while standing in its DepositArea (before glyph pickup).
	if _try_activate_summoning_circle():
		return true

	# Prefer nearby glyphs over orb capture.
	if _try_pickup_glyph():
		return true

	if not capture_enabled:
		return false

	# Capture closest flying orb within focus radius.
	var target := _find_closest_flying_orb(true)
	if target == null:
		return false

	# Always target min_tether_radius; orb spirals from its current capture distance.
	target.begin_tether(owner, min_tether_radius)
	return true


func _try_activate_summoning_circle() -> bool:
	for node in get_tree().get_nodes_in_group("summoning_circle"):
		var circle := node as SummoningCircle
		if circle == null or not is_instance_valid(circle):
			continue
		if not circle.contains_player(owner):
			continue
		if circle.try_activate():
			return true
	return false


func _try_pickup_glyph() -> bool:
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		return false
	var glyph := _find_closest_pickable_glyph(true)
	if glyph == null:
		return false
	if owner.has_method("pick_up_item"):
		return owner.pick_up_item(glyph)
	return glyph.pickup(owner)


func _find_closest_pickable_glyph(require_in_focus: bool) -> Glyph:
	var origin: Vector2 = owner.global_position
	var best: Glyph = null
	var best_dist_sq: float = INF
	for node in get_tree().get_nodes_in_group("glyphs"):
		var glyph := node as Glyph
		if glyph == null or not is_instance_valid(glyph):
			continue
		if not glyph.can_be_picked_up():
			continue
		var dist_sq: float = origin.distance_squared_to(glyph.global_position)
		if require_in_focus and dist_sq > focus_radius * focus_radius:
			continue
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = glyph
	return best


func _update_focus_overlays() -> void:
	if not tether_enabled or Time.get_ticks_msec() < _cooldown_until_msec:
		_clear_this_player_focus()
		return

	var origin: Vector2 = owner.global_position
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not orb.has_method("is_flying") or not orb.is_flying():
			# Tethered orbs keep focus via their own set_in_focus / tether guard.
			continue
		var distance: float = origin.distance_to(orb.global_position)
		var in_range: bool = distance <= focus_radius
		if orb.has_method("set_focus_requested_by"):
			orb.set_focus_requested_by(owner, in_range)
		elif orb.has_method("set_in_focus"):
			orb.set_in_focus(in_range)


func _update_redirect_preview() -> void:
	# Vault mode: no proximity chevron; vault window owns its own preview.
	if dash_vault_enabled:
		_clear_redirect_preview()
		return

	# Redirect preview is independent of tether recapture cooldown.
	if (
		not tether_enabled
		or is_tethering()
		or _channeling
		or (owner.has_method("is_carrying_item") and owner.is_carrying_item())
	):
		_clear_redirect_preview()
		return

	var closest := _find_closest_flying_orb(true)
	if closest == null or not closest.has_method("set_redirect_preview"):
		_clear_redirect_preview()
		return

	# Clear arrow on any previous preview target that is no longer closest.
	if (
		_redirect_preview_orb != null
		and is_instance_valid(_redirect_preview_orb)
		and _redirect_preview_orb != closest
		and _redirect_preview_orb.has_method("clear_redirect_preview")
	):
		_redirect_preview_orb.clear_redirect_preview(owner)

	_redirect_preview_orb = closest
	closest.set_redirect_preview(_get_redirect_aim(), owner)


func _clear_redirect_preview() -> void:
	if (
		_redirect_preview_orb != null
		and is_instance_valid(_redirect_preview_orb)
		and _redirect_preview_orb.has_method("clear_redirect_preview")
	):
		_redirect_preview_orb.clear_redirect_preview(owner)
	_redirect_preview_orb = null


func _get_redirect_aim() -> Vector2:
	if not is_instance_valid(owner):
		return _last_redirect_aim
	var controls: Controls = owner.controls
	var aim: Vector2 = controls.get_aim_vector(owner.global_position)
	if aim.length_squared() > 0.0001:
		_last_redirect_aim = aim.normalized()
	return _last_redirect_aim


func _clear_all_focus() -> void:
	_clear_this_player_focus()


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


func _get_vault_orb() -> RigidBody2D:
	if not is_instance_valid(_vault_orb):
		return null
	return _vault_orb
