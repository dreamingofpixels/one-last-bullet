class_name HomingComponent
extends Node2D

## Steers a heading toward a caller-supplied target. Does not pick targets or move the body.
## Orbs apply the result to BlankOrb.aim_direction; enemies use NavigationComponent instead.

@export var turn_rate: float = 2.4
@export var use_pathing: bool = true
@export var repath_interval: float = 0.2
@export var waypoint_arrive_distance: float = 12.0
## When this close to the raw target, skip remaining waypoints and steer straight at it
## (glyphs / drop points may sit slightly off the navmesh).
@export var final_approach_distance: float = 24.0

var _enabled: bool = false
var _target_node: Node2D = null
var _has_target_position: bool = false
var _target_position: Vector2 = Vector2.ZERO
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_cooldown: float = 0.0
var _nav_map_rid: RID = RID()


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_path = PackedVector2Array()
		_path_index = 0
		_repath_cooldown = 0.0


func is_enabled() -> bool:
	return _enabled


func set_target_node(node: Node2D) -> void:
	if _target_node == node and is_instance_valid(node):
		_has_target_position = false
		return
	_target_node = node
	_has_target_position = false
	_path = PackedVector2Array()
	_path_index = 0
	_repath_cooldown = 0.0


func set_target_position(pos: Vector2) -> void:
	if _has_target_position and _target_node == null and _target_position.is_equal_approx(pos):
		return
	_target_node = null
	_has_target_position = true
	_target_position = pos
	_path = PackedVector2Array()
	_path_index = 0
	_repath_cooldown = 0.0


func clear_target() -> void:
	_target_node = null
	_has_target_position = false
	_target_position = Vector2.ZERO
	_path = PackedVector2Array()
	_path_index = 0
	_repath_cooldown = 0.0


func has_target() -> bool:
	if is_instance_valid(_target_node):
		return true
	return _has_target_position


func get_target_node() -> Node2D:
	if is_instance_valid(_target_node):
		return _target_node
	return null


## Rotate `current_dir` toward the next waypoint / raw target. Returns the new heading.
func steer(current_dir: Vector2, delta: float) -> Vector2:
	var travel: Vector2 = current_dir
	if travel.length_squared() < 0.0001:
		travel = Vector2.RIGHT
	else:
		travel = travel.normalized()

	if not _enabled or not has_target():
		return travel

	var origin: Vector2 = _owner_global_position()
	var goal: Vector2 = _resolve_goal()
	if goal == Vector2.INF:
		clear_target()
		return travel

	var desired: Vector2 = _desired_heading(origin, goal, delta)
	if desired.length_squared() < 0.0001:
		return travel

	var max_turn: float = maxf(turn_rate, 0.0) * delta
	var angle: float = travel.angle_to(desired)
	if absf(angle) <= max_turn:
		return desired.normalized()
	return travel.rotated(signf(angle) * max_turn).normalized()


func _resolve_goal() -> Vector2:
	if is_instance_valid(_target_node):
		return _target_node.global_position
	if _has_target_position:
		return _target_position
	return Vector2.INF


func _desired_heading(origin: Vector2, goal: Vector2, delta: float) -> Vector2:
	var to_goal: Vector2 = goal - origin
	var dist_sq: float = to_goal.length_squared()
	if dist_sq < 0.0001:
		return Vector2.ZERO

	if (
		not use_pathing
		or dist_sq <= final_approach_distance * final_approach_distance
	):
		return to_goal.normalized()

	_repath_cooldown -= delta
	if _repath_cooldown <= 0.0 or _path.is_empty() or _path_index >= _path.size():
		_repath_cooldown = repath_interval
		_rebuild_path(origin, goal)

	var waypoint: Vector2 = _current_waypoint(origin, goal)
	var to_waypoint: Vector2 = waypoint - origin
	if to_waypoint.length_squared() < 0.0001:
		return to_goal.normalized()
	return to_waypoint.normalized()


func _rebuild_path(origin: Vector2, goal: Vector2) -> void:
	_path = PackedVector2Array()
	_path_index = 0
	var nav_map: RID = _get_nav_map()
	if not nav_map.is_valid():
		return

	var from: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, origin)
	var to: Vector2 = NavigationServer2D.map_get_closest_point(nav_map, goal)
	var path: PackedVector2Array = NavigationServer2D.map_get_path(nav_map, from, to, true)
	if path.is_empty():
		return

	# Drop the first point when it is essentially our current position.
	var start_index: int = 0
	if path.size() >= 2 and origin.distance_squared_to(path[0]) < waypoint_arrive_distance * waypoint_arrive_distance:
		start_index = 1

	_path = PackedVector2Array()
	for i in range(start_index, path.size()):
		_path.append(path[i])
	_path_index = 0


func _current_waypoint(origin: Vector2, goal: Vector2) -> Vector2:
	if _path.is_empty():
		return goal

	var arrive_sq: float = waypoint_arrive_distance * waypoint_arrive_distance
	while _path_index < _path.size() - 1:
		if origin.distance_squared_to(_path[_path_index]) > arrive_sq:
			break
		_path_index += 1

	if _path_index >= _path.size():
		return goal
	return _path[_path_index]


func _get_nav_map() -> RID:
	if _nav_map_rid.is_valid():
		return _nav_map_rid

	var tree: SceneTree = get_tree()
	if tree == null:
		return RID()
	var scene: Node = tree.current_scene
	if scene == null:
		return RID()

	var nav: Node = scene.get_node_or_null("%Navigation")
	if nav == null:
		nav = scene.get_node_or_null("Navigation")
	if nav is NavigationRegion2D:
		_nav_map_rid = (nav as NavigationRegion2D).get_navigation_map()
		return _nav_map_rid
	return RID()


func _owner_global_position() -> Vector2:
	if owner is Node2D:
		return (owner as Node2D).global_position
	if get_parent() is Node2D:
		return (get_parent() as Node2D).global_position
	return global_position
