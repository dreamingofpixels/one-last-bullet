class_name PlayerAction extends Node

## A single mappable input action for one player.
## The `action` string is set in the scene with the base action name;
## player.gd calls Controls.apply_player_index() which appends the suffix at runtime.

signal pressed
signal released
signal handling

@export var action: String = ""


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_type():
		return
	if event.is_echo():
		return
	if action.is_empty() or not event.is_action(action):
		return
	_handle_input(event)


func _handle_input(event: InputEvent) -> void:
	handling.emit()
	if event.is_pressed():
		pressed.emit()
	else:
		released.emit()


func is_holding() -> bool:
	if action.is_empty():
		return false
	return Input.is_action_pressed(action)
