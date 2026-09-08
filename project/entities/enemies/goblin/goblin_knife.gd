extends CharacterBody2D

const ANIM_IDLE := &"idle"
const ANIM_RUN := &"running"
const ANIM_ATTACK := &"attacking"
## Below this speed the goblin reads as standing still.
const RUN_SPEED_THRESHOLD := 5.0

var COMPONENTS: Dictionary = {}

@onready var sprite: AnimatedSprite2D = %Sprite2D
@onready var hitbox: HitboxComponent = %HitboxComponent


func _physics_process(_delta: float) -> void:
	if _is_touching_player():
		# `attacking` does not loop, so retrigger it once it finishes.
		if sprite.animation != ANIM_ATTACK or not sprite.is_playing():
			sprite.play(ANIM_ATTACK)
	elif velocity.length() > RUN_SPEED_THRESHOLD:
		sprite.play(ANIM_RUN)
	else:
		sprite.play(ANIM_IDLE)


func _is_touching_player() -> bool:
	# Spawner turns monitoring off while assembling (`set_invulnerable(true)`).
	if not hitbox.monitoring:
		return false
	for area in hitbox.get_overlapping_areas():
		var other := area as HitboxComponent
		if other == null:
			continue
		var root: Node = other.owner
		if root != null and root.is_in_group("player"):
			return true
	return false
