class_name HealthComponent extends Node2D

signal damage_taken
signal health_changed(current: float, maximum: float)

@export var max_health: float = 1.0
@export var destroy_component: DestroyComponent
## Optional override; falls back to DestroyComponent.sprite when unset.
@export var sprite: Node2D
@export var damaged_sound: SoundEvent = preload("res://entities/entity_damaged.tres")
@export var damage_flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var damage_flash_seconds: float = 0.12

var health: float = 1.0
var _flash_tween: Tween


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func take_damage(amount: float) -> void:
	health -= amount
	damage_taken.emit()
	health_changed.emit(health, max_health)
	_flash_damage()
	if health <= 0.0:
		if destroy_component:
			destroy_component.self_destroy()
	elif damaged_sound and owner is Node2D:
		AudioManager.play_at(damaged_sound, (owner as Node2D).global_position)


func _resolve_sprite() -> CanvasItem:
	if sprite is CanvasItem and is_instance_valid(sprite):
		return sprite as CanvasItem
	if destroy_component and destroy_component.sprite is CanvasItem and is_instance_valid(destroy_component.sprite):
		return destroy_component.sprite as CanvasItem
	return null


func _flash_damage() -> void:
	var target := _resolve_sprite()
	if target == null:
		return

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	target.modulate = damage_flash_color
	# Fatal hits keep red so DestructionEffect inherits the hit tint.
	if health <= 0.0:
		return

	_flash_tween = create_tween()
	_flash_tween.tween_property(target, "modulate", Color.WHITE, damage_flash_seconds)
