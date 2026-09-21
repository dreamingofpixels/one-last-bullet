class_name Controls extends Node

## Per-player input abstraction.
## Call apply_player_index() from player._ready() before any input is read.
## player_index 1 = keyboard + mouse + gamepad device 0.
## player_index 2 = gamepad device 1, etc.

enum InputScheme {
	KEYBOARD_MOUSE,
	GAMEPAD,
}

const AIM_DEADZONE: float = 0.2
const SCHEME_STICK_DEADZONE: float = 0.35

var player_index: int = 1
var input_scheme: InputScheme = InputScheme.KEYBOARD_MOUSE

@onready var move_up_action: PlayerAction = %MoveUpAction
@onready var move_down_action: PlayerAction = %MoveDownAction
@onready var move_left_action: PlayerAction = %MoveLeftAction
@onready var move_right_action: PlayerAction = %MoveRightAction
@onready var aim_up_action: PlayerAction = %AimUpAction
@onready var aim_down_action: PlayerAction = %AimDownAction
@onready var aim_left_action: PlayerAction = %AimLeftAction
@onready var aim_right_action: PlayerAction = %AimRightAction
@onready var pickup_action: PlayerAction = %PickupAction
@onready var activate_action: PlayerAction = %ActivateAction
@onready var upgrade_action: PlayerAction = %UpgradeAction
@onready var ritual_cancel_action: PlayerAction = %RitualCancelAction
@onready var attack_action: PlayerAction = %AttackAction
@onready var dash_action: PlayerAction = %DashAction


func apply_player_index(index: int) -> void:
	player_index = index
	var suffix := "" if index == 1 else ("_" + str(index))
	for child in get_children():
		if child is PlayerAction:
			child.action += suffix
	if index == 1:
		input_scheme = InputScheme.KEYBOARD_MOUSE
	else:
		input_scheme = InputScheme.GAMEPAD


func _input(event: InputEvent) -> void:
	_update_scheme_from_event(event)


func _update_scheme_from_event(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		if player_index != 1:
			return
		if not event.is_pressed():
			return
		input_scheme = InputScheme.KEYBOARD_MOUSE
		return

	var device_id: int = player_index - 1
	if event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event as InputEventJoypadButton
		if joy_button.device != device_id or not joy_button.pressed:
			return
		input_scheme = InputScheme.GAMEPAD
		return

	if event is InputEventJoypadMotion:
		var joy_motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		if joy_motion.device != device_id:
			return
		if absf(joy_motion.axis_value) < SCHEME_STICK_DEADZONE:
			return
		input_scheme = InputScheme.GAMEPAD


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


## Explicit bat/redirect aim: right stick past deadzone, else mouse only while on keyboard/mouse scheme.
## No mouse fallback while the last input scheme is gamepad (same idea as throw).
func get_explicit_aim_vector(origin: Vector2) -> Vector2:
	var stick := Input.get_vector(
		aim_left_action.action,
		aim_right_action.action,
		aim_up_action.action,
		aim_down_action.action
	)
	if stick.length() > AIM_DEADZONE:
		return stick.normalized()
	if input_scheme != InputScheme.KEYBOARD_MOUSE or player_index != 1:
		return Vector2.ZERO
	var vp := get_viewport()
	var world_mouse := vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
	var to_mouse := world_mouse - origin
	if to_mouse.length_squared() > 0.0001:
		return to_mouse.normalized()
	return Vector2.ZERO


## True when the player is actively aiming (stick past deadzone, or P1 on keyboard/mouse scheme).
func is_explicitly_aiming() -> bool:
	var stick := Input.get_vector(
		aim_left_action.action,
		aim_right_action.action,
		aim_up_action.action,
		aim_down_action.action
	)
	if stick.length() > AIM_DEADZONE:
		return true
	return input_scheme == InputScheme.KEYBOARD_MOUSE and player_index == 1


## Glyph throw direction: right stick if aimed, else move direction, else zero (caller uses facing).
func get_throw_aim_vector() -> Vector2:
	var stick := Input.get_vector(
		aim_left_action.action,
		aim_right_action.action,
		aim_up_action.action,
		aim_down_action.action
	)
	if stick.length() > AIM_DEADZONE:
		return stick.normalized()
	var move: Vector2 = get_move_vector()
	if move.length_squared() > 0.0001:
		return move.normalized()
	return Vector2.ZERO


func is_pickup_just_pressed() -> bool:
	if pickup_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(pickup_action.action)


func is_pickup_pressed() -> bool:
	if pickup_action.action.is_empty():
		return false
	return Input.is_action_pressed(pickup_action.action)


func is_pickup_just_released() -> bool:
	if pickup_action.action.is_empty():
		return false
	return Input.is_action_just_released(pickup_action.action)


func is_dash_just_pressed() -> bool:
	if dash_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(dash_action.action)


func is_attack_just_pressed() -> bool:
	if attack_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(attack_action.action)


func is_attack_pressed() -> bool:
	if attack_action.action.is_empty():
		return false
	return Input.is_action_pressed(attack_action.action)


func is_attack_just_released() -> bool:
	if attack_action.action.is_empty():
		return false
	return Input.is_action_just_released(attack_action.action)


func is_activate_just_pressed() -> bool:
	if activate_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(activate_action.action)


func is_upgrade_just_pressed() -> bool:
	if upgrade_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(upgrade_action.action)


func is_ritual_cancel_just_pressed() -> bool:
	if ritual_cancel_action.action.is_empty():
		return false
	return Input.is_action_just_pressed(ritual_cancel_action.action)


## True when this player aims with the mouse (P1). Gamepad-only players must not use mouse GUI gates.
func uses_mouse() -> bool:
	return player_index == 1


## True when prompts should show keyboard/mouse icons for this player.
func prefers_keyboard_mouse() -> bool:
	return input_scheme == InputScheme.KEYBOARD_MOUSE
