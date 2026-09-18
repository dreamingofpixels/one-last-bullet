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

const ICON_SIZE := 8
const ICON_GAP := 1
## Gap between the bottom of the icon row and the top of the HP bar.
const ICON_BAR_GAP := 2

const ICON_TEXTURES: Dictionary = {
	StatusComponent.ICON_STUN: preload("res://ui/statuses/stunned_status.png"),
	StatusComponent.ICON_DISEASE: preload("res://ui/statuses/disease_status.png"),
}

var _current: float = 1.0
var _maximum: float = 1.0
var _reveal_until_msec: int = 0
var _status_component: StatusComponent = null
var _icon_ids: Array[StringName] = []


func _ready() -> void:
	position = offset
	z_index = 10
	visible = false
	set_process(false)
	_current = health_component.health
	_maximum = health_component.max_health
	health_component.damage_taken.connect(_on_damage_taken)
	health_component.health_changed.connect(_update_fill)
	# ComponentHandler registers siblings in the same _ready pass; bind next frame.
	call_deferred("_bind_status_component")


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _reveal_until_msec:
		set_process(false)
		_refresh_visibility()
		queue_redraw()


func _draw() -> void:
	_draw_icons()
	if not _is_bar_revealed():
		return
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


func _bind_status_component() -> void:
	if owner == null:
		return
	var comp = owner.get("COMPONENTS")
	if comp == null or not comp.has(StatusComponent):
		return
	_status_component = comp[StatusComponent] as StatusComponent
	if _status_component == null:
		return
	if not _status_component.statuses_changed.is_connected(_on_statuses_changed):
		_status_component.statuses_changed.connect(_on_statuses_changed)
	_on_statuses_changed()


func _on_statuses_changed() -> void:
	if _status_component == null:
		_icon_ids.clear()
	else:
		_icon_ids = _status_component.get_visible_icon_ids()
	_refresh_visibility()
	queue_redraw()


func _is_bar_revealed() -> bool:
	return Time.get_ticks_msec() < _reveal_until_msec


func _has_icons() -> bool:
	return not _icon_ids.is_empty()


func _refresh_visibility() -> void:
	visible = _is_bar_revealed() or _has_icons()
	if _is_bar_revealed():
		set_process(true)


func _draw_icons() -> void:
	if _icon_ids.is_empty():
		return
	var count: int = _icon_ids.size()
	var row_w: float = float(count * ICON_SIZE + (count - 1) * ICON_GAP)
	var start_x: float = -row_w * 0.5
	var icon_y: float = -float(ICON_SIZE + ICON_BAR_GAP)
	for i in count:
		var tex: Texture2D = ICON_TEXTURES.get(_icon_ids[i]) as Texture2D
		if tex == null:
			continue
		var x: float = start_x + float(i * (ICON_SIZE + ICON_GAP))
		draw_texture_rect(tex, Rect2(x, icon_y, float(ICON_SIZE), float(ICON_SIZE)), false)
