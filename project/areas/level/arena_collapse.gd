class_name ArenaCollapse
extends Node2D

## Clockwise Bomberman-style arena shrink: red telegraph, then seal as world|wall.
## Orbs and enemies are pushed inward; players caught in a seal die. Orbs never die.

signal cell_sealed(cell_rect: Rect2)

const ARENA_WIDTH := 640.0
const ARENA_HEIGHT := 360.0
const CELL_SIZE := 32.0
const COLS := 20
## Rows 0–9 are 32 px; row 10 is 40 px so the 360-tall arena has no leftover strip.
const ROWS := 11
const LAST_ROW_HEIGHT := 40.0
const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_WALL := 16
const SEAL_COLLISION_LAYER := PHYSICS_LAYER_WORLD | PHYSICS_LAYER_WALL
const PUSH_MARGIN := 10.0
const WARNING_COLOR := Color(1.0, 0.15, 0.1, 0.45)
const SEALED_COLOR := Color(0.0, 0.0, 0.0, 1.0)

@export var start_delay_seconds: float = 0.0
@export var telegraph_seconds: float = 1.0
@export var step_seconds: float = 3.0
@export var lap_count: int = 3

@onready var rebake_timer: Timer = %RebakeTimer

var _running: bool = false
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _warning_poly: Polygon2D
var _seals: Array[Node2D] = []
var _run_token: int = 0


func start() -> void:
	stop_and_restore()
	_path = _build_spiral_path(lap_count)
	if _path.is_empty():
		return
	_running = true
	_path_index = 0
	_run_token += 1
	var token: int = _run_token
	_run_collapse(token)


func stop_and_restore() -> void:
	_running = false
	_run_token += 1
	_clear_warning()
	_free_all_seals()
	if rebake_timer != null and is_instance_valid(rebake_timer):
		rebake_timer.start()


func _run_collapse(token: int) -> void:
	if start_delay_seconds > 0.0:
		await get_tree().create_timer(start_delay_seconds).timeout
		if token != _run_token or not _running:
			return

	var wait_after_seal: float = maxf(0.0, step_seconds - telegraph_seconds)
	while _running and token == _run_token and _path_index < _path.size():
		var cell: Vector2i = _path[_path_index]
		var cell_rect: Rect2 = _cell_rect(cell)
		_show_warning(cell_rect)
		await get_tree().create_timer(telegraph_seconds).timeout
		if token != _run_token or not _running:
			return
		_clear_warning()
		_seal_cell(cell, cell_rect)
		_path_index += 1
		if wait_after_seal > 0.0 and _path_index < _path.size():
			await get_tree().create_timer(wait_after_seal).timeout
			if token != _run_token or not _running:
				return

	_running = false


func _build_spiral_path(laps: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for lap in laps:
		var left: int = lap
		var right: int = COLS - 1 - lap
		var top: int = lap
		var bottom: int = ROWS - 1 - lap
		if left > right or top > bottom:
			break

		# Top edge, left → right.
		for c in range(left, right + 1):
			path.append(Vector2i(c, top))
		# Right edge, top+1 → bottom.
		for r in range(top + 1, bottom + 1):
			path.append(Vector2i(right, r))
		# Bottom edge, right-1 → left (skip if single-row ring).
		if bottom > top:
			for c in range(right - 1, left - 1, -1):
				path.append(Vector2i(c, bottom))
		# Left edge, bottom-1 → top+1 (skip if single-column ring).
		if left < right:
			for r in range(bottom - 1, top, -1):
				path.append(Vector2i(left, r))
	return path


func _cell_rect(cell: Vector2i) -> Rect2:
	var x: float = float(cell.x) * CELL_SIZE
	var y: float
	var h: float
	if cell.y >= ROWS - 1:
		y = float(ROWS - 1) * CELL_SIZE
		h = LAST_ROW_HEIGHT
	else:
		y = float(cell.y) * CELL_SIZE
		h = CELL_SIZE
	return Rect2(x, y, CELL_SIZE, h)


func _show_warning(cell_rect: Rect2) -> void:
	_clear_warning()
	_warning_poly = Polygon2D.new()
	_warning_poly.color = WARNING_COLOR
	_warning_poly.polygon = PackedVector2Array([
		cell_rect.position,
		Vector2(cell_rect.end.x, cell_rect.position.y),
		cell_rect.end,
		Vector2(cell_rect.position.x, cell_rect.end.y),
	])
	add_child(_warning_poly)


func _clear_warning() -> void:
	if _warning_poly != null and is_instance_valid(_warning_poly):
		_warning_poly.queue_free()
	_warning_poly = null


func _seal_cell(cell: Vector2i, cell_rect: Rect2) -> void:
	_resolve_occupants(cell_rect)

	var seal_root := Node2D.new()
	seal_root.name = "Seal_%d_%d" % [cell.x, cell.y]
	seal_root.position = cell_rect.position
	add_child(seal_root)

	var body := StaticBody2D.new()
	body.collision_layer = SEAL_COLLISION_LAYER
	body.collision_mask = 0
	body.add_to_group("navigation_source")
	seal_root.add_child(body)

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = cell_rect.size
	shape.shape = rect_shape
	shape.position = cell_rect.size * 0.5
	body.add_child(shape)

	var fill := Polygon2D.new()
	fill.color = SEALED_COLOR
	fill.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(cell_rect.size.x, 0.0),
		cell_rect.size,
		Vector2(0.0, cell_rect.size.y),
	])
	seal_root.add_child(fill)

	_seals.append(seal_root)
	if rebake_timer != null and is_instance_valid(rebake_timer):
		rebake_timer.start()
	cell_sealed.emit(cell_rect)


func _free_all_seals() -> void:
	for seal in _seals:
		if seal != null and is_instance_valid(seal):
			seal.queue_free()
	_seals.clear()


func _resolve_occupants(cell_rect: Rect2) -> void:
	_kill_players_in_cell(cell_rect)
	_push_orbs_in_cell(cell_rect)
	_push_enemies_in_cell(cell_rect)
	_destroy_breakables_in_cell(cell_rect)
	_free_glyphs_in_cell(cell_rect)
	_free_earth_spikes_in_cell(cell_rect)


func _kill_players_in_cell(cell_rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		var player: Node2D = node as Node2D
		if not cell_rect.has_point(player.global_position):
			continue
		_destroy_via_component(player)


func _push_orbs_in_cell(cell_rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("orb"):
		if node == null or not is_instance_valid(node) or not (node is BlankOrb):
			continue
		var orb: BlankOrb = node as BlankOrb
		# Possessed + circle-captured stay put; flying / vault / parked get shoved.
		if orb.is_possessed():
			continue
		if not orb.is_flying() and not orb.is_tethered():
			continue
		if not cell_rect.has_point(orb.global_position):
			continue
		var safe_pos: Vector2 = _push_out_of_cell(orb.global_position, cell_rect)
		_set_rigid_position(orb, safe_pos)


func _push_enemies_in_cell(cell_rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy: Node2D = node as Node2D
		if not cell_rect.has_point(enemy.global_position):
			continue
		enemy.global_position = _push_out_of_cell(enemy.global_position, cell_rect)


func _destroy_breakables_in_cell(cell_rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("breakables"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		var breakable: Node2D = node as Node2D
		if not cell_rect.has_point(breakable.global_position):
			continue
		_destroy_via_component(breakable)


func _free_glyphs_in_cell(cell_rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("glyphs"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		var glyph: Node2D = node as Node2D
		if not cell_rect.has_point(glyph.global_position):
			continue
		glyph.queue_free()


func _free_earth_spikes_in_cell(cell_rect: Rect2) -> void:
	var y_sort: Node = get_node_or_null("%WorldYSort")
	if y_sort == null:
		return
	for child in y_sort.get_children():
		if child is EarthSpike and cell_rect.has_point((child as Node2D).global_position):
			(child as Node).queue_free()


func _destroy_via_component(node: Node) -> void:
	var components = node.get("COMPONENTS")
	if components is Dictionary:
		var dict: Dictionary = components as Dictionary
		# Floor seals are not orb kills — clear so glyph_drop does not credit a prior hit.
		var health: HealthComponent = dict.get(HealthComponent) as HealthComponent
		if health != null:
			health.last_damage_source = null
		var destroy: DestroyComponent = dict.get(DestroyComponent) as DestroyComponent
		if destroy != null:
			destroy.self_destroy()
			return
	node.queue_free()


func _push_out_of_cell(pos: Vector2, cell: Rect2) -> Vector2:
	if not cell.has_point(pos):
		return pos
	var arena_center := Vector2(ARENA_WIDTH * 0.5, ARENA_HEIGHT * 0.5)
	var to_center: Vector2 = arena_center - cell.get_center()
	var dir: Vector2
	if absf(to_center.x) >= absf(to_center.y):
		dir = Vector2(signf(to_center.x), 0.0)
	else:
		dir = Vector2(0.0, signf(to_center.y))
	if dir.length_squared() < 0.0001:
		dir = Vector2.DOWN

	var result: Vector2 = pos
	if dir.x > 0.0:
		result.x = cell.end.x + PUSH_MARGIN
	elif dir.x < 0.0:
		result.x = cell.position.x - PUSH_MARGIN
	if dir.y > 0.0:
		result.y = cell.end.y + PUSH_MARGIN
	elif dir.y < 0.0:
		result.y = cell.position.y - PUSH_MARGIN
	result.x = clampf(result.x, 0.0, ARENA_WIDTH)
	result.y = clampf(result.y, 0.0, ARENA_HEIGHT)
	return result


func _set_rigid_position(body: RigidBody2D, pos: Vector2) -> void:
	var xform := Transform2D(body.global_rotation, pos)
	PhysicsServer2D.body_set_state(
		body.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM,
		xform
	)
	body.global_position = pos
