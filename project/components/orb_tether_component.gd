class_name OrbTetherComponent extends Node2D

## Proximity focus + tether capture/release for orbs in the `orb` group.
## Also handles remote tether channeling (hold 2s to snap distant orb).
## Opening sling still uses bind_orb(); mid-combat uses closest-in-group targeting.
## Mid-combat steer is mutually exclusive via orb_redirect_mode: Attack bat (R1 / F) or dash vault.

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_ORB := 8
const PHYSICS_LAYER_WALL := 16

## Playtest A/B: pick one mid-combat orb redirect style.
enum OrbRedirectMode {
	ATTACK_BAT, ## R1 / F — swing-polygon bat along aim (hold = 360° in focus)
	DASH_VAULT, ## R2 into orb — vault hold then aim
}

@export var focus_radius: float = 32.0
@export var min_tether_radius: float = 24.0
@export var tether_cooldown: float = 0.25
@export var tether_enabled: bool = true
## When false, skip orb capture and remote channel; keep glyph pickup, focus, and Attack redirect.
@export var capture_enabled: bool = true
@export var remote_tether_hold_duration: float = 2.0
## Mutual exclusive mid-combat redirect (set per player character: wizard vault / dwarf bat).
@export var orb_redirect_mode: OrbRedirectMode = OrbRedirectMode.DASH_VAULT
@export var vault_catch_radius: float = 28.0
@export var vault_hold_duration: float = 0.5
@export var vault_landing_gap: float = 2.0
## Half-angle of the vault aim cone (180 = full 360°, 90 = 180° away from the player through the orb).
@export var vault_aim_half_angle_degrees: float = 180.0
## After releasing a vaulted orb, ignore that same orb for vault catch (stops dash-away re-grab).
@export var vault_recatch_cooldown: float = 0.35
## Hold Attack this long then release for a 360° bat (attack_around); shorter release = swing polygon.
@export var attack_charge_hold_seconds: float = 0.4
## Orb-only freeze after a connecting bat before deflect (unused for wedge-catch path; launch is on contact frame).
@export var attack_bat_hold_seconds: float = 0.15
## Front-swing (`attacking`) frame that applies the freeze / crack (0-based).
@export var attack_bat_contact_frame: int = 3
## Spin (`attack_around`) frame that applies the freeze / crack (0-based).
@export var attack_bat_spin_contact_frame: int = 1
## Fixed pitch for the one-shot crack at contact (send uses speed pitch separately).
@export var attack_bat_impact_pitch: float = 0.85
## Radius of the charged 360° bat (independent of glyph focus_radius).
@export var attack_spin_radius: float = 32.0
## Axe whoosh on every Attack bat (including misses).
@export var attack_bat_sound: SoundEvent = preload("res://entities/player/dwarf/axe_swing.tres")
## Hit SFX: fixed-pitch crack at contact + speed-pitched send at fly-off.
@export var attack_bat_redirect_sound: SoundEvent = preload("res://entities/player/dwarf/orb_redirect.tres")

## True when mid-combat steer is dash-into-orb vault (read by DashComponent).
var dash_vault_enabled: bool:
	get:
		return orb_redirect_mode == OrbRedirectMode.DASH_VAULT

## True when mid-combat steer is the R1 / F Attack bat.
var attack_bat_enabled: bool:
	get:
		return orb_redirect_mode == OrbRedirectMode.ATTACK_BAT

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
## Attack-bat charge: hold R1 / F on attack_around frame 0 until release.
var _attack_charging: bool = false
var _attack_charge_elapsed: float = 0.0
## Orbs frozen by wedge/spin catch awaiting contact-frame launch.
## Keys: orb, inbound, resume_velocity, default_dir.
var _bat_catches: Array[Dictionary] = []
## Swing waiting for contact frame (null when idle). Keys: front_cone, contact_frame, action.
var _pending_bat_swing: Variant = null


func _ready() -> void:
	z_index = 10
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)


func _on_tree_exiting() -> void:
	if _vaulting:
		_fire_vault(false)
	if _pending_bat_swing != null:
		_fire_pending_bat_swing()
	_release_bat_catches_unboosted()
	_cancel_attack_charge()
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

	# Contact-frame launch continues even while vaulting / charging.
	_update_pending_bat_swing()

	# --- Dash-vault aim window ---
	if _vaulting:
		_cancel_attack_charge()
		_update_vault(delta)
		return

	# --- Handle channeling state ---
	if _channeling:
		_cancel_attack_charge()
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

	# --- Attack-bat charge hold (R1 / F) ---
	if _attack_charging:
		_update_attack_charge(delta)
		_update_focus_overlays()
		_update_redirect_preview()
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

	# --- Attack bat (R1 / F): begin charge hold (polygon or 360° on release) ---
	if controls.is_attack_just_pressed():
		if _try_begin_attack_charge():
			return

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


func is_attack_charging() -> bool:
	return _attack_charging


## True when Attack has been held long enough that release will bat 360° in attack_spin_radius.
func is_attack_charge_ready() -> bool:
	return _attack_charging and _attack_charge_elapsed >= attack_charge_hold_seconds


func get_channel_progress() -> float:
	if not _channeling or remote_tether_hold_duration <= 0.0:
		return 0.0
	return clampf(_channel_elapsed / remote_tether_hold_duration, 0.0, 1.0)


## True when Attack will bat (orb in swing polygon) or vault-held orb can early-fire.
func has_redirect_target() -> bool:
	if not tether_enabled or is_tethering() or _channeling:
		return false
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		return false
	if dash_vault_enabled:
		return _vaulting and is_instance_valid(_vault_orb)
	if attack_bat_enabled:
		return _find_closest_orb_in_attack_polygon() != null
	return false


## Legacy entry point kept for player states that may still call it (release path).
func try_tether_press() -> bool:
	if not tether_enabled:
		return false
	return _try_immediate_tether()


## Bat flying orbs. front_cone=true → swing polygon along aim; false → 360° spin with radial bounce.
## Plays body clip even with no orbs in range. Does not refund dash cooldown.
## Catches may already be frozen from charge; release adds wedge or spin-ring catch then launches on contact frame.
func try_attack_bat(front_cone: bool = true) -> bool:
	if not attack_bat_enabled:
		return false
	if _pending_bat_swing != null:
		return false
	# Hard locks: never leave charge-catches frozen if we abort.
	if not tether_enabled or is_tethering() or _channeling or _vaulting:
		_release_bat_catches_unboosted()
		return false
	if owner.has_method("is_assembling") and owner.is_assembling():
		_release_bat_catches_unboosted()
		return false
	if owner.dash_component.is_dashing():
		_release_bat_catches_unboosted()
		return false

	var aim: Vector2 = get_bat_aim()
	if attack_bat_sound and owner is Node2D:
		AudioManager.play_at(attack_bat_sound, (owner as Node2D).global_position)

	owner.attack_component.consume_cooldown()
	# Dwarf hammer clips are the swing; skip wizard arc sprite.
	var use_body_only: bool = owner.has_method("uses_body_attack_swing") and owner.uses_body_attack_swing()
	if not use_body_only:
		owner.attack_component.play_swing_visual(aim)
	if front_cone:
		if owner.has_method("play_attack_visual"):
			owner.play_attack_visual(aim)
		_catch_orbs_in_wedge()
	else:
		owner.attack_component.begin_spin_overlay()
		if owner.has_method("play_attack_around_visual"):
			owner.play_attack_around_visual(aim)
		elif owner.has_method("play_attack_visual"):
			owner.play_attack_visual(aim)
		# Spin ring ∪ wedge so front orbs still catch when the circle is armed.
		_catch_orbs_in_spin_radius()
		_catch_orbs_in_wedge()

	_retag_bat_catches_for_launch(front_cone)
	if _bat_catches.is_empty():
		return true

	var action: StringName = &"attacking" if front_cone else &"attack_around"
	var contact_frame: int = (
		attack_bat_contact_frame if front_cone else attack_bat_spin_contact_frame
	)
	_pending_bat_swing = {
		"front_cone": front_cone,
		"contact_frame": contact_frame,
		"action": action,
	}
	_update_bat_catch_previews(front_cone)
	return true


## Circle-surface bounce: reflect velocity off the outward radial normal (player → orb).
## Near-zero / degenerate cases fall back to radial outward (or bat aim if on top of the player).
## Optional velocity_override is used when the orb is already frozen (linear_velocity is zero).
func _get_spin_bounce_direction(orb: RigidBody2D, velocity_override: Vector2 = Vector2.ZERO) -> Vector2:
	var from_player: Vector2 = orb.global_position - owner.global_position
	var normal: Vector2
	if from_player.length_squared() < 0.0001:
		normal = get_bat_aim()
		if normal.length_squared() < 0.0001:
			normal = Vector2.RIGHT
	else:
		normal = from_player.normalized()
	var velocity: Vector2 = velocity_override
	if velocity.length_squared() < 0.0001:
		velocity = orb.linear_velocity
	if velocity.length_squared() < 0.0001:
		return normal
	var bounced: Vector2 = velocity.bounce(normal)
	if bounced.length_squared() < 0.0001:
		return normal
	# Inbound-only reflect can leave a near-zero outbound; keep outward bias.
	if bounced.dot(normal) < 0.0:
		return normal
	return bounced.normalized()


## Freeze flying orbs overlapping the swing wedge (tap release only). Never used during charge.
func _catch_orbs_in_wedge() -> void:
	var aim: Vector2 = get_bat_aim()
	for orb in _find_orbs_in_attack_polygon():
		_try_catch_orb(orb, true, aim)


## Freeze flying orbs in the spin ring (spin release; try_attack_bat also unions the wedge).
func _catch_orbs_in_spin_radius() -> void:
	var aim: Vector2 = get_bat_aim()
	for orb in _find_flying_orbs_in_spin_radius():
		_try_catch_orb(orb, false, aim)


func _try_catch_orb(orb: RigidBody2D, front_cone: bool, aim: Vector2) -> bool:
	if orb == null or not is_instance_valid(orb):
		return false
	if not orb.has_method("begin_bat_hold"):
		return false
	if not _is_orb_flying(orb):
		return false
	if orb.has_method("is_vault_held") and orb.is_vault_held():
		return false
	if _bat_catch_index_of(orb) >= 0:
		return false

	var resume_velocity: Vector2 = orb.linear_velocity
	var inbound: Vector2
	var default_dir: Vector2
	if front_cone:
		default_dir = aim if aim.length_squared() > 0.0001 else Vector2.RIGHT
		inbound = -default_dir
	else:
		inbound = (
			resume_velocity
			if resume_velocity.length_squared() > 0.0001
			else -(orb.global_position - owner.global_position)
		)
		default_dir = _get_spin_bounce_direction(orb, resume_velocity)

	if not orb.begin_bat_hold(owner, inbound):
		return false

	_bat_catches.append({
		"orb": orb,
		"inbound": inbound,
		"resume_velocity": resume_velocity,
		"default_dir": default_dir,
	})
	if orb.has_method("set_redirect_preview"):
		orb.set_redirect_preview(default_dir, owner)
	return true


func _bat_catch_index_of(orb: RigidBody2D) -> int:
	for i in _bat_catches.size():
		if _bat_catches[i].get("orb") == orb:
			return i
	return -1


## After release, retag launch style for every catch (wedge-caught orbs may become spin launches).
func _retag_bat_catches_for_launch(front_cone: bool) -> void:
	for i in _bat_catches.size():
		var entry: Dictionary = _bat_catches[i]
		var orb: RigidBody2D = entry.get("orb") as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		var resume_velocity: Vector2 = entry.get("resume_velocity", Vector2.ZERO) as Vector2
		if front_cone:
			var aim: Vector2 = get_bat_aim()
			entry["default_dir"] = aim if aim.length_squared() > 0.0001 else Vector2.RIGHT
		else:
			entry["default_dir"] = _get_spin_bounce_direction(orb, resume_velocity)
		_bat_catches[i] = entry


func _update_bat_catch_previews(front_cone: bool) -> void:
	for entry in _bat_catches:
		var orb: RigidBody2D = entry.get("orb") as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not orb.has_method("set_redirect_preview"):
			continue
		var launch: Vector2 = _resolve_bat_catch_launch(entry, front_cone)
		orb.set_redirect_preview(launch, owner)


func _resolve_bat_catch_launch(entry: Dictionary, front_cone: bool) -> Vector2:
	var default_dir: Vector2 = entry.get("default_dir", Vector2.RIGHT) as Vector2
	if front_cone:
		return get_bat_aim()
	# Spin: always round-body bounce (no stick/aim override).
	if default_dir.length_squared() > 0.0001:
		return default_dir.normalized()
	return Vector2.RIGHT


## Cancel charge / abort: resume prior velocity with no deflect boost.
func _release_bat_catches_unboosted() -> void:
	for entry in _bat_catches:
		var orb: RigidBody2D = entry.get("orb") as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if orb.has_method("clear_redirect_preview"):
			orb.clear_redirect_preview(owner)
		if orb.has_method("end_bat_hold_restore"):
			var resume_velocity: Vector2 = entry.get("resume_velocity", Vector2.ZERO) as Vector2
			orb.end_bat_hold_restore(resume_velocity)
	_bat_catches.clear()


## Wait for the swing contact frame (or an interrupted clip) then launch catches.
func _update_pending_bat_swing() -> void:
	if _pending_bat_swing == null:
		return
	var pending: Dictionary = _pending_bat_swing as Dictionary
	var front_cone: bool = bool(pending.get("front_cone", true))
	_update_bat_catch_previews(front_cone)

	var action: StringName = pending.get("action", &"attacking") as StringName
	var sprite: DirectionalSpriteComponent = owner.directional_sprite
	if sprite == null:
		_fire_pending_bat_swing()
		return
	if not sprite.is_playing_action(action):
		_fire_pending_bat_swing()
		return
	var contact_frame: int = int(pending.get("contact_frame", 0))
	if sprite.get_frame() >= contact_frame:
		_fire_pending_bat_swing()


## Contact-frame send: deflect all catches, crack once, flash overlay.
func _fire_pending_bat_swing() -> void:
	if _pending_bat_swing == null:
		return
	var pending: Dictionary = _pending_bat_swing as Dictionary
	_pending_bat_swing = null
	var front_cone: bool = bool(pending.get("front_cone", true))

	# Snapshot valid launches first so SFX order is crack then pitched sends.
	var to_launch: Array[Dictionary] = []
	var i: int = 0
	while i < _bat_catches.size():
		var entry: Dictionary = _bat_catches[i]
		var orb: RigidBody2D = entry.get("orb") as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			_bat_catches.remove_at(i)
			continue
		if not orb.has_method("is_vault_held") or not orb.is_vault_held():
			if orb.has_method("clear_redirect_preview"):
				orb.clear_redirect_preview(owner)
			_bat_catches.remove_at(i)
			continue
		if not orb.has_method("deflect"):
			_bat_catches.remove_at(i)
			continue
		to_launch.append(entry)
		_bat_catches.remove_at(i)

	if to_launch.is_empty():
		return

	if owner.attack_component.has_method("flash_bat_hit"):
		owner.attack_component.flash_bat_hit()
	if attack_bat_redirect_sound and owner is Node2D:
		AudioManager.play_at(
			attack_bat_redirect_sound,
			(owner as Node2D).global_position,
			attack_bat_impact_pitch
		)

	var instigator: Node = owner if is_instance_valid(owner) else null
	for entry in to_launch:
		var orb: RigidBody2D = entry.get("orb") as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		var launch: Vector2 = _resolve_bat_catch_launch(entry, front_cone)
		orb.deflect(launch, instigator)
		if orb.has_method("clear_redirect_preview"):
			orb.clear_redirect_preview(owner)
		if attack_bat_redirect_sound:
			var pitch: float = _bat_redirect_pitch_for(orb)
			AudioManager.play_at(attack_bat_redirect_sound, orb.global_position, pitch)


func _bat_redirect_pitch_for(orb: RigidBody2D) -> float:
	var speed: float = 100.0
	var max_speed: float = 1500.0
	if orb.get("speed") != null:
		speed = float(orb.speed)
	if orb.get("max_speed") != null:
		max_speed = maxf(float(orb.max_speed), 1.0)
	var t: float = clampf((speed - 100.0) / (max_speed - 100.0), 0.0, 1.0)
	return lerpf(0.92, 1.45, t)


func _can_start_attack_bat() -> bool:
	if not tether_enabled or is_tethering() or _channeling or _vaulting:
		return false
	if _pending_bat_swing != null:
		return false
	if owner.has_method("is_assembling") and owner.is_assembling():
		return false
	if owner.dash_component.is_dashing():
		return false
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		return false
	if not owner.attack_component.can_attack():
		return false
	return true


func _try_begin_attack_charge() -> bool:
	if not attack_bat_enabled:
		return false
	if not _can_start_attack_bat():
		return false
	_attack_charging = true
	_attack_charge_elapsed = 0.0
	# Hold pose = first frame of attack_around (spin wind-up).
	# Orbs keep flying during charge; catch only on release via try_attack_bat.
	if owner.has_method("play_attack_around_visual"):
		owner.play_attack_around_visual(get_bat_aim())
	owner.directional_sprite.pause_hold_at_frame(0)
	return true


func _update_attack_charge(delta: float) -> void:
	var controls: Controls = owner.controls
	if not _can_continue_attack_charge():
		_cancel_attack_charge()
		return

	_attack_charge_elapsed += delta
	if owner.has_method("sync_body_facing"):
		owner.sync_body_facing()
	# Keep charge pose while held.
	if owner.directional_sprite != null and not owner.directional_sprite.is_playing_action(&"attack_around"):
		if owner.has_method("play_attack_around_visual"):
			owner.play_attack_around_visual(get_bat_aim())
		owner.directional_sprite.pause_hold_at_frame(0)

	if controls.is_attack_just_released() or not controls.is_attack_pressed():
		var full_circle: bool = _attack_charge_elapsed >= attack_charge_hold_seconds
		_attack_charging = false
		_attack_charge_elapsed = 0.0
		try_attack_bat(not full_circle)
		return


func _can_continue_attack_charge() -> bool:
	if not attack_bat_enabled or not tether_enabled:
		return false
	if is_tethering() or _channeling or _vaulting:
		return false
	if owner.has_method("is_assembling") and owner.is_assembling():
		return false
	if owner.dash_component.is_dashing():
		return false
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		return false
	return true


func _cancel_attack_charge() -> void:
	if not _attack_charging:
		return
	_attack_charging = false
	_attack_charge_elapsed = 0.0
	_release_bat_catches_unboosted()
	# Drop back to idle/moving; states will re-assert locomotion next frame.
	# Skip sprite restore during player/level teardown (_on_tree_exiting).
	if not is_instance_valid(owner) or owner.directional_sprite == null:
		return
	if owner.directional_sprite.is_playing_action(&"attack_around"):
		owner.directional_sprite.play(&"idle", true)


## Public alias so Dash / other states can abort a held Attack charge.
func cancel_attack_charge() -> void:
	_cancel_attack_charge()


func _find_flying_orbs_in_focus() -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	var origin: Vector2 = owner.global_position
	var radius_sq: float = focus_radius * focus_radius
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not _is_orb_flying(orb):
			continue
		if origin.distance_squared_to(orb.global_position) <= radius_sq:
			result.append(orb)
	return result


func _find_flying_orbs_in_spin_radius() -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	var origin: Vector2 = owner.global_position
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not _is_orb_flying(orb):
			continue
		if orb.has_method("is_vault_held") and orb.is_vault_held():
			continue
		var orb_radius: float = 8.0
		if orb.has_method("get_collision_radius"):
			orb_radius = orb.get_collision_radius()
		var reach: float = attack_spin_radius + orb_radius
		if origin.distance_squared_to(orb.global_position) <= reach * reach:
			result.append(orb)
	return result


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


## Dash-end shoulder redirect: deflect every flying orb whose hurtbox overlaps the player
## hurtbox along `direction`. Used by dwarf dash_end_redirect before monitoring returns.
## Returns how many orbs were redirected.
func redirect_overlapping_orbs(direction: Vector2) -> int:
	if not is_instance_valid(owner):
		return 0
	var hitbox_shape: CollisionShape2D = owner.get("hitbox_shape") as CollisionShape2D
	if hitbox_shape == null or hitbox_shape.shape == null:
		return 0

	var dir: Vector2 = direction
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = hitbox_shape.shape
	params.transform = hitbox_shape.global_transform
	params.collision_mask = PHYSICS_LAYER_ORB
	params.collide_with_bodies = false
	params.collide_with_areas = true
	params.exclude = [owner.get_rid()]

	var hits: Array[Dictionary] = space.intersect_shape(params, 32)
	if hits.is_empty():
		return 0

	var seen_ids: Dictionary = {}
	var redirected: int = 0
	var instigator: Node = owner
	for hit in hits:
		var orb: RigidBody2D = _resolve_orb_from_collider(hit.get("collider"))
		if orb == null:
			continue
		var orb_id: int = orb.get_instance_id()
		if seen_ids.has(orb_id):
			continue
		seen_ids[orb_id] = true
		if not _can_dash_end_redirect_orb(orb):
			continue
		orb.deflect(dir, instigator)
		if orb.has_method("clear_redirect_preview"):
			orb.clear_redirect_preview(owner)
		if attack_bat_redirect_sound:
			var pitch: float = _bat_redirect_pitch_for(orb)
			AudioManager.play_at(attack_bat_redirect_sound, orb.global_position, pitch)
		redirected += 1

	return redirected


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

	# Throw carried glyph on second pickup press — unless the circle ritual wants the press.
	if owner.has_method("is_carrying_item") and owner.is_carrying_item():
		if _try_ritual_circle_pickup():
			return true
		if owner.has_method("try_throw_item"):
			return owner.try_throw_item()
		return false

	# Live ritual socket / unsocket while an orb is captured in the circle.
	if _try_ritual_circle_pickup():
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


func _try_ritual_circle_pickup() -> bool:
	for node in get_tree().get_nodes_in_group("summoning_circle"):
		var circle := node as SummoningCircle
		if circle == null or not is_instance_valid(circle):
			continue
		if circle.try_handle_ritual_pickup(owner):
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
	# Vault window owns its own preview while holding; skip proximity chevron then.
	if _vaulting:
		return

	# Bat catches own chevrons on held orbs; do not clear or steal them.
	if not _bat_catches.is_empty():
		return

	# Attack-bat chevron only in ATTACK_BAT mode.
	if not attack_bat_enabled:
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

	var controls: Controls = owner.controls
	if not controls.is_explicitly_aiming():
		_clear_redirect_preview()
		return

	var closest := _find_closest_orb_in_attack_polygon()
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
	closest.set_redirect_preview(get_bat_aim(), owner)


func _clear_redirect_preview() -> void:
	if (
		_redirect_preview_orb != null
		and is_instance_valid(_redirect_preview_orb)
		and _redirect_preview_orb.has_method("clear_redirect_preview")
	):
		_redirect_preview_orb.clear_redirect_preview(owner)
	_redirect_preview_orb = null


## Attack-bat aim: right stick (mouse on keyboard/mouse scheme). Neutral stick keeps last aim.
func get_bat_aim() -> Vector2:
	if not is_instance_valid(owner):
		return _last_redirect_aim
	var controls: Controls = owner.controls
	var explicit: Vector2 = controls.get_explicit_aim_vector(owner.global_position)
	if explicit.length_squared() > 0.0001:
		_last_redirect_aim = explicit.normalized()
	return _last_redirect_aim


func _get_redirect_aim() -> Vector2:
	if not is_instance_valid(owner):
		return _last_redirect_aim
	var controls: Controls = owner.controls
	var aim: Vector2 = controls.get_aim_vector(owner.global_position)
	if aim.length_squared() > 0.0001:
		_last_redirect_aim = aim.normalized()
	return _last_redirect_aim


## True when the flying orb's body circle overlaps the AttackComponent swing polygon.
func _orb_in_attack_polygon(orb: RigidBody2D) -> bool:
	if orb == null or not is_instance_valid(orb):
		return false
	var radius: float = 8.0
	if orb.has_method("get_collision_radius"):
		radius = orb.get_collision_radius()
	return owner.attack_component.overlaps_world_circle(orb.global_position, radius)


func _find_orbs_in_attack_polygon() -> Array[RigidBody2D]:
	var result: Array[RigidBody2D] = []
	for node in get_tree().get_nodes_in_group("orb"):
		var orb := node as RigidBody2D
		if orb == null or not is_instance_valid(orb):
			continue
		if not _is_orb_flying(orb):
			continue
		if orb.has_method("is_vault_held") and orb.is_vault_held():
			continue
		if _orb_in_attack_polygon(orb):
			result.append(orb)
	return result


func _find_closest_orb_in_attack_polygon() -> RigidBody2D:
	var origin: Vector2 = owner.global_position
	var best: RigidBody2D = null
	var best_dist_sq: float = INF
	for orb in _find_orbs_in_attack_polygon():
		var dist_sq: float = origin.distance_squared_to(orb.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = orb
	return best


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
		if orb.has_method("is_vault_held") and orb.is_vault_held():
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


func _resolve_orb_from_collider(collider: Variant) -> RigidBody2D:
	if collider == null or not is_instance_valid(collider):
		return null
	if not collider is Node:
		return null
	var node: Node = collider as Node
	if collider is Area2D:
		var area_owner: Node = (collider as Area2D).owner
		if area_owner is RigidBody2D and area_owner.is_in_group("orb"):
			return area_owner as RigidBody2D
	while node != null:
		if node is RigidBody2D and node.is_in_group("orb"):
			return node as RigidBody2D
		node = node.get_parent()
	return null


func _can_dash_end_redirect_orb(orb: RigidBody2D) -> bool:
	if not _is_orb_flying(orb) or not orb.has_method("deflect"):
		return false
	var comp = orb.get("COMPONENTS")
	if comp == null or not comp.has(DamageComponent):
		return false
	var dc: DamageComponent = comp[DamageComponent]
	if dc.damage <= 0.0:
		return false
	if is_instance_valid(dc.instigator) and dc.instigator == owner:
		return false
	if orb.has_method("should_apply_hitbox_damage") and not bool(orb.should_apply_hitbox_damage(owner)):
		return false
	return true


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
