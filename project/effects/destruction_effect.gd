class_name DestructionEffect
extends RefCounted

const PIXEL_FALL_SHADER: Shader = preload("res://effects/pixel_fall.gdshader")
const DEFAULT_DURATION: float = 0.7


static func play_from_sprite(source: Sprite2D, duration: float = DEFAULT_DURATION) -> void:
	if source == null or source.texture == null:
		return

	var tree := source.get_tree()
	if tree == null:
		return

	var parent := tree.current_scene as Node
	if parent == null:
		parent = source.get_parent()
	if parent == null:
		return

	var fx := Sprite2D.new()
	fx.texture = source.texture
	fx.centered = source.centered
	fx.offset = source.offset
	fx.flip_h = source.flip_h
	fx.flip_v = source.flip_v
	fx.modulate = source.modulate
	fx.z_index = source.z_index
	fx.texture_filter = source.texture_filter
	fx.global_transform = source.global_transform

	var tex_size := source.texture.get_size()
	var mat := ShaderMaterial.new()
	mat.shader = PIXEL_FALL_SHADER
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("tex_size", tex_size)
	fx.material = mat

	parent.add_child(fx)
	fx.global_transform = source.global_transform

	var tween := fx.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_method(
		func(value: float) -> void:
			mat.set_shader_parameter("progress", value),
		0.0,
		1.0,
		duration
	)
	tween.tween_callback(fx.queue_free)
