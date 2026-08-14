class_name HealthBarComponent extends Node2D

## The HealthComponent this bar displays. Required — fail if unset.
@export var health_component: HealthComponent
## Local offset from the Components node (entity origin). Tune per sprite height.
@export var offset: Vector2 = Vector2(0, -18)
@export var bar_width: int = 18
@export var bar_height: int = 2
@export var reveal_seconds: float = 1.5
@export var bg_color: Color = Color(0.1, 0.1, 0.1, 0.9)
@export var fill_color: Color = Color(0.9, 0.25, 0.15, 1.0)

var _current: float = 1.0
var _maximum: float = 1.0
var _reveal_until_msec: int = 0


func _ready() -> void:
	position = offset
	z_index = 10
	visible = false
	set_process(false)
	_current = health_component.health
	_maximum = health_component.max_health
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.health_changed.connect(_update_fill)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _reveal_until_msec:
		visible = false
		set_process(false)


func _draw() -> void:
	var half_w := bar_width * 0.5
	draw_rect(Rect2(-half_w, 0.0, float(bar_width), float(bar_height)), bg_color)
	if _maximum <= 0.0:
		return
	var fill_w := ceili(float(bar_width) * clampf(_current / _maximum, 0.0, 1.0))
	if fill_w > 0:
		draw_rect(Rect2(-half_w, 0.0, float(fill_w), float(bar_height)), fill_color)


func _on_damage_taken() -> void:
	_reveal_until_msec = Time.get_ticks_msec() + int(reveal_seconds * 1000.0)
	visible = true
	set_process(true)
	queue_redraw()


func _update_fill(current: float, maximum: float) -> void:
	_current = current
	_maximum = maximum
	queue_redraw()
