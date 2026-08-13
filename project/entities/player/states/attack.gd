extends State


func enter() -> void:
	var controls: Controls = owner.controls
	var aim := controls.get_aim_vector(owner.global_position)
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT
	owner.directional_sprite.face(aim)
	owner.attack_component.start(aim)


func exit() -> void:
	pass


func update(_delta: float) -> void:
	var attack: AttackComponent = owner.attack_component
	var controls: Controls = owner.controls

	if not attack.lock_movement:
		var dir := controls.get_move_vector()
		if dir != Vector2.ZERO:
			owner.movement_component.move(dir)
		else:
			owner.movement_component.stop()
	else:
		owner.movement_component.stop()

	if not attack.is_attacking():
		if controls.get_move_vector() != Vector2.ZERO:
			emit_signal("finished", "walk")
		else:
			emit_signal("finished", "idle")


func handle_input(_event: InputEvent) -> void:
	pass
