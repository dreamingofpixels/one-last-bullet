@tool
class_name EnemyAttackComponent extends Area2D

## Committed enemy melee: proximity windup → hold telegraph → strike with an authored rect hitbox.
## Optional self-lunge (`lunge_distance`) and/or victim shove (`hit_knockback_distance`).

## Emitted once when the strike hitbox goes live (after hold). Listeners can spawn extras (e.g. shockwave).
signal struck

enum Phase { READY, WINDUP, HOLD, STRIKE, RECOVER }

const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_WORLD := 1
const EDITOR_GIZMO_COLOR := Color(1.0, 0.35, 0.2, 0.85)

@export var damage: float = 5.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 1.25
@export var hold_duration: float = 0.25
@export var lunge_distance: float = 28.0
## Shove hit players this many px away from the attacker (0 = no victim knockback).
@export var hit_knockback_distance: float = 0.0
@export var hitbox_size: Vector2 = Vector2(18.0, 14.0):
	set(value):
		hitbox_size = value
		_rebuild_hitbox_shape()
		queue_redraw()
@export var hitbox_offset: Vector2 = Vector2(12.0, -2.0):
	set(value):
		hitbox_offset = value
		_apply_hitbox_transform()
		queue_redraw()
@export var attack_animation: StringName = &"attacking"
@export var lunge_frame: int = 3
@export var animation_speed_scale: float = 1.0
@export var attack_sound: SoundEvent
@export var windup_sound: SoundEvent

@export var animated_sprite: AnimatedSprite2D
@export var movement_component: MovementComponent
@export var navigation_component: NavigationComponent
@export var knockback_component: KnockbackComponent
@export var status_component: StatusComponent

## Chill / other slows multiply animation + phase timing (1 = full speed).
var speed_multiplier: float = 1.0:
	set(value):
		speed_multiplier = maxf(value, 0.1)
		_apply_anim_speed()

var _phase: Phase = Phase.READY
var _active: bool = true
var _cooldown_remaining: float = 0.0
var _hold_remaining: float = 0.0
var _lunge_direction: Vector2 = Vector2.RIGHT
var _facing_sign: float = 1.0
var _hit_this_swing: Dictionary = {}
var _collision_shape: CollisionShape2D
var _rectangle_shape: RectangleShape2D
var _was_chasing_before_attack: bool = true
var _frame_changed_connected: bool = false
var _anim_finished_connected: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_WORLD
	monitoring = false
	monitorable = false
	_ensure_collision_shape()
	_rebuild_hitbox_shape()
	_apply_hitbox_transform()
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_connect_sprite_signals()
	set_physics_process(true)
	set_process(false)


func is_attacking() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.HOLD or _phase == Phase.STRIKE


func set_active(enabled: bool) -> void:
	_active = enabled
	if not enabled and is_attacking():
		cancel()


func cancel() -> void:
	if Engine.is_editor_hint():
		return
	if _phase == Phase.READY and _cooldown_remaining <= 0.0:
		return
	_set_hitbox_live(false)
	_hit_this_swing.clear()
	if animated_sprite and animated_sprite.animation == attack_animation:
		animated_sprite.pause()
	_phase = Phase.READY
	_cooldown_remaining = 0.0
	_hold_remaining = 0.0
	_restore_chase_if_allowed()
	_apply_anim_speed()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if is_attacking() and Players.count(get_tree()) <= 0:
		cancel()
		return

	var scaled_delta: float = delta * speed_multiplier

	match _phase:
		Phase.READY:
			_tick_ready(scaled_delta)
		Phase.WINDUP:
			pass
		Phase.HOLD:
			_tick_hold(scaled_delta)
		Phase.STRIKE:
			_poll_hits()
		Phase.RECOVER:
			_tick_recover(scaled_delta)


func _tick_ready(scaled_delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - scaled_delta)
		return
	if not _active:
		return
	if status_component and status_component.is_stunned():
		return
	if knockback_component and knockback_component.is_active():
		return

	var target: Node2D = _find_target_in_range()
	if target == null:
		return
	_begin_windup(target)


func _tick_hold(scaled_delta: float) -> void:
	_hold_remaining -= scaled_delta
	if _hold_remaining > 0.0:
		return
	_begin_strike()


func _tick_recover(scaled_delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - scaled_delta)
	if _cooldown_remaining > 0.0:
		return
	_phase = Phase.READY


func _begin_windup(target: Node2D) -> void:
	_phase = Phase.WINDUP
	_hit_this_swing.clear()
	_face_toward(target.global_position)
	_lunge_direction = _direction_to(target.global_position)
	_apply_hitbox_transform()

	if navigation_component:
		_was_chasing_before_attack = true
		navigation_component.set_chasing(false)
	if movement_component:
		movement_component.stop()

	if windup_sound and owner is Node2D:
		AudioManager.play_at(windup_sound, (owner as Node2D).global_position)

	if animated_sprite:
		_apply_anim_speed()
		animated_sprite.play(attack_animation)
		# Already on the lunge frame (short clip / high speed) — skip straight to hold.
		if animated_sprite.frame >= lunge_frame:
			_begin_hold()


func _begin_hold() -> void:
	_phase = Phase.HOLD
	_hold_remaining = hold_duration
	if animated_sprite:
		animated_sprite.pause()
		animated_sprite.frame = lunge_frame
	# Re-snapshot aim at the telegraph so the player can dodge during hold.
	var target: Node2D = Players.closest_to(get_tree(), (owner as Node2D).global_position)
	if target != null:
		_face_toward(target.global_position)
		_lunge_direction = _direction_to(target.global_position)
		_apply_hitbox_transform()


func _begin_strike() -> void:
	_phase = Phase.STRIKE
	_hit_this_swing.clear()
	if attack_sound and owner is Node2D:
		AudioManager.play_at(attack_sound, (owner as Node2D).global_position)
	_set_hitbox_live(true)
	if knockback_component and lunge_distance > 0.0:
		knockback_component.push_distance(_lunge_direction, lunge_distance)
	if animated_sprite:
		_apply_anim_speed()
		# Resume from the held frame through the rest of the clip.
		animated_sprite.play(attack_animation)
		animated_sprite.set_frame_and_progress(lunge_frame, 0.0)
	struck.emit()
	_poll_hits()


func _begin_recover() -> void:
	_set_hitbox_live(false)
	_hit_this_swing.clear()
	_phase = Phase.RECOVER
	_cooldown_remaining = attack_cooldown
	_restore_chase_if_allowed()


func _on_frame_changed() -> void:
	if _phase != Phase.WINDUP:
		return
	if animated_sprite == null:
		return
	if animated_sprite.animation != attack_animation:
		return
	if animated_sprite.frame >= lunge_frame:
		_begin_hold()


func _on_animation_finished() -> void:
	if _phase != Phase.STRIKE:
		return
	if animated_sprite == null:
		return
	if animated_sprite.animation != attack_animation:
		return
	_begin_recover()


func _set_hitbox_live(live: bool) -> void:
	monitoring = live
	if _collision_shape:
		_collision_shape.disabled = not live


func _poll_hits() -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var victim := area as HitboxComponent
		if victim == null or not victim.monitoring:
			continue
		var root: Node = victim.owner
		if root == null:
			continue
		if not root.is_in_group("player") and not root.is_in_group("breakables"):
			continue
		var id: int = root.get_instance_id()
		if _hit_this_swing.has(id):
			continue
		if victim.health_component == null:
			continue
		_hit_this_swing[id] = true
		victim.health_component.take_damage(damage, HealthComponent.DamageKind.STANDARD, owner)
		_apply_hit_knockback(root)


func _apply_hit_knockback(victim_root: Node) -> void:
	if hit_knockback_distance <= 0.0:
		return
	var comp = victim_root.get("COMPONENTS")
	if comp == null or not comp.has(KnockbackComponent):
		return
	var origin: Vector2 = (owner as Node2D).global_position
	var victim_pos: Vector2 = (victim_root as Node2D).global_position
	var push_dir: Vector2 = victim_pos - origin
	if push_dir.length_squared() < 0.0001:
		push_dir = Vector2.RIGHT if _facing_sign >= 0.0 else Vector2.LEFT
	else:
		push_dir = push_dir.normalized()
	(comp[KnockbackComponent] as KnockbackComponent).push_distance(push_dir, hit_knockback_distance)


func _find_target_in_range() -> Node2D:
	if owner == null or not (owner is Node2D):
		return null
	var origin: Vector2 = (owner as Node2D).global_position
	var closest: Node2D = Players.closest_to(get_tree(), origin)
	if closest == null:
		return null
	if origin.distance_to(closest.global_position) > attack_range:
		return null
	return closest


func _direction_to(world_pos: Vector2) -> Vector2:
	var origin: Vector2 = (owner as Node2D).global_position
	var delta: Vector2 = world_pos - origin
	if delta.length_squared() < 0.0001:
		return Vector2.RIGHT if _facing_sign >= 0.0 else Vector2.LEFT
	return delta.normalized()


func _face_toward(world_pos: Vector2) -> void:
	var origin: Vector2 = (owner as Node2D).global_position
	var dx: float = world_pos.x - origin.x
	if absf(dx) < 0.0001:
		return
	_facing_sign = 1.0 if dx > 0.0 else -1.0
	if movement_component:
		movement_component.face_horizontal(dx)


func _restore_chase_if_allowed() -> void:
	if navigation_component == null:
		return
	if status_component and status_component.is_stunned():
		return
	if not _active:
		return
	if Players.count(get_tree()) <= 0:
		return
	if _was_chasing_before_attack:
		navigation_component.set_chasing(true)


func _apply_anim_speed() -> void:
	if animated_sprite == null:
		return
	animated_sprite.speed_scale = animation_speed_scale * speed_multiplier


func _connect_sprite_signals() -> void:
	if animated_sprite == null:
		return
	if not _frame_changed_connected:
		animated_sprite.frame_changed.connect(_on_frame_changed)
		_frame_changed_connected = true
	if not _anim_finished_connected:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		_anim_finished_connected = true


func _ensure_collision_shape() -> void:
	if _collision_shape != null and is_instance_valid(_collision_shape):
		return
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child as CollisionShape2D
			break
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
		if Engine.is_editor_hint() and owner != null:
			_collision_shape.owner = owner
	_collision_shape.disabled = true


func _rebuild_hitbox_shape() -> void:
	_ensure_collision_shape()
	if _rectangle_shape == null or not is_instance_valid(_rectangle_shape):
		_rectangle_shape = RectangleShape2D.new()
	_rectangle_shape.size = hitbox_size
	_collision_shape.shape = _rectangle_shape
	_apply_hitbox_transform()


func _apply_hitbox_transform() -> void:
	if _collision_shape == null:
		return
	var sign_x: float = _facing_sign
	if Engine.is_editor_hint():
		sign_x = 1.0
	_collision_shape.position = Vector2(hitbox_offset.x * sign_x, hitbox_offset.y)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half: Vector2 = hitbox_size * 0.5
	var center: Vector2 = hitbox_offset
	var rect := Rect2(center - half, hitbox_size)
	draw_rect(rect, EDITOR_GIZMO_COLOR, false, 1.0)
	draw_circle(center, 1.5, EDITOR_GIZMO_COLOR)
