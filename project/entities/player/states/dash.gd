extends State


func enter() -> void:
	if owner.orb_tether_component.is_attack_charging():
		owner.orb_tether_component.cancel_attack_charge()
	# Dodge along move if held so a dwarf facing bat-aim still dashes the way they run.
	var move: Vector2 = owner.controls.get_move_vector()
	var dash_dir: Vector2 = (
		move if move.length_squared() > 0.0001 else owner.directional_sprite.facing_vector()
	)
	owner.dash_component.start(dash_dir)


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
