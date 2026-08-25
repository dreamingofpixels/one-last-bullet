class_name ElectricOrb extends ChaosOrb

const CURRENT_RANGE := 130.0
const CURRENT_DAMAGE := 5.0
const CURRENT_SHOCK_STACKS := 3
const CURRENT_TICK_INTERVAL := 1.0
const CURRENT_HALF_WIDTH := 8.0

@onready var current_line: Line2D = %CurrentLine
@onready var current_area: Area2D = %CurrentArea
@onready var current_shape: CollisionShape2D = %CurrentShape

## Per-enemy: next tick time in msec.
var _current_tick_state: Dictionary = {}


func _ready() -> void:
	super._ready()
	current_line.visible = false
	current_area.monitoring = false
	current_area.monitorable = false
	current_shape.disabled = true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == OrbState.FLYING or state == OrbState.TETHERED:
		_update_current()
	else:
		_disable_current()


func _update_current() -> void:
	var player_node: Node2D = _find_closest_player()
	if player_node == null:
		_disable_current()
		return

	var to_player: Vector2 = player_node.global_position - global_position
	var dist: float = to_player.length()
	if dist > CURRENT_RANGE or dist < 0.001:
		_disable_current()
		return

	_enable_current(player_node.global_position)
	_poll_current_victims()


func _find_closest_player() -> Node2D:
	var closest: Node2D = null
	var best_dist_sq: float = INF
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var candidate: Node2D = node as Node2D
		var dist_sq: float = global_position.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			closest = candidate
	return closest


func _enable_current(player_pos: Vector2) -> void:
	current_line.visible = true
	current_line.clear_points()
	current_line.add_point(Vector2.ZERO)
	current_line.add_point(to_local(player_pos))

	current_area.monitoring = true
	current_shape.disabled = false

	var mid: Vector2 = (player_pos + global_position) * 0.5
	var segment: Vector2 = player_pos - global_position
	var length: float = segment.length()
	current_area.global_position = mid
	# Capsule's long axis is local Y; rotate so Y aligns with the segment.
	current_area.rotation = segment.angle() + PI * 0.5

	var capsule := current_shape.shape as CapsuleShape2D
	if capsule:
		capsule.radius = CURRENT_HALF_WIDTH
		capsule.height = maxf(length, CURRENT_HALF_WIDTH * 2.0)


func _disable_current() -> void:
	current_line.visible = false
	current_line.clear_points()
	current_area.monitoring = false
	current_shape.disabled = true
	_current_tick_state.clear()


func _poll_current_victims() -> void:
	var now_msec: int = Time.get_ticks_msec()
	var seen_ids: Dictionary = {}

	for body in current_area.get_overlapping_bodies():
		var victim_root: Node = _resolve_entity_root(body)
		if victim_root == null or not is_instance_valid(victim_root):
			continue
		if not victim_root.is_in_group("enemies"):
			continue

		var victim_id: int = victim_root.get_instance_id()
		seen_ids[victim_id] = true
		var next_msec: int = int(_current_tick_state.get(victim_id, 0))
		if now_msec < next_msec:
			continue

		_apply_current_tick(victim_root)
		_current_tick_state[victim_id] = now_msec + int(CURRENT_TICK_INTERVAL * 1000.0)

	# Drop enemies that left the beam so re-entry ticks immediately.
	var stale: Array = []
	for victim_id in _current_tick_state:
		if not seen_ids.has(victim_id):
			stale.append(victim_id)
	for victim_id in stale:
		_current_tick_state.erase(victim_id)


func _apply_current_tick(victim_root: Node) -> void:
	var comp = victim_root.get("COMPONENTS")
	if comp == null:
		return

	if comp.has(HealthComponent):
		(comp[HealthComponent] as HealthComponent).take_damage(CURRENT_DAMAGE)

	if not comp.has(StatusComponent):
		return
	var status: StatusComponent = comp[StatusComponent] as StatusComponent
	if status.is_stunned():
		return
	status.add_stacks(StatusComponent.StatusId.SHOCK, CURRENT_SHOCK_STACKS)
