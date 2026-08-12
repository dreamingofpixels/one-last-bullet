extends CharacterBody2D

## Player index: 1 = keyboard/mouse + gamepad device 0.
## 2 = gamepad device 1. Set this before adding to the scene tree.
@export var player_index: int = 1

var COMPONENTS: Dictionary = {}

@onready var movement_component: MovementComponent = %MovementComponent
@onready var redirect_component: RedirectComponent = %RedirectComponent
@onready var destroy_component: DestroyComponent = %DestroyComponent
@onready var controls: Controls = %Controls
@onready var state_machine: StateMachine = %StateMachine


func _ready() -> void:
	add_to_group("player")
	controls.apply_player_index(player_index)


# ── Public API (called from level.gd) ─────────────────────────────────────────

func bind_bullet(bullet: RigidBody2D) -> void:
	redirect_component.bind_bullet(bullet)


func begin_opening_aim(bullet: RigidBody2D, duration_seconds: float) -> void:
	redirect_component.bind_bullet(bullet)
	redirect_component.begin_opening_aim(duration_seconds)
	# During the opening aim the bullet drives its own slow-mo; the Redirect state
	# will detect can_aim() == true and keep feeding aim until the window closes.
	state_machine.force_state("redirect")
