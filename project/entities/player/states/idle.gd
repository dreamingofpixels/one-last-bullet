extends State


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var controls: Controls = owner.controls
	owner.movement_component.stop()
	# Locked in place while tethering or channeling the orb.
	if (
		owner.is_assembling()
		or owner.orb_tether_component.is_tethering()
		or owner.orb_tether_component.is_channeling()
	):
		return
	# Poll held keys — is_action_pressed only fires on the rising edge, so returning
	# here after attack while still holding WASD would otherwise soft-lock movement.
	if controls.get_move_vector() != Vector2.ZERO:
		emit_signal("finished", "walk")


func handle_input(event: InputEvent) -> void:
	var controls: Controls = owner.controls

	if owner.is_assembling() or owner.orb_tether_component.is_channeling():
		return

	if event.is_action_pressed(controls.dash_action.action):
		if not owner.orb_tether_component.is_tethering() and owner.dash_component.can_dash():
			emit_signal("finished", "dash")
			return

	if event.is_action_pressed(controls.attack_action.action):
		if controls.uses_mouse() and _is_pointer_over_blocking_gui():
			return
		if owner.orb_tether_component.is_tethering():
			return
		if owner.has_method("try_throw_crystal") and owner.try_throw_crystal():
			return
		if not owner.attack_component.can_attack():
			return
		if owner.orb_tether_component.try_redirect_attack():
			return
		# Melee swing parked (AttackComponent.melee_enabled); Attack is redirect-only.


func _is_pointer_over_blocking_gui() -> bool:
	var hovered: Control = owner.get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE
