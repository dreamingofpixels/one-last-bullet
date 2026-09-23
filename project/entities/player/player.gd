extends CharacterBody2D

## Player index: 1 = keyboard/mouse + gamepad device 0.
## 2 = gamepad device 1. Set this before adding to the scene tree.
@export var player_index: int = 1

enum CharacterId { WIZARD, DWARF }

## Body + redirect fantasy. Wizard = dash vault; dwarf = Attack bat (incl. hold-to-spin).
@export var character: CharacterId = CharacterId.WIZARD

const STUCK_FRAMES_BEFORE_UNSTICK := 6
const WIZARD_FRAMES := preload("res://entities/player/player_frames.tres")
const DWARF_FRAMES := preload("res://entities/player/dwarf/dwarf_frames.tres")

var COMPONENTS: Dictionary = {}

@onready var movement_component: MovementComponent = %MovementComponent
@onready var knockback_component: KnockbackComponent = %KnockbackComponent
@onready var attack_component: AttackComponent = %AttackComponent
@onready var dash_component: DashComponent = %DashComponent
@onready var orb_tether_component: OrbTetherComponent = %OrbTetherComponent
@onready var destroy_component: DestroyComponent = %DestroyComponent
@onready var directional_sprite: DirectionalSpriteComponent = %DirectionalSpriteComponent
@onready var player_sprite: AnimatedSprite2D = %PlayerSprite
@onready var controls: Controls = %Controls
@onready var state_machine: StateMachine = %StateMachine
@onready var body_collision_shape: CollisionShape2D = %CollisionShape2D

var _assembling: bool = true
var _carried_item: Glyph = null
var _stuck_frames: int = 0


func _ready() -> void:
	add_to_group("player")
	controls.apply_player_index(player_index)
	_apply_character()
	player_sprite.visible = false
	_set_spawn_inert(true)


func _physics_process(_delta: float) -> void:
	if _assembling or dash_component.is_dashing():
		_stuck_frames = 0
		return
	if CollisionSeparation.is_clear(self, body_collision_shape, global_position, collision_mask):
		_stuck_frames = 0
		return
	_stuck_frames += 1
	if _stuck_frames >= STUCK_FRAMES_BEFORE_UNSTICK:
		_stuck_frames = 0
		CollisionSeparation.separate(
			self,
			body_collision_shape,
			collision_mask,
			CollisionSeparation.MAX_PUSH_PX
		)


# ── Public API (called from level.gd) ─────────────────────────────────────────

func begin_level() -> void:
	await DestructionEffect.play_assemble_from_sprite(player_sprite)
	player_sprite.visible = true
	_set_spawn_inert(false)
	_assembling = false


func is_assembling() -> bool:
	return _assembling


func is_carrying_item() -> bool:
	return is_instance_valid(_carried_item) and _carried_item.is_carried()


func get_carried_item() -> Glyph:
	if is_carrying_item():
		return _carried_item
	return null


func pick_up_item(item: Glyph) -> bool:
	if is_carrying_item() or item == null or not is_instance_valid(item):
		return false
	if not item.pickup(self):
		return false
	_carried_item = item
	return true


func clear_carried_item(item: Glyph = null) -> void:
	if item != null and _carried_item != item:
		return
	_carried_item = null


func try_throw_item() -> bool:
	if not is_carrying_item():
		return false

	var aim: Vector2 = controls.get_throw_aim_vector()
	if aim.length_squared() < 0.0001:
		aim = directional_sprite.facing_vector()
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT

	# Players live under %WorldYSort, so Items is on the level (current scene), not our parent.
	var items_parent: Node = get_tree().current_scene.get_node("%Items")

	var item: Glyph = _carried_item
	_carried_item = null
	if not item.throw_toward(aim, items_parent, velocity):
		_carried_item = item
		return false

	play_attack_visual(aim)
	return true


## Dwarf: body faces the wedge visual center. The polygon centroid is on local +X, so this matches stick aim.
func sync_body_facing(move_dir: Vector2 = Vector2.ZERO) -> void:
	if orb_tether_component.attack_bat_enabled:
		var aim: Vector2 = orb_tether_component.get_bat_aim()
		_face_aim(attack_component.get_visual_forward(aim))
		return
	if move_dir.length_squared() > 0.0001:
		directional_sprite.face(move_dir)


## Face aim and play the body attacking clip (glyph throw / Attack bat front swing).
func play_attack_visual(aim: Vector2 = Vector2.ZERO) -> void:
	_face_aim(aim)
	directional_sprite.play(&"attacking", true)


## Face aim and play the 360° spin clip (dwarf hold-to-release Attack bat).
func play_attack_around_visual(aim: Vector2 = Vector2.ZERO) -> void:
	_face_aim(aim)
	directional_sprite.play(&"attack_around", true)


## True while charging Attack hold, or while a body attack clip is active (incl. paused charge pose).
func is_attack_busy() -> bool:
	if orb_tether_component.is_attack_charging():
		return true
	return (
		directional_sprite.is_playing_action(&"attacking")
		or directional_sprite.is_playing_action(&"attack_around")
	)


## True for dwarf (body hammer clips are the Attack swing; no wizard arc sprite).
func uses_body_attack_swing() -> bool:
	return character == CharacterId.DWARF


func _face_aim(aim: Vector2) -> void:
	var dir: Vector2 = aim
	if dir.length_squared() < 0.0001:
		dir = controls.get_aim_vector(global_position)
	if dir.length_squared() < 0.0001:
		dir = directional_sprite.facing_vector()
	if dir.length_squared() < 0.0001:
		dir = Vector2.RIGHT
	directional_sprite.face(dir)


func _apply_character() -> void:
	match character:
		CharacterId.DWARF:
			player_sprite.sprite_frames = DWARF_FRAMES
			# Sheet faces SE; invert so logical west matches the art after flip.
			directional_sprite.set_flip_h_inverted(true)
			orb_tether_component.orb_redirect_mode = OrbTetherComponent.OrbRedirectMode.ATTACK_BAT
		_:
			player_sprite.sprite_frames = WIZARD_FRAMES
			directional_sprite.set_flip_h_inverted(false)
			orb_tether_component.orb_redirect_mode = OrbTetherComponent.OrbRedirectMode.DASH_VAULT
	directional_sprite.play(&"idle", true)


func _set_spawn_inert(inert: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = inert

	var hitbox_component: HitboxComponent = COMPONENTS.get(HitboxComponent)
	if hitbox_component:
		hitbox_component.monitoring = not inert
		hitbox_component.set_invulnerable(inert)
		for shape in hitbox_component.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).disabled = inert
