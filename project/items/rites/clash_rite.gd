class_name ClashRite
extends Rite

const EXPLOSION_SCENE: PackedScene = preload("res://effects/explosion/medium_explosion.tscn")
const DAMAGE := 10.0
const PHYSICS_LAYER_PLAYER := 2
const PHYSICS_LAYER_ENEMY := 4

## instance_id_a|instance_id_b (sorted) -> physics frame last fired
var _pair_frames: Dictionary = {}


func notify(event: StringName, ctx: RiteContext) -> void:
	if event != &"orb_orb_contact":
		return
	if ctx.victim == null or ctx.other == null:
		return
	if not is_instance_valid(ctx.victim) or not is_instance_valid(ctx.other):
		return
	if not _both_flying(ctx.victim, ctx.other):
		return
	if not _claim_pair(ctx.victim, ctx.other):
		return

	var mid: Vector2 = ctx.position
	if mid == Vector2.ZERO and ctx.victim is Node2D and ctx.other is Node2D:
		mid = ((ctx.victim as Node2D).global_position + (ctx.other as Node2D).global_position) * 0.5

	var radius: float = _spawn_explosion(mid, ctx.victim)
	_damage_in_radius(mid, radius, ctx.victim)


func _both_flying(a: Node, b: Node) -> bool:
	var a_flying: bool = a is BlankOrb and (a as BlankOrb).state == BlankOrb.OrbState.FLYING
	var b_flying: bool = b is BlankOrb and (b as BlankOrb).state == BlankOrb.OrbState.FLYING
	return a_flying and b_flying


func _claim_pair(a: Node, b: Node) -> bool:
	var id_a: int = a.get_instance_id()
	var id_b: int = b.get_instance_id()
	var lo: int = mini(id_a, id_b)
	var hi: int = maxi(id_a, id_b)
	var key: String = "%d|%d" % [lo, hi]
	var frame: int = Engine.get_physics_frames()
	if int(_pair_frames.get(key, -1)) == frame:
		return false
	_pair_frames[key] = frame
	# Drop stale keys occasionally so the dict cannot grow forever.
	if _pair_frames.size() > 64:
		var stale: Array = []
		for k in _pair_frames.keys():
			if int(_pair_frames[k]) < frame - 2:
				stale.append(k)
		for k in stale:
			_pair_frames.erase(k)
	return true


func _spawn_explosion(mid: Vector2, anchor: Node) -> float:
	var fx_parent: Node = _resolve_fx_parent(anchor)
	if fx_parent == null:
		return float(MediumExplosion.FRAME_W) * 0.5
	var fx: MediumExplosion = EXPLOSION_SCENE.instantiate() as MediumExplosion
	fx_parent.add_child(fx)
	fx.global_position = mid
	return fx.blast_radius()


func _resolve_fx_parent(anchor: Node) -> Node:
	if anchor != null and anchor.is_inside_tree():
		var parent: Node = anchor.get_parent()
		if parent is Node2D and (parent as Node2D).y_sort_enabled:
			return parent
		var scene: Node = anchor.get_tree().current_scene
		if scene != null:
			var ysort: Node = scene.get_node_or_null("%WorldYSort")
			if ysort == null:
				ysort = scene.get_node_or_null("WorldYSort")
			if ysort != null:
				return ysort
			return scene
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		return tree.current_scene
	return null


func _damage_in_radius(mid: Vector2, radius: float, source: Node) -> void:
	if radius <= 0.0:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var world: World2D = tree.root.get_viewport().find_world_2d()
	if world == null:
		return
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	if space == null:
		return
	var params := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	params.shape = circle
	params.transform = Transform2D(0.0, mid)
	params.collision_mask = PHYSICS_LAYER_PLAYER | PHYSICS_LAYER_ENEMY
	params.collide_with_areas = true
	params.collide_with_bodies = true

	var damaged_ids: Dictionary = {}
	for hit in space.intersect_shape(params, 32):
		var collider: Object = hit.get("collider")
		if collider == null or not (collider is Node):
			continue
		var victim_root: Node = _resolve_entity_root(collider as Node)
		if victim_root == null or not is_instance_valid(victim_root):
			continue
		if not victim_root.is_in_group("enemies") and not victim_root.is_in_group("player"):
			continue
		var victim_id: int = victim_root.get_instance_id()
		if damaged_ids.has(victim_id):
			continue
		damaged_ids[victim_id] = true
		var comp = victim_root.get("COMPONENTS")
		if comp == null or not comp.has(HealthComponent):
			continue
		(comp[HealthComponent] as HealthComponent).take_damage(
			DAMAGE,
			HealthComponent.DamageKind.STANDARD,
			source
		)


func _resolve_entity_root(collider: Node) -> Node:
	if collider == null or not is_instance_valid(collider):
		return null
	var node: Node = collider
	while node != null and node.get("COMPONENTS") == null:
		node = node.get_parent()
	return node
