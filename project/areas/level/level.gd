extends Node2D

const CHAOS_ORB_SCENE := preload("res://entities/chaos_orb/chaos_orb.tscn")

@export var level_music: AudioStream
## Half-angle of the opening release fan (degrees). Extra orbs fly at ± this from the launch tangent.
@export var opening_volley_spread_degrees: float = 20.0

@onready var navigation_region: NavigationRegion2D = %Navigation
@onready var player: CharacterBody2D = %Player
@onready var chaos_orb: RigidBody2D = %ChaosOrb
@onready var rebake_timer: Timer = %RebakeTimer
@onready var status_label: Label = %StatusLabel
@onready var enemy_spawner: EnemySpawner = %EnemySpawner
@onready var time_slow_overlay: TimeSlowOverlay = %TimeSlowOverlay

var _game_over: bool = false
var _cleared: bool = false
var _opening_volley_spawned: bool = false


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	status_label.text = "Tether to release"

	if level_music:
		AudioManager.play_music(level_music)

	_connect_orb_signals(chaos_orb, true)
	rebake_timer.timeout.connect(_on_rebake_timer_timeout)
	enemy_spawner.wave_started.connect(_on_wave_started)
	enemy_spawner.all_cleared.connect(_on_all_cleared)

	var player_destroy: DestroyComponent = player.COMPONENTS.get(DestroyComponent)
	if player_destroy:
		player_destroy.destroyed.connect(_on_player_died)

	_connect_breakable_destroy_signals()
	await get_tree().physics_frame
	navigation_region.bake_navigation_polygon(true)
	await navigation_region.bake_finished
	await _await_navigation_ready()
	enemy_spawner.start()
	await player.begin_level(chaos_orb)
	# begin_level emits tethered; keep the opening prompt instead of "Tethered!".
	status_label.text = "Tether to release"


func _connect_orb_signals(orb: RigidBody2D, include_launched: bool) -> void:
	if include_launched and not orb.launched.is_connected(_on_orb_launched):
		orb.launched.connect(_on_orb_launched)
	if not orb.deflected.is_connected(_on_orb_deflected):
		orb.deflected.connect(_on_orb_deflected)
	if not orb.tethered.is_connected(_on_orb_tethered):
		orb.tethered.connect(_on_orb_tethered)
	if not orb.tether_released.is_connected(_on_orb_tether_released):
		orb.tether_released.connect(_on_orb_tether_released)


func _await_navigation_ready() -> void:
	var probe := Vector2(320.0, 180.0)
	for _attempt in 20:
		var nav_map := navigation_region.get_navigation_map()
		var from := NavigationServer2D.map_get_closest_point(nav_map, probe)
		var to := NavigationServer2D.map_get_closest_point(nav_map, player.global_position)
		if from.distance_squared_to(Vector2.ZERO) > 1.0 and to.distance_squared_to(Vector2.ZERO) > 1.0:
			var path := NavigationServer2D.map_get_path(nav_map, from, to, true)
			if path.size() >= 2:
				return
		await get_tree().physics_frame


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


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
	time_slow_overlay.end()
	_spawn_opening_volley()


func _spawn_opening_volley() -> void:
	if _opening_volley_spawned:
		return
	_opening_volley_spawned = true
	if not chaos_orb.has_method("begin_flight"):
		return

	var launch_dir: Vector2 = chaos_orb.aim_direction
	if launch_dir.length_squared() < 0.0001:
		launch_dir = Vector2.UP
	else:
		launch_dir = launch_dir.normalized()

	var spread_rad: float = deg_to_rad(opening_volley_spread_degrees)
	var source_damage: float = 0.0
	var source_components = chaos_orb.get("COMPONENTS")
	if source_components is Dictionary and source_components.has(DamageComponent):
		source_damage = (source_components[DamageComponent] as DamageComponent).damage

	for sign_f in [-1.0, 1.0]:
		var extra: RigidBody2D = CHAOS_ORB_SCENE.instantiate() as RigidBody2D
		add_child(extra)
		extra.global_position = chaos_orb.global_position
		extra.speed = chaos_orb.speed
		if source_damage > 0.0:
			var extra_components = extra.get("COMPONENTS")
			if extra_components is Dictionary and extra_components.has(DamageComponent):
				(extra_components[DamageComponent] as DamageComponent).damage = source_damage
		_connect_orb_signals(extra, false)
		extra.begin_flight(launch_dir.rotated(spread_rad * sign_f), player)


func _on_orb_deflected(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Redirected!"


func _on_orb_tethered(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Tethered!"
	time_slow_overlay.begin()


func _on_orb_tether_released(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Released!"
	time_slow_overlay.end()


func _on_wave_started(wave_index: int, wave_count: int) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Wave %d/%d" % [wave_index + 1, wave_count]


func _on_all_cleared() -> void:
	if _game_over:
		return
	_cleared = true
	time_slow_overlay.end()
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
	enemy_spawner.stop()
	time_slow_overlay.end()
	status_label.text = "You died. Press R to restart"
