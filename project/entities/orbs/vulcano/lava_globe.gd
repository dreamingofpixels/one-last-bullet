class_name LavaGlobe
extends Node2D

## Arcing lava projectile from Vulcano: fly → splat → puddle (Burn/s), then free.
## Flies under `%WorldYSort` so the globes y-sort with entities; on landing they
## reparent to `%GroundEffects` so puddles stay under entities and orbs.
## Node origin is the ground contact (bottom of art).

const GROUP_NAME := &"lava_puddles"
const PHYSICS_LAYER_ENEMY := 4
const ANIM_FLY := &"fly"
const ANIM_SPLAT := &"splat"
const ANIM_PUDDLE := &"puddle"
const ANIM_EXPIRE := &"expire"
const PUDDLE_DURATION := 6.0
const BURN_TICK_INTERVAL := 1.0
const BURN_STACKS_PER_TICK := 1
const FLIGHT_DURATION := 0.55
const ARC_HEIGHT := 28.0
## 32px frames: half-height so the node sits at the art bottom (prop convention).
const FRAME_HALF_HEIGHT := 16.0

enum Phase { FLYING, SPLATTING, PUDDLE, EXPIRING }

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var hitbox: Area2D = %Hitbox
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

var _source: Node = null
var _start: Vector2 = Vector2.ZERO
var _end: Vector2 = Vector2.ZERO
var _flight_elapsed: float = 0.0
var _phase: Phase = Phase.FLYING
var _puddle_remaining: float = 0.0
var _tick_state: Dictionary = {}
var _setup_done: bool = false


func setup(from: Vector2, to: Vector2, source: Node) -> void:
	_start = from
	_end = to
	_source = source if source != null and is_instance_valid(source) else null
	_setup_done = true
	if is_node_ready():
		_begin_flight()


func get_landing_position() -> Vector2:
	return _end


func blocks_landing() -> bool:
	return _phase != Phase.EXPIRING


func _ready() -> void:
	add_to_group(GROUP_NAME)
	hitbox.collision_layer = 0
	hitbox.collision_mask = PHYSICS_LAYER_ENEMY
	hitbox.monitoring = false
	hitbox.monitorable = false
	collision_shape.disabled = true
	sprite.animation_finished.connect(_on_animation_finished)
	if _setup_done:
		_begin_flight()


func _grounded_sprite_offset() -> Vector2:
	return Vector2(0.0, -FRAME_HALF_HEIGHT)


func _place_at_landing() -> void:
	global_position = _end


func _begin_flight() -> void:
	_phase = Phase.FLYING
	_flight_elapsed = 0.0
	global_position = _start
	sprite.offset = _grounded_sprite_offset()
	sprite.play(ANIM_FLY)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.FLYING:
			_update_flight(delta)
		Phase.PUDDLE:
			_update_puddle(delta)
		Phase.SPLATTING, Phase.EXPIRING:
			pass


func _update_flight(delta: float) -> void:
	_flight_elapsed += delta
	var t: float = clampf(_flight_elapsed / FLIGHT_DURATION, 0.0, 1.0)
	var ground: Vector2 = _start.lerp(_end, t)
	var arc: float = -4.0 * ARC_HEIGHT * t * (1.0 - t)
	# Sort point follows the ground track; visual rides the arc via offset.
	global_position = ground
	sprite.offset = _grounded_sprite_offset() + Vector2(0.0, arc)
	if t < 1.0:
		return
	_begin_splat()


func _begin_splat() -> void:
	_phase = Phase.SPLATTING
	_move_to_floor_layer()
	_place_at_landing()
	sprite.offset = _grounded_sprite_offset()
	sprite.play(ANIM_SPLAT)


func _move_to_floor_layer() -> void:
	var ground: Node = _find_ground_effects()
	if ground == null or get_parent() == ground:
		return
	reparent(ground)


func _find_ground_effects() -> Node:
	if get_tree() == null:
		return null
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var ground: Node = scene.get_node_or_null("%GroundEffects")
	if ground == null:
		ground = scene.get_node_or_null("GroundEffects")
	return ground


func _on_animation_finished() -> void:
	match _phase:
		Phase.SPLATTING:
			_begin_puddle()
		Phase.EXPIRING:
			queue_free()
		_:
			pass


func _begin_puddle() -> void:
	_phase = Phase.PUDDLE
	_puddle_remaining = PUDDLE_DURATION
	_tick_state.clear()
	_place_at_landing()
	sprite.offset = _grounded_sprite_offset()
	sprite.play(ANIM_PUDDLE)
	hitbox.monitoring = true
	collision_shape.disabled = false
	_poll_puddle_victims()


func _begin_expire() -> void:
	_phase = Phase.EXPIRING
	_tick_state.clear()
	hitbox.monitoring = false
	collision_shape.disabled = true
	sprite.play(ANIM_EXPIRE)


func _update_puddle(delta: float) -> void:
	_puddle_remaining -= delta
	if _puddle_remaining <= 0.0:
		_begin_expire()
		return
	_poll_puddle_victims()


func _poll_puddle_victims() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var seen_ids: Dictionary = {}

	for area in hitbox.get_overlapping_areas():
		var victim_hitbox := area as HitboxComponent
		if victim_hitbox == null or not victim_hitbox.monitoring:
			continue
		var victim_root: Node = victim_hitbox.owner
		if victim_root == null or not is_instance_valid(victim_root):
			continue
		if not victim_root.is_in_group("enemies"):
			continue

		var victim_id: int = victim_root.get_instance_id()
		seen_ids[victim_id] = true
		var next_msec: int = int(_tick_state.get(victim_id, 0))
		if now_msec < next_msec:
			continue

		_apply_burn_tick(victim_root)
		_tick_state[victim_id] = now_msec + int(BURN_TICK_INTERVAL * 1000.0)

	var stale: Array = []
	for victim_id in _tick_state:
		if not seen_ids.has(victim_id):
			stale.append(victim_id)
	for victim_id in stale:
		_tick_state.erase(victim_id)


func _apply_burn_tick(victim_root: Node) -> void:
	var comp = victim_root.get("COMPONENTS")
	if comp == null or not comp.has(StatusComponent):
		return
	var source: Node = _source if _source != null and is_instance_valid(_source) else null
	(comp[StatusComponent] as StatusComponent).add_stacks(
		StatusComponent.StatusId.BURN,
		BURN_STACKS_PER_TICK,
		source
	)
