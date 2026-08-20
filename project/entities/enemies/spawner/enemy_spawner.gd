class_name EnemySpawner
extends Node2D

signal wave_started(wave_index: int, wave_count: int)
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)
signal all_cleared

const SPAWN_NAV_TOLERANCE := 8.0
const PHYSICS_LAYER_WORLD := 1
const SPAWN_PHYSICS_MARGIN := 2.0
const SEPARATE_STEP_PX := 2.0
const SEPARATE_MAX_PUSH_PX := 16.0
const SEPARATE_MAX_ITERS := 8

@export var waves: Array[EnemyWave] = []
@export var assemble_duration: float = 2.0
@export var telegraph_duration: float = 0.6
@export var min_spawn_distance: float = 120.0
@export var min_spawn_separation: float = 48.0
@export var play_rect: Rect2 = Rect2(24.0, 24.0, 592.0, 312.0)

@onready var player: CharacterBody2D = owner.get_node("%Player")
@onready var navigation_region: NavigationRegion2D = owner.get_node("%Navigation")
@onready var enemies: Node2D = owner.get_node("%Enemies")

var _pending: int = 0
var _alive: int = 0
var _waves_issued: int = 0
var _stopped: bool = false
var _cleared: bool = false


func start() -> void:
	_stopped = false
	_cleared = false
	_pending = _count_planned()
	_alive = 0
	_waves_issued = 0
	if _pending <= 0:
		_waves_issued = waves.size()
		_try_clear()
		return

	for wave_index in waves.size():
		if _stopped:
			return
		var wave := waves[wave_index]
		if wave != null and wave.delay_before > 0.0:
			await get_tree().create_timer(wave.delay_before).timeout
			if _stopped:
				return
		_waves_issued += 1
		wave_started.emit(wave_index, waves.size())
		if wave != null:
			_issue_wave(wave)
		_try_clear()


func stop() -> void:
	_stopped = true


func _count_planned() -> int:
	var total := 0
	for wave in waves:
		if wave == null:
			continue
		for entry in wave.entries:
			if entry == null or entry.enemy_scene == null:
				continue
			total += maxi(entry.count, 0)
	return total


func _issue_wave(wave: EnemyWave) -> void:
	for entry in wave.entries:
		if entry == null or entry.enemy_scene == null:
			continue
		for _i in maxi(entry.count, 0):
			_spawn_one(entry.enemy_scene)


func _spawn_one(scene: PackedScene) -> void:
	if _stopped:
		return

	var enemy := scene.instantiate() as CharacterBody2D
	if enemy == null:
		_pending = maxi(0, _pending - 1)
		_try_clear()
		return

	var collision_shape := _get_body_collision_shape(enemy)
	var spawn_position := _pick_spawn_position(collision_shape)
	enemies.add_child(enemy)
	enemy.global_position = spawn_position

	_pending = maxi(0, _pending - 1)
	_alive += 1

	var destroy_comp: DestroyComponent = enemy.COMPONENTS.get(DestroyComponent)
	if destroy_comp:
		destroy_comp.destroyed.connect(_on_enemy_destroyed)
		if destroy_comp.sprite:
			destroy_comp.sprite.visible = false

	_set_spawn_inert(enemy, true)

	SpawnTelegraphEffect.play(self, spawn_position, telegraph_duration, assemble_duration)

	if telegraph_duration > 0.0:
		await get_tree().create_timer(telegraph_duration).timeout

	if _stopped or not is_instance_valid(enemy):
		return

	if destroy_comp and is_instance_valid(destroy_comp.sprite):
		await DestructionEffect.play_assemble_from_sprite(destroy_comp.sprite, assemble_duration)

	if _stopped or not is_instance_valid(enemy):
		return

	if destroy_comp and is_instance_valid(destroy_comp.sprite):
		destroy_comp.sprite.visible = true

	_set_spawn_inert(enemy, false)
	_depenetrate_enemy_from_world(enemy)
	enemy_spawned.emit(enemy)


func _set_spawn_inert(enemy: CharacterBody2D, inert: bool) -> void:
	for child in enemy.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = inert

	var hitbox: HitboxComponent = enemy.COMPONENTS.get(HitboxComponent)
	if hitbox:
		hitbox.monitoring = not inert
		hitbox.set_invulnerable(inert)
		for shape in hitbox.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).disabled = inert

	var navigation: NavigationComponent = enemy.COMPONENTS.get(NavigationComponent)
	if navigation:
		navigation.set_chasing(not inert)


func _pick_spawn_position(collision_shape: CollisionShape2D) -> Vector2:
	var player_nav_position := _closest_nav_point(player.global_position)
	var occupied := _occupied_positions()

	for _attempt in 80:
		var pos := Vector2(
			randf_range(play_rect.position.x, play_rect.end.x),
			randf_range(play_rect.position.y, play_rect.end.y)
		)
		if pos.distance_to(player.global_position) < min_spawn_distance:
			continue

		var nav_pos: Variant = _validated_spawn_position(pos, player_nav_position, collision_shape)
		if nav_pos != null and _is_separated(nav_pos, occupied):
			return nav_pos

	for candidate in _fallback_candidates():
		var nav_pos: Variant = _validated_spawn_position(candidate, player_nav_position, collision_shape)
		if nav_pos != null and _is_separated(nav_pos, occupied):
			return nav_pos

	for candidate in _fallback_candidates():
		var nav_pos: Variant = _validated_spawn_position(candidate, player_nav_position, collision_shape)
		if nav_pos != null:
			return nav_pos

	if _is_physics_clear(player_nav_position, collision_shape):
		return player_nav_position
	return player_nav_position


func _fallback_candidates() -> Array[Vector2]:
	var inset := 40.0
	return [
		play_rect.get_center(),
		Vector2(play_rect.position.x + inset, play_rect.position.y + inset),
		Vector2(play_rect.end.x - inset, play_rect.position.y + inset),
		Vector2(play_rect.position.x + inset, play_rect.end.y - inset),
		Vector2(play_rect.end.x - inset, play_rect.end.y - inset),
	]


func _validated_spawn_position(
	candidate: Vector2,
	player_nav_position: Vector2,
	collision_shape: CollisionShape2D
) -> Variant:
	var nav_position := _closest_nav_point(candidate)
	if nav_position.distance_to(candidate) > SPAWN_NAV_TOLERANCE:
		return null
	if nav_position.distance_to(player_nav_position) < min_spawn_distance:
		return null

	var path := NavigationServer2D.map_get_path(
		navigation_region.get_navigation_map(),
		nav_position,
		player_nav_position,
		true
	)
	if path.size() < 2:
		return null
	if not _is_physics_clear(nav_position, collision_shape):
		return null

	return nav_position


func _get_body_collision_shape(enemy: CharacterBody2D) -> CollisionShape2D:
	for child in enemy.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null


func _is_physics_clear(pos: Vector2, collision_shape: CollisionShape2D) -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return true
	var query_shape := _spawn_query_shape(collision_shape.shape)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = query_shape
	params.transform = Transform2D(0.0, pos + collision_shape.position)
	params.collision_mask = PHYSICS_LAYER_WORLD
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


func _spawn_query_shape(base_shape: Shape2D) -> Shape2D:
	if base_shape is CircleShape2D:
		var source_circle := base_shape as CircleShape2D
		var expanded_circle := CircleShape2D.new()
		expanded_circle.radius = source_circle.radius + SPAWN_PHYSICS_MARGIN
		return expanded_circle
	return base_shape


func _depenetrate_enemy_from_world(enemy: CharacterBody2D) -> void:
	var collision_shape := _get_body_collision_shape(enemy)
	if collision_shape == null or collision_shape.shape == null:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var pushed: float = 0.0

	for _i in SEPARATE_MAX_ITERS:
		if pushed >= SEPARATE_MAX_PUSH_PX:
			return
		var params := PhysicsShapeQueryParameters2D.new()
		params.shape = collision_shape.shape
		params.transform = Transform2D(0.0, enemy.global_position + collision_shape.position)
		params.collision_mask = PHYSICS_LAYER_WORLD
		params.collide_with_bodies = true
		params.collide_with_areas = false
		params.exclude = [enemy.get_rid()]
		var overlaps: Array[Dictionary] = space.intersect_shape(params, 4)
		if overlaps.is_empty():
			return

		var escape: Vector2 = Vector2.ZERO
		var rest: Dictionary = space.get_rest_info(params)
		if not rest.is_empty():
			escape = rest.get("normal", Vector2.ZERO)
		if escape.length_squared() < 0.0001:
			var collider: Object = overlaps[0].get("collider")
			if collider is Node2D:
				var from_collider: Vector2 = enemy.global_position - (collider as Node2D).global_position
				if from_collider.length_squared() > 0.0001:
					escape = from_collider.normalized()
		if escape.length_squared() < 0.0001:
			escape = Vector2.UP
		escape = escape.normalized()

		var step_px: float = minf(SEPARATE_STEP_PX, SEPARATE_MAX_PUSH_PX - pushed)
		enemy.global_position += escape * step_px
		pushed += step_px


func _closest_nav_point(point: Vector2) -> Vector2:
	return NavigationServer2D.map_get_closest_point(navigation_region.get_navigation_map(), point)


func _occupied_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for child in enemies.get_children():
		if child is Node2D:
			result.append((child as Node2D).global_position)
	return result


func _is_separated(pos: Vector2, occupied: Array[Vector2]) -> bool:
	for other in occupied:
		if pos.distance_to(other) < min_spawn_separation:
			return false
	return true


func _on_enemy_destroyed(node: Node = null) -> void:
	_alive = maxi(0, _alive - 1)
	enemy_died.emit(node)
	_try_clear()


func _try_clear() -> void:
	if _stopped or _cleared:
		return
	if _waves_issued < waves.size():
		return
	if _pending > 0 or _alive > 0:
		return
	_cleared = true
	all_cleared.emit()
