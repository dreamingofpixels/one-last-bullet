extends State


func enter() -> void:
	var controls: Controls = owner.controls
	var aim := controls.get_aim_vector(owner.global_position)
	if aim.length_squared() < 0.0001:
		aim = Vector2.LEFT if owner.is_sprite_flipped() else Vector2.RIGHT
	owner.dash_component.start(aim)


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
