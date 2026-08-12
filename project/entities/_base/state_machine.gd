class_name StateMachine extends Node

signal state_changed(current_state: State)

@export var start_state: NodePath

## Optional debug label — set in the scene; missing label is silently ignored.
@export var optional_state_label: NodePath

var current_state: State = null
var _states_stack: Array[State] = []
var _states_map: Dictionary = {}
var _active: bool = false


func _ready() -> void:
	for child in get_children():
		if child is State:
			_states_map[child.name.to_lower()] = child
			child.finished.connect(_on_state_finished)

	_initialize(start_state)


func _initialize(initial_state: NodePath) -> void:
	var state: State = get_node(initial_state) as State
	_states_stack.push_front(state)
	_states_stack.push_front(state)
	current_state = _states_stack[0]
	current_state.enter()
	set_active(true)


## Force an immediate transition (bypasses current state's finished signal).
## Useful for external code that needs to set the initial state.
func force_state(state_name: String) -> void:
	_on_state_finished(state_name)


func set_active(value: bool) -> void:
	_active = value
	set_physics_process(value)
	set_process_input(value)
	if not _active:
		_states_stack.clear()
		current_state = null


func _physics_process(delta: float) -> void:
	current_state.update(delta)


func _input(event: InputEvent) -> void:
	current_state.handle_input(event)


func _on_state_finished(next_state_name: String) -> void:
	if not _active:
		return

	current_state.exit()

	if next_state_name == "previous":
		_states_stack[0] = _states_stack[1]
	else:
		if not _states_map.has(next_state_name):
			push_error("StateMachine: unknown state '%s'" % next_state_name)
			return
		_states_stack[0] = _states_map[next_state_name]

	_states_stack[1] = current_state
	current_state = _states_stack[0]
	state_changed.emit(current_state)

	_update_debug_label(current_state.name)

	if next_state_name != "previous":
		current_state.enter()


func _update_debug_label(text: String) -> void:
	if optional_state_label.is_empty():
		return
	var label := get_node_or_null(optional_state_label)
	if label and label.has_method("set") and "text" in label:
		label.text = text
