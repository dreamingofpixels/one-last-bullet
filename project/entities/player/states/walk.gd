extends State


func enter() -> void:
	if not owner.is_attack_busy():
		owner.directional_sprite.play(&"moving")


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var controls: Controls = owner.controls
	# Yield while enemy slam / other shove owns velocity.
	if owner.knockback_component.is_active():
		return
	if (
		owner.is_assembling()
		or owner.orb_tether_component.is_tethering()
		or owner.orb_tether_component.is_channeling()
		or owner.orb_tether_component.is_vaulting()
	):
		owner.movement_component.stop()
		emit_signal("finished", "idle")
		return

	var dir := controls.get_move_vector()
	owner.movement_component.move(dir)

	# Face while charging so the bat cone tracks movement; do not overwrite attack clips.
	if owner.orb_tether_component.is_attack_charging():
		owner.directional_sprite.face(dir)
	elif not owner.is_attack_busy():
		owner.directional_sprite.face(dir)
		owner.directional_sprite.play(&"moving")

	if dir == Vector2.ZERO:
		emit_signal("finished", "idle")


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
