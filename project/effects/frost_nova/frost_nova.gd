class_name FrostNova
extends Node2D

## One-shot frost-nova burst FX. Origin is the orb center (ring sits mid-frame).

const ANIM_BURST := &"burst"
## Sheet is 1248×96; 13 frames → 96×96 cells.
const FRAME_W := 96
const FRAME_H := 96
const FRAME_COUNT := 13

@export var burst_sound: SoundEvent

@onready var sprite: AnimatedSprite2D = %Sprite

var _anim_fps: float = 13.0
var _visual_scale: float = 1.0
var _setup_done: bool = false


func setup(anim_fps: float, visual_scale: float, sound: SoundEvent = null) -> void:
	_anim_fps = maxf(anim_fps, 0.001)
	_visual_scale = visual_scale
	if sound != null:
		burst_sound = sound
	_setup_done = true
	if is_node_ready():
		_begin()


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	if _setup_done:
		_begin()


func _begin() -> void:
	scale = Vector2(_visual_scale, _visual_scale)
	if sprite.sprite_frames != null:
		sprite.sprite_frames = sprite.sprite_frames.duplicate()
		sprite.sprite_frames.set_animation_speed(ANIM_BURST, _anim_fps)
	if burst_sound:
		AudioManager.play_at(burst_sound, global_position)
	sprite.play(ANIM_BURST)


func _on_animation_finished() -> void:
	queue_free()
