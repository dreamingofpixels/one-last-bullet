class_name EarthSpike
extends Node2D

## One earth-spike eruption: play once, damage during peak frames, then free.
## Sort point is biased north of the visual base so center-origin entities
## (player / ogre) at the same ground line draw in front of the spike.

const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_WORLD := 1
const ANIM_ERUPT := &"erupt"
## Inclusive frame range (0-based) where the hitbox is live.
const HITBOX_FRAME_START := 3
const HITBOX_FRAME_END := 8
## Pull the y-sort point upward (smaller Y) so feet-line overlaps put entities in front.
const SORT_BIAS_Y := 24.0
## Sprite is 16px tall and centered; -8 puts the base on the node before sort bias.
const SPRITE_BASE_OFFSET_Y := -8.0

@onready var sprite: AnimatedSprite2D = %Sprite
@onready var hitbox: Area2D = %Hitbox
@onready var collision_shape: CollisionShape2D = %CollisionShape2D

var _damage: float = 10.0
var _knockback_distance: float = 40.0
var _instigator: Node = null
var _shove_origin: Vector2 = Vector2.ZERO
var _hit_victims: Dictionary = {}
var _setup_done: bool = false


## Place the spike so its visual base sits at `world_base_pos`, with y-sort biased north.
func place_at(world_base_pos: Vector2) -> void:
	global_position = Vector2(world_base_pos.x, world_base_pos.y - SORT_BIAS_Y)
	if is_node_ready():
		_apply_sprite_offset()


func setup(
	damage: float,
	knockback_distance: float,
	instigator: Node,
	shove_origin: Vector2
) -> void:
	_damage = damage
	_knockback_distance = knockback_distance
	_instigator = instigator if instigator != null and is_instance_valid(instigator) else null
	_shove_origin = shove_origin
	_setup_done = true
	if is_node_ready():
		_begin()


func _ready() -> void:
	hitbox.collision_layer = 0
	hitbox.collision_mask = PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_WORLD
	hitbox.monitoring = false
	hitbox.monitorable = false
	collision_shape.disabled = true
	_apply_sprite_offset()
	# Keep hitbox at the visual base (below the biased sort point).
	collision_shape.position = Vector2(0.0, SORT_BIAS_Y - 6.0)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	if _setup_done:
		_begin()


func _apply_sprite_offset() -> void:
	sprite.offset = Vector2(0.0, SPRITE_BASE_OFFSET_Y + SORT_BIAS_Y)


func _physics_process(_delta: float) -> void:
	if not hitbox.monitoring:
		return
	_poll_hits()


func _begin() -> void:
	sprite.play(ANIM_ERUPT)
	_update_hitbox_for_frame(sprite.frame)


func _on_frame_changed() -> void:
	_update_hitbox_for_frame(sprite.frame)


func _update_hitbox_for_frame(frame: int) -> void:
	var live: bool = frame >= HITBOX_FRAME_START and frame <= HITBOX_FRAME_END
	hitbox.monitoring = live
	collision_shape.disabled = not live
	if live:
		_poll_hits()


func _poll_hits() -> void:
	for area in hitbox.get_overlapping_areas():
		var victim := area as HitboxComponent
		if victim == null or not victim.monitoring:
			continue
		var root: Node = victim.owner
		if root == null:
			continue
		if not root.is_in_group("player") and not root.is_in_group("breakables"):
			continue
		var id: int = root.get_instance_id()
		if _hit_victims.has(id):
			continue
		if victim.health_component == null:
			continue
		_hit_victims[id] = true
		var source: Node = _instigator if _instigator != null and is_instance_valid(_instigator) else null
		victim.health_component.take_damage(
			_damage, HealthComponent.DamageKind.STANDARD, source
		)
		_apply_hit_knockback(root)


func _apply_hit_knockback(victim_root: Node) -> void:
	if _knockback_distance <= 0.0:
		return
	var comp = victim_root.get("COMPONENTS")
	if comp == null or not comp.has(KnockbackComponent):
		return
	var victim_pos: Vector2 = (victim_root as Node2D).global_position
	var push_dir: Vector2 = victim_pos - _shove_origin
	if push_dir.length_squared() < 0.0001:
		push_dir = Vector2.RIGHT
	else:
		push_dir = push_dir.normalized()
	(comp[KnockbackComponent] as KnockbackComponent).push_distance(push_dir, _knockback_distance)


func _on_animation_finished() -> void:
	queue_free()
