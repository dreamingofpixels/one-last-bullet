extends Node2D

@export var level_music: AudioStream

@onready var navigation_region: NavigationRegion2D = %Navigation
@onready var player: CharacterBody2D = %Player
@onready var chaos_orb: RigidBody2D = %ChaosOrb
@onready var rebake_timer: Timer = %RebakeTimer
@onready var status_label: Label = %StatusLabel
@onready var enemy_spawner: EnemySpawner = %EnemySpawner

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
	enemy_spawner.wave_started.connect(_on_wave_started)
	enemy_spawner.all_cleared.connect(_on_all_cleared)

	var player_destroy: DestroyComponent = player.COMPONENTS.get(DestroyComponent)
	if player_destroy:
		player_destroy.destroyed.connect(_on_player_died)

	_connect_breakable_destroy_signals()
	await get_tree().physics_frame
	navigation_region.bake_navigation_polygon(true)
	await navigation_region.bake_finished
	enemy_spawner.start()
	player.begin_level(chaos_orb)
	# begin_level emits tethered; keep the opening prompt instead of "Tethered!".
	status_label.text = "Tether to release"


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


func _on_wave_started(wave_index: int, wave_count: int) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Wave %d/%d" % [wave_index + 1, wave_count]


func _on_all_cleared() -> void:
	if _game_over:
		return
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
	enemy_spawner.stop()
	Engine.time_scale = 1.0
	status_label.text = "You died. Press R to restart"
