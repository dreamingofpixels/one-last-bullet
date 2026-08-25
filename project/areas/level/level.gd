extends Node2D

const SHADOW_ORB_SCENE := preload("res://entities/chaos_orb/shadow_orb.tscn")
const POISON_ORB_SCENE := preload("res://entities/chaos_orb/poison_orb.tscn")
const ELECTRIC_ORB_SCENE := preload("res://entities/chaos_orb/electric_orb.tscn")
const MANA_CRYSTAL_SCENE := preload("res://items/mana_crystal.tscn")
const OPENING_ORB_SPEED := 100.0

@export var level_music: AudioStream
## Chance (0–1) that a mana crystal spawns when an enemy dies.
@export var mana_crystal_drop_chance: float = 0.25
## When true, flying orbs bounce off players/enemies; when false, they punch through.
@export var bounce_orbs_off_entities: bool = false

@onready var navigation_region: NavigationRegion2D = %Navigation
@onready var player: CharacterBody2D = %Player
@onready var summoning_circle: SummoningCircle = %SummoningCircle
@onready var items: Node2D = %Items
@onready var rebake_timer: Timer = %RebakeTimer
@onready var status_label: Label = %StatusLabel
@onready var enemy_spawner: EnemySpawner = %EnemySpawner
@onready var time_slow_overlay: TimeSlowOverlay = %TimeSlowOverlay

var _game_over: bool = false
var _cleared: bool = false
var _opening_orbs_spawned: bool = false


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	status_label.text = "Assemble..."
	ChaosOrb.set_bounce_off_entities(bounce_orbs_off_entities)

	if level_music:
		AudioManager.play_music(level_music)

	rebake_timer.timeout.connect(_on_rebake_timer_timeout)
	enemy_spawner.wave_started.connect(_on_wave_started)
	enemy_spawner.all_cleared.connect(_on_all_cleared)
	enemy_spawner.enemy_died.connect(_on_enemy_died)

	var player_destroy: DestroyComponent = player.COMPONENTS.get(DestroyComponent)
	if player_destroy:
		player_destroy.destroyed.connect(_on_player_died)

	_connect_breakable_destroy_signals()
	await get_tree().physics_frame
	navigation_region.bake_navigation_polygon(true)
	await navigation_region.bake_finished
	await _await_navigation_ready()
	enemy_spawner.start()
	await player.begin_level()
	_launch_opening_orbs()
	status_label.text = "Clear the room"


func _connect_orb_signals(orb: RigidBody2D) -> void:
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


func _launch_opening_orbs() -> void:
	if _opening_orbs_spawned:
		return
	_opening_orbs_spawned = true

	var origin: Vector2 = summoning_circle.get_launch_origin()
	var scenes: Array[PackedScene] = [
		SHADOW_ORB_SCENE,
		POISON_ORB_SCENE,
		ELECTRIC_ORB_SCENE,
	]
	for scene in scenes:
		var orb: RigidBody2D = scene.instantiate() as RigidBody2D
		add_child(orb)
		orb.global_position = origin
		orb.speed = OPENING_ORB_SPEED
		_connect_orb_signals(orb)
		orb.begin_flight(Vector2.from_angle(randf() * TAU), player)


func _on_enemy_died(enemy: Node = null) -> void:
	if _game_over or _cleared:
		return
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
		return
	# Capture before any further teardown; drop roll after so position is never wasted work on a miss.
	var drop_pos: Vector2 = (enemy as Node2D).global_position
	if randf() > mana_crystal_drop_chance:
		return

	var crystal: ManaCrystal = MANA_CRYSTAL_SCENE.instantiate() as ManaCrystal
	items.add_child(crystal)
	crystal.global_position = drop_pos


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
	_drop_carried_crystal_on_death()


func _drop_carried_crystal_on_death() -> void:
	if not player.has_method("get_carried_crystal"):
		return
	var crystal: ManaCrystal = player.get_carried_crystal()
	if crystal == null or not is_instance_valid(crystal):
		return
	var drop_pos: Vector2 = player.global_position
	if not crystal.throw_toward(Vector2.DOWN, items):
		return
	player.clear_carried_crystal(crystal)
	crystal.global_position = drop_pos
	crystal.linear_velocity = Vector2.ZERO
	crystal.settle_on_ground()
