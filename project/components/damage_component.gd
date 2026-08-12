class_name DamageComponent extends Node2D

## Amount of damage dealt per hit.
@export var damage: float = 1.0

## The entity responsible for this damage (e.g. the player who aimed or deflected).
## Used to skip friendly-fire: HitboxComponent ignores damage when instigator == its owner.
@export var instigator: Node = null
