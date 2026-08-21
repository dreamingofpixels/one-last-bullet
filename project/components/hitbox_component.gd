class_name HitboxComponent extends Area2D

## The HealthComponent on this entity that receives incoming damage.
@export var health_component: HealthComponent
## Physics-frame grace after an attacker leaves before a new overlap counts as a fresh hit.
## Absorbs residual enter/exit/enter artifacts; not a gameplay cooldown.
@export var hit_dedup_frames: int = 2

## Per attacker: { "last_seen_frame": int, "next_damage_msec": int }
var _attacker_state: Dictionary = {}


func _ready() -> void:
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return

	var frame: int = Engine.get_physics_frames()
	var now_msec: int = Time.get_ticks_msec()
	var seen_ids: Dictionary = {}

	for area in get_overlapping_areas():
		if not area is HitboxComponent:
			continue
		var attacker: Node = _resolve_attacker_root(area)
		if attacker == null or not is_instance_valid(attacker):
			continue
		var attacker_id: int = attacker.get_instance_id()
		seen_ids[attacker_id] = true
		_poll_attacker(attacker, attacker_id, frame, now_msec)

	_prune_attacker_state(frame, seen_ids)


## Disable monitoring while invulnerable so overlaps deal no damage.
## Deferred because callers often toggle from _physics_process.
func set_invulnerable(value: bool) -> void:
	if value:
		_attacker_state.clear()
	set_deferred("monitoring", not value)


## Walk up from a collider until we find the entity root that holds `COMPONENTS`.
func _resolve_attacker_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null

	var attacker: Node = collider
	if collider is Area2D:
		# `owner` is scene metadata; it may not be the entity root that holds `COMPONENTS`.
		attacker = collider.owner
		if attacker == null or not is_instance_valid(attacker):
			attacker = collider

	while attacker != null and attacker.get("COMPONENTS") == null:
		attacker = attacker.get_parent()

	return attacker


func _poll_attacker(attacker: Node, attacker_id: int, frame: int, now_msec: int) -> void:
	var comp = attacker.get("COMPONENTS")
	if comp == null or not comp.has(DamageComponent):
		return

	var dc: DamageComponent = comp[DamageComponent]
	if dc.damage <= 0.0:
		return

	# Friendly-fire filter: the instigator of the damage is immune.
	if is_instance_valid(dc.instigator) and dc.instigator == owner:
		return

	var state: Dictionary = _attacker_state.get(attacker_id, {})
	var is_fresh: bool = state.is_empty()
	state["last_seen_frame"] = frame

	if is_fresh or now_msec >= int(state.get("next_damage_msec", 0)):
		var applied := false
		if health_component:
			applied = health_component.take_damage(dc.damage)
		if applied:
			# Zero interval = single hit per continuous overlap; >0 = contact tick.
			var interval_msec: int = int(dc.contact_damage_interval * 1000.0)
			if interval_msec > 0:
				state["next_damage_msec"] = now_msec + interval_msec
			else:
				# Far future until the attacker leaves and re-enters (after dedup prune).
				state["next_damage_msec"] = 0x7fffffff
		else:
			# I-frames (or missing health) blocked the hit — retry next poll.
			state["next_damage_msec"] = now_msec

	_attacker_state[attacker_id] = state


func _prune_attacker_state(frame: int, seen_ids: Dictionary) -> void:
	var to_remove: Array = []
	for attacker_id in _attacker_state:
		if seen_ids.has(attacker_id):
			continue
		var state: Dictionary = _attacker_state[attacker_id]
		var last_seen: int = int(state.get("last_seen_frame", 0))
		if frame - last_seen > hit_dedup_frames:
			to_remove.append(attacker_id)
	for attacker_id in to_remove:
		_attacker_state.erase(attacker_id)
