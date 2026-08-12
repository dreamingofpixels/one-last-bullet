extends State


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var controls: Controls = owner.controls
	# Poll held keys — is_action_pressed only fires on the rising edge, so returning
	# here after attack while still holding WASD would otherwise soft-lock movement.
	if controls.get_move_vector() != Vector2.ZERO:
		emit_signal("finished", "walk")
		return
	owner.movement_component.stop()


func handle_input(event: InputEvent) -> void:
	var controls: Controls = owner.controls

	if event.is_action_pressed(controls.attack_action.action):
		if owner.attack_component.can_attack():
			emit_signal("finished", "attack")
