class_name DestructionEffect
extends RefCounted

const PIXEL_FALL_SHADER: Shader = preload("res://effects/pixel_fall.gdshader")
const DEFAULT_DURATION: float = 0.7


static func play_from_sprite(source: Node2D, duration: float = DEFAULT_DURATION) -> void:
	if source == null:
		return

	var tree := source.get_tree()
	if tree == null:
		return

	var parent := tree.current_scene as Node
	if parent == null:
		parent = source.get_parent()
	if parent == null:
		return

	var frame_tex: Texture2D = _extract_frame_texture(source)
	if frame_tex == null:
		return

	var fx := Sprite2D.new()
	fx.texture = frame_tex
	if source is Sprite2D:
		var spr := source as Sprite2D
		fx.centered = spr.centered
		fx.offset = spr.offset
		fx.flip_h = spr.flip_h
		fx.flip_v = spr.flip_v
	elif source is AnimatedSprite2D:
		var anim := source as AnimatedSprite2D
		fx.centered = anim.centered
		fx.offset = anim.offset
		fx.flip_h = anim.flip_h
		fx.flip_v = anim.flip_v
	fx.modulate = source.modulate
	fx.z_index = source.z_index
	fx.texture_filter = source.texture_filter
	fx.global_transform = source.global_transform

	var tex_size := frame_tex.get_size()
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


## Flatten Sprite2D / AnimatedSprite2D to a single ImageTexture so pixel_fall
## sees one frame's tex_size and full 0..1 UVs (not a whole spritesheet).
static func _extract_frame_texture(source: Node2D) -> Texture2D:
	if source is AnimatedSprite2D:
		var anim := source as AnimatedSprite2D
		if anim.sprite_frames == null:
			return null
		var current: StringName = anim.animation
		if not anim.sprite_frames.has_animation(current):
			return null
		var frame_tex: Texture2D = anim.sprite_frames.get_frame_texture(current, anim.frame)
		if frame_tex == null:
			return null
		var img: Image = frame_tex.get_image()
		if img == null:
			return null
		return ImageTexture.create_from_image(img)

	if source is Sprite2D:
		var spr := source as Sprite2D
		if spr.texture == null:
			return null
		# Single-frame sprites: use texture as-is (enemies, props).
		# Multi-frame Sprite2D sheets are not used for destruction sources today.
		return spr.texture

	return null
