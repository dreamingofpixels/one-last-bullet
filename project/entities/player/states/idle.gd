extends State


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	owner.movement_component.stop()


func handle_input(event: InputEvent) -> void:
	var controls: Controls = owner.controls

	# Any movement key → walk
	if event.is_action_pressed(controls.move_up_action.action) \
	or event.is_action_pressed(controls.move_down_action.action) \
	or event.is_action_pressed(controls.move_left_action.action) \
	or event.is_action_pressed(controls.move_right_action.action):
		emit_signal("finished", "walk")
		return

	# Redirect press near bullet → redirect state
	if event.is_action_pressed(controls.redirect_action.action):
		if owner.redirect_component.can_redirect():
			emit_signal("finished", "redirect")
