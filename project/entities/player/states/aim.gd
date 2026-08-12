extends State

# Ignore the same confirm press that may have been used elsewhere for a short window.
var _ignore_confirm_until_msec: int = 0


func enter() -> void:
	owner.movement_component.stop()
	_ignore_confirm_until_msec = Time.get_ticks_msec() + 200


func exit() -> void:
	pass


func update(_delta: float) -> void:
	if not owner.opening_aim_component.can_aim():
		var controls: Controls = owner.controls
		if controls.get_move_vector() != Vector2.ZERO:
			emit_signal("finished", "walk")
		else:
			emit_signal("finished", "idle")
		return

	var controls: Controls = owner.controls
	var local_dir := controls.get_aim_vector(owner.global_position)
	if local_dir.length_squared() > 0.0001:
		owner.opening_aim_component.set_aim_direction(local_dir)

	if Time.get_ticks_msec() >= _ignore_confirm_until_msec:
		if controls.is_confirm_just_pressed():
			owner.opening_aim_component.confirm_aim()


func handle_input(_event: InputEvent) -> void:
	pass
