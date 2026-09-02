extends Node2D

const GHOST_ORB_SCENE := preload("res://entities/orbs/ghost/ghost_orb.tscn")
const ROT_ORB_SCENE := preload("res://entities/orbs/rot/rot_orb.tscn")
const CONDUIT_ORB_SCENE := preload("res://entities/orbs/conduit/conduit_orb.tscn")
const GLYPH_SCENE := preload("res://items/glyph/glyph.tscn")
const BLANK_ORB_SCENE := preload("res://entities/orbs/blank/blank_orb.tscn")
const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const MAX_PLAYERS := 2
## Shared i-frames for all living players when the opening volley launches (P2 has no orb instigator grace).
const OPENING_PLAYER_INVULN_SECONDS := 1.0
const PHYSICS_LAYER_WORLD := 1
const P2_SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(40.0, 0.0),
	Vector2(-40.0, 0.0),
	Vector2(0.0, -40.0),
	Vector2(40.0, -40.0),
	Vector2(-40.0, -40.0),
	Vector2(56.0, 0.0),
	Vector2(-56.0, 0.0),
]

@export var level_music: AudioStream
## Chance (0–1) that a glyph spawns when an enemy dies (fallback when killer has no glyph_drop).
@export var glyph_drop_chance: float = 0.25
@export var glyph_rarity_weight_common: float = 70.0
@export var glyph_rarity_weight_rare: float = 25.0
@export var glyph_rarity_weight_unique: float = 5.0
@export var new_orb_cost: float = 20.0
## When true, flying orbs bounce off players/enemies; when false, they punch through.
@export var bounce_orbs_off_entities: bool = false

@onready var navigation_region: NavigationRegion2D = %Navigation
@onready var players_root: Node2D = %Players
@onready var player: CharacterBody2D = %Player1
@onready var summoning_circle: SummoningCircle = %SummoningCircle
@onready var items: Node2D = %Items
@onready var rebake_timer: Timer = %RebakeTimer
@onready var status_label: Label = %StatusLabel
@onready var enemy_spawner: EnemySpawner = %EnemySpawner
@onready var time_slow_overlay: TimeSlowOverlay = %TimeSlowOverlay
@onready var ritual_menu: RitualMenu = %RitualMenu

var _game_over: bool = false
var _cleared: bool = false
var _opening_orbs_spawned: bool = false
var _level_intro_done: bool = false
var _p2_spawn_shape: CircleShape2D


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	status_label.text = "Assemble..."
	BlankOrb.set_bounce_off_entities(bounce_orbs_off_entities)

	if level_music:
		AudioManager.play_music(level_music)

	rebake_timer.timeout.connect(_on_rebake_timer_timeout)
	enemy_spawner.wave_started.connect(_on_wave_started)
	enemy_spawner.all_cleared.connect(_on_all_cleared)
	enemy_spawner.enemy_died.connect(_on_enemy_died)

	_connect_player_destroy(player)
	_connect_breakable_destroy_signals()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	summoning_circle.ritual_started.connect(_on_ritual_started)
	ritual_menu.closed.connect(_on_ritual_menu_closed)
	ritual_menu.new_blank_orb_requested.connect(_on_new_blank_orb_requested)

	await get_tree().physics_frame
	# P2 is instanced as soon as a second pad is already connected — no join button.
	_try_add_player_2()
	navigation_region.bake_navigation_polygon(true)
	await navigation_region.bake_finished
	await _await_navigation_ready()
	enemy_spawner.start()
	await _assemble_all_players()
	_level_intro_done = true
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


func _connect_player_destroy(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	var components = p.get("COMPONENTS")
	if components == null:
		return
	var player_destroy: DestroyComponent = components.get(DestroyComponent)
	if player_destroy and not player_destroy.destroyed.is_connected(_on_player_died):
		player_destroy.destroyed.connect(_on_player_died)


func _has_second_controller() -> bool:
	return Input.get_connected_joypads().size() >= 2


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected or not _has_second_controller():
		return
	var p2: CharacterBody2D = _try_add_player_2()
	if p2 == null:
		return
	# Hot-join after intro: assemble the new player. During intro they are already in the roster.
	if _level_intro_done:
		await p2.begin_level()
		if not _game_over and not _cleared:
			status_label.text = "Clear the room"


func _try_add_player_2() -> CharacterBody2D:
	if _game_over or _cleared:
		return null
	if not _has_second_controller():
		return null
	if Players.count(get_tree()) >= MAX_PLAYERS:
		return null
	if _has_player_index(2):
		return null

	var p: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	p.player_index = 2
	players_root.add_child(p)
	p.global_position = _pick_join_spawn_position()
	_connect_player_destroy(p)
	return p


func _assemble_all_players() -> void:
	var to_assemble: Array[Node2D] = []
	for p in Players.all(get_tree()):
		if p.has_method("begin_level"):
			to_assemble.append(p)
	if to_assemble.is_empty():
		return

	# Godot forbids calling async funcs without await; kick each begin_level off via a
	# one-shot process_frame so both players assemble in the same intro beat.
	var remaining: Array = [to_assemble.size()]
	for p in to_assemble:
		var player_ref: Node2D = p
		var start_assemble := func() -> void:
			await player_ref.begin_level()
			remaining[0] -= 1
		get_tree().process_frame.connect(start_assemble, CONNECT_ONE_SHOT)

	while remaining[0] > 0:
		await get_tree().process_frame


func _has_player_index(index: int) -> bool:
	for p in Players.all(get_tree()):
		if p.get("player_index") == index:
			return true
	return false


func _pick_join_spawn_position() -> Vector2:
	var anchor: Vector2 = player.global_position
	for offset in P2_SPAWN_OFFSETS:
		var candidate: Vector2 = anchor + offset
		if _is_spawn_physics_clear(candidate):
			return candidate
	return anchor + P2_SPAWN_OFFSETS[0]


func _is_spawn_physics_clear(pos: Vector2) -> bool:
	if _p2_spawn_shape == null:
		_p2_spawn_shape = CircleShape2D.new()
		_p2_spawn_shape.radius = 8.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _p2_spawn_shape
	params.transform = Transform2D(0.0, pos)
	params.collision_mask = PHYSICS_LAYER_WORLD
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


func _launch_opening_orbs() -> void:
	if _opening_orbs_spawned:
		return
	_opening_orbs_spawned = true

	var origin: Vector2 = summoning_circle.get_launch_origin()
	var scenes: Array[PackedScene] = [
		#BLANK_ORB_SCENE
		GHOST_ORB_SCENE,
		ROT_ORB_SCENE,
		CONDUIT_ORB_SCENE,
	]
	for scene in scenes:
		var orb: RigidBody2D = scene.instantiate() as RigidBody2D
		add_child(orb)
		orb.global_position = origin
		_connect_orb_signals(orb)
		orb.begin_flight(Vector2.from_angle(randf() * TAU), player)

	_grant_opening_invulnerability()


func _grant_opening_invulnerability() -> void:
	for p in Players.all(get_tree()):
		var components = p.get("COMPONENTS")
		if components == null:
			continue
		var health: HealthComponent = components.get(HealthComponent)
		if health:
			health.start_invulnerability(OPENING_PLAYER_INVULN_SECONDS)


func _on_enemy_died(enemy: Node = null) -> void:
	if _game_over or _cleared:
		return
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
		return
	var drop_pos: Vector2 = (enemy as Node2D).global_position
	var source: Node = _get_damage_source(enemy)
	_try_drop_glyph_at(drop_pos, source)


func _try_drop_glyph_at(pos: Vector2, source: Node = null) -> void:
	var chance: float = glyph_drop_chance
	if source is BlankOrb:
		chance = (source as BlankOrb).glyph_drop
	chance = clampf(chance, 0.0, 1.0)
	if randf() > chance:
		return

	var glyph_table: Array = GameData.get_table(&"glyphs")
	if glyph_table.is_empty():
		return

	var row: Dictionary = glyph_table[randi() % glyph_table.size()]
	var glyph_id: StringName = StringName(String(row.get("id", "")))
	if glyph_id.is_empty():
		return

	var glyph: Glyph = GLYPH_SCENE.instantiate() as Glyph
	glyph.setup(glyph_id, _roll_glyph_rarity())
	# Death can fire during physics query flush; defer so add_child is safe.
	call_deferred("_spawn_glyph", glyph, pos)


func _spawn_glyph(glyph: Glyph, pos: Vector2) -> void:
	if glyph == null or not is_instance_valid(glyph) or items == null:
		return
	items.add_child(glyph)
	glyph.global_position = pos


func _roll_glyph_rarity() -> Glyph.Rarity:
	var total: float = (
		glyph_rarity_weight_common
		+ glyph_rarity_weight_rare
		+ glyph_rarity_weight_unique
	)
	if total <= 0.0:
		return Glyph.Rarity.COMMON
	var roll: float = randf() * total
	if roll < glyph_rarity_weight_common:
		return Glyph.Rarity.COMMON
	roll -= glyph_rarity_weight_common
	if roll < glyph_rarity_weight_rare:
		return Glyph.Rarity.RARE
	return Glyph.Rarity.UNIQUE


func _get_damage_source(entity: Node) -> Node:
	var comp = entity.get("COMPONENTS")
	if comp == null or not comp.has(HealthComponent):
		return null
	return (comp[HealthComponent] as HealthComponent).last_damage_source


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


func _on_breakable_destroyed(node: Node = null) -> void:
	rebake_timer.start()
	if node == null or not is_instance_valid(node):
		return
	var drop_pos: Vector2 = (node as Node2D).global_position if node is Node2D else Vector2.ZERO
	var source: Node = _get_damage_source(node)
	_try_drop_glyph_at(drop_pos, source)


func _on_rebake_timer_timeout() -> void:
	if navigation_region.is_baking():
		rebake_timer.start()
		return
	navigation_region.bake_navigation_polygon(true)


func _on_player_died(node: Node = null) -> void:
	if _cleared:
		return

	var downed_index: int = 0
	if node != null and is_instance_valid(node):
		downed_index = int(node.get("player_index"))

	_drop_carried_item_on_death(node)

	# DestroyComponent emits before queue_free; count remaining after this frame.
	await get_tree().process_frame
	if _cleared or _game_over:
		return

	var remaining: int = Players.count(get_tree())
	if remaining > 0:
		if downed_index > 0:
			status_label.text = "P%d down — %d left" % [downed_index, remaining]
		else:
			status_label.text = "Player down — %d left" % remaining
		return

	_game_over = true
	enemy_spawner.stop()
	time_slow_overlay.end()
	status_label.text = "You died. Press R to restart"


func _drop_carried_item_on_death(dying_player: Node = null) -> void:
	var p: Node = dying_player if dying_player != null and is_instance_valid(dying_player) else player
	if p == null or not is_instance_valid(p):
		return
	if not p.has_method("get_carried_item"):
		return
	var item: Glyph = p.get_carried_item()
	if item == null or not is_instance_valid(item):
		return
	var drop_pos: Vector2 = (p as Node2D).global_position if p is Node2D else player.global_position
	if not item.throw_toward(Vector2.DOWN, items):
		return
	if p.has_method("clear_carried_item"):
		p.clear_carried_item(item)
	item.global_position = drop_pos
	item.linear_velocity = Vector2.ZERO
	item.settle_on_ground()


func _on_ritual_started(orb: BlankOrb) -> void:
	if _game_over or _cleared:
		return
	time_slow_overlay.end()
	get_tree().paused = true
	ritual_menu.open(orb, summoning_circle, new_orb_cost)


func _on_ritual_menu_closed() -> void:
	get_tree().paused = false
	if summoning_circle != null and is_instance_valid(summoning_circle):
		summoning_circle.release_orb()


func _on_new_blank_orb_requested() -> void:
	if _game_over or _cleared:
		return
	_spawn_blank_orb_at_circle()


func _spawn_blank_orb_at_circle() -> void:
	var orb: BlankOrb = BLANK_ORB_SCENE.instantiate() as BlankOrb
	add_child(orb)
	orb.global_position = summoning_circle.get_launch_origin()
	_connect_orb_signals(orb)
	orb.begin_flight(Vector2.from_angle(randf() * TAU), player)
