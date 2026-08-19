class_name TimeSlowOverlay
extends CanvasLayer

## Fullscreen tether time-slow overlay.
## Call begin() when the orb becomes tethered; end() when it is released.
## Tweens Engine.time_scale from 1.0 to target_time_scale and back,
## and drives the shader `intensity` uniform in sync.

@export var target_time_scale: float = 0.5
@export var ramp_in_seconds: float = 0.3

@onready var overlay_rect: ColorRect = %OverlayRect

var _tween: Tween = null
var _current_intensity: float = 0.0


func _ready() -> void:
	# CanvasLayer children do not inherit Control layout; size must be set explicitly.
	overlay_rect.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_set_intensity(0.0)


func begin() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_ignore_time_scale(true)
	var scale_from: float = Engine.time_scale
	var intensity_from: float = _current_intensity
	# Map time_scale linearly to intensity: 1.0 scale → 0 intensity; target_scale → 1 intensity.
	var intensity_to: float = 1.0
	_tween.tween_method(
		func(t: float) -> void:
			var time_scale: float = lerpf(scale_from, target_time_scale, t)
			Engine.time_scale = time_scale
			var intensity: float = lerpf(intensity_from, intensity_to, t)
			_set_intensity(intensity),
		0.0,
		1.0,
		ramp_in_seconds
	)


func end() -> void:
	_kill_tween()
	Engine.time_scale = 1.0
	_set_intensity(0.0)


func _set_intensity(value: float) -> void:
	_current_intensity = value
	var mat := overlay_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("intensity", value)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_viewport_size_changed() -> void:
	overlay_rect.size = get_viewport().get_visible_rect().size


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Engine.time_scale = 1.0
