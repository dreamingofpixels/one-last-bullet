class_name DirectionalSpriteComponent extends Node2D

## Tracks 8-way logical facing (N/S/E/W + diagonals) and plays
## "<action>_<west>" on an AnimatedSprite2D. Authored art is SW/NW only;
## SE/NE reuse those clips with flip_h. N/S pick east/west from aim X (flip at 12/6);
## E/W keep the last N/S diagonal. If an NW clip is missing (e.g. dwarf SW-only), falls back to SW.

enum Facing { N, S, E, W, NE, NW, SE, SW }

signal facing_changed(facing: Facing)

## tan(22.5°) — boundary between cardinal and diagonal octants.
const _CARDINAL_THRESHOLD := 0.41421356237
## Normalized X must pass this to flip east/west at N/S (~3° off 12/6 o'clock).
const _AXIS_FLIP_DEADZONE := 0.05

const _VECTOR: Dictionary = {
	Facing.N: Vector2(0, -1),
	Facing.S: Vector2(0, 1),
	Facing.E: Vector2(1, 0),
	Facing.W: Vector2(-1, 0),
	Facing.SW: Vector2(-1, 1),
	Facing.SE: Vector2(1, 1),
	Facing.NE: Vector2(1, -1),
	Facing.NW: Vector2(-1, -1),
}

@export var animated_sprite: AnimatedSprite2D
@export var default_facing: Facing = Facing.SE
## When true, invert east/west flip (for sheets authored facing SE instead of SW).
@export var flip_h_inverted: bool = false

var facing: Facing
var _action: StringName = &"idle"
var _current_anim: StringName = &""
var _visual_suffix: String = "se"
var _flip_h: bool = true
## Last non-zero `face()` vector; N/S east-west uses its X sign.
var _face_dir: Vector2 = Vector2.RIGHT
## True while pause_hold_at_frame() froze a clip (charge pose); counts as playing that action.
var _hold_paused: bool = false


func _ready() -> void:
	facing = default_facing
	_face_dir = _VECTOR[default_facing] as Vector2
	_sync_visual()
	_refresh()


## Toggle east/west flip polarity (dwarf SE art vs wizard SW art). Re-applies immediately.
func set_flip_h_inverted(inverted: bool) -> void:
	if flip_h_inverted == inverted:
		return
	flip_h_inverted = inverted
	_sync_visual()
	_refresh()


## Zero-length input is ignored. Snaps to the nearest of 8 octants.
## N/S also refresh east/west from aim X while the octant stays north/south.
func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return

	_face_dir = direction
	var next := _octant(direction)
	var old_facing: Facing = facing
	var old_suffix: String = _visual_suffix
	facing = next
	_sync_visual()
	if facing == old_facing and _visual_suffix == old_suffix:
		return
	if facing != old_facing:
		facing_changed.emit(facing)
	_refresh()


## Switch action (idle / moving / attacking / attack_around). Facing suffix + flip applied automatically.
## Pass restart=true to replay the same action from frame 0 (e.g. a second redirect).
func play(action: StringName, restart: bool = false) -> void:
	if action == _action and not restart:
		return
	_action = action
	_hold_paused = false
	if restart:
		_current_anim = &""
	_refresh()


## Freeze the current clip on a frame (dwarf Attack charge hold on attack_around frame 0).
func pause_hold_at_frame(frame: int = 0) -> void:
	if animated_sprite == null:
		return
	animated_sprite.pause()
	animated_sprite.frame = frame
	_hold_paused = true


## Resume a pause_hold_at_frame clip from the held frame (no restart at 0).
func resume_hold() -> void:
	if animated_sprite == null:
		return
	if not _hold_paused:
		return
	var held_frame: int = animated_sprite.frame
	_hold_paused = false
	var anim: StringName = _current_anim
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
		animated_sprite.set_frame_and_progress(held_frame, 0.0)


## Current AnimatedSprite2D frame (0 when no sprite).
func get_frame() -> int:
	if animated_sprite == null:
		return 0
	return animated_sprite.frame


## Current logical action (idle / moving / attacking / attack_around).
func get_action() -> StringName:
	return _action


## True while pause_hold_at_frame froze the clip.
func is_hold_paused() -> bool:
	return _hold_paused


## True while the given action clip is current and still playing, or held paused for charge.
func is_playing_action(action: StringName) -> bool:
	if _action != action:
		return false
	if animated_sprite == null:
		return false
	return animated_sprite.is_playing() or _hold_paused


## Unit vector for the current 8-way facing (dash direction).
func facing_vector() -> Vector2:
	return (_VECTOR[facing] as Vector2).normalized()


func _octant(direction: Vector2) -> Facing:
	var d := direction.normalized()
	var ax := absf(d.x)
	var ay := absf(d.y)

	if ay < ax * _CARDINAL_THRESHOLD:
		return Facing.E if d.x > 0.0 else Facing.W
	if ax < ay * _CARDINAL_THRESHOLD:
		return Facing.S if d.y > 0.0 else Facing.N

	if d.x > 0.0:
		return Facing.SE if d.y > 0.0 else Facing.NE
	return Facing.SW if d.y > 0.0 else Facing.NW


## N/S pick east/west from aim X (flip at 12/6). E/W still keep N/S bias from the last diagonal.
func _sync_visual() -> void:
	match facing:
		Facing.SW:
			_visual_suffix = "sw"
		Facing.SE:
			_visual_suffix = "se"
		Facing.NE:
			_visual_suffix = "ne"
		Facing.NW:
			_visual_suffix = "nw"
		Facing.N:
			_visual_suffix = "ne" if _prefer_east_from_x(_face_dir.x) else "nw"
		Facing.S:
			_visual_suffix = "se" if _prefer_east_from_x(_face_dir.x) else "sw"
		Facing.E:
			_visual_suffix = "se" if _is_south_visual() else "ne"
		Facing.W:
			_visual_suffix = "sw" if _is_south_visual() else "nw"
	# Authored west clips play unflipped; east uses flip_h. Invert for SE-authored sheets (dwarf).
	_flip_h = _is_east_visual() != flip_h_inverted


## True when X is clearly right of 12/6. Near-zero X keeps the current east/west so analog noise does not flicker.
func _prefer_east_from_x(x: float) -> bool:
	if absf(x) <= _AXIS_FLIP_DEADZONE:
		return _is_east_visual()
	return x > 0.0


func _is_east_visual() -> bool:
	return _visual_suffix == "se" or _visual_suffix == "ne"


func _is_south_visual() -> bool:
	return _visual_suffix == "se" or _visual_suffix == "sw"


func _west_suffix() -> String:
	return "sw" if _is_south_visual() else "nw"


func _resolve_anim_name() -> StringName:
	var preferred: StringName = StringName("%s_%s" % [_action, _west_suffix()])
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return preferred
	if animated_sprite.sprite_frames.has_animation(preferred):
		return preferred
	# Dwarf (and future SW-only sheets): reuse south-west when NW is missing.
	var sw_fallback: StringName = StringName("%s_sw" % _action)
	if animated_sprite.sprite_frames.has_animation(sw_fallback):
		return sw_fallback
	return preferred


func _refresh() -> void:
	if animated_sprite == null:
		return
	animated_sprite.flip_h = _flip_h
	var anim: StringName = _resolve_anim_name()
	if anim == _current_anim:
		# Same clip (incl. charge pause-hold): flip_h already applied; do not restart.
		return
	_current_anim = anim
	_hold_paused = false
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
