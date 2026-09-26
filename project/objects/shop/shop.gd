class_name Shop
extends Node2D

const GLYPH_SCENE := preload("res://items/glyphs/glyph.tscn")
const RITE_HOP_HEIGHT := 12.0
const RITE_HOP_DURATION := 0.2
const RITE_FLY_DURATION := 0.5
## Shop glyph toss: south of the stall shelf (px/s).
const GLYPH_TOSS_SPEED := 140.0
const ASSEMBLE_DURATION := 2.0
const FALL_DURATION := 0.7

@export var rite_cost: float = 50.0
@export var glyph_cost_multiplier: float = 2.0
## Half-extents of the interact ellipse: x = horizontal, y = vertical.
@export var slot_interact_radius: Vector2 = Vector2(16.0, 24.0)
@export var glyph_rarity_weight_common: float = 70.0
@export var glyph_rarity_weight_rare: float = 25.0
@export var glyph_rarity_weight_unique: float = 5.0

var _glyph_slots: Array[ItemShopSlot] = []
var _rite_slots: Array[ItemShopSlot] = []
var _stall_bodies: Array[StaticBody2D] = []
var _focused_slot: ItemShopSlot = null
var _prompt_cache_key: String = ""
var _interactive: bool = false
var _materializing: bool = false

@onready var rite_stall: Sprite2D = %RiteStall
@onready var glyph_stall: Sprite2D = %GlyphStall
@onready var shop_keeper: AnimatedSprite2D = %ShopKeeper
@onready var rite_info: Control = %RiteInfo
@onready var rite_name_label: Label = %RiteNameLabel
@onready var rite_desc_label: Label = %RiteDescLabel
@onready var rite_buy_prompt: InputPrompt = %RiteBuyPrompt
@onready var glyph_info: Control = %GlyphInfo
@onready var glyph_name_label: Label = %GlyphNameLabel
@onready var glyph_desc_label: Label = %GlyphDescLabel
@onready var glyph_buy_prompt: InputPrompt = %GlyphBuyPrompt


func _ready() -> void:
	_collect_slots()
	_collect_stall_bodies()
	rite_info.visible = false
	glyph_info.visible = false
	_stock_glyph_slots()
	_stock_rite_slots()
	_set_stall_collision_enabled(false)
	_set_visuals_visible(false)
	_interactive = false


func _process(_delta: float) -> void:
	if not _interactive or _materializing:
		return
	_refresh_focus()
	_poll_buy_input()


## Pixel-assemble stalls, stock, and keeper. Enables buys when finished.
func materialize_in() -> void:
	_materializing = true
	_interactive = false
	_set_stall_collision_enabled(false)
	_set_visuals_visible(false)
	rite_info.visible = false
	glyph_info.visible = false
	await _play_assemble_on_visuals()
	if not is_inside_tree():
		return
	_set_visuals_visible(true)
	_set_stall_collision_enabled(true)
	_materializing = false
	_interactive = true


## Pixel-fall then free this shop instance.
func materialize_out() -> void:
	_materializing = true
	_interactive = false
	_set_focused_slot(null)
	rite_info.visible = false
	glyph_info.visible = false
	_set_stall_collision_enabled(false)
	_play_fall_on_visuals()
	await get_tree().create_timer(FALL_DURATION).timeout
	if is_instance_valid(self):
		queue_free()


func _assemble_sprites() -> Array[Node2D]:
	var sprites: Array[Node2D] = []
	if rite_stall != null:
		sprites.append(rite_stall)
	if glyph_stall != null:
		sprites.append(glyph_stall)
	if shop_keeper != null:
		sprites.append(shop_keeper)
	for slot in _glyph_slots:
		if slot != null and is_instance_valid(slot) and slot.is_stocked():
			sprites.append(slot)
	for slot in _rite_slots:
		if slot != null and is_instance_valid(slot) and slot.is_stocked():
			sprites.append(slot)
	return sprites


func _set_visuals_visible(show: bool) -> void:
	if rite_stall != null:
		rite_stall.visible = show
	if glyph_stall != null:
		glyph_stall.visible = show
	if shop_keeper != null:
		shop_keeper.visible = show
	for slot in _glyph_slots:
		_set_slot_visible(slot, show)
	for slot in _rite_slots:
		_set_slot_visible(slot, show)


func _set_slot_visible(slot: ItemShopSlot, show: bool) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var show_slot: bool = show and slot.is_stocked()
	slot.visible = show_slot
	var icon: Node2D = slot.get_node_or_null("%Icon") as Node2D
	if icon != null:
		icon.visible = show_slot and slot.stock_kind == ItemShopSlot.StockKind.RITE


func _set_stall_collision_enabled(enabled: bool) -> void:
	for body in _stall_bodies:
		if body == null or not is_instance_valid(body):
			continue
		body.set_deferred("collision_layer", 1 if enabled else 0)
		for child in body.get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", not enabled)


func _play_assemble_on_visuals() -> void:
	var sprites: Array[Node2D] = _assemble_sprites()
	if sprites.is_empty():
		return
	var remaining: Array = [sprites.size()]
	for spr in sprites:
		var sprite_ref: Node2D = spr
		var run := func() -> void:
			await DestructionEffect.play_assemble_from_sprite(sprite_ref, ASSEMBLE_DURATION)
			remaining[0] -= 1
		get_tree().process_frame.connect(run, CONNECT_ONE_SHOT)
	while remaining[0] > 0:
		if not is_inside_tree():
			return
		await get_tree().process_frame


func _play_fall_on_visuals() -> void:
	for spr in _assemble_sprites():
		if spr == null or not is_instance_valid(spr) or not spr.visible:
			continue
		DestructionEffect.play_from_sprite(spr, FALL_DURATION)
		spr.visible = false


func _collect_slots() -> void:
	_glyph_slots.clear()
	_rite_slots.clear()
	for node in find_children("*", "ItemShopSlot", true, false):
		var slot: ItemShopSlot = node as ItemShopSlot
		if slot == null:
			continue
		if slot.stock_kind == ItemShopSlot.StockKind.RITE:
			_rite_slots.append(slot)
		else:
			_glyph_slots.append(slot)


func _collect_stall_bodies() -> void:
	_stall_bodies.clear()
	for node in find_children("*", "StaticBody2D", true, false):
		if node is StaticBody2D:
			_stall_bodies.append(node as StaticBody2D)


func _stock_glyph_slots() -> void:
	var pool: Array[StringName] = _all_glyph_ids()
	pool.shuffle()
	for i in _glyph_slots.size():
		var slot: ItemShopSlot = _glyph_slots[i]
		if pool.is_empty():
			slot.clear_stock()
			continue
		var id: StringName = pool.pop_back()
		var rarity: Glyph.Rarity = _roll_glyph_rarity()
		var cost: float = float(Glyph.MANA_BY_RARITY.get(rarity, 5.0)) * glyph_cost_multiplier
		slot.stock_glyph(id, rarity, cost)


func _stock_rite_slots() -> void:
	var owned: Array[StringName] = []
	var circle: SummoningCircle = _find_circle()
	if circle != null:
		owned = circle.get_owned_rite_ids()
	var pool: Array[StringName] = _active_rite_ids()
	var filtered: Array[StringName] = []
	for id in pool:
		if not owned.has(id):
			filtered.append(id)
	filtered.shuffle()
	for i in _rite_slots.size():
		var slot: ItemShopSlot = _rite_slots[i]
		if filtered.is_empty():
			slot.clear_stock()
			continue
		var id: StringName = filtered.pop_back()
		slot.stock_rite(id, rite_cost)


func _refresh_focus() -> void:
	var slot: ItemShopSlot = _find_nearest_stocked_slot()
	_set_focused_slot(slot)
	if slot == null:
		rite_info.visible = false
		glyph_info.visible = false
		_prompt_cache_key = ""
		return
	if slot.stock_kind == ItemShopSlot.StockKind.RITE:
		glyph_info.visible = false
		rite_name_label.text = slot.get_display_name().to_upper()
		rite_desc_label.text = slot.get_description()
		rite_info.visible = true
		_configure_buy_prompt(rite_buy_prompt, slot)
	else:
		rite_info.visible = false
		glyph_name_label.text = slot.get_display_name().to_upper()
		glyph_desc_label.text = slot.get_description()
		glyph_info.visible = true
		_configure_buy_prompt(glyph_buy_prompt, slot)


func _configure_buy_prompt(prompt: InputPrompt, slot: ItemShopSlot) -> void:
	var keyboard_mouse: bool = _prompt_prefers_keyboard_mouse()
	var cost_i: int = int(slot.get_cost())
	var key: String = "%s|%d|%s" % [String(slot.item_id), cost_i, str(keyboard_mouse)]
	if key == _prompt_cache_key:
		return
	_prompt_cache_key = key
	prompt.configure_action(&"upgrade", "Buy (%d mana)" % cost_i, keyboard_mouse)


func _poll_buy_input() -> void:
	if _focused_slot == null or not _focused_slot.is_stocked():
		return
	for player_variant in Players.all(get_tree()):
		if player_variant == null or not is_instance_valid(player_variant):
			continue
		var player: Node2D = player_variant as Node2D
		if player == null:
			continue
		if not _is_within_interact_radius(player.global_position, _focused_slot.global_position):
			continue
		var controls: Controls = player.get("controls") as Controls
		if controls == null:
			continue
		if controls.is_upgrade_just_pressed():
			_try_buy(_focused_slot)
			return


func _try_buy(slot: ItemShopSlot) -> void:
	if slot == null or not slot.is_stocked():
		return
	var circle: SummoningCircle = _find_circle()
	if circle == null:
		return
	var cost: float = slot.get_cost()
	if cost > 0.0 and circle.mana_pool < cost:
		return
	if slot.stock_kind == ItemShopSlot.StockKind.RITE:
		_try_buy_rite(slot, circle, cost)
	else:
		_try_buy_glyph(slot, circle, cost)


func _try_buy_glyph(slot: ItemShopSlot, circle: SummoningCircle, cost: float) -> void:
	var glyph_id: StringName = slot.item_id
	var rarity: Glyph.Rarity = slot.rarity
	if cost > 0.0 and not circle.spend(cost):
		return
	slot.clear_stock()
	_set_focused_slot(null)
	rite_info.visible = false
	glyph_info.visible = false
	_prompt_cache_key = ""
	_spawn_glyph_at(slot.global_position, glyph_id, rarity)


func _try_buy_rite(slot: ItemShopSlot, circle: SummoningCircle, cost: float) -> void:
	var target: RiteSlot = circle.reserve_next_rite_slot()
	if target == null:
		return
	if cost > 0.0 and not circle.spend(cost):
		circle.release_rite_slot_reservation(target)
		return
	var rite_id: StringName = slot.item_id
	var start_pos: Vector2 = slot.global_position
	slot.clear_stock()
	_set_focused_slot(null)
	rite_info.visible = false
	glyph_info.visible = false
	_prompt_cache_key = ""
	_fly_rite_to_slot(rite_id, start_pos, target, circle)


func _spawn_glyph_at(world_pos: Vector2, glyph_id: StringName, rarity: Glyph.Rarity) -> void:
	var glyph: Glyph = GLYPH_SCENE.instantiate() as Glyph
	if glyph == null:
		return
	glyph.setup(glyph_id, rarity)
	var items_parent: Node = get_tree().current_scene.get_node_or_null("%Items")
	if items_parent == null:
		items_parent = get_tree().current_scene
	items_parent.add_child(glyph)
	glyph.global_position = world_pos
	glyph.launch_toward(Vector2.DOWN, GLYPH_TOSS_SPEED, _stall_bodies)


func _fly_rite_to_slot(
	rite_id: StringName,
	start_pos: Vector2,
	target: RiteSlot,
	circle: SummoningCircle
) -> void:
	var flyer: Sprite2D = Sprite2D.new()
	flyer.texture = RiteSlot.resolve_texture(rite_id)
	flyer.z_as_relative = false
	flyer.z_index = 10
	var parent: Node = _world_ysort_parent()
	parent.add_child(flyer)
	flyer.global_position = start_pos

	var hop_pos: Vector2 = start_pos + Vector2(0.0, -RITE_HOP_HEIGHT)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(flyer, "global_position", hop_pos, RITE_HOP_DURATION)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(flyer, "global_position", target.global_position, RITE_FLY_DURATION)
	tween.tween_callback(_finish_rite_flight.bind(flyer, target, rite_id, circle))


func _finish_rite_flight(
	flyer: Sprite2D,
	target: RiteSlot,
	rite_id: StringName,
	circle: SummoningCircle
) -> void:
	if is_instance_valid(flyer):
		flyer.queue_free()
	if circle == null or not is_instance_valid(circle):
		return
	if target == null or not is_instance_valid(target):
		return
	circle.fill_rite_slot(target, rite_id)


func _set_focused_slot(slot: ItemShopSlot) -> void:
	if _focused_slot == slot:
		return
	if _focused_slot != null and is_instance_valid(_focused_slot):
		_focused_slot.set_focused(false)
	_focused_slot = slot
	if _focused_slot != null:
		_focused_slot.set_focused(true)
	_prompt_cache_key = ""


func _find_nearest_stocked_slot() -> ItemShopSlot:
	var best_slot: ItemShopSlot = null
	var best_dist_sq: float = INF
	for player_variant in Players.all(get_tree()):
		if player_variant == null or not is_instance_valid(player_variant):
			continue
		if not (player_variant is Node2D):
			continue
		var origin: Vector2 = (player_variant as Node2D).global_position
		for slot in _glyph_slots:
			if slot == null or not slot.is_stocked():
				continue
			if not _is_within_interact_radius(origin, slot.global_position):
				continue
			var dist_sq: float = origin.distance_squared_to(slot.global_position)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best_slot = slot
		for slot in _rite_slots:
			if slot == null or not slot.is_stocked():
				continue
			if not _is_within_interact_radius(origin, slot.global_position):
				continue
			var dist_sq: float = origin.distance_squared_to(slot.global_position)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best_slot = slot
	return best_slot


## Ellipse check: `slot_interact_radius.x` horizontal, `.y` vertical.
func _is_within_interact_radius(from: Vector2, to: Vector2) -> bool:
	var rx: float = maxf(slot_interact_radius.x, 0.001)
	var ry: float = maxf(slot_interact_radius.y, 0.001)
	var delta: Vector2 = to - from
	var nx: float = delta.x / rx
	var ny: float = delta.y / ry
	return nx * nx + ny * ny <= 1.0


func _find_circle() -> SummoningCircle:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("summoning_circle")
	for node in nodes:
		if node is SummoningCircle:
			return node as SummoningCircle
	return null


func _world_ysort_parent() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return self
	var y_sort: Node = scene.get_node_or_null("%WorldYSort")
	if y_sort == null:
		y_sort = scene.get_node_or_null("WorldYSort")
	if y_sort != null:
		return y_sort
	return scene


func _prompt_prefers_keyboard_mouse() -> bool:
	if _focused_slot == null:
		return true
	var nearest: Node2D = Players.closest_to(get_tree(), _focused_slot.global_position)
	if nearest == null:
		return true
	var controls: Controls = nearest.get("controls") as Controls
	if controls == null:
		return true
	return controls.prefers_keyboard_mouse()


func _all_glyph_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row_variant in GameData.get_table(&"glyphs"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var id_s: String = String((row_variant as Dictionary).get("id", "")).strip_edges()
		if not id_s.is_empty():
			ids.append(StringName(id_s))
	return ids


func _active_rite_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row_variant in GameData.get_table(&"rites"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant as Dictionary
		if row.get("active") != true:
			continue
		var id_s: String = String(row.get("id", "")).strip_edges()
		if not id_s.is_empty():
			ids.append(StringName(id_s))
	return ids


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
