class_name OrbImpactEffect
extends RefCounted

const IMPACT_SCENE: PackedScene = preload("res://effects/orb_impact.tscn")


static func play_at(parent: Node, position: Vector2, normal: Vector2) -> void:
	if parent == null:
		return

	var fx: GPUParticles2D = IMPACT_SCENE.instantiate()
	parent.add_child(fx)
	fx.global_position = position
	if normal.length_squared() > 0.0001:
		fx.rotation = normal.normalized().angle()
	fx.restart()
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
