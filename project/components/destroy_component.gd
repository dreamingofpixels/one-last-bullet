class_name DestroyComponent extends Node2D

signal destroyed(node: Node)

## The sprite to use for the pixel-fall destruction VFX (Sprite2D or AnimatedSprite2D).
@export var sprite: Node2D
@export var destroy_sound: SoundEvent = preload("res://entities/entity_destroyed.tres")

var _is_destroying: bool = false


func self_destroy(play_sound: bool = true) -> void:
	if _is_destroying:
		return
	_is_destroying = true

	_disable_collisions()

	destroyed.emit(owner)

	if play_sound and destroy_sound and owner is Node2D:
		AudioManager.play_at(destroy_sound, (owner as Node2D).global_position)

	if sprite:
		DestructionEffect.play_from_sprite(sprite)

	owner.queue_free()


func _disable_collisions() -> void:
	if owner == null or not is_instance_valid(owner):
		return

	if owner is CharacterBody2D or owner is RigidBody2D:
		owner.set_deferred("collision_layer", 0)

	# Disable every CollisionShape2D directly under the owner.
	for child in owner.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)

	# Also disable shapes inside any HitboxComponent areas.
	for child in owner.get_children():
		if child.name == "Components":
			for component in child.get_children():
				if component is Area2D:
					for shape in component.get_children():
						if shape is CollisionShape2D:
							(shape as CollisionShape2D).set_deferred("disabled", true)
					component.set_deferred("monitoring", false)
