class_name AttackComponent extends Area2D

## Player melee arc: authored CollisionPolygon2D that knocks enemies (and optionally reflects the orb).

const PHYSICS_LAYER_ENEMY := 4
const PHYSICS_LAYER_ORB := 8

@export var knockback_force: float = 220.0
@export var attack_cooldown: float = 0.35
## When false, the arc still knocks enemies but does not deflect the orb (tether steering is active instead).
@export var deflect_orb_enabled: bool = false
## When orb velocity aligns with player→orb (dot > this), push along aim instead of bouncing.
@export var same_direction_dot_threshold: float = 0.5
## Visual-only rotation: art is a NE quarter-arc; +45° puts its midline on parent +X (aim).
@export var sprite_angle_offset: float = PI / 4.0
@export var lock_movement: bool = false
## Optional swing SFX; left unassigned until a clip exists.
@export var swing_sound: SoundEvent

@onready var attack_sprite: Sprite2D = %AttackSprite
@onready var attack_sprite_hint: Sprite2D = %AttackSpriteHint
@onready var attack_animation: AnimationPlayer = %AttackAnimation
@onready var collision_polygon: CollisionPolygon2D = %CollisionPolygon2D

var _aim_direction: Vector2 = Vector2.RIGHT
var _attacking: bool = false
var _cooldown_until_msec: int = 0
var _hit_orb: bool = false
var _hit_enemies: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = PHYSICS_LAYER_ENEMY | PHYSICS_LAYER_ORB
	monitoring = false
	monitorable = false
	collision_polygon.disabled = true
	attack_sprite.visible = false
	attack_sprite.hframes = 6
	attack_sprite.vframes = 1
	attack_sprite.centered = false
	# Arc art's circle center sits at the bottom-left of each 16x16 frame.
	attack_sprite.offset = Vector2(0.0, -16.0)
	attack_sprite.rotation = sprite_angle_offset
	attack_sprite_hint.hframes = 6
	attack_sprite_hint.vframes = 1
	attack_sprite_hint.centered = false
	attack_sprite_hint.offset = Vector2(0.0, -16.0)
	attack_sprite_hint.rotation = sprite_angle_offset
	attack_sprite_hint.frame = 2
	body_entered.connect(_on_body_entered)
	attack_animation.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	if _attacking or owner.orb_tether_component.is_tethering():
		attack_sprite_hint.visible = false
		return

	var aim: Vector2 = owner.controls.get_aim_vector(owner.global_position)
	if aim.length_squared() < 0.0001:
		attack_sprite_hint.visible = false
		return

	_aim_direction = aim.normalized()
	rotation = _aim_direction.angle()
	attack_sprite_hint.rotation = sprite_angle_offset
	attack_sprite_hint.visible = true


func start(aim_direction: Vector2) -> void:
	if not can_attack():
		return
	_aim_direction = aim_direction.normalized() if aim_direction.length_squared() > 0.0001 else Vector2.RIGHT
	_attacking = true
	_hit_orb = false
	_hit_enemies.clear()
	rotation = _aim_direction.angle()
	attack_sprite.rotation = sprite_angle_offset
	attack_sprite_hint.visible = false
	attack_sprite.visible = true
	attack_sprite.frame = 0
	if swing_sound and owner is Node2D:
		AudioManager.play_at(swing_sound, (owner as Node2D).global_position)
	attack_animation.play("attack")


func is_attacking() -> bool:
	return _attacking


func can_attack() -> bool:
	return not _attacking and Time.get_ticks_msec() >= _cooldown_until_msec


## Called from AnimationPlayer method tracks.
func set_hitbox_active(active: bool) -> void:
	monitoring = active
	collision_polygon.disabled = not active
	if active:
		# Catch bodies already overlapping when the hitbox turns on.
		for body in get_overlapping_bodies():
			_resolve_hit(body)


func _on_body_entered(body: Node2D) -> void:
	_resolve_hit(body)


func _resolve_hit(body: Node) -> void:
	if not monitoring or body == null or not is_instance_valid(body):
		return

	if body.is_in_group("orb"):
		_try_deflect_orb(body)
		return

	if body.is_in_group("enemies"):
		_try_knockback_enemy(body)


func _try_deflect_orb(orb: Node) -> void:
	if not deflect_orb_enabled:
		return
	if _hit_orb:
		return
	if not orb.has_method("deflect") or not orb.has_method("is_flying"):
		return
	if not orb.is_flying():
		return

	var from_player: Vector2 = (orb as Node2D).global_position - owner.global_position
	var n: Vector2
	if from_player.length_squared() < 0.0001:
		n = _aim_direction
	else:
		n = from_player.normalized()

	var v: Vector2 = (orb as RigidBody2D).linear_velocity
	var reflected: Vector2
	# Chasing from behind: radial bounce would flip ~180°; push along the aimed arc instead.
	if v.length_squared() > 0.0001 and v.normalized().dot(n) > same_direction_dot_threshold:
		reflected = _aim_direction
	else:
		reflected = v.bounce(n)
		if reflected.length_squared() < 0.0001:
			reflected = _aim_direction
	_hit_orb = true
	orb.deflect(reflected, owner)


func _try_knockback_enemy(enemy: Node) -> void:
	var id := enemy.get_instance_id()
	if _hit_enemies.has(id):
		return

	var comp = enemy.get("COMPONENTS")
	if comp == null or not comp.has(KnockbackComponent):
		return

	var from_player: Vector2 = (enemy as Node2D).global_position - owner.global_position
	var push_dir := from_player.normalized() if from_player.length_squared() > 0.0001 else _aim_direction
	_hit_enemies[id] = true
	(comp[KnockbackComponent] as KnockbackComponent).apply(push_dir, knockback_force)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"attack":
		return
	set_hitbox_active(false)
	attack_sprite.visible = false
	_attacking = false
	_cooldown_until_msec = Time.get_ticks_msec() + int(attack_cooldown * 1000.0)
