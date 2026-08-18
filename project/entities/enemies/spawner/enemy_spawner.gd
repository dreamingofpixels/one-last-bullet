class_name EnemySpawner
extends Node2D

signal wave_started(wave_index: int, wave_count: int)
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node)
signal all_cleared

const SPAWN_NAV_TOLERANCE := 8.0

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

	var saved_layer := enemy.collision_layer
	var saved_mask := enemy.collision_mask
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.collision_layer = 0
	enemy.collision_mask = 0

	var spawn_position := _pick_spawn_position()
	enemies.add_child(enemy)
	enemy.global_position = spawn_position

	_pending = maxi(0, _pending - 1)
	_alive += 1

	var destroy_comp: DestroyComponent = enemy.COMPONENTS.get(DestroyComponent)
	if destroy_comp:
		destroy_comp.destroyed.connect(_on_enemy_destroyed)
		if destroy_comp.sprite:
			destroy_comp.sprite.visible = false

	var hitbox: HitboxComponent = enemy.COMPONENTS.get(HitboxComponent)
	if hitbox:
		hitbox.monitoring = false
		hitbox.set_invulnerable(true)

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

	enemy.collision_layer = saved_layer
	enemy.collision_mask = saved_mask
	if hitbox:
		hitbox.set_invulnerable(false)
		hitbox.monitoring = true
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	enemy_spawned.emit(enemy)


func _pick_spawn_position() -> Vector2:
	var player_nav_position := _closest_nav_point(player.global_position)
	var occupied := _occupied_positions()
	var fallback_nav: Variant = null

	for _attempt in 40:
		var pos := Vector2(
			randf_range(play_rect.position.x, play_rect.end.x),
			randf_range(play_rect.position.y, play_rect.end.y)
		)
		if pos.distance_to(player.global_position) < min_spawn_distance:
			continue

		var nav_pos: Variant = _validated_spawn_position(pos, player_nav_position)
		if nav_pos == null:
			continue
		if fallback_nav == null:
			fallback_nav = nav_pos
		if _is_separated(nav_pos, occupied):
			return nav_pos

	if fallback_nav != null:
		return fallback_nav

	var corner := Vector2(play_rect.position.x + 40.0, play_rect.position.y + 40.0)
	var corner_nav: Variant = _validated_spawn_position(corner, player_nav_position)
	return corner_nav if corner_nav != null else player_nav_position


func _validated_spawn_position(candidate: Vector2, player_nav_position: Vector2) -> Variant:
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

	return nav_position


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
