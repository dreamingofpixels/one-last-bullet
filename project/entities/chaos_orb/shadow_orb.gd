class_name ShadowOrb extends ChaosOrb

const POSSESSION_DPS := 3.0
const POSSESSION_TICK_INTERVAL := 1.0
const POSSESSION_FLASH_COLOR := Color(0.25, 0.12, 0.35, 1.0)

var _host: Node2D = null
var _host_health: HealthComponent = null
var _host_destroy: DestroyComponent = null
var _saved_flash_color: Color = Color(1.0, 0.2, 0.2, 1.0)
var _possession_tick_remaining: float = 0.0
var _saved_collision_layer: int = 8


func should_apply_hitbox_damage(victim: Node) -> bool:
	# Enter enemies without dealing impact HP; still chip the player.
	if victim != null and victim.is_in_group("enemies"):
		return false
	return true


func on_hitbox_hit(victim: Node) -> void:
	if state != OrbState.FLYING:
		return
	if victim == null or not is_instance_valid(victim):
		return
	if not victim.is_in_group("enemies"):
		return
	if not (victim is Node2D):
		return
	_begin_possession(victim as Node2D)


func _physics_process(delta: float) -> void:
	if state == OrbState.POSSESSED:
		_update_possession(delta)
		return
	super._physics_process(delta)


func _begin_possession(host: Node2D) -> void:
	var comp = host.get("COMPONENTS")
	if comp == null or not comp.has(HealthComponent):
		return

	_host = host
	_host_health = comp[HealthComponent] as HealthComponent
	_host_destroy = comp.get(DestroyComponent) as DestroyComponent
	if _host_destroy and not _host_destroy.destroyed.is_connected(_on_host_destroyed):
		_host_destroy.destroyed.connect(_on_host_destroyed)

	if _host_health:
		_saved_flash_color = _host_health.damage_flash_color
		_host_health.damage_flash_color = POSSESSION_FLASH_COLOR

	_opening_tether = false
	_clear_tether_vars()
	clear_redirect_preview()
	set_in_focus(false)
	_end_grace_visual()

	state = OrbState.POSSESSED
	freeze = true
	linear_velocity = Vector2.ZERO
	_saved_collision_layer = collision_layer
	collision_layer = 0
	hitbox_component.monitoring = false
	orb_sprite.visible = false
	orb_in_focus.visible = false
	aim_arrow.visible = false
	trail_particles.emitting = false
	redirect_particles.emitting = false

	_possession_tick_remaining = 0.0
	global_position = host.global_position


func _update_possession(delta: float) -> void:
	if not is_instance_valid(_host):
		_emerge_and_fly(Vector2.from_angle(randf() * TAU))
		return

	global_position = _host.global_position
	_possession_tick_remaining -= delta
	if _possession_tick_remaining > 0.0:
		return

	_possession_tick_remaining = POSSESSION_TICK_INTERVAL
	if _host_health and is_instance_valid(_host_health):
		_host_health.take_damage(POSSESSION_DPS, HealthComponent.DamageKind.SHADOW)


func _on_host_destroyed(_node: Node) -> void:
	var emerge_pos: Vector2 = global_position
	if is_instance_valid(_host):
		emerge_pos = _host.global_position
	_clear_possession_host()
	global_position = emerge_pos
	_emerge_and_fly(Vector2.from_angle(randf() * TAU))


func _clear_possession_host() -> void:
	if _host_health and is_instance_valid(_host_health):
		_host_health.damage_flash_color = _saved_flash_color
	if _host_destroy and is_instance_valid(_host_destroy):
		if _host_destroy.destroyed.is_connected(_on_host_destroyed):
			_host_destroy.destroyed.disconnect(_on_host_destroyed)
	_host = null
	_host_health = null
	_host_destroy = null
	_possession_tick_remaining = 0.0


func _emerge_and_fly(direction: Vector2) -> void:
	_clear_possession_host()
	collision_layer = _saved_collision_layer if _saved_collision_layer != 0 else 8
	# No player grace — orb reappears mid-fight from a corpse.
	begin_flight(direction, null)
