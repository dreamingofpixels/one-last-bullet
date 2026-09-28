class_name MediumExplosion
extends Node2D

## One-shot medium explosion FX. Origin is the blast center (ring matches cell width).

const ANIM_EXPLODE := &"explode"
## Sheet is 1344×96; 14 frames → 96×96 cells.
const FRAME_W := 96

@onready var sprite: AnimatedSprite2D = %Sprite


func blast_radius() -> float:
	return float(FRAME_W) * 0.5


func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	# Scene is saved on the last frame. play() does not rewind when the
	# animation name is already "explode".
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play(ANIM_EXPLODE)


func _on_animation_finished() -> void:
	queue_free()
