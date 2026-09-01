class_name SummoningCircle
extends Node2D

signal mana_deposited(amount: float, total: float)
signal mana_spent(amount: float, total: float)
signal activated
signal deactivated
signal inventory_changed
signal ritual_started(orb: RigidBody2D)
signal ritual_ended

@export var activation_step: float = 5.0
@export var max_glyph_capacity: int = 3
@export var blink_color: Color = Color(0.55, 0.4, 0.95, 1.0)
@export var blink_duration: float = 0.35
@export var orb_capture_suck_speed: float = 240.0

var mana_pool: float = 0.0
var glyph_inventory: Array[Dictionary] = []

var _activation_count: int = 0
var _active: bool = false
var _ritual_running: bool = false
var _captured_orb: RigidBody2D = null
var _players_inside: Dictionary = {}
var _blink_tween: Tween
var _capture_tween: Tween

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


func is_active() -> bool:
	return _active


func is_ritual_running() -> bool:
	return _ritual_running


func get_activation_cost() -> float:
	return activation_step * float(_activation_count)


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


func try_activate() -> bool:
	if _active or _ritual_running:
		return false
	var cost: float = get_activation_cost()
	# First activation is free (cost 0); spend() rejects amount <= 0.
	if cost > 0.0 and not spend(cost):
		return false
	_activation_count += 1
	_active = true
	_start_activation_vfx()
	activated.emit()
	return true


func deactivate() -> void:
	if not _active:
		return
	_active = false
	_stop_activation_vfx()
	deactivated.emit()


func receive_glyph(glyph: Node) -> void:
	if glyph == null or not is_instance_valid(glyph):
		return
	if not glyph.has_method("get_mana_value"):
		return
	var entry: Dictionary = {
		"id": String(glyph.get("glyph_id")),
		"rarity": glyph.get("rarity"),
	}
	if glyph_inventory.size() < max_glyph_capacity:
		glyph_inventory.append(entry)
		inventory_changed.emit()
	else:
		deposit(glyph.call("get_mana_value"))


func remove_inventory_entry(index: int) -> Dictionary:
	if index < 0 or index >= glyph_inventory.size():
		return {}
	var entry: Dictionary = glyph_inventory[index]
	glyph_inventory.remove_at(index)
	inventory_changed.emit()
	return entry


func capture_orb(orb: RigidBody2D) -> void:
	if not _active or _ritual_running or orb == null or not is_instance_valid(orb):
		return
	if not orb.has_method("is_flying") or not orb.is_flying():
		return
	if not orb.has_method("begin_circle_capture"):
		return

	_ritual_running = true
	_captured_orb = orb
	orb.begin_circle_capture(get_launch_origin(), orb_capture_suck_speed, _on_orb_capture_finished)


func _on_orb_capture_finished() -> void:
	if _captured_orb == null or not is_instance_valid(_captured_orb):
		_ritual_running = false
		_captured_orb = null
		return
	ritual_started.emit(_captured_orb)


func release_orb(direction: Vector2 = Vector2.ZERO) -> void:
	if _captured_orb == null or not is_instance_valid(_captured_orb):
		_ritual_running = false
		_captured_orb = null
		deactivate()
		ritual_ended.emit()
		return

	var orb: RigidBody2D = _captured_orb
	_captured_orb = null
	_ritual_running = false

	var exit_dir: Vector2 = direction
	if exit_dir.length_squared() < 0.0001:
		exit_dir = Vector2.from_angle(randf() * TAU)
	if orb.has_method("release_from_circle"):
		orb.release_from_circle(exit_dir)
	deactivate()
	ritual_ended.emit()


func get_captured_orb() -> RigidBody2D:
	return _captured_orb if is_instance_valid(_captured_orb) else null


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


func _stop_activation_vfx() -> void:
	arcane_particles.emitting = false
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	sprite.modulate = Color.WHITE


func _on_deposit_area_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_players_inside[body] = true
	_try_deposit_glyph(_resolve_glyph(body))
	_try_capture_orb_body(body)


func _on_deposit_area_body_exited(body: Node2D) -> void:
	if body != null:
		_players_inside.erase(body)


func _on_deposit_area_area_entered(area: Area2D) -> void:
	_try_deposit_glyph(_resolve_glyph(area))
	_try_capture_orb_area(area)


func _resolve_glyph(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.is_in_group("glyphs"):
		return node
	var parent := node.get_parent()
	if parent != null and parent.is_in_group("glyphs"):
		return parent
	if node.owner != null and node.owner.is_in_group("glyphs"):
		return node.owner
	return null


func _try_deposit_glyph(glyph: Node) -> void:
	if glyph == null or not is_instance_valid(glyph):
		return
	if glyph.has_method("deposit_into"):
		glyph.deposit_into(self)


func _try_capture_orb_body(body: Node2D) -> void:
	if body == null or not body.is_in_group("orb"):
		return
	if body is RigidBody2D:
		capture_orb(body as RigidBody2D)


func _try_capture_orb_area(area: Area2D) -> void:
	if area == null:
		return
	var owner_node: Node = area.owner
	if owner_node is RigidBody2D and owner_node.is_in_group("orb"):
		capture_orb(owner_node as RigidBody2D)
		return
	var parent := area.get_parent()
	while parent != null:
		if parent is RigidBody2D and parent.is_in_group("orb"):
			capture_orb(parent as RigidBody2D)
			return
		parent = parent.get_parent()
