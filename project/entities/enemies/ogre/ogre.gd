extends CharacterBody2D

const ANIM_IDLE := &"idle"
const ANIM_RUN := &"running"
## Below this speed the ogre reads as standing still.
const RUN_SPEED_THRESHOLD := 5.0

var COMPONENTS: Dictionary = {}

@onready var sprite: AnimatedSprite2D = %Sprite2D
@onready var attack_component: EnemyAttackComponent = %EnemyAttackComponent


func _physics_process(_delta: float) -> void:
	if attack_component.is_attacking():
		return
	if velocity.length() > RUN_SPEED_THRESHOLD:
		sprite.play(ANIM_RUN)
	else:
		sprite.play(ANIM_IDLE)
