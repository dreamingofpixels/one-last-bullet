extends State


func enter() -> void:
	if not owner.directional_sprite.is_playing_action(&"attacking"):
		owner.directional_sprite.play(&"idle")


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var controls: Controls = owner.controls
	# Yield while enemy slam / other shove owns velocity.
	if owner.knockback_component.is_active():
		return
	owner.movement_component.stop()
	# Locked in place while tethering, channeling, or vault-aiming an orb.
	if (
		owner.is_assembling()
		or owner.orb_tether_component.is_tethering()
		or owner.orb_tether_component.is_channeling()
		or owner.orb_tether_component.is_vaulting()
	):
		return
	# Poll held keys — is_action_pressed only fires on the rising edge, so returning
	# here after attack while still holding WASD would otherwise soft-lock movement.
	if controls.get_move_vector() != Vector2.ZERO:
		emit_signal("finished", "walk")
		return
	if not owner.directional_sprite.is_playing_action(&"attacking"):
		owner.directional_sprite.play(&"idle")


func handle_input(event: InputEvent) -> void:
	var controls: Controls = owner.controls

	if owner.is_assembling() or owner.orb_tether_component.is_channeling():
		return

	if event.is_action_pressed(controls.dash_action.action):
		if (
			not owner.orb_tether_component.is_tethering()
			and not owner.orb_tether_component.is_vaulting()
			and owner.dash_component.can_dash()
		):
			emit_signal("finished", "dash")
			return

	# Attack parked: glyph throw is on pickup; vault early-fire is on dash-again.
	# Melee / proximity redirect remain behind AttackComponent / OrbTetherComponent flags.
