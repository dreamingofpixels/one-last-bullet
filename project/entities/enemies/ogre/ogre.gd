extends CharacterBody2D

const ANIM_IDLE := &"idle"
const ANIM_RUN := &"running"
## Below this speed the ogre reads as standing still.
const RUN_SPEED_THRESHOLD := 5.0

const LINE_SHOCKWAVE_SCENE: PackedScene = preload("res://effects/shockwave/line_shockwave.tscn")
## Eight rays: N, S, E, W, NW, NE, SW, SE.
const SHOCKWAVE_DIRS: Array[Vector2] = [
	Vector2(0, -1),
	Vector2(0, 1),
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(-0.70710678, -0.70710678),
	Vector2(0.70710678, -0.70710678),
	Vector2(-0.70710678, 0.70710678),
	Vector2(0.70710678, 0.70710678),
]

var COMPONENTS: Dictionary = {}

@onready var sprite: AnimatedSprite2D = %Sprite2D
@onready var attack_component: EnemyAttackComponent = %EnemyAttackComponent


func _ready() -> void:
	attack_component.struck.connect(_on_attack_struck)


func _physics_process(_delta: float) -> void:
	if attack_component.is_attacking():
		return
	if velocity.length() > RUN_SPEED_THRESHOLD:
		sprite.play(ANIM_RUN)
	else:
		sprite.play(ANIM_IDLE)


func _on_attack_struck() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	# Spikes must be siblings of entities under %WorldYSort — parenting to the
	# scene root draws them above the entire y-sorted group.
	var spike_parent: Node = get_parent()
	if not (spike_parent is Node2D and (spike_parent as Node2D).y_sort_enabled):
		spike_parent = scene.get_node_or_null("WorldYSort")
	if spike_parent == null:
		spike_parent = scene.get_node_or_null("%WorldYSort")
	if spike_parent == null:
		push_warning("Ogre shockwave: WorldYSort missing; spikes will not y-sort.")
		spike_parent = scene

	var origin: Vector2 = global_position
	var dmg: float = attack_component.damage
	var knock: float = attack_component.hit_knockback_distance

	for dir in SHOCKWAVE_DIRS:
		var line: LineShockwave = LINE_SHOCKWAVE_SCENE.instantiate() as LineShockwave
		scene.add_child(line)
		line.damage = dmg
		line.knockback_distance = knock
		line.start(origin, dir, self, spike_parent)
