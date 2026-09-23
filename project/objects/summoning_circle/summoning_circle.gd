class_name SummoningCircle
extends Node2D

signal mana_deposited(amount: float, total: float)
signal mana_spent(amount: float, total: float)
signal activated
signal deactivated
signal ritual_started(orb: RigidBody2D)
signal ritual_ended
signal new_blank_orb_requested
signal transform_requested(orb_id: StringName, by: Node)

const GLYPH_SCENE := preload("res://items/glyphs/glyph.tscn")
const MAX_ORBS := 5
const BLANK_ORB_COST_PER_EXISTING := 20.0
const MANA_BY_RARITY: Dictionary = {
	Glyph.Rarity.COMMON: 5.0,
	Glyph.Rarity.RARE: 10.0,
	Glyph.Rarity.UNIQUE: 20.0,
}
const CAPTURE_GRACE_SECONDS := 0.35
const COMMIT_STAGGER := 0.1
const COMMIT_FLY_DURATION := 0.1
const COMMIT_PEAK_TO_LAUNCH := 0.2
const COMMIT_CAMERA_KICK_PX := 2.0
const SOCKET_NOTE_D4: SoundEvent = preload("res://objects/summoning_circle/add_glyph_sfx/socket_note_d4.tres")
const SOCKET_NOTE_FS4: SoundEvent = preload("res://objects/summoning_circle/add_glyph_sfx/socket_note_fs4.tres")
const SOCKET_NOTE_A4: SoundEvent = preload("res://objects/summoning_circle/add_glyph_sfx/socket_note_a4.tres")
## Name-row hint tints match each element's glyph fill.
var HINT_ELEMENT_MODULATE: Dictionary = {
	"Fire": Color.html("#a53030"),
	"Water": Color.html("#4f8fba"),
	"Air": Color.html("#c7cfcc"),
	"Earth": Color.html("#ad7757"),
}

@export var activation_step: float = 5.0
@export var blink_color: Color = Color(0.55, 0.4, 0.95, 1.0)
@export var blink_duration: float = 0.35
@export var orb_capture_suck_speed: float = 240.0
## Tiny player-detect radius around each world glyph socket for Cross place/remove.
@export var socket_interact_radius: float = 16.0

var mana_pool: float = 0.0

var _activation_count: int = 0
var _active: bool = false
var _ritual_running: bool = false
var _captured_orb: RigidBody2D = null
var _players_inside: Dictionary = {}
## Players inside InfoProximityArea (larger than DepositArea); drives OrbInfo and input prompts.
var _players_near_info: Dictionary = {}
var _blink_tween: Tween
var _capture_tween: Tween
var _capture_grace_orbs: Dictionary = {}
var _glyph_sockets: Array[Sprite2D] = []
var _glyph_icons: Array[Sprite2D] = []
var _glyph_icon_home: Array[Vector2] = []
var _socket_notes: Array[SoundEvent] = []
## Attribute-row Fire/Water/Air/Earth hints — kept in the scene, hidden for now.
var _hint_labels: Array[Label] = []
## Name-row HintContainer (%Hint1–%Hint4), same element order as OrbRecipes.ELEMENTS.
var _name_hint_labels: Array[Label] = []
## Cache so _refresh_input_prompts does not rebuild SpriteFrames every frame.
var _prompt_cache_key: String = ""
var _commit_busy: bool = false
var _commit_trail_nodes: Array[Node] = []
var _arcane_default_material: ParticleProcessMaterial

@onready var deposit_area: Area2D = %DepositArea
@onready var info_proximity_area: Area2D = %InfoProximityArea
@onready var mana_pool_label: Label = %ManaPoolLabel
@onready var sprite: Sprite2D = %Sprite2D
@onready var arcane_particles: GPUParticles2D = %ArcaneParticles
@onready var orb_info: Control = %OrbInfo
@onready var orb_name_label: Label = %OrbNameLabel
@onready var hint_arrow: TextureRect = %HintArrow
@onready var transform_section: VBoxContainer = %TransformSection
@onready var hint_1: Label = %Hint1
@onready var hint_2: Label = %Hint2
@onready var hint_3: Label = %Hint3
@onready var hint_4: Label = %Hint4
@onready var effect_label: Label = %EffectLabel
@onready var damage_box: AttributeBox = %DamageBox
@onready var self_damage_box: AttributeBox = %SelfDamageBox
@onready var crit_chance_box: AttributeBox = %CritChanceBox
@onready var crit_damage_box: AttributeBox = %CritDamageBox
@onready var speed_box: AttributeBox = %SpeedBox
@onready var weight_box: AttributeBox = %WeightBox
@onready var splash_box: AttributeBox = %SplashBox
@onready var glyph_drop_box: AttributeBox = %GlyphDropBox
@onready var burn_box: AttributeBox = %BurnBox
@onready var chill_box: AttributeBox = %ChillBox
@onready var shock_box: AttributeBox = %ShockBox
@onready var blight_box: AttributeBox = %BlightBox
@onready var fire_hint: Label = %FireHint
@onready var water_hint: Label = %WaterHint
@onready var air_hint: Label = %AirHint
@onready var earth_hint: Label = %EarthHint
@onready var glyph_slots: Node2D = %GlyphSlots
@onready var glyph_socket_1: Sprite2D = %GlyphSocket1
@onready var glyph_socket_2: Sprite2D = %GlyphSocket2
@onready var glyph_socket_3: Sprite2D = %GlyphSocket3
@onready var glyph_icon_1: Sprite2D = %GlyphIcon1
@onready var glyph_icon_2: Sprite2D = %GlyphIcon2
@onready var glyph_icon_3: Sprite2D = %GlyphIcon3
@onready var prompt_stack: VBoxContainer = %PromptStack
@onready var prompt_buy: InputPrompt = %PromptBuy
@onready var prompt_activate: InputPrompt = %PromptActivate
@onready var prompt_cancel: InputPrompt = %PromptCancel
@onready var prompt_commit: InputPrompt = %PromptCommit


func _ready() -> void:
	add_to_group("summoning_circle")
	arcane_particles.emitting = false
	_arcane_default_material = arcane_particles.process_material as ParticleProcessMaterial
	_glyph_sockets = [glyph_socket_1, glyph_socket_2, glyph_socket_3]
	_glyph_icons = [glyph_icon_1, glyph_icon_2, glyph_icon_3]
	_glyph_icon_home.clear()
	for icon in _glyph_icons:
		_glyph_icon_home.append(icon.position)
	_socket_notes = [SOCKET_NOTE_D4, SOCKET_NOTE_FS4, SOCKET_NOTE_A4]
	_hint_labels = [fire_hint, water_hint, air_hint, earth_hint]
	_name_hint_labels = [hint_1, hint_2, hint_3, hint_4]
	orb_info.visible = false
	glyph_slots.visible = false
	_hide_hints()
	_refresh_mana_label()
	_refresh_input_prompts()
	deposit_area.body_entered.connect(_on_deposit_area_body_entered)
	deposit_area.body_exited.connect(_on_deposit_area_body_exited)
	deposit_area.area_entered.connect(_on_deposit_area_area_entered)
	info_proximity_area.body_entered.connect(_on_info_proximity_body_entered)
	info_proximity_area.body_exited.connect(_on_info_proximity_body_exited)


func _process(_delta: float) -> void:
	_prune_capture_grace()
	_poll_ritual_input()
	if _ritual_running:
		_refresh_orb_info(false)
	_refresh_input_prompts()


## Apply editor-authored starting mana; starting glyphs convert straight to mana.
func apply_start_config(mana: float, entries: Array) -> void:
	mana_pool = maxf(mana, 0.0)
	for entry_variant in entries:
		var rarity: int = Glyph.Rarity.COMMON
		if entry_variant is GlyphEntryConfig:
			rarity = int((entry_variant as GlyphEntryConfig).rarity)
		elif typeof(entry_variant) == TYPE_DICTIONARY:
			rarity = int((entry_variant as Dictionary).get("rarity", Glyph.Rarity.COMMON))
		else:
			continue
		mana_pool += float(MANA_BY_RARITY.get(rarity, 5.0))
	_refresh_mana_label()
	_refresh_input_prompts()
	mana_deposited.emit(0.0, mana_pool)


func get_launch_origin() -> Vector2:
	return deposit_area.global_position


func is_active() -> bool:
	return _active


func is_ritual_running() -> bool:
	return _ritual_running


func get_activation_cost() -> float:
	return activation_step * float(_activation_count)


func get_blank_orb_cost() -> float:
	return float(_live_orb_count()) * BLANK_ORB_COST_PER_EXISTING


func contains_player(player: Node) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return _players_inside.has(player)


func deposit(amount: float) -> void:
	if amount <= 0.0:
		return
	mana_pool += amount
	_refresh_mana_label()
	_refresh_input_prompts()
	mana_deposited.emit(amount, mana_pool)


func spend(amount: float) -> bool:
	if amount <= 0.0 or mana_pool < amount:
		return false
	mana_pool -= amount
	_refresh_mana_label()
	_refresh_input_prompts()
	mana_spent.emit(amount, mana_pool)
	return true


func try_activate() -> bool:
	if _active or _ritual_running:
		return false
	var cost: float = get_activation_cost()
	# First activation is free (cost 0); spend() rejects amount <= 0.
	if cost > 0.0 and not spend(cost):
		return false
	_activation_count += 1
	_active = true
	_start_activation_vfx()
	activated.emit()
	return true


func deactivate() -> void:
	if not _active:
		return
	_active = false
	_stop_activation_vfx()
	deactivated.emit()


func receive_glyph(glyph: Node) -> void:
	if glyph == null or not is_instance_valid(glyph):
		return
	if not glyph.has_method("get_mana_value"):
		return
	deposit(float(glyph.call("get_mana_value")))


## Stubs kept so legacy RitualMenu drag paths compile; circle no longer stores glyphs.
func add_inventory_entry(_glyph_id: StringName, _rarity: int) -> bool:
	return false


func insert_inventory_entry(_index: int, _glyph_id: StringName, _rarity: int) -> bool:
	return false


func remove_inventory_entry(_index: int) -> Dictionary:
	return {}


## Live ritual: Cross near a socket places a carried glyph into that slot, or picks one out.
## Returns true when the press was consumed by the ritual.
func try_handle_ritual_pickup(player: Node) -> bool:
	if not _ritual_running or player == null or not is_instance_valid(player):
		return false
	if _commit_busy:
		return true
	if not glyph_slots.visible:
		return false
	var slot_index: int = _find_nearest_socket_for_player(player)
	if slot_index < 0:
		return false
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	if orb == null:
		return false

	if player.has_method("is_carrying_item") and player.is_carrying_item():
		var carried: Glyph = player.get_carried_item() as Glyph
		if carried == null or not is_instance_valid(carried):
			return false
		if orb.has_glyph_at(slot_index):
			return false
		var before: Dictionary = _displayed_stat_snapshot(orb)
		var glyph_id: StringName = carried.glyph_id
		var rarity: int = int(carried.rarity)
		if not orb.apply_glyph_at(slot_index, glyph_id, rarity):
			return false
		if player.has_method("clear_carried_item"):
			player.clear_carried_item(carried)
		carried.queue_free()
		_play_socket_note(slot_index)
		_refresh_orb_info(true)
		_flash_stat_deltas(before, _displayed_stat_snapshot(orb))
		_update_ready_idle()
		return true

	if not orb.has_glyph_at(slot_index):
		return false
	var before_remove: Dictionary = _displayed_stat_snapshot(orb)
	var entry: Dictionary = orb.remove_glyph(slot_index)
	if entry.is_empty():
		return false
	var spawned: Glyph = _spawn_glyph_for_player(
		player,
		StringName(String(entry.get("id", ""))),
		int(entry.get("rarity", Glyph.Rarity.COMMON))
	)
	if spawned == null:
		# Put the glyph back if the player could not take it.
		orb.apply_glyph_at(slot_index, StringName(String(entry.get("id", ""))), int(entry.get("rarity", 0)))
		return false
	_refresh_orb_info(true)
	_flash_stat_deltas(before_remove, _displayed_stat_snapshot(orb))
	_update_ready_idle()
	return true


func capture_orb(orb: RigidBody2D) -> void:
	if not _active or _ritual_running or orb == null or not is_instance_valid(orb):
		return
	if _capture_grace_orbs.has(orb.get_instance_id()):
		return
	if not orb.has_method("is_flying") or not orb.is_flying():
		return
	if not orb.has_method("begin_circle_capture"):
		return

	_ritual_running = true
	_captured_orb = orb
	orb.begin_circle_capture(get_launch_origin(), orb_capture_suck_speed, _on_orb_capture_finished)


func _on_orb_capture_finished() -> void:
	if _captured_orb == null or not is_instance_valid(_captured_orb):
		_ritual_running = false
		_captured_orb = null
		_hide_ritual_ui()
		return
	_show_ritual_ui()
	ritual_started.emit(_captured_orb)


func release_orb(direction: Vector2 = Vector2.ZERO, by: Node = null) -> void:
	_clear_ready_idle()
	_restore_arcane_particles()
	_clear_commit_trails()
	if _captured_orb == null or not is_instance_valid(_captured_orb):
		_ritual_running = false
		_captured_orb = null
		_commit_busy = false
		_hide_ritual_ui()
		deactivate()
		ritual_ended.emit()
		return

	var orb: RigidBody2D = _captured_orb
	_captured_orb = null
	_ritual_running = false
	_commit_busy = false
	_hide_ritual_ui()
	_reset_glyph_icon_homes()

	var exit_dir: Vector2 = direction
	if exit_dir.length_squared() < 0.0001:
		exit_dir = Vector2.from_angle(randf() * TAU)
	if orb is BlankOrb:
		(orb as BlankOrb).clear_commit_visuals()
	grant_capture_grace(orb)
	if orb.has_method("release_from_circle"):
		orb.release_from_circle(exit_dir, by)
	deactivate()
	ritual_ended.emit()


func get_captured_orb() -> RigidBody2D:
	return _captured_orb if is_instance_valid(_captured_orb) else null


func is_commit_busy() -> bool:
	return _commit_busy


## Replace the captured orb during a ritual (e.g. Transform) without ending the ritual.
func swap_captured_orb(new_orb: RigidBody2D) -> void:
	if not _ritual_running or new_orb == null or not is_instance_valid(new_orb):
		return
	_captured_orb = new_orb
	if new_orb.has_method("assume_circle_capture"):
		new_orb.assume_circle_capture(get_launch_origin())
	_refresh_orb_info(true)


## Stage a Transformed orb mid-commit (no launch). Legacy menu still uses commit_transformed_orb.
func stage_transformed_orb(new_orb: RigidBody2D) -> void:
	if not _ritual_running or new_orb == null or not is_instance_valid(new_orb):
		return
	_captured_orb = new_orb
	if new_orb.has_method("assume_circle_capture"):
		new_orb.assume_circle_capture(get_launch_origin())
	if new_orb is BlankOrb:
		(new_orb as BlankOrb).snap_to_commit_white()


## Swap in the transformed orb, then launch it and end the ritual.
func commit_transformed_orb(new_orb: RigidBody2D, by: Node = null) -> void:
	if not _ritual_running or new_orb == null or not is_instance_valid(new_orb):
		return
	# Do not assume_circle_capture: that defers collision_layer/mask to 0, and a
	# same-frame release restores them only for the deferred zeros to wipe walls.
	_captured_orb = new_orb
	release_orb(Vector2.ZERO, by)


func grant_capture_grace(orb: Node, seconds: float = CAPTURE_GRACE_SECONDS) -> void:
	if orb == null or not is_instance_valid(orb):
		return
	_capture_grace_orbs[orb.get_instance_id()] = Time.get_ticks_msec() + int(seconds * 1000.0)


func notify_orb_count_changed() -> void:
	_refresh_input_prompts()


func _poll_ritual_input() -> void:
	var seen: Dictionary = {}
	for player_variant in _players_inside.keys():
		_handle_ritual_player_input(player_variant as Node, true)
		seen[player_variant] = true
	# Glyph sockets sit outside DepositArea (~33 px vs radius 22). Transform / bake /
	# cancel / waiting-disarm (prompts use InfoProximityArea) must still work from there.
	for player_variant in _players_near_info.keys():
		if seen.has(player_variant):
			continue
		_handle_ritual_player_input(player_variant as Node, false)


func _handle_ritual_player_input(player: Node, in_deposit: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	var controls: Controls = player.get("controls") as Controls
	if controls == null:
		return

	# Triangle / F: arm from DepositArea; Transform/bake from InfoProximityArea during capture.
	if controls.is_activate_just_pressed():
		if in_deposit:
			try_activate()
		if _ritual_running and not _commit_busy:
			_try_commit_upgrade(player)
	# Square / E: buy blank while idle or waiting (same DepositArea range as activate).
	if in_deposit and controls.is_upgrade_just_pressed() and not _ritual_running:
		_try_buy_blank_orb()
	# Circle / C: disarm waiting (no mana refund) or release captured orb.
	if controls.is_ritual_cancel_just_pressed():
		if _commit_busy:
			return
		if _ritual_running:
			release_orb(Vector2.ZERO, player)
		elif _active:
			deactivate()


func _try_buy_blank_orb() -> void:
	var live_count: int = _live_orb_count()
	if live_count >= MAX_ORBS:
		return
	var cost: float = get_blank_orb_cost()
	if cost > 0.0 and not spend(cost):
		return
	if cost <= 0.0 and live_count == 0:
		# Zero orbs → free first blank (cost formula is count × 20).
		pass
	new_blank_orb_requested.emit()
	_refresh_input_prompts()


func _try_commit_upgrade(player: Node) -> void:
	if _commit_busy:
		return
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	if orb == null or orb.socketed_count() < 3:
		return
	var elements: Array[String] = OrbRecipes.elements_from_socketed(orb.socketed_glyphs)
	var row: Dictionary = OrbRecipes.result_for(orb, elements)
	var is_transform: bool = OrbRecipes.is_playable(row)
	var orb_id: StringName = &""
	if is_transform:
		orb_id = StringName(String(row.get("id", "")))
		if orb_id.is_empty():
			return
	_run_commit_sequence(player, is_transform, orb_id)


func _run_commit_sequence(player: Node, is_transform: bool, orb_id: StringName) -> void:
	_commit_busy = true
	_prompt_cache_key = ""
	_refresh_input_prompts()
	_clear_ready_idle_visuals_only()
	_start_commit_particle_suck()

	var bake_attrs: Array[String] = []
	if not is_transform:
		bake_attrs = _socketed_attribute_keys(get_captured_orb() as BlankOrb)

	for i in _glyph_icons.size():
		if i > 0:
			await get_tree().create_timer(COMMIT_STAGGER).timeout
			if not _ensure_commit_still_valid():
				return
		_start_glyph_fly_in(i)

	# Last glyph started at 0.2s; wait its flight so peak lands at ~0.3s.
	await get_tree().create_timer(COMMIT_FLY_DURATION).timeout
	if not _ensure_commit_still_valid():
		return

	if is_transform:
		await _finish_transform_commit(player, orb_id)
	else:
		await _finish_bake_commit(player, bake_attrs)


func _ensure_commit_still_valid() -> bool:
	if _commit_busy and _ritual_running and is_instance_valid(self):
		return true
	_commit_busy = false
	_restore_arcane_particles()
	_clear_commit_trails()
	return false


func _finish_transform_commit(player: Node, orb_id: StringName) -> void:
	var old_orb: BlankOrb = get_captured_orb() as BlankOrb
	if old_orb != null:
		old_orb.play_commit_flash(1.0, 0.05, 0.01)
	_burst_commit_particles()
	_kick_camera()
	transform_requested.emit(orb_id, player)

	await get_tree().process_frame
	if not _ensure_commit_still_valid():
		return

	var new_orb: BlankOrb = get_captured_orb() as BlankOrb
	if new_orb == null:
		_commit_busy = false
		return

	new_orb.begin_transform_bloom(0.12)
	var launch_dir: Vector2 = Vector2.from_angle(randf() * TAU)
	new_orb.play_commit_squash_stretch(launch_dir, 0.12)
	await get_tree().create_timer(COMMIT_PEAK_TO_LAUNCH).timeout
	if not _ensure_commit_still_valid():
		return
	release_orb(launch_dir, player)


func _finish_bake_commit(player: Node, bake_attrs: Array[String]) -> void:
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	if orb == null:
		_commit_busy = false
		return
	orb.play_commit_flash(0.55, 0.04, 0.12)
	_burst_commit_particles()
	_flash_attribute_keys(bake_attrs)
	orb.bake_socketed_glyphs()
	_hide_all_glyph_icons()
	await get_tree().create_timer(COMMIT_PEAK_TO_LAUNCH).timeout
	if not _ensure_commit_still_valid():
		return
	release_orb(Vector2.ZERO, player)


func _hide_all_glyph_icons() -> void:
	for i in _glyph_icons.size():
		var icon: Sprite2D = _glyph_icons[i]
		icon.visible = false
		icon.texture = null
		icon.scale = Vector2.ONE
		icon.position = _glyph_icon_home[i] if i < _glyph_icon_home.size() else Vector2.ZERO


func _show_ritual_ui() -> void:
	glyph_slots.visible = true
	_update_ritual_ui_proximity()
	_refresh_orb_info(true)
	_update_ready_idle()


func _hide_ritual_ui() -> void:
	_clear_ready_idle()
	orb_info.visible = false
	glyph_slots.visible = false
	_hide_hints()
	_refresh_input_prompts()


## OrbInfo (ritual) and input prompts only while a player is in InfoProximityArea.
func _update_ritual_ui_proximity() -> void:
	orb_info.visible = _ritual_running and not _players_near_info.is_empty()
	if orb_info.visible:
		_refresh_orb_info(true)
	_refresh_input_prompts()


func _refresh_orb_info(_force_slots: bool = true) -> void:
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	if orb == null:
		return
	var preview: Dictionary = _playable_transform_row(orb)
	if preview.is_empty():
		orb_name_label.text = orb.get_display_name().to_upper()
		effect_label.text = _effect_text_for_orb(orb)
		_apply_stats(orb.get_stat_snapshot())
	else:
		orb_name_label.text = String(preview.get("name", orb.get_display_name())).to_upper()
		effect_label.text = OrbRecipes.effect_text(preview)
		_apply_stats(OrbRecipes.stats_from_row(preview))
	_refresh_hints(orb)
	_refresh_glyph_slot_icons(orb)


## Playable 3-glyph recipe for the captured orb, or {} if Transform is not available.
func _playable_transform_row(orb: BlankOrb) -> Dictionary:
	if orb == null or orb.socketed_count() != 3:
		return {}
	var elements: Array[String] = OrbRecipes.elements_from_socketed(orb.socketed_glyphs)
	var row: Dictionary = OrbRecipes.result_for(orb, elements)
	if OrbRecipes.is_playable(row):
		return row
	return {}


func _displayed_stat_snapshot(orb: BlankOrb) -> Dictionary:
	var preview: Dictionary = _playable_transform_row(orb)
	if preview.is_empty():
		return orb.get_stat_snapshot()
	return OrbRecipes.stats_from_row(preview)


## Two socketed glyphs: hide the orb name and show Transform names (or ???) on HintContainer.
## Name shows at 0 / 1 / 3 glyphs. HintArrow stays hidden for now.
func _refresh_hints(orb: BlankOrb) -> void:
	hint_arrow.visible = false
	if orb == null or orb.socketed_count() != 2:
		_hide_hints()
		return
	var elements: Array[String] = OrbRecipes.elements_from_socketed(orb.socketed_glyphs)
	var hints: Array = OrbRecipes.hints_for(orb, elements)
	for i in _name_hint_labels.size():
		var name_hint: Label = _name_hint_labels[i]
		name_hint.visible = true
		if i < hints.size():
			var name_entry: Dictionary = hints[i]
			name_hint.text = String(name_entry.get("label", "???")).to_upper()
			name_hint.modulate = _hint_modulate_for(String(name_entry.get("element", "")))
		else:
			name_hint.text = "???"
			name_hint.modulate = Color.WHITE
	orb_name_label.visible = false
	transform_section.visible = true


func _hide_hints() -> void:
	for hint_label in _hint_labels:
		hint_label.visible = false
		hint_label.text = "???"
	for name_hint in _name_hint_labels:
		name_hint.visible = false
		name_hint.text = "???"
		name_hint.modulate = Color.WHITE
	hint_arrow.visible = false
	transform_section.visible = false
	orb_name_label.visible = true


func _hint_modulate_for(element: String) -> Color:
	var tint: Color = HINT_ELEMENT_MODULATE.get(element, Color.WHITE) as Color
	return tint


func _apply_stats(stats: Dictionary) -> void:
	damage_box.value = float(stats.get("damage", 0.0))
	self_damage_box.value = float(stats.get("self_damage", 0.0))
	crit_chance_box.value = float(stats.get("crit_chance", 0.0))
	crit_damage_box.value = float(stats.get("crit_damage", 0.0))
	speed_box.value = float(stats.get("speed", 0.0))
	weight_box.value = float(stats.get("weight", 0.0))
	splash_box.value = float(stats.get("splash", 0.0))
	glyph_drop_box.value = float(stats.get("glyph_drop", 0.0))
	burn_box.value = float(stats.get("burn", 0.0))
	chill_box.value = float(stats.get("chill", 0.0))
	shock_box.value = float(stats.get("shock", 0.0))
	blight_box.value = float(stats.get("blight", 0.0))


func _flash_stat_deltas(before: Dictionary, after: Dictionary) -> void:
	var keys: Array[String] = [
		"damage", "self_damage", "crit_chance", "crit_damage", "speed", "weight",
		"splash", "glyph_drop", "burn", "chill", "shock", "blight",
	]
	var box_by_key: Dictionary = {
		"damage": damage_box,
		"self_damage": self_damage_box,
		"crit_chance": crit_chance_box,
		"crit_damage": crit_damage_box,
		"speed": speed_box,
		"weight": weight_box,
		"splash": splash_box,
		"glyph_drop": glyph_drop_box,
		"burn": burn_box,
		"chill": chill_box,
		"shock": shock_box,
		"blight": blight_box,
	}
	for key in keys:
		if not is_equal_approx(float(before.get(key, 0.0)), float(after.get(key, 0.0))):
			var box: AttributeBox = box_by_key.get(key) as AttributeBox
			if box != null:
				box.flash_value_changed()


func _refresh_glyph_slot_icons(orb: BlankOrb) -> void:
	if _commit_busy:
		return
	for i in _glyph_icons.size():
		var icon: Sprite2D = _glyph_icons[i]
		if orb.has_glyph_at(i):
			var entry: Dictionary = orb.socketed_glyphs[i]
			var glyph_id: StringName = StringName(String(entry.get("id", "")))
			icon.texture = Glyph.texture_for_id(glyph_id)
			icon.visible = icon.texture != null
		else:
			icon.texture = null
			icon.visible = false
	_update_ready_idle()


func _play_socket_note(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _socket_notes.size():
		return
	var event: SoundEvent = _socket_notes[slot_index]
	if event == null:
		return
	AudioManager.play_at(event, global_position)


func _update_ready_idle() -> void:
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	var ready: bool = (
		not _commit_busy
		and orb != null
		and is_instance_valid(orb)
		and orb.socketed_count() == 3
	)
	if ready:
		orb.set_ritual_ready_pulse(true)
	elif orb != null and is_instance_valid(orb):
		orb.set_ritual_ready_pulse(false)


func _clear_ready_idle() -> void:
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	if orb != null and is_instance_valid(orb):
		orb.set_ritual_ready_pulse(false)


func _clear_ready_idle_visuals_only() -> void:
	# Stop pulse for commit fly-in without resetting icon textures.
	var orb: BlankOrb = get_captured_orb() as BlankOrb
	if orb != null and is_instance_valid(orb):
		orb.set_ritual_ready_pulse(false)


func _reset_glyph_icon_homes() -> void:
	for i in _glyph_icons.size():
		var icon: Sprite2D = _glyph_icons[i]
		var home: Vector2 = _glyph_icon_home[i] if i < _glyph_icon_home.size() else Vector2.ZERO
		icon.position = home
		icon.modulate = Color.WHITE
		icon.scale = Vector2.ONE


func _start_glyph_fly_in(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _glyph_icons.size():
		return
	var icon: Sprite2D = _glyph_icons[slot_index]
	var socket: Sprite2D = _glyph_sockets[slot_index]
	if not icon.visible or icon.texture == null:
		# Empty gap: still chime on schedule so the triad resolves.
		var delay_tw: Tween = create_tween()
		delay_tw.tween_interval(COMMIT_FLY_DURATION)
		delay_tw.tween_callback(_play_socket_note.bind(slot_index))
		return

	var start_global: Vector2 = icon.global_position
	var end_local: Vector2 = -socket.position
	var texture: Texture2D = icon.texture
	_spawn_glyph_trails(texture, start_global, socket.to_global(end_local))

	var fly_tw: Tween = create_tween()
	fly_tw.set_trans(Tween.TRANS_CUBIC)
	fly_tw.set_ease(Tween.EASE_IN)
	fly_tw.tween_property(icon, "position", end_local, COMMIT_FLY_DURATION)
	fly_tw.parallel().tween_property(icon, "scale", Vector2(0.55, 0.55), COMMIT_FLY_DURATION)
	fly_tw.tween_callback(func() -> void:
		icon.visible = false
		icon.texture = null
		icon.position = _glyph_icon_home[slot_index] if slot_index < _glyph_icon_home.size() else Vector2.ZERO
		icon.scale = Vector2.ONE
		_play_socket_note(slot_index)
	)


func _spawn_glyph_trails(texture: Texture2D, from_global: Vector2, to_global: Vector2) -> void:
	if texture == null:
		return
	for step in 3:
		var t: float = float(step + 1) / 4.0
		var pos: Vector2 = from_global.lerp(to_global, t)
		var delay: float = COMMIT_FLY_DURATION * t * 0.85
		var trail_tw: Tween = create_tween()
		trail_tw.tween_interval(delay)
		trail_tw.tween_callback(_spawn_one_glyph_trail.bind(texture, pos))


func _spawn_one_glyph_trail(texture: Texture2D, global_pos: Vector2) -> void:
	if not is_inside_tree() or texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.z_as_relative = false
	ghost.z_index = 2
	ghost.modulate = Color(1, 1, 1, 0.65)
	glyph_slots.add_child(ghost)
	ghost.global_position = global_pos
	_commit_trail_nodes.append(ghost)
	var fade_tw: Tween = create_tween()
	fade_tw.tween_property(ghost, "modulate:a", 0.0, 0.14)
	fade_tw.parallel().tween_property(ghost, "scale", Vector2(0.4, 0.4), 0.14)
	fade_tw.tween_callback(func() -> void:
		_commit_trail_nodes.erase(ghost)
		if is_instance_valid(ghost):
			ghost.queue_free()
	)


func _clear_commit_trails() -> void:
	for node in _commit_trail_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_commit_trail_nodes.clear()


func _start_commit_particle_suck() -> void:
	if _arcane_default_material == null:
		return
	var mat: ParticleProcessMaterial = _arcane_default_material.duplicate() as ParticleProcessMaterial
	mat.radial_accel_min = -120.0
	mat.radial_accel_max = -60.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 18.0
	arcane_particles.process_material = mat
	arcane_particles.emitting = true


func _burst_commit_particles() -> void:
	if _arcane_default_material == null:
		return
	var mat: ParticleProcessMaterial = _arcane_default_material.duplicate() as ParticleProcessMaterial
	mat.radial_accel_min = 40.0
	mat.radial_accel_max = 90.0
	mat.initial_velocity_min = 28.0
	mat.initial_velocity_max = 55.0
	arcane_particles.process_material = mat
	arcane_particles.restart()
	arcane_particles.emitting = true
	var stop_tw: Tween = create_tween()
	stop_tw.tween_interval(0.25)
	stop_tw.tween_callback(_restore_arcane_particles)


func _restore_arcane_particles() -> void:
	if _arcane_default_material != null:
		arcane_particles.process_material = _arcane_default_material
	if not _active:
		arcane_particles.emitting = false


func _kick_camera() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var base_offset: Vector2 = cam.offset
	cam.offset = base_offset + Vector2(COMMIT_CAMERA_KICK_PX, 0.0)
	var kick_tw: Tween = create_tween()
	kick_tw.tween_property(cam, "offset", base_offset, 0.08)


func _socketed_attribute_keys(orb: BlankOrb) -> Array[String]:
	var keys: Array[String] = []
	if orb == null:
		return keys
	for i in orb.socketed_glyphs.size():
		if not orb.has_glyph_at(i):
			continue
		var entry: Dictionary = orb.socketed_glyphs[i]
		var glyph_id: StringName = StringName(String(entry.get("id", "")))
		var row: Variant = GameData.get_row(&"glyphs", glyph_id)
		if row == null or typeof(row) != TYPE_DICTIONARY:
			continue
		var attr: String = String((row as Dictionary).get("attribute", ""))
		if attr == "poison":
			attr = "blight"
		if not attr.is_empty() and not keys.has(attr):
			keys.append(attr)
	return keys


func _flash_attribute_keys(keys: Array[String]) -> void:
	var box_by_key: Dictionary = {
		"damage": damage_box,
		"self_damage": self_damage_box,
		"crit_chance": crit_chance_box,
		"crit_damage": crit_damage_box,
		"speed": speed_box,
		"weight": weight_box,
		"splash": splash_box,
		"glyph_drop": glyph_drop_box,
		"burn": burn_box,
		"chill": chill_box,
		"shock": shock_box,
		"blight": blight_box,
	}
	for key in keys:
		var box: AttributeBox = box_by_key.get(key) as AttributeBox
		if box != null:
			box.flash_value_changed()


func _effect_text_for_orb(orb: BlankOrb) -> String:
	var row: Variant = GameData.get_row(&"orbs", orb.orb_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return ""
	return OrbRecipes.effect_text(row as Dictionary)


## Nearest world glyph socket within `socket_interact_radius`, or -1 if none.
func _find_nearest_socket_for_player(player: Node) -> int:
	if player == null or not (player is Node2D):
		return -1
	var origin: Vector2 = (player as Node2D).global_position
	var radius_sq: float = socket_interact_radius * socket_interact_radius
	var best_index: int = -1
	var best_dist_sq: float = INF
	for i in _glyph_sockets.size():
		var dist_sq: float = origin.distance_squared_to(_glyph_sockets[i].global_position)
		if dist_sq > radius_sq:
			continue
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index


func _spawn_glyph_for_player(player: Node, glyph_id: StringName, rarity: int) -> Glyph:
	if glyph_id.is_empty():
		return null
	if not player.has_method("pick_up_item"):
		return null
	var glyph: Glyph = GLYPH_SCENE.instantiate() as Glyph
	if glyph == null:
		return null
	var items_parent: Node = get_tree().current_scene.get_node_or_null("%Items")
	if items_parent == null:
		items_parent = get_tree().current_scene
	items_parent.add_child(glyph)
	glyph.setup(glyph_id, rarity as Glyph.Rarity)
	glyph.global_position = (player as Node2D).global_position if player is Node2D else global_position
	if not player.pick_up_item(glyph):
		glyph.queue_free()
		return null
	return glyph


func _live_orb_count() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("orb"):
		if is_instance_valid(node):
			count += 1
	return count


func _refresh_input_prompts() -> void:
	if _players_near_info.is_empty():
		if not _prompt_cache_key.is_empty():
			_prompt_cache_key = ""
			_hide_input_prompts()
		return

	var keyboard_mouse: bool = _prompt_prefers_keyboard_mouse()
	var show_buy: bool = (
		not _ritual_running
		and _live_orb_count() < MAX_ORBS
		and _any_near_info_in_deposit()
	)
	var show_activate: bool = (
		not _ritual_running
		and not _active
		and _any_near_info_in_deposit()
	)
	var show_cancel: bool = _active or _ritual_running
	var cancel_text: String = "Release" if _ritual_running else "Cancel"
	var show_commit: bool = false
	var commit_text: String = "Bake"
	if _ritual_running and not _commit_busy:
		var orb: BlankOrb = get_captured_orb() as BlankOrb
		if orb != null and orb.socketed_count() >= 3:
			show_commit = true
			if not _playable_transform_row(orb).is_empty():
				commit_text = "Transform"

	var activate_cost: float = get_activation_cost()
	var buy_cost: int = int(get_blank_orb_cost())
	var cache_key: String = "%s|%s|%s|%s|%s|%s|%d|%d|%s" % [
		keyboard_mouse,
		show_buy,
		show_activate,
		show_cancel,
		show_commit,
		cancel_text,
		buy_cost,
		int(activate_cost),
		commit_text,
	]
	if cache_key == _prompt_cache_key:
		return
	_prompt_cache_key = cache_key

	var any_visible: bool = false

	if show_buy:
		prompt_buy.visible = true
		prompt_buy.configure_action(
			&"upgrade",
			"Buy Blank Orb (%d mana)" % buy_cost,
			keyboard_mouse
		)
		any_visible = true
	else:
		prompt_buy.visible = false

	if show_activate:
		var activate_text: String = "Activate"
		if activate_cost > 0.0:
			activate_text = "Activate\n(%d mana)" % int(activate_cost)
		prompt_activate.visible = true
		prompt_activate.configure_action(&"activate", activate_text, keyboard_mouse)
		any_visible = true
	else:
		prompt_activate.visible = false

	if show_cancel:
		prompt_cancel.visible = true
		prompt_cancel.configure_action(&"ritual_cancel", cancel_text, keyboard_mouse)
		any_visible = true
	else:
		prompt_cancel.visible = false

	if show_commit:
		prompt_commit.visible = true
		prompt_commit.configure_action(&"activate", commit_text, keyboard_mouse)
		any_visible = true
	else:
		prompt_commit.visible = false

	prompt_stack.visible = any_visible


func _hide_input_prompts() -> void:
	prompt_stack.visible = false
	prompt_buy.visible = false
	prompt_activate.visible = false
	prompt_cancel.visible = false
	prompt_commit.visible = false


func _prompt_prefers_keyboard_mouse() -> bool:
	var nearest: Node = _nearest_player_near_info()
	if nearest == null:
		return true
	var controls: Controls = nearest.get("controls") as Controls
	if controls == null:
		return true
	return controls.prefers_keyboard_mouse()


func _nearest_player_near_info() -> Node:
	var origin: Vector2 = global_position
	var best: Node = null
	var best_dist_sq: float = INF
	for player_variant in _players_near_info.keys():
		var player: Node = player_variant as Node
		if player == null or not is_instance_valid(player) or not (player is Node2D):
			continue
		var dist_sq: float = origin.distance_squared_to((player as Node2D).global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = player
	return best


func _any_near_info_in_deposit() -> bool:
	for player_variant in _players_near_info.keys():
		if _players_inside.has(player_variant):
			return true
	return false


func _refresh_mana_label() -> void:
	mana_pool_label.text = str(int(mana_pool))


func _start_activation_vfx() -> void:
	arcane_particles.emitting = true
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(sprite, "modulate", blink_color, blink_duration)
	_blink_tween.tween_property(sprite, "modulate", Color.WHITE, blink_duration)


func _stop_activation_vfx() -> void:
	arcane_particles.emitting = false
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	sprite.modulate = Color.WHITE


func _prune_capture_grace() -> void:
	if _capture_grace_orbs.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var expired: Array = []
	for id in _capture_grace_orbs.keys():
		if now >= int(_capture_grace_orbs[id]):
			expired.append(id)
	for id in expired:
		_capture_grace_orbs.erase(id)


func _on_deposit_area_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_players_inside[body] = true
	_try_deposit_glyph(_resolve_glyph(body))
	_try_capture_orb_body(body)


func _on_deposit_area_body_exited(body: Node2D) -> void:
	if body != null:
		_players_inside.erase(body)


func _on_info_proximity_body_entered(body: Node2D) -> void:
	if body != null and body.is_in_group("player"):
		_players_near_info[body] = true
		_update_ritual_ui_proximity()


func _on_info_proximity_body_exited(body: Node2D) -> void:
	if body != null:
		_players_near_info.erase(body)
		_update_ritual_ui_proximity()


func _on_deposit_area_area_entered(area: Area2D) -> void:
	_try_deposit_glyph(_resolve_glyph(area))
	_try_capture_orb_area(area)


func _resolve_glyph(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.is_in_group("glyphs"):
		return node
	var parent := node.get_parent()
	if parent != null and parent.is_in_group("glyphs"):
		return parent
	if node.owner != null and node.owner.is_in_group("glyphs"):
		return node.owner
	return null


func _try_deposit_glyph(glyph: Node) -> void:
	if glyph == null or not is_instance_valid(glyph):
		return
	# Mana conversion only when no orb is captured; sockets use Cross instead.
	if _ritual_running:
		return
	if glyph.has_method("deposit_into"):
		glyph.deposit_into(self)


func _try_capture_orb_body(body: Node2D) -> void:
	if body == null or not body.is_in_group("orb"):
		return
	if body is RigidBody2D:
		capture_orb(body as RigidBody2D)


func _try_capture_orb_area(area: Area2D) -> void:
	if area == null:
		return
	var owner_node: Node = area.owner
	if owner_node is RigidBody2D and owner_node.is_in_group("orb"):
		capture_orb(owner_node as RigidBody2D)
		return
	var parent := area.get_parent()
	while parent != null:
		if parent is RigidBody2D and parent.is_in_group("orb"):
			capture_orb(parent as RigidBody2D)
			return
		parent = parent.get_parent()
