extends State


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var controls: Controls = owner.controls
	if owner.orb_tether_component.is_tethering() or owner.orb_tether_component.is_channeling():
		owner.movement_component.stop()
		emit_signal("finished", "idle")
		return

	var dir := controls.get_move_vector()
	owner.movement_component.move(dir)
	owner.directional_sprite.face(dir)

	if dir == Vector2.ZERO:
		emit_signal("finished", "idle")


func handle_input(event: InputEvent) -> void:
	var controls: Controls = owner.controls

	if owner.orb_tether_component.is_channeling():
		return

	if event.is_action_pressed(controls.dash_action.action):
		if not owner.orb_tether_component.is_tethering() and owner.dash_component.can_dash():
			emit_signal("finished", "dash")
			return

	if event.is_action_pressed(controls.attack_action.action):
		if owner.orb_tether_component.is_tethering():
			return
		if owner.attack_component.can_attack():
			emit_signal("finished", "attack")
