class_name HealthComponent extends Node2D

signal damage_taken
signal health_changed(current: float, maximum: float)

@export var max_health: float = 1.0
@export var destroy_component: DestroyComponent
@export var damaged_sound: SoundEvent = preload("res://entities/entity_damaged.tres")

var health: float = 1.0


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func take_damage(amount: float) -> void:
	health -= amount
	damage_taken.emit()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		if destroy_component:
			destroy_component.self_destroy()
	elif damaged_sound and owner is Node2D:
		AudioManager.play_at(damaged_sound, (owner as Node2D).global_position)
