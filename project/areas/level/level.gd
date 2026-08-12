extends Node2D

const GRUNT_SCENE := preload("res://entities/enemies/grunt/grunt_knife.tscn")
const OPENING_AIM_SECONDS := 3.0
const ENEMY_COUNT := 3
const MIN_SPAWN_DISTANCE := 120.0
const PLAY_RECT := Rect2(24.0, 24.0, 592.0, 312.0)

@onready var player: CharacterBody2D = %Player
@onready var enemies: Node2D = %Enemies
@onready var last_bullet: RigidBody2D = %LastBullet
@onready var status_label: Label = %StatusLabel

var _enemies_alive: int = 0
var _game_over: bool = false
var _cleared: bool = false


func _ready() -> void:
	Engine.time_scale = 1.0
	randomize()
	status_label.text = "Aim your last bullet"

	last_bullet.launched.connect(_on_bullet_launched)
	last_bullet.deflected.connect(_on_bullet_deflected)

	var player_destroy: DestroyComponent = player.COMPONENTS.get(DestroyComponent)
	if player_destroy:
		player_destroy.destroyed.connect(_on_player_died)

	_spawn_enemies()
	player.begin_opening_aim(last_bullet, OPENING_AIM_SECONDS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _spawn_enemies() -> void:
	_enemies_alive = 0
	for i in ENEMY_COUNT:
		var grunt := GRUNT_SCENE.instantiate() as CharacterBody2D
		enemies.add_child(grunt)
		grunt.global_position = _pick_spawn_position()
		# Connect destroy_component.destroyed (emitted after death FX starts).
		var destroy_comp: DestroyComponent = grunt.COMPONENTS.get(DestroyComponent)
		if destroy_comp:
			destroy_comp.destroyed.connect(_on_enemy_died.bind())
		_enemies_alive += 1


func _pick_spawn_position() -> Vector2:
	for _attempt in 40:
		var pos := Vector2(
			randf_range(PLAY_RECT.position.x, PLAY_RECT.end.x),
			randf_range(PLAY_RECT.position.y, PLAY_RECT.end.y)
		)
		if pos.distance_to(player.global_position) >= MIN_SPAWN_DISTANCE:
			return pos
	return Vector2(PLAY_RECT.position.x + 40.0, PLAY_RECT.position.y + 40.0)


func _on_bullet_launched() -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Clear the saloon"


func _on_bullet_deflected(_by: Node = null) -> void:
	if _game_over or _cleared:
		return
	status_label.text = "Deflected!"


func _on_enemy_died(_node: Node = null) -> void:
	_enemies_alive = maxi(0, _enemies_alive - 1)
	if _enemies_alive <= 0 and not _game_over:
		_cleared = true
		Engine.time_scale = 1.0
		status_label.text = "Cleared! Press R to restart"


func _on_player_died(_node: Node = null) -> void:
	if _cleared:
		return
	_game_over = true
	Engine.time_scale = 1.0
	status_label.text = "You died. Press R to restart"
