class_name DashComponent extends Node2D

## Fixed-distance dash with i-frames. Self-driven via _physics_process.
## While dashing, the player phases through props and enemies but still
## collides with the arena's outer walls (physics layer `wall`).

const PHYSICS_LAYER_WALL := 16

@export var dash_distance: float = 50.0
@export var dash_speed: float = 400.0
@export var dash_cooldown: float = 4.0
@export var animated_sprite: AnimatedSprite2D
@export var hitbox_component: HitboxComponent
@export var dash_sound: SoundEvent = preload("res://entities/player/dash.tres")
@export var dash_alpha: float = 0.55
@export var afterimage_enabled: bool = true
@export var afterimage_interval: float = 16.0
@export var indicator_enabled: bool = true
@export var indicator_offset: Vector2 = Vector2(0, -26)
@export var indicator_radius: float = 3.0
@export var indicator_line_width: float = 1.0
@export var indicator_bg_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var indicator_fill_color: Color = Color(1.0, 1.0, 1.0, 0.9)

var _direction: Vector2 = Vector2.RIGHT
var _remaining_distance: float = 0.0
var _dashing: bool = false
var _cooldown_until_msec: int = 0
var _saved_collision_mask: int = 0
var _saved_collision_layer: int = 0
var _saved_modulate: Color = Color.WHITE
var _distance_since_last_afterimage: float = 0.0


func _ready() -> void:
	z_index = 10
	set_physics_process(false)
	set_process(false)
	if indicator_enabled:
		visible = false


func start(direction: Vector2) -> void:
	if not can_dash():
		return
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	_remaining_distance = dash_distance
	_distance_since_last_afterimage = 0.0
	_dashing = true
	if animated_sprite:
		_saved_modulate = animated_sprite.modulate
		var alpha: float = clampf(dash_alpha, 0.0, 1.0)
		var dash_modulate := _saved_modulate
		dash_modulate.a = alpha
		animated_sprite.modulate = dash_modulate
		if _direction.x != 0.0:
			animated_sprite.flip_h = _direction.x < 0.0
	if hitbox_component:
		hitbox_component.set_invulnerable(true)
	if dash_sound and owner is Node2D:
		AudioManager.play_at(dash_sound, (owner as Node2D).global_position)
	_begin_phase()
	set_physics_process(true)


func is_dashing() -> bool:
	return _dashing


func can_dash() -> bool:
	return not _dashing and Time.get_ticks_msec() >= _cooldown_until_msec


func _physics_process(delta: float) -> void:
	if not _dashing:
		set_physics_process(false)
		return

	var body := owner as CharacterBody2D
	var start_pos: Vector2 = body.global_position
	var step: float = minf(dash_speed * delta, _remaining_distance)
	if delta > 0.0:
		body.velocity = _direction * (step / delta)
	else:
		body.velocity = Vector2.ZERO
	body.move_and_slide()

	var moved: float = start_pos.distance_to(body.global_position)
	if afterimage_enabled and afterimage_interval > 0.0 and animated_sprite:
		_distance_since_last_afterimage += moved
		if _distance_since_last_afterimage >= afterimage_interval:
			_spawn_afterimage(start_pos)
			_distance_since_last_afterimage = 0.0
	# Consume intended distance so a wall block cannot stall the dash forever.
	_remaining_distance -= step

	if _remaining_distance <= 0.0:
		_end_dash()


func _end_dash() -> void:
	_dashing = false
	_remaining_distance = 0.0
	var body := owner as CharacterBody2D
	body.velocity = Vector2.ZERO
	_end_phase()
	if hitbox_component:
		hitbox_component.set_invulnerable(false)
	if animated_sprite:
		animated_sprite.modulate = _saved_modulate
	_cooldown_until_msec = Time.get_ticks_msec() + int(dash_cooldown * 1000.0)
	set_physics_process(false)
	if indicator_enabled:
		set_process(true)
		queue_redraw()


func _begin_phase() -> void:
	var body := owner as CharacterBody2D
	_saved_collision_mask = body.collision_mask
	_saved_collision_layer = body.collision_layer
	body.collision_layer = 0
	body.collision_mask = PHYSICS_LAYER_WALL


func _end_phase() -> void:
	var body := owner as CharacterBody2D
	body.collision_mask = _saved_collision_mask
	body.collision_layer = _saved_collision_layer


func _spawn_afterimage(position: Vector2) -> void:
	var parent := owner as Node
	DashAfterimageEffect.spawn(parent, animated_sprite, position)


func _process(_delta: float) -> void:
	if _get_cooldown_fraction() >= 1.0:
		visible = false
		set_process(false)
		return
	visible = true
	queue_redraw()


func _draw() -> void:
	if not indicator_enabled:
		return
	var fraction := _get_cooldown_fraction()
	if fraction >= 1.0:
		return
	var center := indicator_offset
	draw_arc(center, indicator_radius, 0.0, TAU, 24, indicator_bg_color, indicator_line_width)
	if fraction <= 0.0:
		return
	var start_angle := -PI / 2.0
	draw_arc(center, indicator_radius, start_angle, start_angle + TAU * fraction, 24, indicator_fill_color, indicator_line_width)


func _get_cooldown_fraction() -> float:
	if _dashing:
		return 0.0
	var remaining_msec := _cooldown_until_msec - Time.get_ticks_msec()
	if remaining_msec <= 0:
		return 1.0
	return 1.0 - (float(remaining_msec) / (dash_cooldown * 1000.0))
