class_name AttackComponent extends Area2D

## Player melee arc: authored CollisionPolygon2D that knocks enemies (and optionally reflects the orb).
## Parked behind melee_enabled for Attack-redirect-only playtest (nodes/code kept).
## Attack bat (dwarf) uses the same polygon as a geometry hit test + persistent overlay.

const PHYSICS_LAYER_ENEMY := 4
const PHYSICS_LAYER_ORB := 8
const BAT_OVERLAY_FILL := Color(1.0, 0.35, 0.2, 0.28)
const BAT_OVERLAY_OUTLINE := Color(1.0, 0.35, 0.2, 0.85)
const SPIN_OVERLAY_FILL := Color(1.0, 0.55, 0.15, 0.22)
const SPIN_OVERLAY_OUTLINE := Color(1.0, 0.55, 0.15, 0.9)
const SPIN_OVERLAY_SEGMENTS := 48

@export var knockback_force: float = 220.0
@export var attack_cooldown: float = 0.35
## When false, Attack never swings for melee (sprite/hitbox/knockback dormant).
## Orb-bat playtest still calls play_swing_visual() for the arc art without enabling melee.
@export var melee_enabled: bool = false
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
var _show_bat_overlay: bool = false
var _show_spin_overlay: bool = false
var _spin_overlay_active: bool = false


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
	attack_sprite_hint.visible = false
	body_entered.connect(_on_body_entered)
	attack_animation.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	_update_bat_overlay_and_aim()
	_update_melee_hint()


## True when world_pos lies inside the authored swing polygon.
func contains_world_point(world_pos: Vector2) -> bool:
	var pts: PackedVector2Array = collision_polygon.polygon
	if pts.size() < 3:
		return false
	var local: Vector2 = collision_polygon.to_local(world_pos)
	return Geometry2D.is_point_in_polygon(local, pts)


## True when a world-space circle (orb body) overlaps the authored swing polygon.
func overlaps_world_circle(world_center: Vector2, radius: float) -> bool:
	var pts: PackedVector2Array = collision_polygon.polygon
	if pts.size() < 3:
		return false
	var local: Vector2 = collision_polygon.to_local(world_center)
	# Scale radius into CollisionPolygon2D local space (handles non-uniform parent scale).
	var local_radius: float = radius
	var scale_abs: Vector2 = collision_polygon.global_scale.abs()
	if scale_abs.x > 0.0001 and scale_abs.y > 0.0001:
		local_radius = radius / minf(scale_abs.x, scale_abs.y)
	if Geometry2D.is_point_in_polygon(local, pts):
		return true
	var r_sq: float = local_radius * local_radius
	var count: int = pts.size()
	for i in count:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % count]
		# Vertex inside circle.
		if local.distance_squared_to(a) <= r_sq:
			return true
		# Edge within radius of center.
		if Geometry2D.get_closest_point_to_segment(local, a, b).distance_squared_to(local) <= r_sq:
			return true
	return false


func _update_bat_overlay_and_aim() -> void:
	var tether: OrbTetherComponent = owner.orb_tether_component
	var assembling: bool = owner.has_method("is_assembling") and owner.is_assembling()
	_show_bat_overlay = tether.attack_bat_enabled and not assembling
	if not _show_bat_overlay:
		_spin_overlay_active = false
		_show_spin_overlay = false
		queue_redraw()
		return

	if _spin_overlay_active:
		var still_spinning: bool = (
			owner.directional_sprite != null
			and owner.directional_sprite.is_playing_action(&"attack_around")
		)
		if not still_spinning:
			_spin_overlay_active = false

	_show_spin_overlay = tether.is_attack_charge_ready() or _spin_overlay_active

	var aim: Vector2 = tether.get_bat_aim()
	if aim.length_squared() > 0.0001:
		_aim_direction = aim.normalized()
		rotation = _aim_direction.angle()
	queue_redraw()


## Show the focus-radius ring through the attack_around spin after a 360° bat.
func begin_spin_overlay() -> void:
	_spin_overlay_active = true
	_show_spin_overlay = true
	queue_redraw()


func _update_melee_hint() -> void:
	if not melee_enabled or _show_bat_overlay:
		attack_sprite_hint.visible = false
		return
	if (
		_attacking
		or owner.orb_tether_component.is_tethering()
		or owner.orb_tether_component.is_channeling()
		or owner.orb_tether_component.has_redirect_target()
	):
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


func _draw() -> void:
	if not _show_bat_overlay:
		return
	if _show_spin_overlay:
		_draw_spin_overlay()
		return
	_draw_wedge_overlay()


func _draw_wedge_overlay() -> void:
	var pts: PackedVector2Array = collision_polygon.polygon
	if pts.size() < 3:
		return
	var offset: Vector2 = collision_polygon.position
	var drawn := PackedVector2Array()
	for p in pts:
		drawn.append(p + offset)
	draw_colored_polygon(drawn, BAT_OVERLAY_FILL)
	drawn.append(drawn[0])
	draw_polyline(drawn, BAT_OVERLAY_OUTLINE, 1.0)


func _draw_spin_overlay() -> void:
	var tether: OrbTetherComponent = owner.orb_tether_component
	var radius: float = tether.attack_spin_radius
	if radius <= 0.0:
		return
	# Draw in unrotated local space so the ring stays circular around the player.
	var inv_rot := Transform2D(-rotation, Vector2.ZERO)
	var ring := PackedVector2Array()
	for i in SPIN_OVERLAY_SEGMENTS:
		var angle: float = TAU * float(i) / float(SPIN_OVERLAY_SEGMENTS)
		ring.append(inv_rot * Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(ring, SPIN_OVERLAY_FILL)
	ring.append(ring[0])
	draw_polyline(ring, SPIN_OVERLAY_OUTLINE, 1.0)


func start(aim_direction: Vector2) -> void:
	if not melee_enabled:
		return
	if not can_attack():
		return
	_begin_swing(aim_direction)


## Play the arc swing sprite/animation without enabling melee hitbox or knockback.
## Used by the Attack bat redirect. Caller owns cooldown via consume_cooldown().
func play_swing_visual(aim_direction: Vector2) -> void:
	_begin_swing(aim_direction)


func _begin_swing(aim_direction: Vector2) -> void:
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


## Start the attack cooldown without playing a swing (used by proximity / bat redirect).
func consume_cooldown() -> void:
	_cooldown_until_msec = Time.get_ticks_msec() + int(attack_cooldown * 1000.0)
	attack_sprite_hint.visible = false


## Called from AnimationPlayer method tracks.
func set_hitbox_active(active: bool) -> void:
	if not melee_enabled:
		monitoring = false
		collision_polygon.disabled = true
		return
	monitoring = active
	collision_polygon.disabled = not active
	if active:
		# Catch bodies already overlapping when the hitbox turns on.
		for body in get_overlapping_bodies():
			_resolve_hit(body)


func _on_body_entered(body: Node2D) -> void:
	_resolve_hit(body)


func _resolve_hit(body: Node) -> void:
	if not melee_enabled or not monitoring or body == null or not is_instance_valid(body):
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
	# Melee start() relies on finish for cooldown; bat already called consume_cooldown().
	if melee_enabled:
		_cooldown_until_msec = Time.get_ticks_msec() + int(attack_cooldown * 1000.0)
