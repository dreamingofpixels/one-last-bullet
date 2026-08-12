extends CharacterBody2D

signal died

const PHYSICS_LAYER_WORLD := 1
const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_BULLET := 8

@export var move_speed: float = 90.0

@onready var player_sprite: Sprite2D = %PlayerSprite
@onready var redirect_range: Area2D = %RedirectRange

var can_move: bool = true
var is_dead: bool = false
var _bullet_in_range: bool = false
var _bullet: RigidBody2D = null


func _ready() -> void:
	add_to_group("player")
	collision_layer = PHYSICS_LAYER_PLAYER
	collision_mask = PHYSICS_LAYER_WORLD

	redirect_range.collision_layer = 0
	redirect_range.collision_mask = PHYSICS_LAYER_BULLET
	redirect_range.monitoring = true
	redirect_range.monitorable = false
	redirect_range.body_entered.connect(_on_redirect_range_body_entered)
	redirect_range.body_exited.connect(_on_redirect_range_body_exited)


func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if can_move:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input_dir * move_speed
		if input_dir.x != 0.0:
			player_sprite.flip_h = input_dir.x < 0.0
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if can_move and _bullet_in_range and Input.is_action_just_pressed("redirect"):
		_try_redirect()


func set_movement_locked(locked: bool) -> void:
	can_move = not locked
	if locked:
		velocity = Vector2.ZERO


func bind_bullet(bullet: RigidBody2D) -> void:
	_bullet = bullet


func die() -> void:
	if is_dead:
		return
	is_dead = true
	can_move = false
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	redirect_range.set_deferred("monitoring", false)
	died.emit()
	DestructionEffect.play_from_sprite(player_sprite)
	queue_free()


func _try_redirect() -> void:
	if not is_instance_valid(_bullet):
		return
	if _bullet.has_method("is_flying") and not _bullet.is_flying():
		return
	if _bullet.has_method("begin_redirect"):
		_bullet.begin_redirect(1.5)


func _on_redirect_range_body_entered(body: Node2D) -> void:
	if body == _bullet or (is_instance_valid(_bullet) and body == _bullet):
		_bullet_in_range = true
	elif body.is_in_group("bullet") or body.name == "LastBullet" or body.name == "LastOrb":
		_bullet = body as RigidBody2D
		_bullet_in_range = true


func _on_redirect_range_body_exited(body: Node2D) -> void:
	if body == _bullet:
		_bullet_in_range = false
