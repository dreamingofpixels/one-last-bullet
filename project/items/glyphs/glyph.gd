class_name Glyph
extends RigidBody2D

enum Rarity { COMMON, RARE, UNIQUE }
enum GlyphState { GROUNDED, CARRIED, THROWN, DEPOSITING }

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_ITEM := 32
const STOP_SPEED := 12.0
const CARRY_OFFSET := Vector2(10.0, -12.0)
const DEPOSIT_SUCK_MIN_DURATION := 0.12

const MANA_BY_RARITY: Dictionary = {
	Rarity.COMMON: 5.0,
	Rarity.RARE: 10.0,
	Rarity.UNIQUE: 20.0,
}
const ELEMENT_TEXTURES: Dictionary = {
	"Fire": preload("res://items/glyphs/fire_glyph.png"),
	"Water": preload("res://items/glyphs/water_glyph.png"),
	"Air": preload("res://items/glyphs/air_glyph.png"),
	"Earth": preload("res://items/glyphs/earth_glyph.png"),
}
const RARITY_SHADER: Shader = preload("res://items/glyphs/glyph_rarity.gdshader")
const RARITY_PARTICLES_SCENE: PackedScene = preload("res://items/glyphs/glyph_rarity_particles.tscn")
const RARITY_PARTICLES_NODE := &"RarityParticles"
const COMMON_GLOW := 0.2
const RARE_GLOW := 1.4
const UNIQUE_GLOW := 1.5
const RARE_PARTICLE_AMOUNT := 8
const UNIQUE_PARTICLE_AMOUNT := 16
const TINT_COMMON := Color(1.0, 1.0, 1.0, 1.0)
const TINT_RARE := Color(0.248, 0.842, 0.545, 1.0)
const TINT_UNIQUE := Color(0.617, 0.312, 0.992, 1.0)

static var _rarity_material_base: ShaderMaterial


static func _get_rarity_material_base() -> ShaderMaterial:
	if _rarity_material_base == null:
		_rarity_material_base = ShaderMaterial.new()
		_rarity_material_base.shader = RARITY_SHADER
	return _rarity_material_base


static func _ensure_rarity_material(item: CanvasItem) -> ShaderMaterial:
	var existing: ShaderMaterial = item.material as ShaderMaterial
	if existing != null and existing.shader == RARITY_SHADER:
		return existing
	var mat: ShaderMaterial = _get_rarity_material_base().duplicate() as ShaderMaterial
	item.material = mat
	return mat


static func _rarity_visuals(rarity_tier: int) -> Dictionary:
	match rarity_tier:
		Rarity.RARE:
			return {
				"glow": RARE_GLOW,
				"tint": TINT_RARE,
				"particles": true,
				"amount": RARE_PARTICLE_AMOUNT,
			}
		Rarity.UNIQUE:
			return {
				"glow": UNIQUE_GLOW,
				"tint": TINT_UNIQUE,
				"particles": true,
				"amount": UNIQUE_PARTICLE_AMOUNT,
			}
		_:
			return {
				"glow": COMMON_GLOW,
				"tint": TINT_COMMON,
				"particles": false,
				"amount": 0,
			}


static func _center_rarity_particles(particles: GPUParticles2D) -> void:
	var parent_node: Node = particles.get_parent()
	if parent_node is Control:
		var control: Control = parent_node as Control
		particles.position = control.size * 0.5


static func _ensure_rarity_particles(item: CanvasItem) -> GPUParticles2D:
	var existing: Node = item.get_node_or_null(NodePath(String(RARITY_PARTICLES_NODE)))
	if existing is GPUParticles2D:
		return existing as GPUParticles2D
	var particles: GPUParticles2D = RARITY_PARTICLES_SCENE.instantiate() as GPUParticles2D
	particles.name = String(RARITY_PARTICLES_NODE)
	item.add_child(particles)
	if item is Control:
		var control: Control = item as Control
		if not particles.has_meta(&"resized_hook"):
			particles.set_meta(&"resized_hook", true)
			control.resized.connect(func() -> void: _center_rarity_particles(particles))
		_center_rarity_particles(particles)
	return particles


static func _configure_rarity_particles(item: CanvasItem, rarity_tier: int) -> void:
	var visuals: Dictionary = _rarity_visuals(rarity_tier)
	var want_particles: bool = bool(visuals.get("particles", false))
	var existing: Node = item.get_node_or_null(NodePath(String(RARITY_PARTICLES_NODE)))
	if not want_particles:
		if existing is GPUParticles2D:
			var idle: GPUParticles2D = existing as GPUParticles2D
			idle.emitting = false
		return
	var particles: GPUParticles2D = _ensure_rarity_particles(item)
	particles.emitting = false
	particles.amount = int(visuals.get("amount", RARE_PARTICLE_AMOUNT))
	particles.modulate = visuals.get("tint", TINT_COMMON) as Color
	_center_rarity_particles(particles)
	particles.emitting = true


## All rarities pulse the center rune in unison. Tint + particles carry rarity.
static func apply_rarity_visual(item: CanvasItem, rarity_tier: int) -> void:
	if item == null or not is_instance_valid(item):
		return
	var visuals: Dictionary = _rarity_visuals(rarity_tier)
	var mat: ShaderMaterial = _ensure_rarity_material(item)
	mat.set_shader_parameter(&"glow", float(visuals.get("glow", COMMON_GLOW)))
	mat.set_shader_parameter(&"pulse", 1.0)
	mat.set_shader_parameter(&"tint", visuals.get("tint", TINT_COMMON) as Color)
	_configure_rarity_particles(item, rarity_tier)


static func clear_rarity_visual(item: CanvasItem) -> void:
	if item == null or not is_instance_valid(item):
		return
	var mat: ShaderMaterial = _ensure_rarity_material(item)
	mat.set_shader_parameter(&"glow", 0.0)
	mat.set_shader_parameter(&"pulse", 0.0)
	mat.set_shader_parameter(&"tint", TINT_COMMON)
	item.modulate = Color.WHITE
	var existing: Node = item.get_node_or_null(NodePath(String(RARITY_PARTICLES_NODE)))
	if existing is GPUParticles2D:
		(existing as GPUParticles2D).emitting = false


var COMPONENTS: Dictionary = {}

@export var glyph_id: StringName = &"coal"
@export var rarity: Rarity = Rarity.COMMON
@export var throw_speed: float = 200.0
@export var throw_damp: float = 5.0
@export var bounce_height: float = 5.0
@export var bounce_hops: int = 2
@export var deposit_suck_speed: float = 240.0
@export var pickup_sound: SoundEvent = preload("res://items/item_picked_up.tres")
@export var deposit_sound: SoundEvent = preload("res://items/mana_crystal_deposited.tres")

@onready var sprite: Sprite2D = %Sprite2D
@onready var body_collision: CollisionShape2D = %CollisionShape2D
@onready var presence_area: Area2D = %PresenceArea
@onready var hitbox_component: HitboxComponent = %HitboxComponent

var _state: GlyphState = GlyphState.GROUNDED
var _carrier: Node2D = null
var _deposited: bool = false
var _bounce_tween: Tween
var _deposit_tween: Tween
var _sprite_rest_y: float = 0.0


func _ready() -> void:
	add_to_group("glyphs")
	gravity_scale = 0.0
	lock_rotation = true
	can_sleep = false
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 100.0
	_sprite_rest_y = sprite.position.y
	_apply_visuals()
	_set_grounded_physics()
	set_physics_process(false)

	var destroy_comp: DestroyComponent = COMPONENTS.get(DestroyComponent)
	if destroy_comp and not destroy_comp.destroyed.is_connected(_on_destroyed):
		destroy_comp.destroyed.connect(_on_destroyed)


func setup(id: StringName, r: Rarity) -> void:
	glyph_id = id
	rarity = r
	_apply_visuals()


func get_mana_value() -> float:
	return float(MANA_BY_RARITY.get(rarity, 5.0))


func get_attribute() -> StringName:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return &""
	return StringName(String((row as Dictionary).get("attribute", "")))


func get_attribute_value() -> float:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return 0.0
	var data: Dictionary = row
	match rarity:
		Rarity.RARE:
			return float(data.get("rarity_rare", 0.0))
		Rarity.UNIQUE:
			return float(data.get("rarity_unique", 0.0))
		_:
			return float(data.get("rarity_common", 0.0))


func get_element() -> String:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return ""
	return String((row as Dictionary).get("element", ""))


func get_display_name() -> String:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return String(glyph_id)
	return String((row as Dictionary).get("name", glyph_id))


static func rarity_to_string(r: Rarity) -> String:
	match r:
		Rarity.RARE:
			return "Rare"
		Rarity.UNIQUE:
			return "Unique"
		_:
			return "Common"


func _apply_visuals() -> void:
	if not is_instance_valid(sprite):
		return
	var element: String = get_element()
	var tex: Texture2D = ELEMENT_TEXTURES.get(element, ELEMENT_TEXTURES["Fire"]) as Texture2D
	if tex:
		sprite.texture = tex
	sprite.modulate = Color.WHITE
	apply_rarity_visual(sprite, rarity)


func _on_destroyed(_node: Node = null) -> void:
	if is_instance_valid(_carrier) and _carrier.has_method("clear_carried_item"):
		_carrier.clear_carried_item(self)
	_carrier = null


func can_be_picked_up() -> bool:
	return not _deposited and (_state == GlyphState.GROUNDED or _state == GlyphState.THROWN)


func is_carried() -> bool:
	return _state == GlyphState.CARRIED


func get_carrier() -> Node2D:
	return _carrier if is_instance_valid(_carrier) else null


func pickup(carrier: Node2D) -> bool:
	if not can_be_picked_up() or carrier == null or not is_instance_valid(carrier):
		return false
	if carrier.has_method("is_carrying_item") and carrier.is_carrying_item():
		return false

	_stop_bounce()
	_state = GlyphState.CARRIED
	_carrier = carrier
	freeze = true
	linear_velocity = Vector2.ZERO
	body_collision.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	hitbox_component.set_invulnerable(true)
	set_physics_process(false)

	presence_area.collision_layer = PHYSICS_LAYER_ITEM
	presence_area.monitoring = false
	presence_area.monitorable = true

	var keep_global: Vector2 = global_position
	reparent(carrier, true)
	global_position = keep_global
	position = CARRY_OFFSET
	sprite.position.y = _sprite_rest_y

	if pickup_sound:
		AudioManager.play_at(pickup_sound, global_position)
	return true


func throw_toward(direction: Vector2, level_root: Node, inherit_velocity: Vector2 = Vector2.ZERO) -> bool:
	if _state != GlyphState.CARRIED or level_root == null or not is_instance_valid(level_root):
		return false

	var aim: Vector2 = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var throw_pos: Vector2 = global_position
	_carrier = null
	_state = GlyphState.THROWN

	reparent(level_root, true)
	global_position = throw_pos

	body_collision.set_deferred("disabled", false)
	collision_layer = PHYSICS_LAYER_ITEM
	collision_mask = PHYSICS_LAYER_WORLD
	hitbox_component.set_invulnerable(false)
	presence_area.collision_layer = PHYSICS_LAYER_ITEM
	presence_area.monitorable = true

	freeze = false
	linear_damp = throw_damp
	linear_velocity = inherit_velocity + aim * throw_speed
	_play_bounce_visual()
	set_physics_process(true)
	return true


func deposit_into(circle: Node) -> void:
	if _deposited or circle == null or not is_instance_valid(circle):
		return
	if not circle.has_method("receive_glyph"):
		return
	_deposited = true
	_stop_bounce()
	set_physics_process(false)

	if _state == GlyphState.CARRIED and is_instance_valid(_carrier) and _carrier.has_method("clear_carried_item"):
		_carrier.clear_carried_item(self)
	_carrier = null
	_state = GlyphState.DEPOSITING

	call_deferred("_begin_deposit_suck", circle)


func _begin_deposit_suck(circle: Node) -> void:
	if not is_instance_valid(circle):
		queue_free()
		return

	var keep_global: Vector2 = global_position
	reparent(circle, true)
	global_position = keep_global
	sprite.position.y = _sprite_rest_y

	freeze = true
	linear_velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	body_collision.disabled = true
	hitbox_component.set_invulnerable(true)
	presence_area.monitorable = false
	presence_area.collision_layer = 0

	var target: Vector2 = circle.call("get_launch_origin") if circle.has_method("get_launch_origin") else circle.global_position
	var distance: float = global_position.distance_to(target)
	var duration: float = maxf(DEPOSIT_SUCK_MIN_DURATION, distance / maxf(deposit_suck_speed, 1.0))

	if _deposit_tween != null and _deposit_tween.is_valid():
		_deposit_tween.kill()
	_deposit_tween = create_tween()
	_deposit_tween.set_trans(Tween.TRANS_CUBIC)
	_deposit_tween.set_ease(Tween.EASE_IN)
	_deposit_tween.tween_property(self, "global_position", target, duration)
	_deposit_tween.tween_callback(_finish_deposit.bind(circle))


func _finish_deposit(circle: Node) -> void:
	_deposit_tween = null
	if not is_instance_valid(circle):
		queue_free()
		return

	circle.call("receive_glyph", self)
	if deposit_sound:
		AudioManager.play_at(deposit_sound, global_position)

	var destroy_comp: DestroyComponent = COMPONENTS.get(DestroyComponent)
	if destroy_comp:
		destroy_comp.self_destroy(false)
	else:
		queue_free()


func _physics_process(_delta: float) -> void:
	if _state != GlyphState.THROWN:
		set_physics_process(false)
		return
	if linear_velocity.length() <= STOP_SPEED:
		_settle_grounded()


func settle_on_ground() -> void:
	_settle_grounded()


func _settle_grounded() -> void:
	_state = GlyphState.GROUNDED
	linear_velocity = Vector2.ZERO
	freeze = true
	linear_damp = 0.0
	set_physics_process(false)
	_set_grounded_physics()
	_stop_bounce()
	sprite.position.y = _sprite_rest_y


func _set_grounded_physics() -> void:
	collision_layer = PHYSICS_LAYER_ITEM
	collision_mask = PHYSICS_LAYER_WORLD
	freeze = true
	linear_velocity = Vector2.ZERO
	body_collision.set_deferred("disabled", false)
	hitbox_component.set_invulnerable(false)
	presence_area.collision_layer = PHYSICS_LAYER_ITEM
	presence_area.set_deferred("monitoring", false)
	presence_area.set_deferred("monitorable", true)


func _play_bounce_visual() -> void:
	_stop_bounce()
	sprite.position.y = _sprite_rest_y
	_bounce_tween = create_tween()
	var hops: int = maxi(bounce_hops, 1)
	for i in hops:
		var height: float = bounce_height * (1.0 - float(i) / float(hops))
		var up_time: float = 0.08 + 0.02 * float(i)
		var down_time: float = 0.1 + 0.02 * float(i)
		_bounce_tween.tween_property(sprite, "position:y", _sprite_rest_y - height, up_time)
		_bounce_tween.tween_property(sprite, "position:y", _sprite_rest_y, down_time)


func _stop_bounce() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = null
	if is_instance_valid(sprite):
		sprite.position.y = _sprite_rest_y
