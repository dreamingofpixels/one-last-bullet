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


func _ready() -> void:
	add_to_group("player")
	controls.apply_player_index(player_index)
	player_sprite.visible = false
	_set_spawn_inert(true)


# ── Public API (called from level.gd) ─────────────────────────────────────────

func begin_level(orb: RigidBody2D) -> void:
	await DestructionEffect.play_assemble_from_sprite(player_sprite)
	player_sprite.visible = true
	_set_spawn_inert(false)
	_assembling = false
	orb_tether_component.bind_orb(orb)
	orb_tether_component.begin_opening_tether()
	# Stay in Idle — is_tethering() locks movement.


func is_assembling() -> bool:
	return _assembling


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
