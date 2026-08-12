extends State


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var controls: Controls = owner.controls
	var dir := controls.get_move_vector()
	owner.movement_component.move(dir)

	if dir == Vector2.ZERO:
		emit_signal("finished", "idle")


func handle_input(event: InputEvent) -> void:
	var controls: Controls = owner.controls

	if event.is_action_pressed(controls.dash_action.action):
		if owner.dash_component.can_dash():
			emit_signal("finished", "dash")
			return

	if event.is_action_pressed(controls.attack_action.action):
		if owner.attack_component.can_attack():
			emit_signal("finished", "attack")
