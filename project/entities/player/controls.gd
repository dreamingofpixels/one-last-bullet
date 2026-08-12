class_name Controls extends Node

## Per-player input abstraction.
## Call apply_player_index() from player._ready() before any input is read.
## player_index 1 = keyboard + mouse + gamepad device 0.
## player_index 2 = gamepad device 1, etc.

const AIM_DEADZONE: float = 0.2

var player_index: int = 1

@onready var move_up_action: PlayerAction = %MoveUpAction
@onready var move_down_action: PlayerAction = %MoveDownAction
@onready var move_left_action: PlayerAction = %MoveLeftAction
@onready var move_right_action: PlayerAction = %MoveRightAction
@onready var aim_up_action: PlayerAction = %AimUpAction
@onready var aim_down_action: PlayerAction = %AimDownAction
@onready var aim_left_action: PlayerAction = %AimLeftAction
@onready var aim_right_action: PlayerAction = %AimRightAction
@onready var redirect_action: PlayerAction = %RedirectAction
@onready var aim_confirm_action: PlayerAction = %AimConfirmAction


func apply_player_index(index: int) -> void:
	player_index = index
	var suffix := "" if index == 1 else ("_" + str(index))
	for child in get_children():
		if child is PlayerAction:
			child.action += suffix


## Returns the normalized movement direction from WASD or left stick.
func get_move_vector() -> Vector2:
	return Input.get_vector(
		move_left_action.action,
		move_right_action.action,
		move_up_action.action,
		move_down_action.action
	)


## Returns the aim direction vector.
## Gamepad right-stick if deflected past deadzone; otherwise mouse (P1 only) or zero.
func get_aim_vector(origin: Vector2) -> Vector2:
	var stick := Input.get_vector(
		aim_left_action.action,
		aim_right_action.action,
		aim_up_action.action,
		aim_down_action.action
	)
	if stick.length() > AIM_DEADZONE:
		return stick.normalized()
	if player_index == 1:
		# Convert screen-space mouse to world space via the viewport's canvas transform.
		var vp := get_viewport()
		var world_mouse := vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
		var to_mouse := world_mouse - origin
		if to_mouse.length_squared() > 0.0001:
			return to_mouse.normalized()
	return Vector2.ZERO


func is_redirect_just_pressed() -> bool:
	if redirect_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(redirect_action.action)


func is_confirm_just_pressed() -> bool:
	if aim_confirm_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(aim_confirm_action.action)
