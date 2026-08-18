extends Node2D

const GRUNT_SCENE := preload("res://entities/enemies/grunt/grunt_knife.tscn")
const BRUTE_SCENE := preload("res://entities/enemies/brute/brute.tscn")
const ENEMY_COUNT := 3
const MIN_SPAWN_DISTANCE := 120.0
const PLAY_RECT := Rect2(24.0, 24.0, 592.0, 312.0)
const SPAWN_NAV_TOLERANCE := 8.0

@export var level_music: AudioStream

@onready var navigation_region: NavigationRegion2D = %Navigation
@onready var player: CharacterBody2D = %Player
@onready var enemies: Node2D = %Enemies
@onready var chaos_orb: RigidBody2D = %ChaosOrb
@onready var rebake_timer: Timer = %RebakeTimer
@onready var status_label: Label = %StatusLabel

var _enemies_alive: int = 0
var _game_over: bool = false
var _cleared: bool = false


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	status_label.text = "Tether to release"

	if level_music:
		AudioManager.play_music(level_music)

	chaos_orb.launched.connect(_on_orb_launched)
	chaos_orb.deflected.connect(_on_orb_deflected)
	chaos_orb.tethered.connect(_on_orb_tethered)
	chaos_orb.tether_released.connect(_on_orb_tether_released)
	rebake_timer.timeout.connect(_on_rebake_timer_timeout)

	var player_destroy: DestroyComponent = player.COMPONENTS.get(DestroyComponent)
	if player_destroy:
		player_destroy.destroyed.connect(_on_player_died)

	_connect_breakable_destroy_signals()
	await get_tree().physics_frame
	navigation_region.bake_navigation_polygon(true)
	await navigation_region.bake_finished
	_spawn_enemies()
	player.begin_level(chaos_orb)
	# begin_level emits tethered; keep the opening prompt instead of "Tethered!".
	status_label.text = "Tether to release"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _spawn_enemies() -> void:
	_enemies_alive = 0
	for i in ENEMY_COUNT:
		_spawn_enemy(GRUNT_SCENE)
	_spawn_enemy(BRUTE_SCENE)


func _spawn_enemy(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as CharacterBody2D
	enemies.add_child(enemy)
	enemy.global_position = _pick_spawn_position()
	# Connect destroy_component.destroyed (emitted after death FX starts).
	var destroy_comp: DestroyComponent = enemy.COMPONENTS.get(DestroyComponent)
	if destroy_comp:
		destroy_comp.destroyed.connect(_on_enemy_died.bind())
	_enemies_alive += 1


func _pick_spawn_position() -> Vector2:
	var player_nav_position := _closest_nav_point(player.global_position)
	for _attempt in 40:
		var pos := Vector2(
			randf_range(PLAY_RECT.position.x, PLAY_RECT.end.x),
			randf_range(PLAY_RECT.position.y, PLAY_RECT.end.y)
		)
		if pos.distance_to(player.global_position) < MIN_SPAWN_DISTANCE:
			continue

		var nav_pos: Variant = _validated_spawn_position(pos, player_nav_position)
		if nav_pos != null:
			return nav_pos

	var fallback := Vector2(PLAY_RECT.position.x + 40.0, PLAY_RECT.position.y + 40.0)
	var fallback_nav_position: Variant = _validated_spawn_position(fallback, player_nav_position)
	return fallback_nav_position if fallback_nav_position != null else player_nav_position


func _validated_spawn_position(candidate: Vector2, player_nav_position: Vector2) -> Variant:
	var nav_position := _closest_nav_point(candidate)
	if nav_position.distance_to(candidate) > SPAWN_NAV_TOLERANCE:
		return null
	if nav_position.distance_to(player_nav_position) < MIN_SPAWN_DISTANCE:
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


func _connect_breakable_destroy_signals() -> void:
	for breakable in get_tree().get_nodes_in_group("breakables"):
		var breakable_node := breakable as Node
		if breakable_node == null or not breakable_node.has_method("get"):
			continue
		var components: Dictionary = breakable_node.get("COMPONENTS")
		var destroy_component: DestroyComponent = components.get(DestroyComponent)
		if destroy_component and not destroy_component.destroyed.is_connected(_on_breakable_destroyed):
			destroy_component.destroyed.connect(_on_breakable_destroyed)


func _on_orb_launched() -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Clear the room"


func _on_orb_deflected(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Deflected!"


func _on_orb_tethered(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Tethered!"


func _on_orb_tether_released(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Released!"


func _on_enemy_died(_node: Node = null) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	if _enemies_alive <= 0 and not _game_over:
		_cleared = true
		Engine.time_scale = 1.0
		status_label.text = "Cleared! Press R to restart"


func _on_breakable_destroyed(_node: Node = null) -> void:
	rebake_timer.start()


func _on_rebake_timer_timeout() -> void:
	if navigation_region.is_baking():
		rebake_timer.start()
		return
	navigation_region.bake_navigation_polygon(true)


func _on_player_died(_node: Node = null) -> void:
	if _cleared:
		return
	_game_over = true
	Engine.time_scale = 1.0
	status_label.text = "You died. Press R to restart"
