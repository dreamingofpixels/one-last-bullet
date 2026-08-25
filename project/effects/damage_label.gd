extends Node2D

const RISE_PX := 20.0
const DURATION := 1.0
const FADE_SECONDS := 0.3
const JITTER_X := 4.0

@onready var label: Label = %Label


func play(amount: float, color: Color) -> void:
	label.text = str(roundi(amount))
	label.add_theme_color_override("font_color", color)
	if color.r + color.g + color.b < 0.5:
		label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 1.0))
	else:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 1)

	position.x += randf_range(-JITTER_X, JITTER_X)

	var start: Vector2 = position
	var end: Vector2 = start + Vector2(0.0, -RISE_PX)
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(self, "position", end, DURATION).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS).set_delay(DURATION - FADE_SECONDS)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
