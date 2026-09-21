class_name NovaOrb
extends BlankOrb

## Flying orb that pulses a frost nova around itself on an interval.

const FROST_NOVA_SCENE: PackedScene = preload("res://effects/frost_nova/frost_nova.tscn")
## Half-width of one frost_nova frame (96×96 sheet cells).
const NOVA_FRAME_HALF_W := 48.0

@export_group("Frost Nova")
@export var nova_radius: float = 48.0
@export var nova_interval: float = 3.0
@export var nova_chill: int = 5
@export var nova_anim_fps: float = 13.0
@export var nova_visual_scale: float = 1.0
@export var nova_sound: SoundEvent

var _nova_remaining: float = 0.0


func _ready() -> void:
	super._ready()
	_nova_remaining = maxf(nova_interval, 0.001)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_flying():
		return
	_update_nova(delta)


func _update_nova(delta: float) -> void:
	_nova_remaining -= delta
	if _nova_remaining > 0.0:
		return
	_nova_remaining = maxf(nova_interval, 0.001)
	_pulse_nova()


func _pulse_nova() -> void:
	_apply_nova_chill()
	_spawn_frost_nova_fx()


func _apply_nova_chill() -> void:
	if nova_chill <= 0 or nova_radius <= 0.0:
		return
	if not is_inside_tree():
		return

	var radius_sq: float = nova_radius * nova_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue
		if global_position.distance_squared_to(enemy_node.global_position) > radius_sq:
			continue
		var comp = enemy.get("COMPONENTS")
		if comp == null or not comp.has(StatusComponent):
			continue
		(comp[StatusComponent] as StatusComponent).add_stacks(
			StatusComponent.StatusId.CHILL,
			nova_chill,
			self
		)


func _spawn_frost_nova_fx() -> void:
	var fx: FrostNova = FROST_NOVA_SCENE.instantiate() as FrostNova
	if fx == null:
		return
	# Child of the orb so the ring stays centered while the orb moves.
	add_child(fx)
	fx.position = Vector2(0,-10)
	var scale_factor: float = (nova_radius / NOVA_FRAME_HALF_W) * nova_visual_scale
	fx.setup(nova_anim_fps, scale_factor, nova_sound)
