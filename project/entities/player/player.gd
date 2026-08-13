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


func _ready() -> void:
	add_to_group("player")
	controls.apply_player_index(player_index)


# ── Public API (called from level.gd) ─────────────────────────────────────────

func begin_level(orb: RigidBody2D) -> void:
	orb_tether_component.bind_orb(orb)
	orb_tether_component.begin_opening_tether()
	# Stay in Idle — is_tethering() locks movement.
