class_name SpawnTelegraphEffect
extends Node2D

const RING_COLOR := Color(0.95, 0.35, 0.12, 0.95)
const FILL_COLOR := Color(0.95, 0.22, 0.08, 0.28)
const RING_RADIUS := 14.0
const RING_WIDTH := 1.5
const PULSE_SPEED := 2.5
const PULSE_AMOUNT := 0.14


static func play(
	parent: Node,
	at_position: Vector2,
	telegraph_duration: float,
	assemble_duration: float
) -> void:
	if parent == null:
		return

	var fx := SpawnTelegraphEffect.new()
	fx.z_index = 0
	fx._telegraph_duration = maxf(telegraph_duration, 0.0)
	fx._assemble_duration = maxf(assemble_duration, 0.0)
	parent.add_child(fx)
	fx.global_position = at_position


var _telegraph_duration: float = 0.6
var _assemble_duration: float = 2.0
var _elapsed: float = 0.0


func _ready() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _telegraph_duration + _assemble_duration:
		queue_free()


func _draw() -> void:
	var pulse := 1.0
	var alpha := 1.0
	if _elapsed <= _telegraph_duration:
		pulse = 1.0 + PULSE_AMOUNT * sin(_elapsed * TAU * PULSE_SPEED)
	else:
		var fade_t := (_elapsed - _telegraph_duration) / maxf(_assemble_duration, 0.001)
		alpha = 1.0 - clampf(fade_t, 0.0, 1.0)

	var radius := RING_RADIUS * pulse
	var fill := Color(FILL_COLOR, FILL_COLOR.a * alpha)
	var ring := Color(RING_COLOR, RING_COLOR.a * alpha)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring, RING_WIDTH)
