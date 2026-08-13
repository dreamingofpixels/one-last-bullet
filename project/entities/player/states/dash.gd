extends State


func enter() -> void:
	owner.dash_component.start(owner.directional_sprite.facing_vector())


func exit() -> void:
	pass


func update(_delta: float) -> void:
	if owner.dash_component.is_dashing():
		return
	if owner.controls.get_move_vector() != Vector2.ZERO:
		emit_signal("finished", "walk")
	else:
		emit_signal("finished", "idle")


func handle_input(_event: InputEvent) -> void:
	pass
