class_name LineShockwave
extends Node2D

## Spawns a staggered line of earth spikes along a direction from an origin.
## Spikes are parented to a y-sort root (not this controller) so they depth-sort with entities.

const DEFAULT_SPIKE_SCENE: PackedScene = preload("res://effects/shockwave/earth_spike.tscn")
const DEFAULT_START_SOUND: SoundEvent = preload("res://effects/shockwave/line_shockwave.tres")

@export var spike_scene: PackedScene
@export var spike_count: int = 5
@export var spacing: float = 24.0
@export var step_delay: float = 0.06
@export var damage: float = 10.0
@export var knockback_distance: float = 40.0
@export var start_sound: SoundEvent = DEFAULT_START_SOUND

var _origin: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.UP
var _instigator: Node = null
var _spawned: int = 0
var _alive_spikes: int = 0
var _all_spawned: bool = false
var _spike_parent: Node = null


func _ready() -> void:
	if spike_scene == null:
		spike_scene = DEFAULT_SPIKE_SCENE
	if start_sound == null:
		start_sound = DEFAULT_START_SOUND


func start(origin: Vector2, direction: Vector2, instigator: Node, spike_parent: Node = null) -> void:
	if spike_scene == null:
		spike_scene = DEFAULT_SPIKE_SCENE
	if start_sound == null:
		start_sound = DEFAULT_START_SOUND
	_origin = origin
	_instigator = instigator
	_spike_parent = spike_parent if spike_parent != null else self
	if direction.length_squared() < 0.0001:
		_direction = Vector2.UP
	else:
		_direction = direction.normalized()
	_spawned = 0
	_alive_spikes = 0
	_all_spawned = false
	global_position = origin
	set_process(true)
	if start_sound:
		AudioManager.play_at(start_sound, origin)
	_spawn_next()


func _process(_delta: float) -> void:
	if not _all_spawned:
		return
	if _alive_spikes <= 0:
		queue_free()


func _spawn_next() -> void:
	if not is_instance_valid(self):
		return
	if spike_scene == null:
		spike_scene = DEFAULT_SPIKE_SCENE
	if spike_scene == null:
		queue_free()
		return
	if _spawned >= spike_count:
		_all_spawned = true
		return

	var index: int = _spawned
	_spawned += 1
	_spawn_spike_at(index)

	if _spawned < spike_count:
		get_tree().create_timer(step_delay).timeout.connect(_spawn_next)
	else:
		_all_spawned = true


func _spawn_spike_at(index: int) -> void:
	if not is_instance_valid(_spike_parent):
		_all_spawned = true
		queue_free()
		return

	var spike: Node = spike_scene.instantiate()
	_spike_parent.add_child(spike)
	_alive_spikes += 1
	spike.tree_exiting.connect(_on_spike_exiting)
	var world_base: Vector2 = _origin + _direction * float(index + 1) * spacing
	var instigator: Node = _live_instigator()
	if spike is EarthSpike:
		var earth: EarthSpike = spike as EarthSpike
		earth.place_at(world_base)
		earth.setup(damage, knockback_distance, instigator, _origin)
	elif spike is Node2D:
		(spike as Node2D).global_position = world_base
		if spike.has_method("setup"):
			spike.call("setup", damage, knockback_distance, instigator, _origin)


func _live_instigator() -> Node:
	if _instigator != null and is_instance_valid(_instigator):
		return _instigator
	_instigator = null
	return null


func _on_spike_exiting() -> void:
	_alive_spikes = maxi(0, _alive_spikes - 1)
