class_name DirectionalSpriteComponent extends Node2D

## Tracks 8-way logical facing (N/S/E/W + diagonals) and plays
## "<action>_<visual>" on an AnimatedSprite2D. Visual art is 4-way
## diagonal only (sw/se/ne/nw); cardinals map to the nearest diagonal.

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


## Switch action (idle / walk / attack). Facing suffix is applied automatically.
func play(action: StringName) -> void:
	if action == _action:
		return
	_action = action
	_refresh()


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


func _is_east_visual() -> bool:
	return _visual_suffix == "se" or _visual_suffix == "ne"


func _is_south_visual() -> bool:
	return _visual_suffix == "se" or _visual_suffix == "sw"


func _refresh() -> void:
	if animated_sprite == null:
		return
	var anim: StringName = StringName("%s_%s" % [_action, _visual_suffix])
	if anim == _current_anim:
		return
	_current_anim = anim
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
