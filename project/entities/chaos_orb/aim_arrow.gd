extends Node2D

## Sized to fit inside the 8 px orb body (tip stays within the circle).
@export var shaft_length: float = 4.0
@export var shaft_width: float = 1.0
@export var head_length: float = 3.0
@export var head_width: float = 4.0
@export var color: Color = Color(1.0, 0.85, 0.2, 1.0)


func _draw() -> void:
	if not visible:
		return
	draw_line(Vector2.ZERO, Vector2(shaft_length, 0.0), color, shaft_width)
	var tip := Vector2(shaft_length + head_length, 0.0)
	var left := Vector2(shaft_length, -head_width * 0.5)
	var right := Vector2(shaft_length, head_width * 0.5)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
