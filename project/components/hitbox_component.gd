class_name HitboxComponent extends Area2D

## The HealthComponent on this entity that receives incoming damage.
@export var health_component: HealthComponent


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## Disable monitoring while invulnerable so overlaps deal no damage.
## Deferred because callers often toggle from _physics_process.
func set_invulnerable(value: bool) -> void:
	set_deferred("monitoring", not value)


func _on_area_entered(area: Area2D) -> void:
	_try_apply_damage_from(_resolve_attacker_root(area))


func _on_body_entered(body: Node2D) -> void:
	_try_apply_damage_from(_resolve_attacker_root(body))


## Walk up from a collider until we find the entity root that holds `COMPONENTS`.
func _resolve_attacker_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null

	var attacker: Node = collider
	if collider is Area2D:
		# `owner` is scene metadata; it may not be the entity root that holds `COMPONENTS`.
		attacker = collider.owner
		if attacker == null or not is_instance_valid(attacker):
			attacker = collider

	while attacker != null and attacker.get("COMPONENTS") == null:
		attacker = attacker.get_parent()

	return attacker


func _try_apply_damage_from(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return

	var comp = attacker.get("COMPONENTS")
	if comp == null or not comp.has(DamageComponent):
		return

	var dc: DamageComponent = comp[DamageComponent]
	if dc.damage <= 0.0:
		return

	# Friendly-fire filter: the instigator of the damage is immune.
	if is_instance_valid(dc.instigator) and dc.instigator == owner:
		return

	if health_component:
		health_component.take_damage(dc.damage)
