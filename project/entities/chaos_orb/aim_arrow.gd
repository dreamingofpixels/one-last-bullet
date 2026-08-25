extends Node2D

## Three chevrons outside the 8 px orb body, marching along local +X (aim).
@export var start_distance: float = 12.0
@export var spacing: float = 8.0
@export var chevron_count: int = 3
@export var chevron_depth: float = 4.0
@export var chevron_half_height: float = 3.5
@export var line_width: float = 1.25
@export var outline_width: float = 2.5
@export var color: Color = Color(1.0, 0.92, 0.45, 1.0)
@export var outline_color: Color = Color(0.08, 0.05, 0.12, 0.9)
@export var pulse_speed: float = 3.5
@export var pulse_travel: float = 2.0

var _elapsed: float = 0.0


func _ready() -> void:
	set_process(false)
	hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(visible)
		if visible:
			queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var phase: float = _elapsed * pulse_speed
	var travel: float = sin(phase) * pulse_travel
	for i in chevron_count:
		var origin := Vector2(start_distance + float(i) * spacing + travel, 0.0)
		var fade: float = 1.0 - float(i) / float(maxi(chevron_count, 1)) * 0.35
		var pulse: float = 0.72 + 0.28 * sin(phase - float(i) * 0.9)
		var col := Color(color, color.a * fade * pulse)
		var outline := Color(outline_color, outline_color.a * fade * pulse)
		_draw_chevron(origin, outline, outline_width)
		_draw_chevron(origin, col, line_width)


func _draw_chevron(origin: Vector2, col: Color, width: float) -> void:
	var tip := origin + Vector2(chevron_depth, 0.0)
	var top := origin + Vector2(0.0, -chevron_half_height)
	var bot := origin + Vector2(0.0, chevron_half_height)
	draw_line(top, tip, col, width)
	draw_line(bot, tip, col, width)
