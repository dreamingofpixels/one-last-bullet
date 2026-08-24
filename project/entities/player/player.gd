extends CharacterBody2D

## Player index: 1 = keyboard/mouse + gamepad device 0.
## 2 = gamepad device 1. Set this before adding to the scene tree.
@export var player_index: int = 1

var COMPONENTS: Dictionary = {}

@onready var movement_component: MovementComponent = %MovementComponent
@onready var attack_component: AttackComponent = %AttackComponent
@onready var dash_component: DashComponent = %DashComponent
@onready var orb_tether_component: OrbTetherComponent = %OrbTetherComponent
@onready var destroy_component: DestroyComponent = %DestroyComponent
@onready var directional_sprite: DirectionalSpriteComponent = %DirectionalSpriteComponent
@onready var player_sprite: AnimatedSprite2D = %PlayerSprite
@onready var controls: Controls = %Controls
@onready var state_machine: StateMachine = %StateMachine

var _assembling: bool = true
var _carried_crystal: ManaCrystal = null


func _ready() -> void:
	add_to_group("player")
	controls.apply_player_index(player_index)
	player_sprite.visible = false
	_set_spawn_inert(true)


# ── Public API (called from level.gd) ─────────────────────────────────────────

func begin_level() -> void:
	await DestructionEffect.play_assemble_from_sprite(player_sprite)
	player_sprite.visible = true
	_set_spawn_inert(false)
	_assembling = false


func is_assembling() -> bool:
	return _assembling


func is_carrying_crystal() -> bool:
	return is_instance_valid(_carried_crystal) and _carried_crystal.is_carried()


func get_carried_crystal() -> ManaCrystal:
	if is_carrying_crystal():
		return _carried_crystal
	return null


func pick_up_crystal(crystal: ManaCrystal) -> bool:
	if is_carrying_crystal() or crystal == null or not is_instance_valid(crystal):
		return false
	if not crystal.pickup(self):
		return false
	_carried_crystal = crystal
	return true


func clear_carried_crystal(crystal: ManaCrystal = null) -> void:
	if crystal != null and _carried_crystal != crystal:
		return
	_carried_crystal = null


func try_throw_crystal() -> bool:
	if not is_carrying_crystal():
		return false
	if not attack_component.can_attack():
		return false

	var aim: Vector2 = controls.get_aim_vector(global_position)
	if aim.length_squared() < 0.0001:
		aim = directional_sprite.facing_vector()
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT

	var items_parent: Node = get_parent().get_node("%Items")

	var crystal: ManaCrystal = _carried_crystal
	_carried_crystal = null
	if not crystal.throw_toward(aim, items_parent, velocity):
		_carried_crystal = crystal
		return false

	attack_component.consume_cooldown()
	return true


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
