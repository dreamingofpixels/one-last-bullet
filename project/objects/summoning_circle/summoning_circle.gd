class_name SummoningCircle
extends Node2D

signal mana_deposited(amount: float, total: float)
signal mana_spent(amount: float, total: float)
signal activated

@export var activation_cost: float = 5.0
@export var blink_color: Color = Color(0.55, 0.4, 0.95, 1.0)
@export var blink_duration: float = 0.35

var mana_pool: float = 0.0

var _activated: bool = false
var _players_inside: Dictionary = {}
var _blink_tween: Tween

@onready var deposit_area: Area2D = %DepositArea
@onready var mana_pool_label: Label = %ManaPoolLabel
@onready var sprite: Sprite2D = %Sprite2D
@onready var arcane_particles: GPUParticles2D = %ArcaneParticles


func _ready() -> void:
	add_to_group("summoning_circle")
	arcane_particles.emitting = false
	_refresh_mana_label()
	deposit_area.body_entered.connect(_on_deposit_area_body_entered)
	deposit_area.body_exited.connect(_on_deposit_area_body_exited)
	deposit_area.area_entered.connect(_on_deposit_area_area_entered)


func get_launch_origin() -> Vector2:
	return deposit_area.global_position


func is_activated() -> bool:
	return _activated


func contains_player(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return _players_inside.has(player)


func deposit(amount: float) -> void:
	if amount <= 0.0:
		return
	mana_pool += amount
	_refresh_mana_label()
	mana_deposited.emit(amount, mana_pool)


func spend(amount: float) -> bool:
	if amount <= 0.0 or mana_pool < amount:
		return false
	mana_pool -= amount
	_refresh_mana_label()
	mana_spent.emit(amount, mana_pool)
	return true


## Spend activation_cost and start active VFX. Once per circle; false if already on or unaffordable.
func try_activate() -> bool:
	if _activated:
		return false
	if not spend(activation_cost):
		return false
	_activated = true
	_start_activation_vfx()
	activated.emit()
	return true


func _refresh_mana_label() -> void:
	mana_pool_label.text = str(int(mana_pool))


func _start_activation_vfx() -> void:
	arcane_particles.emitting = true
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(sprite, "modulate", blink_color, blink_duration)
	_blink_tween.tween_property(sprite, "modulate", Color.WHITE, blink_duration)


func _on_deposit_area_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_players_inside[body] = true
	_try_deposit_crystal(_resolve_crystal(body))


func _on_deposit_area_body_exited(body: Node2D) -> void:
	if body != null:
		_players_inside.erase(body)


func _on_deposit_area_area_entered(area: Area2D) -> void:
	_try_deposit_crystal(_resolve_crystal(area))


func _resolve_crystal(node: Node) -> ManaCrystal:
	if node == null or not is_instance_valid(node):
		return null
	if node is ManaCrystal:
		return node as ManaCrystal
	var parent := node.get_parent()
	if parent is ManaCrystal:
		return parent as ManaCrystal
	if node.owner is ManaCrystal:
		return node.owner as ManaCrystal
	return null


func _try_deposit_crystal(crystal: ManaCrystal) -> void:
	if crystal == null or not is_instance_valid(crystal):
		return
	crystal.deposit_into(self)
