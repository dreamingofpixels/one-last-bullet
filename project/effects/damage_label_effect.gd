class_name DamageLabelEffect
extends RefCounted

const LABEL_SCENE: PackedScene = preload("res://effects/damage_label.tscn")

const COLOR_STANDARD := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_POISON := Color(0.35, 0.9, 0.35, 1.0)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 1.0)


static func color_for_kind(kind: HealthComponent.DamageKind) -> Color:
	match kind:
		HealthComponent.DamageKind.POISON:
			return COLOR_POISON
		HealthComponent.DamageKind.SHADOW:
			return COLOR_SHADOW
		_:
			return COLOR_STANDARD


static func spawn_at(origin: Node2D, amount: float, kind: HealthComponent.DamageKind) -> void:
	if origin == null or not is_instance_valid(origin):
		return

	var tree := origin.get_tree()
	if tree == null:
		return

	var parent: Node = tree.current_scene
	if parent == null:
		parent = origin.get_parent()
	if parent == null:
		return

	var fx = LABEL_SCENE.instantiate()
	parent.add_child(fx)
	fx.global_position = origin.global_position
	fx.play(amount, color_for_kind(kind))
