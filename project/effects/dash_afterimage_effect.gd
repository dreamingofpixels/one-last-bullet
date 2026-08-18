class_name DashAfterimageEffect
extends RefCounted

const AFTERIMAGE_COLOR: Color = Color(0.85, 0.95, 1.0, 0.55)
const AFTERIMAGE_LIFETIME: float = 0.25


static func spawn(parent: Node, source: AnimatedSprite2D, at_position: Vector2) -> void:
	if parent == null or source == null:
		return

	var tree := source.get_tree()
	if tree == null:
		return

	var scene_parent := tree.current_scene as Node
	if scene_parent == null:
		scene_parent = parent
	if scene_parent == null:
		return

	var frame_tex: Texture2D = _extract_frame_texture(source)
	if frame_tex == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = frame_tex
	ghost.centered = source.centered
	ghost.offset = source.offset
	ghost.flip_h = source.flip_h
	ghost.flip_v = source.flip_v
	ghost.texture_filter = source.texture_filter
	ghost.z_index = source.z_index + 1
	ghost.global_position = at_position
	ghost.modulate = AFTERIMAGE_COLOR

	scene_parent.add_child(ghost)
	ghost.global_position = at_position

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	tween.tween_callback(ghost.queue_free)


static func _extract_frame_texture(source: AnimatedSprite2D) -> Texture2D:
	if source.sprite_frames == null:
		return null
	var current: StringName = source.animation
	if not source.sprite_frames.has_animation(current):
		return null
	var frame_tex: Texture2D = source.sprite_frames.get_frame_texture(current, source.frame)
	if frame_tex == null:
		return null
	return frame_tex
