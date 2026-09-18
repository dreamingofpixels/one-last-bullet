class_name LightningStrike
extends Node2D

## One-shot Shock-10 stun FX. Ground splash sits at this node's origin.

const ANIM_STRIKE := &"strike"
## Sheet is 364×51; 7 frames → 52×51 cells.
const FRAME_W := 52
const FRAME_H := 51
## Centered sprite; shift up so the ground splash lands on the origin.
const SPRITE_OFFSET_Y := -float(FRAME_H) * 0.5
const DEFAULT_STRIKE_SOUND: SoundEvent = preload("res://effects/lightning_strike/lightning_strike.tres")

@export var strike_sound: SoundEvent = DEFAULT_STRIKE_SOUND

@onready var sprite: AnimatedSprite2D = %Sprite


func _ready() -> void:
	sprite.offset = Vector2(0.0, SPRITE_OFFSET_Y)
	sprite.animation_finished.connect(_on_animation_finished)
	if strike_sound:
		AudioManager.play_at(strike_sound, global_position)
	sprite.play(ANIM_STRIKE)


func _on_animation_finished() -> void:
	queue_free()
