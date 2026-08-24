class_name SummoningCircle
extends Node2D

signal mana_deposited(amount: float, total: float)

var mana_pool: float = 0.0

@onready var deposit_area: Area2D = %DepositArea


func _ready() -> void:
	deposit_area.body_entered.connect(_on_deposit_area_body_entered)
	deposit_area.area_entered.connect(_on_deposit_area_area_entered)


func get_launch_origin() -> Vector2:
	return deposit_area.global_position


func deposit(amount: float) -> void:
	if amount <= 0.0:
		return
	mana_pool += amount
	mana_deposited.emit(amount, mana_pool)


func _on_deposit_area_body_entered(body: Node2D) -> void:
	_try_deposit_crystal(_resolve_crystal(body))


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
