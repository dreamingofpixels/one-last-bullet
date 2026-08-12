class_name HitboxComponent extends Area2D

## The HealthComponent on this entity that receives incoming damage.
@export var health_component: HealthComponent


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## Disable monitoring while invulnerable so area overlaps deal no damage.
## Deferred because callers often toggle from _physics_process.
func set_invulnerable(value: bool) -> void:
	set_deferred("monitoring", not value)


func _on_area_entered(area: Area2D) -> void:
	# `area.owner` is the scene-owner metadata; depending on how the scene was saved/instanced
	# it may not be the entity root that holds `COMPONENTS`.
	# Walk up the tree until we find a node with a COMPONENTS dictionary.
	var attacker: Node = area.owner
	if attacker == null or not is_instance_valid(attacker):
		attacker = area as Node
	while attacker != null and (attacker.get("COMPONENTS") == null):
		attacker = attacker.get_parent()

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
