class_name State extends Node

## Base class for all state machine states.
## States must live as direct children of a StateMachine node.
## Emit finished(next_state_name) to request a transition.
## Use "previous" as next_state_name to return to the previous state.

signal finished(next_state_name: String)


## Called when entering this state (except when restoring via "previous").
func enter() -> void:
	pass


## Called when leaving this state.
func exit() -> void:
	pass


## Called every physics tick while this state is active.
func update(_delta: float) -> void:
	pass


## Called for every unhandled input event while this state is active.
func handle_input(_event: InputEvent) -> void:
	pass
