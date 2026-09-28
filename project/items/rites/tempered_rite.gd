class_name TemperedRite
extends Rite


func activate() -> void:
	_refresh_world_glyphs()


func modify(stat: StringName, value: float, _subject: Node) -> float:
	if stat != &"glyph_max_health":
		return value
	return value * 2.0


func _refresh_world_glyphs() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for node in tree.get_nodes_in_group("glyphs"):
		if node is Glyph and is_instance_valid(node):
			(node as Glyph).apply_rite_max_health()
