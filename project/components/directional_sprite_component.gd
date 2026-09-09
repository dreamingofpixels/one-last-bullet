class_name DirectionalSpriteComponent extends Node2D

## Tracks 8-way logical facing (N/S/E/W + diagonals) and plays
## "<action>_<west>" on an AnimatedSprite2D. Authored art is SW/NW only;
## SE/NE reuse those clips with flip_h. Cardinals map to the nearest diagonal.

enum Facing { N, S, E, W, NE, NW, SE, SW }

signal facing_changed(facing: Facing)

## tan(22.5°) — boundary between cardinal and diagonal octants.
const _CARDINAL_THRESHOLD := 0.41421356237

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

var facing: Facing
var _action: StringName = &"idle"
var _current_anim: StringName = &""
var _visual_suffix: String = "se"
var _flip_h: bool = true


func _ready() -> void:
	facing = default_facing
	_sync_visual()
	_refresh()


## Zero-length input is ignored. Snaps to the nearest of 8 octants.
func face(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return

	var next := _octant(direction)
	if next == facing:
		return
	facing = next
	_sync_visual()
	facing_changed.emit(facing)
	_refresh()


## Switch action (idle / moving / attacking). Facing suffix + flip applied automatically.
## Pass restart=true to replay the same action from frame 0 (e.g. a second redirect).
func play(action: StringName, restart: bool = false) -> void:
	if action == _action and not restart:
		return
	_action = action
	if restart:
		_current_anim = &""
	_refresh()


## True while the given action clip is the current one and still playing.
func is_playing_action(action: StringName) -> bool:
	if _action != action:
		return false
	if animated_sprite == null:
		return false
	return animated_sprite.is_playing()


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


## Cardinals reuse the prior visual's other axis (N keeps E/W bias, etc.).
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
			_visual_suffix = "ne" if _is_east_visual() else "nw"
		Facing.S:
			_visual_suffix = "se" if _is_east_visual() else "sw"
		Facing.E:
			_visual_suffix = "se" if _is_south_visual() else "ne"
		Facing.W:
			_visual_suffix = "sw" if _is_south_visual() else "nw"
	_flip_h = _is_east_visual()


func _is_east_visual() -> bool:
	return _visual_suffix == "se" or _visual_suffix == "ne"


func _is_south_visual() -> bool:
	return _visual_suffix == "se" or _visual_suffix == "sw"


func _west_suffix() -> String:
	return "sw" if _is_south_visual() else "nw"


func _refresh() -> void:
	if animated_sprite == null:
		return
	animated_sprite.flip_h = _flip_h
	var anim: StringName = StringName("%s_%s" % [_action, _west_suffix()])
	if anim == _current_anim:
		return
	_current_anim = anim
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
