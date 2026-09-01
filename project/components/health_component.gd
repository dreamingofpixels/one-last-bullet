class_name HealthComponent extends Node2D

signal damage_taken
signal health_changed(current: float, maximum: float)

enum DamageKind { STANDARD, POISON, SHADOW }

@export var max_health: float = 1.0
@export var destroy_component: DestroyComponent
## Optional override; falls back to DestroyComponent.sprite when unset.
@export var sprite: Node2D
@export var damaged_sound: SoundEvent = preload("res://entities/entity_damaged.tres")
@export var damage_flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var damage_flash_seconds: float = 0.12
## Gameplay i-frames after a non-fatal hit. 0 = none.
@export var invulnerable_seconds: float = 0.0
@export var invulnerable_blink_alpha: float = 0.35
@export var invulnerable_blink_hz: float = 12.0

var health: float = 1.0
var _flash_tween: Tween
var _invulnerable_until_msec: int = 0


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_until_msec


## Grant gameplay i-frames for `seconds` without dealing damage (e.g. co-op opening volley).
func start_invulnerability(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_invulnerable_until_msec = maxi(
		_invulnerable_until_msec,
		Time.get_ticks_msec() + int(seconds * 1000.0)
	)


func take_damage(amount: float, kind: DamageKind = DamageKind.STANDARD) -> bool:
	if is_invulnerable():
		return false

	health -= amount
	damage_taken.emit()
	health_changed.emit(health, max_health)
	if owner is Node2D:
		DamageLabelEffect.spawn_at(owner as Node2D, amount, kind)
	_flash_damage()
	if health <= 0.0:
		_invulnerable_until_msec = 0
		if destroy_component:
			destroy_component.self_destroy()
	else:
		if invulnerable_seconds > 0.0:
			_invulnerable_until_msec = Time.get_ticks_msec() + int(invulnerable_seconds * 1000.0)
		if damaged_sound and owner is Node2D:
			AudioManager.play_at(damaged_sound, (owner as Node2D).global_position)
	return true


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

	if invulnerable_seconds <= damage_flash_seconds:
		return

	var blink_duration: float = invulnerable_seconds - damage_flash_seconds
	var blink_period: float = 1.0 / maxf(invulnerable_blink_hz, 1.0)
	var half_period: float = blink_period * 0.5
	var cycles: int = maxi(1, int(ceil(blink_duration / blink_period)))
	var dim := Color(1.0, 1.0, 1.0, invulnerable_blink_alpha)
	for _i in cycles:
		_flash_tween.tween_property(target, "modulate", dim, half_period)
		_flash_tween.tween_property(target, "modulate", Color.WHITE, half_period)
