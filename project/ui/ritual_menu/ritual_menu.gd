class_name RitualMenu
extends CanvasLayer

signal closed
signal inspect_closed
signal new_blank_orb_requested
signal transform_requested(orb_id: StringName)

const MAX_ORBS := 3
const DROP_RECYCLE := 0
const DROP_SLOT_0 := 1
const DROP_SLOT_1 := 2
const DROP_SLOT_2 := 3
const DROP_INV_0 := 4
const DROP_INV_1 := 5
const DROP_INV_2 := 6
## Stick must pass this strength to take one menu step, then return below it for the next.
const ANALOG_NAV_DEADZONE := 0.55
## Held drag preview is darkened vs focus outline / rune glow.
const HELD_PREVIEW_DARKEN := Color(0.65, 0.65, 0.65, 1.0)

enum MenuMode {
	RITUAL,
	INSPECT,
}

enum FocusZone {
	INV_GLYPH,
	INV_ORB,
	RECYCLE,
	ORB_SLOT,
	TRANSFORM,
	HINT,
	BUY,
	DONE,
}

@onready var panel: ColorRect = %Panel
@onready var orb_name_label: Label = %OrbNameLabel
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
@onready var poison_box: AttributeBox = %PoisonBox
@onready var orb_slots_container: HBoxContainer = %OrbSlotsContainer
@onready var orb_slot_1: TextureRect = %OrbSlot1
@onready var orb_slot_2: TextureRect = %OrbSlot2
@onready var orb_slot_3: TextureRect = %OrbSlot3
@onready var recycle_column: VBoxContainer = %Recycle
@onready var recycle_socket: TextureRect = %RecycleSocket
@onready var recycle_label: Label = %RecycleLabel
@onready var transform_section: VBoxContainer = %TransformSection
@onready var transform_button: Button = %TransformButton
@onready var hint_container: GridContainer = %HintContainer
@onready var hint_1: Label = %Hint1
@onready var hint_2: Label = %Hint2
@onready var hint_3: Label = %Hint3
@onready var hint_4: Label = %Hint4
@onready var buy_column: VBoxContainer = %BuyBlankOrb
@onready var buy_button: Button = %BuyButton
@onready var buy_label: Label = %BuyLabel
@onready var done_button: Button = %DoneButton
@onready var inventory: OrbInventoryBar = %Inventory
@onready var drag_preview: Panel = %DragPreview
@onready var drag_icon: TextureRect = %DragIcon

var _menu_mode: MenuMode = MenuMode.RITUAL
var _orb: BlankOrb = null
var _circle: SummoningCircle = null
var _orbs: Array = []
var _new_orb_cost: float = 20.0
var _orb_slots: Array[TextureRect] = []
var _hint_labels: Array[Label] = []
var _hint_outlines: Array[Panel] = []
var _hint_data: Array[Dictionary] = []
var _slot_icons: Array[TextureRect] = []
var _slot_outlines: Array[Panel] = []
var _stat_boxes: Array[AttributeBox] = []
var _hint_label_settings_normal: LabelSettings = null
var _hint_label_settings_large: LabelSettings = null

## Held glyph: from inventory index, or from an orb slot (-1 / -1 = nothing held).
var _held_inv_index: int = -1
var _held_orb_slot: int = -1
var _held_entry: Dictionary = {}
var _target_index: int = DROP_SLOT_0
var _dragging_mouse: bool = false
## Mouse-hovered hint index (-1 = none). Wins over controller HINT focus for preview.
var _hovered_hint_index: int = -1

var _focus_zone: FocusZone = FocusZone.INV_GLYPH
var _focus_index: int = 0
## True after an analog flick until the left stick recenters (one step per flick).
var _analog_nav_latched: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_orb_slots = [orb_slot_1, orb_slot_2, orb_slot_3]
	_hint_labels = [hint_1, hint_2, hint_3, hint_4]
	_stat_boxes = [
		damage_box, self_damage_box, crit_chance_box, crit_damage_box,
		speed_box, weight_box, splash_box, glyph_drop_box,
		burn_box, chill_box, shock_box, poison_box,
	]
	_hint_label_settings_normal = hint_1.label_settings
	if _hint_label_settings_normal != null:
		_hint_label_settings_large = _hint_label_settings_normal.duplicate()
		_hint_label_settings_large.font_size = 16
	for i in _orb_slots.size():
		var slot: TextureRect = _orb_slots[i]
		_ensure_slot_icon(slot)
		_slot_icons.append(slot.get_node("Icon") as TextureRect)
		_slot_outlines.append(_ensure_outline(slot))
		slot.gui_input.connect(_on_orb_slot_gui_input.bind(i))
	for i in _hint_labels.size():
		var hint_label: Label = _hint_labels[i]
		hint_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_hint_outlines.append(_ensure_outline(hint_label))
		hint_label.mouse_entered.connect(_on_hint_hover.bind(i, true))
		hint_label.mouse_exited.connect(_on_hint_hover.bind(i, false))
	_ensure_outline(recycle_socket)
	_center_panel()
	visible = false
	drag_preview.visible = false
	done_button.pressed.connect(_on_done_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	transform_button.pressed.connect(_on_transform_pressed)
	inventory.glyph_grab_requested.connect(_on_inventory_glyph_grab)
	inventory.orb_selected.connect(_on_inventory_orb_selected)


func _center_panel() -> void:
	var designed_size: Vector2 = _editor_panel_size()
	designed_size.x = maxf(designed_size.x, 1.0)
	designed_size.y = maxf(designed_size.y, 1.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.45
	panel.offset_left = -designed_size.x * 0.5
	panel.offset_top = -designed_size.y * 0.5
	panel.offset_right = designed_size.x * 0.5
	panel.offset_bottom = designed_size.y * 0.5


func _editor_panel_size() -> Vector2:
	var editor_parent := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height")),
	)
	return Vector2(
		(panel.anchor_right - panel.anchor_left) * editor_parent.x + (panel.offset_right - panel.offset_left),
		(panel.anchor_bottom - panel.anchor_top) * editor_parent.y + (panel.offset_bottom - panel.offset_top),
	)


func open(orb: RigidBody2D, circle: SummoningCircle, new_orb_cost: float = 20.0, orbs: Array = []) -> void:
	_menu_mode = MenuMode.RITUAL
	_orb = orb as BlankOrb
	_circle = circle
	_new_orb_cost = new_orb_cost
	_orbs = orbs.duplicate()
	_cancel_drag()
	_hovered_hint_index = -1
	visible = true
	_set_economy_columns_visible(true)
	inventory.set_orbs_selectable(false)
	inventory.set_glyphs_interactive(true)
	_focus_zone = FocusZone.INV_GLYPH
	_focus_index = 0
	# Ignore a stick that was already deflected from walking into the circle.
	_analog_nav_latched = _move_stick().length() >= ANALOG_NAV_DEADZONE

	_connect_circle_signals()

	buy_label.text = "Blank Orb\n(%d mana)" % int(_new_orb_cost)
	_refresh_ui()
	_apply_focus_visuals()


func open_inspect(circle: SummoningCircle, orbs: Array = []) -> void:
	_menu_mode = MenuMode.INSPECT
	_circle = circle
	_orbs = orbs.duplicate()
	_orb = null
	for candidate in _orbs:
		if is_instance_valid(candidate):
			_orb = candidate as BlankOrb
			break
	_cancel_drag()
	_hovered_hint_index = -1
	visible = true
	_set_economy_columns_visible(false)
	inventory.set_orbs_selectable(true)
	inventory.set_glyphs_interactive(false)
	_focus_zone = FocusZone.INV_ORB if _count_live_orbs() > 0 else FocusZone.DONE
	_focus_index = 0
	_analog_nav_latched = _move_stick().length() >= ANALOG_NAV_DEADZONE

	_connect_circle_signals()
	_refresh_ui()
	_apply_focus_visuals()


func is_inspect_mode() -> bool:
	return _menu_mode == MenuMode.INSPECT


func close_menu() -> void:
	_cancel_drag()
	_hovered_hint_index = -1
	_hint_data.clear()
	_disconnect_circle_signals()
	inventory.set_orbs_selectable(false)
	inventory.set_glyphs_interactive(true)
	inventory.set_orb_menu_focus(false)
	_set_economy_columns_visible(true)
	_orb = null
	_circle = null
	_orbs.clear()
	_menu_mode = MenuMode.RITUAL
	visible = false


func set_orbs(orbs: Array) -> void:
	_orbs = orbs.duplicate()
	if visible:
		_refresh_inventory_bar()
		_apply_focus_visuals()


func _connect_circle_signals() -> void:
	if _circle == null:
		return
	if not _circle.inventory_changed.is_connected(_refresh_ui):
		_circle.inventory_changed.connect(_refresh_ui)
	if not _circle.mana_deposited.is_connected(_on_mana_changed):
		_circle.mana_deposited.connect(_on_mana_changed)
	if not _circle.mana_spent.is_connected(_on_mana_changed):
		_circle.mana_spent.connect(_on_mana_changed)


func _disconnect_circle_signals() -> void:
	if _circle == null or not is_instance_valid(_circle):
		return
	if _circle.inventory_changed.is_connected(_refresh_ui):
		_circle.inventory_changed.disconnect(_refresh_ui)
	if _circle.mana_deposited.is_connected(_on_mana_changed):
		_circle.mana_deposited.disconnect(_on_mana_changed)
	if _circle.mana_spent.is_connected(_on_mana_changed):
		_circle.mana_spent.disconnect(_on_mana_changed)


func _set_economy_columns_visible(show_economy: bool) -> void:
	recycle_column.visible = show_economy
	buy_column.visible = show_economy
	transform_section.visible = show_economy


func _process(_delta: float) -> void:
	if not visible or not _is_holding():
		return
	if _dragging_mouse:
		_update_drag_preview_position(get_viewport().get_mouse_position())
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_mouse_drop()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		_on_done_pressed()
		get_viewport().set_input_as_handled()
		return
	if _is_holding() and _dragging_mouse:
		return
	if _menu_mode == MenuMode.INSPECT:
		_input_inspect(event)
		return

	if event.is_action_pressed("dash"):
		_on_controller_confirm()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tether"):
		if _is_holding():
			_cancel_drag()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadMotion:
		_handle_analog_nav()
		return

	if event.is_action_pressed("move_up"):
		_apply_menu_nav(Vector2.UP)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down"):
		_apply_menu_nav(Vector2.DOWN)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left"):
		_apply_menu_nav(Vector2.LEFT)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		_apply_menu_nav(Vector2.RIGHT)
		get_viewport().set_input_as_handled()
		return


func _input_inspect(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		_on_controller_confirm()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadMotion:
		_handle_analog_nav()
		return

	if event.is_action_pressed("move_up"):
		_apply_menu_nav(Vector2.UP)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down"):
		_apply_menu_nav(Vector2.DOWN)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left"):
		_apply_menu_nav(Vector2.LEFT)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		_apply_menu_nav(Vector2.RIGHT)
		get_viewport().set_input_as_handled()
		return


func _is_holding() -> bool:
	return _held_inv_index >= 0 or _held_orb_slot >= 0


func _move_stick() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _handle_analog_nav() -> void:
	var stick: Vector2 = _move_stick()
	if stick.length() < ANALOG_NAV_DEADZONE:
		_analog_nav_latched = false
		return
	if _analog_nav_latched:
		get_viewport().set_input_as_handled()
		return
	_analog_nav_latched = true
	var dir: Vector2
	if absf(stick.x) >= absf(stick.y):
		dir = Vector2.RIGHT if stick.x > 0.0 else Vector2.LEFT
	else:
		dir = Vector2.DOWN if stick.y > 0.0 else Vector2.UP
	_apply_menu_nav(dir)
	get_viewport().set_input_as_handled()


func _apply_menu_nav(dir: Vector2) -> void:
	if _menu_mode == MenuMode.INSPECT:
		_navigate_inspect_focus(dir)
		return
	if _is_holding():
		if dir == Vector2.UP:
			_snap_to_first_empty_orb_slot()
		elif dir == Vector2.DOWN:
			_target_index = DROP_INV_0
			_place_preview_on_target()
			_refresh_drop_target_outline()
		elif dir == Vector2.LEFT:
			_move_drop_target(-1)
		elif dir == Vector2.RIGHT:
			_move_drop_target(1)
		return
	_navigate_focus(dir)


func _on_mana_changed(_amount: float, _total: float) -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if _circle == null or not is_instance_valid(_circle):
		return

	if _orb != null and is_instance_valid(_orb):
		_refresh_orb_slots()
		if _menu_mode == MenuMode.RITUAL:
			_refresh_hints()
			_refresh_transform()
			_refresh_buy()
			recycle_label.text = "Drop to\nrecycle"
		else:
			_hide_hints()
		_apply_orb_info_display()
	else:
		orb_name_label.text = ""
		effect_label.text = ""
		for box in _stat_boxes:
			box.unknown = false
			box.value = 0.0
		for i in _slot_icons.size():
			_slot_icons[i].visible = false
			_slot_icons[i].texture = null
			Glyph.clear_rarity_visual(_slot_icons[i])
		_hide_hints()

	_refresh_inventory_bar()
	_apply_focus_visuals()


func _refresh_stats() -> void:
	_apply_stats_from_dict(_orb.get_stat_snapshot())


func _apply_stats_from_dict(stats: Dictionary) -> void:
	for box in _stat_boxes:
		box.unknown = false
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
	poison_box.value = float(stats.get("poison", 0.0))


func _set_stats_unknown() -> void:
	for box in _stat_boxes:
		box.unknown = true


func _hints_visible() -> bool:
	return hint_container.visible


func _active_hint_preview_index() -> int:
	if _is_holding():
		return -1
	if _hovered_hint_index >= 0:
		return _hovered_hint_index
	if _focus_zone == FocusZone.HINT:
		return _focus_index
	return -1


func _apply_orb_info_display() -> void:
	var preview_index: int = _active_hint_preview_index()
	if preview_index >= 0 and preview_index < _hint_data.size():
		_apply_hint_preview(_hint_data[preview_index])
		return
	_show_current_orb_info()


func _show_current_orb_info() -> void:
	if _orb == null or not is_instance_valid(_orb):
		return
	orb_name_label.text = _orb.get_display_name().to_upper()
	effect_label.text = _effect_text_for_orb(_orb)
	_refresh_stats()


func _apply_hint_preview(hint: Dictionary) -> void:
	var label: String = String(hint.get("label", "???"))
	var row: Dictionary = hint.get("row", {}) as Dictionary
	var discovered: bool = bool(hint.get("discovered", false))
	if label == "???" or not discovered or row.is_empty():
		orb_name_label.text = "???"
		effect_label.text = "???"
		_set_stats_unknown()
		return

	orb_name_label.text = String(row.get("name", "???")).to_upper()
	var effect: String = String(row.get("effect", ""))
	if effect.is_empty():
		effect = String(row.get("desc", ""))
	effect_label.text = effect if not effect.is_empty() else "???"

	# Orb recipe rows carry the 12 stats; attunements do not — keep live orb stats.
	if row.has("damage") or row.has("speed") or row.has("self_damage"):
		_apply_stats_from_dict(row)
	else:
		_refresh_stats()


func _on_hint_hover(index: int, active: bool) -> void:
	if active and (index < 0 or index >= _hint_labels.size() or not _hint_labels[index].visible):
		return
	if active:
		_hovered_hint_index = index
	elif _hovered_hint_index == index:
		_hovered_hint_index = -1
	_apply_orb_info_display()
	_apply_focus_visuals()


func _refresh_orb_slots() -> void:
	for i in _orb_slots.size():
		var icon: TextureRect = _slot_icons[i]
		# Hide the slot being dragged so it does not look duplicated.
		if i == _held_orb_slot:
			icon.visible = false
			icon.texture = null
			Glyph.clear_rarity_visual(icon)
			continue
		if _orb.has_glyph_at(i):
			var entry: Dictionary = _orb.socketed_glyphs[i]
			var glyph_id: StringName = StringName(String(entry.get("id", "")))
			var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
			icon.visible = true
			icon.texture = _texture_for_glyph_id(glyph_id)
			icon.modulate = Color.WHITE
			Glyph.apply_rarity_visual(icon, rarity)
		else:
			icon.visible = false
			icon.texture = null
			Glyph.clear_rarity_visual(icon)
	_refresh_drop_target_outline()


func _refresh_inventory_bar() -> void:
	inventory.set_orbs(_orbs, _orb)
	inventory.set_glyphs(_circle.glyph_inventory, _held_inv_index)
	inventory.set_mana(_circle.mana_pool)


func _refresh_hints() -> void:
	var count: int = _orb.socketed_count()
	_hint_data.clear()

	if count == 2:
		_show_four_hints()
		return

	if count == 3:
		var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
		var row: Dictionary = OrbRecipes.result_for(_orb, elements)
		if not row.is_empty():
			_show_single_result_hint(row)
			return

	_hide_hints()


func _hide_hints() -> void:
	hint_container.visible = false
	_hovered_hint_index = -1
	if _focus_zone == FocusZone.HINT:
		_focus_zone = FocusZone.TRANSFORM if _menu_mode == MenuMode.RITUAL else FocusZone.DONE
		_focus_index = 0
	hint_container.columns = 2
	for i in _hint_labels.size():
		_hint_labels[i].visible = true
		_hint_labels[i].text = "???"
		if _hint_label_settings_normal != null:
			_hint_labels[i].label_settings = _hint_label_settings_normal


func _show_four_hints() -> void:
	hint_container.visible = true
	hint_container.columns = 2
	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var hints: Array = OrbRecipes.hints_for(_orb, elements)
	for i in _hint_labels.size():
		_hint_labels[i].visible = true
		if _hint_label_settings_normal != null:
			_hint_labels[i].label_settings = _hint_label_settings_normal
		if i < hints.size():
			var hint: Dictionary = hints[i]
			_hint_data.append(hint)
			_hint_labels[i].text = String(hint.get("label", "???")).to_upper()
		else:
			_hint_labels[i].text = "???"
			_hint_data.append({"label": "???", "row": {}, "discovered": false})


func _show_single_result_hint(row: Dictionary) -> void:
	hint_container.visible = true
	hint_container.columns = 1
	var row_id: StringName = StringName(String(row.get("id", "")))
	var discovered: bool = OrbRecipes.is_discovered(row_id)
	var label_text: String = "???"
	if discovered:
		label_text = String(row.get("name", "???"))
	var hint := {
		"label": label_text,
		"row": row,
		"discovered": discovered,
	}
	_hint_data.append(hint)
	hint_1.visible = true
	hint_1.text = label_text.to_upper()
	if _hint_label_settings_large != null:
		hint_1.label_settings = _hint_label_settings_large
	elif _hint_label_settings_normal != null:
		hint_1.label_settings = _hint_label_settings_normal
	for i in range(1, _hint_labels.size()):
		_hint_labels[i].visible = false
		_hint_labels[i].text = "???"
		if _hint_label_settings_normal != null:
			_hint_labels[i].label_settings = _hint_label_settings_normal
	if _hovered_hint_index > 0:
		_hovered_hint_index = -1
	if _focus_zone == FocusZone.HINT:
		_focus_index = 0


func _is_single_result_hint() -> bool:
	return _hint_data.size() == 1


func _refresh_transform() -> void:
	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var can_transform: bool = (
		_orb.socketed_count() >= 3
		and OrbRecipes.is_playable(OrbRecipes.result_for(_orb, elements))
	)
	transform_button.disabled = not can_transform


func _refresh_buy() -> void:
	var orb_count: int = _count_live_orbs()
	buy_button.disabled = _circle.mana_pool < _new_orb_cost or orb_count >= MAX_ORBS


func _count_live_orbs() -> int:
	var count: int = 0
	for orb in _orbs:
		if is_instance_valid(orb):
			count += 1
	return count


func _effect_text_for_orb(orb: BlankOrb) -> String:
	var row: Variant = GameData.get_row(&"orbs", orb.orb_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return ""
	return String((row as Dictionary).get("effect", ""))


func _on_inventory_glyph_grab(index: int) -> void:
	if _menu_mode == MenuMode.INSPECT:
		return
	_begin_drag_from_inventory(index, true)


func _on_inventory_orb_selected(index: int) -> void:
	if _menu_mode != MenuMode.INSPECT:
		return
	_select_inspect_orb(index)


func _select_inspect_orb(index: int) -> void:
	if index < 0 or index >= _orbs.size():
		return
	var candidate: Variant = _orbs[index]
	if not is_instance_valid(candidate):
		return
	_orb = candidate as BlankOrb
	_focus_zone = FocusZone.INV_ORB
	_focus_index = index
	_refresh_ui()


func _on_orb_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if _menu_mode == MenuMode.INSPECT:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if _orb == null or not _orb.has_glyph_at(slot_index):
		return
	get_viewport().set_input_as_handled()
	_begin_drag_from_orb_slot(slot_index, true)


func _begin_drag_from_inventory(index: int, from_mouse: bool) -> void:
	if _menu_mode == MenuMode.INSPECT:
		return
	if _circle == null or index < 0 or index >= _circle.glyph_inventory.size():
		return
	_held_inv_index = index
	_held_orb_slot = -1
	_held_entry = _circle.glyph_inventory[index].duplicate()
	_dragging_mouse = from_mouse
	_target_index = DROP_SLOT_0
	_show_drag_preview(_held_entry)
	inventory.set_held_glyph_index(_held_inv_index)
	_refresh_inventory_bar()
	if from_mouse:
		_update_drag_preview_position(get_viewport().get_mouse_position())
	else:
		_snap_to_first_empty_orb_slot()
	_refresh_drop_target_outline()


func _begin_drag_from_orb_slot(slot_index: int, from_mouse: bool) -> void:
	if _menu_mode == MenuMode.INSPECT:
		return
	if _orb == null or not _orb.has_glyph_at(slot_index):
		return
	var entry: Dictionary = _orb.remove_glyph(slot_index)
	if entry.is_empty():
		return
	_held_inv_index = -1
	_held_orb_slot = slot_index
	_held_entry = entry
	_dragging_mouse = from_mouse
	# Start on the slot it came from so confirm-to-grab leaves it highlighted and movable.
	_target_index = DROP_SLOT_0 + slot_index
	_show_drag_preview(_held_entry)
	_refresh_stats()
	_refresh_orb_slots()
	_refresh_hints()
	_refresh_transform()
	if from_mouse:
		_update_drag_preview_position(get_viewport().get_mouse_position())
	else:
		_place_preview_on_target()
	_refresh_drop_target_outline()


func _show_drag_preview(entry: Dictionary) -> void:
	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
	drag_icon.texture = _texture_for_glyph_id(glyph_id)
	Glyph.apply_rarity_visual(drag_icon, rarity)
	drag_icon.modulate = HELD_PREVIEW_DARKEN
	drag_preview.visible = true


func _cancel_drag() -> void:
	# If we pulled a glyph off an orb slot, put it back in that slot.
	if _held_orb_slot >= 0 and not _held_entry.is_empty() and _orb != null and is_instance_valid(_orb):
		var glyph_id: StringName = StringName(String(_held_entry.get("id", "")))
		var rarity: int = int(_held_entry.get("rarity", Glyph.Rarity.COMMON))
		if not _orb.apply_glyph_at(_held_orb_slot, glyph_id, rarity):
			_orb.apply_glyph(glyph_id, rarity)
	_held_inv_index = -1
	_held_orb_slot = -1
	_held_entry = {}
	_dragging_mouse = false
	_target_index = DROP_SLOT_0
	drag_preview.visible = false
	inventory.set_held_glyph_index(-1)
	if visible and _orb != null and _circle != null:
		_refresh_ui()
	else:
		_refresh_drop_target_outline()


func _update_drag_preview_position(pos: Vector2) -> void:
	drag_preview.global_position = pos - drag_preview.size * 0.5


func _finish_mouse_drop() -> void:
	if not _is_holding():
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var target: int = _hit_test_drop_target(mouse_pos)
	if target >= 0:
		_resolve_drop(target)
	else:
		_cancel_drag()


func _hit_test_drop_target(pos: Vector2) -> int:
	var targets: Array[Control] = _drop_target_controls()
	for i in targets.size():
		var control: Control = targets[i]
		if control == null:
			continue
		var rect := Rect2(control.global_position, control.size)
		if rect.has_point(pos):
			return i
	return -1


func _drop_target_controls() -> Array[Control]:
	return [
		recycle_socket,
		orb_slot_1,
		orb_slot_2,
		orb_slot_3,
		inventory.get_glyph_socket(0),
		inventory.get_glyph_socket(1),
		inventory.get_glyph_socket(2),
	]


func _on_controller_confirm() -> void:
	if _menu_mode == MenuMode.INSPECT:
		match _focus_zone:
			FocusZone.INV_ORB:
				_select_inspect_orb(_focus_index)
			FocusZone.DONE:
				_on_done_pressed()
			_:
				pass
		return

	if _is_holding():
		_resolve_drop(_target_index)
		return

	match _focus_zone:
		FocusZone.INV_GLYPH:
			_begin_drag_from_inventory(_focus_index, false)
		FocusZone.ORB_SLOT:
			if _orb != null and _orb.has_glyph_at(_focus_index):
				_begin_drag_from_orb_slot(_focus_index, false)
		FocusZone.TRANSFORM:
			if not transform_button.disabled:
				_on_transform_pressed()
		FocusZone.BUY:
			if not buy_button.disabled:
				_on_buy_pressed()
		FocusZone.DONE:
			_on_done_pressed()
		FocusZone.HINT, FocusZone.RECYCLE, FocusZone.INV_ORB:
			pass
		_:
			pass


func _navigate_inspect_focus(dir: Vector2) -> void:
	var orb_count: int = _count_live_orbs()
	match _focus_zone:
		FocusZone.INV_ORB:
			if dir.y < 0.0:
				_focus_zone = FocusZone.DONE
				_focus_index = 0
			elif dir.x < 0.0:
				_focus_index = maxi(_focus_index - 1, 0)
				if orb_count > 0:
					_select_inspect_orb(_focus_index)
					return
			elif dir.x > 0.0:
				_focus_index = mini(_focus_index + 1, maxi(orb_count - 1, 0))
				if orb_count > 0:
					_select_inspect_orb(_focus_index)
					return
		FocusZone.DONE:
			if dir.y > 0.0 and orb_count > 0:
				_focus_zone = FocusZone.INV_ORB
				_focus_index = 0
				_select_inspect_orb(_focus_index)
				return
		_:
			_focus_zone = FocusZone.INV_ORB if orb_count > 0 else FocusZone.DONE
			_focus_index = 0
	_apply_orb_info_display()
	_apply_focus_visuals()


func _navigate_focus(dir: Vector2) -> void:
	match _focus_zone:
		FocusZone.INV_GLYPH:
			if dir.x < 0.0:
				_focus_index = maxi(_focus_index - 1, 0)
			elif dir.x > 0.0:
				var max_g: int = maxi((_circle.glyph_inventory.size() if _circle else 1) - 1, 0)
				_focus_index = mini(_focus_index + 1, max_g)
			elif dir.y < 0.0:
				if _hints_visible():
					_focus_zone = FocusZone.HINT
					if _is_single_result_hint():
						_focus_index = 0
					else:
						# Prefer bottom row under the glyph index (0/1 → 2/3).
						_focus_index = 2 if _focus_index <= 0 else 3
				else:
					_focus_zone = FocusZone.ORB_SLOT
					_focus_index = mini(_focus_index, 2)
			inventory.set_controller_glyph_index(_focus_index)
		FocusZone.RECYCLE:
			if dir.x > 0.0:
				_focus_zone = FocusZone.ORB_SLOT
				_focus_index = 0
			elif dir.y > 0.0:
				_focus_zone = FocusZone.INV_GLYPH
				_focus_index = 0
			elif dir.y < 0.0:
				_focus_zone = FocusZone.DONE
				_focus_index = 0
		FocusZone.ORB_SLOT:
			if dir.x < 0.0:
				if _focus_index <= 0:
					_focus_zone = FocusZone.RECYCLE
					_focus_index = 0
				else:
					_focus_index -= 1
			elif dir.x > 0.0:
				if _focus_index >= 2:
					_focus_zone = FocusZone.TRANSFORM
					_focus_index = 0
				else:
					_focus_index += 1
			elif dir.y > 0.0:
				_focus_zone = FocusZone.INV_GLYPH
				_focus_index = mini(_focus_index, maxi((_circle.glyph_inventory.size() if _circle else 1) - 1, 0))
			elif dir.y < 0.0:
				_focus_zone = FocusZone.DONE
				_focus_index = 0
		FocusZone.TRANSFORM:
			if dir.x < 0.0:
				_focus_zone = FocusZone.ORB_SLOT
				_focus_index = 2
			elif dir.x > 0.0:
				_focus_zone = FocusZone.BUY
				_focus_index = 0
			elif dir.y > 0.0:
				if _hints_visible():
					_focus_zone = FocusZone.HINT
					_focus_index = 0
				else:
					_focus_zone = FocusZone.INV_GLYPH
					_focus_index = 0
			elif dir.y < 0.0:
				_focus_zone = FocusZone.DONE
				_focus_index = 0
		FocusZone.HINT:
			if _is_single_result_hint():
				_focus_index = 0
				if dir.x < 0.0:
					_focus_zone = FocusZone.RECYCLE
					_focus_index = 0
				elif dir.x > 0.0:
					_focus_zone = FocusZone.BUY
					_focus_index = 0
				elif dir.y < 0.0:
					_focus_zone = FocusZone.TRANSFORM
					_focus_index = 0
				elif dir.y > 0.0:
					_focus_zone = FocusZone.INV_GLYPH
					_focus_index = mini(0, maxi((_circle.glyph_inventory.size() if _circle else 1) - 1, 0))
			elif dir.x < 0.0:
				if _focus_index == 0 or _focus_index == 2:
					_focus_zone = FocusZone.RECYCLE
					_focus_index = 0
				else:
					_focus_index -= 1
			elif dir.x > 0.0:
				if _focus_index == 1 or _focus_index == 3:
					_focus_zone = FocusZone.BUY
					_focus_index = 0
				else:
					_focus_index += 1
			elif dir.y < 0.0:
				if _focus_index <= 1:
					_focus_zone = FocusZone.TRANSFORM
					_focus_index = 0
				else:
					_focus_index -= 2
			elif dir.y > 0.0:
				if _focus_index <= 1:
					_focus_index += 2
				else:
					_focus_zone = FocusZone.INV_GLYPH
					_focus_index = mini(_focus_index - 2, maxi((_circle.glyph_inventory.size() if _circle else 1) - 1, 0))
		FocusZone.BUY:
			if dir.x < 0.0:
				_focus_zone = FocusZone.TRANSFORM
				_focus_index = 0
			elif dir.y > 0.0:
				_focus_zone = FocusZone.INV_GLYPH
				_focus_index = maxi((_circle.glyph_inventory.size() if _circle else 1) - 1, 0)
			elif dir.y < 0.0:
				_focus_zone = FocusZone.DONE
				_focus_index = 0
		FocusZone.DONE:
			if dir.y > 0.0:
				_focus_zone = FocusZone.ORB_SLOT
				_focus_index = 1
			elif dir.x < 0.0:
				_focus_zone = FocusZone.RECYCLE
				_focus_index = 0
			elif dir.x > 0.0:
				_focus_zone = FocusZone.BUY
				_focus_index = 0

	_apply_orb_info_display()
	_apply_focus_visuals()


func _apply_focus_visuals() -> void:
	var on_glyphs: bool = (
		_menu_mode == MenuMode.RITUAL
		and _focus_zone == FocusZone.INV_GLYPH
		and not _is_holding()
	)
	var on_orbs: bool = _menu_mode == MenuMode.INSPECT and _focus_zone == FocusZone.INV_ORB
	inventory.set_menu_focus(on_glyphs)
	inventory.set_orb_menu_focus(on_orbs)
	if on_glyphs:
		inventory.set_controller_glyph_index(_focus_index)
	if on_orbs:
		inventory.set_controller_orb_index(_focus_index)
	inventory.set_orbs(_orbs, _orb)

	for i in _slot_outlines.size():
		_slot_outlines[i].visible = (
			_menu_mode == MenuMode.RITUAL
			and not _is_holding()
			and _focus_zone == FocusZone.ORB_SLOT
			and i == _focus_index
		)

	var recycle_outline: Panel = recycle_socket.get_node_or_null("Outline") as Panel
	if recycle_outline:
		recycle_outline.visible = (
			_menu_mode == MenuMode.RITUAL
			and not _is_holding()
			and _focus_zone == FocusZone.RECYCLE
		)

	for i in _hint_outlines.size():
		var highlighted: bool = (
			_menu_mode == MenuMode.RITUAL
			and _hints_visible()
			and _hint_labels[i].visible
			and not _is_holding()
			and (
				_hovered_hint_index == i
				or (_hovered_hint_index < 0 and _focus_zone == FocusZone.HINT and i == _focus_index)
			)
		)
		_hint_outlines[i].visible = highlighted

	transform_button.modulate = (
		Color(1.35, 1.35, 1.35, 1.0)
		if _menu_mode == MenuMode.RITUAL and _focus_zone == FocusZone.TRANSFORM and not _is_holding()
		else Color.WHITE
	)
	buy_button.modulate = (
		Color(1.35, 1.35, 1.35, 1.0)
		if _menu_mode == MenuMode.RITUAL and _focus_zone == FocusZone.BUY and not _is_holding()
		else Color.WHITE
	)
	done_button.modulate = (
		Color(1.35, 1.35, 1.35, 1.0)
		if _focus_zone == FocusZone.DONE and not _is_holding()
		else Color.WHITE
	)


func _move_drop_target(delta: int) -> void:
	var prev_index: int = _target_index
	var max_target: int = DROP_INV_2
	_target_index = clampi(_target_index + delta, DROP_RECYCLE, max_target)
	if not _dragging_mouse:
		if _held_orb_slot >= 0 and _is_orb_drop_index(_target_index):
			_try_live_orb_swap(_target_index - DROP_SLOT_0)
		elif _held_inv_index >= 0 and _is_orb_drop_index(_target_index):
			if not _is_orb_drop_index(prev_index) and _first_empty_orb_slot() >= 0:
				# Entering the orb row: prefer an empty slot.
				_target_index = DROP_SLOT_0 + _first_empty_orb_slot()
			elif _is_orb_drop_index(prev_index):
				# Within orb slots: push the occupied glyph into the empty hole we left.
				_try_live_inv_orb_swap(prev_index - DROP_SLOT_0, _target_index - DROP_SLOT_0)
	_place_preview_on_target()
	_refresh_drop_target_outline()


func _is_orb_drop_index(index: int) -> bool:
	return index >= DROP_SLOT_0 and index <= DROP_SLOT_2


func _first_empty_orb_slot() -> int:
	if _orb == null:
		return -1
	for i in _orb.socketed_glyphs.size():
		if not _orb.has_glyph_at(i):
			return i
	return -1


func _move_occupied_into_hole(hole_slot: int, occupied_slot: int) -> bool:
	if _orb == null:
		return false
	if hole_slot < 0 or hole_slot >= _orb.socketed_glyphs.size():
		return false
	if occupied_slot < 0 or occupied_slot >= _orb.socketed_glyphs.size():
		return false
	if hole_slot == occupied_slot:
		return false
	if _orb.has_glyph_at(hole_slot):
		return false
	if not _orb.has_glyph_at(occupied_slot):
		return false

	var displaced: Dictionary = _orb.remove_glyph(occupied_slot)
	if displaced.is_empty():
		return false
	var displaced_id: StringName = StringName(String(displaced.get("id", "")))
	var displaced_rarity: int = int(displaced.get("rarity", Glyph.Rarity.COMMON))
	if not _orb.apply_glyph_at(hole_slot, displaced_id, displaced_rarity):
		_orb.apply_glyph_at(occupied_slot, displaced_id, displaced_rarity)
		return false
	return true


func _try_live_orb_swap(slot_index: int) -> void:
	if _held_orb_slot < 0 or _held_entry.is_empty():
		return
	if not _move_occupied_into_hole(_held_orb_slot, slot_index):
		return
	_held_orb_slot = slot_index
	_refresh_stats()
	_refresh_orb_slots()
	_refresh_hints()
	_refresh_transform()
	_show_drag_preview(_held_entry)


func _try_live_inv_orb_swap(hole_slot: int, occupied_slot: int) -> void:
	# Inventory-held: only live-swap when leaving an empty slot onto an occupied one.
	if _held_inv_index < 0 or _held_entry.is_empty():
		return
	if not _move_occupied_into_hole(hole_slot, occupied_slot):
		return
	_refresh_stats()
	_refresh_orb_slots()
	_refresh_hints()
	_refresh_transform()
	_show_drag_preview(_held_entry)


func _snap_to_first_empty_orb_slot() -> void:
	var open_index: int = _first_empty_orb_slot()
	if open_index < 0:
		open_index = 2
	_target_index = DROP_SLOT_0 + open_index
	_place_preview_on_target()
	_refresh_drop_target_outline()


func _place_preview_on_target() -> void:
	var targets: Array[Control] = _drop_target_controls()
	if _target_index < 0 or _target_index >= targets.size():
		return
	var target: Control = targets[_target_index]
	if target == null:
		return
	drag_preview.global_position = target.global_position + (target.size - drag_preview.size) * 0.5


func _refresh_drop_target_outline() -> void:
	var targets: Array[Control] = _drop_target_controls()
	for i in targets.size():
		var control: Control = targets[i]
		if control == null:
			continue
		if _is_holding() and i == _target_index and not _dragging_mouse:
			control.self_modulate = Color(1.4, 1.4, 1.4, 1.0)
		else:
			control.self_modulate = Color.WHITE


func _resolve_drop(target: int) -> void:
	if not _is_holding() or _circle == null or _orb == null:
		_cancel_drag()
		return

	var from_inv: int = _held_inv_index
	var from_slot: int = _held_orb_slot
	var entry: Dictionary = _held_entry.duplicate()
	# Clear hold flags before mutating so refresh doesn't hide slots incorrectly.
	_held_inv_index = -1
	_held_orb_slot = -1
	_held_entry = {}
	_dragging_mouse = false
	drag_preview.visible = false
	inventory.set_held_glyph_index(-1)

	if target == DROP_RECYCLE:
		if from_inv >= 0:
			_recycle_inventory_glyph(from_inv)
		elif not entry.is_empty():
			var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
			_circle.deposit(float(Glyph.MANA_BY_RARITY.get(rarity, 5.0)))
	elif target >= DROP_SLOT_0 and target <= DROP_SLOT_2:
		_resolve_slot_drop(target - DROP_SLOT_0, from_inv, from_slot, entry)
	elif target >= DROP_INV_0 and target <= DROP_INV_2:
		if from_slot >= 0 and not entry.is_empty():
			if not _circle.add_inventory_entry(
				StringName(String(entry.get("id", ""))),
				int(entry.get("rarity", Glyph.Rarity.COMMON))
			):
				# Inventory full — restore onto the original orb slot.
				_orb.apply_glyph_at(
					from_slot,
					StringName(String(entry.get("id", ""))),
					int(entry.get("rarity", Glyph.Rarity.COMMON))
				)
		elif from_inv >= 0:
			# Dropped back onto inventory — leave as-is.
			pass
	else:
		# Unknown target: restore.
		if from_slot >= 0 and not entry.is_empty():
			_orb.apply_glyph_at(
				from_slot,
				StringName(String(entry.get("id", ""))),
				int(entry.get("rarity", Glyph.Rarity.COMMON))
			)

	_refresh_ui()


func _resolve_slot_drop(slot_index: int, from_inv: int, from_slot: int, entry: Dictionary) -> void:
	if entry.is_empty():
		return

	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))

	# Same slot the held glyph came from — put it back.
	if from_slot == slot_index:
		_orb.apply_glyph_at(slot_index, glyph_id, rarity)
		return

	if not _orb.has_glyph_at(slot_index):
		if from_inv >= 0:
			_circle.remove_inventory_entry(from_inv)
		if not _orb.apply_glyph_at(slot_index, glyph_id, rarity):
			_restore_held_glyph(from_inv, from_slot, glyph_id, rarity)
		return

	# Occupied: swap the target glyph into the held glyph's origin.
	var displaced: Dictionary = _orb.remove_glyph(slot_index)
	if not _orb.apply_glyph_at(slot_index, glyph_id, rarity):
		# Restore displaced, then restore held.
		if not displaced.is_empty():
			_orb.apply_glyph_at(
				slot_index,
				StringName(String(displaced.get("id", ""))),
				int(displaced.get("rarity", Glyph.Rarity.COMMON))
			)
		_restore_held_glyph(from_inv, from_slot, glyph_id, rarity)
		return

	if from_inv >= 0:
		_circle.remove_inventory_entry(from_inv)
		if not displaced.is_empty():
			if not _circle.insert_inventory_entry(
				from_inv,
				StringName(String(displaced.get("id", ""))),
				int(displaced.get("rarity", Glyph.Rarity.COMMON))
			):
				# No room — put displaced back on the orb (held already landed).
				_orb.apply_glyph(
					StringName(String(displaced.get("id", ""))),
					int(displaced.get("rarity", Glyph.Rarity.COMMON))
				)
	elif from_slot >= 0:
		if not displaced.is_empty():
			if not _orb.apply_glyph_at(
				from_slot,
				StringName(String(displaced.get("id", ""))),
				int(displaced.get("rarity", Glyph.Rarity.COMMON))
			):
				_orb.apply_glyph(
					StringName(String(displaced.get("id", ""))),
					int(displaced.get("rarity", Glyph.Rarity.COMMON))
				)
	elif not displaced.is_empty():
		# No known origin — try inventory, else first open orb slot.
		if not _circle.add_inventory_entry(
			StringName(String(displaced.get("id", ""))),
			int(displaced.get("rarity", Glyph.Rarity.COMMON))
		):
			_orb.apply_glyph(
				StringName(String(displaced.get("id", ""))),
				int(displaced.get("rarity", Glyph.Rarity.COMMON))
			)


func _restore_held_glyph(from_inv: int, from_slot: int, glyph_id: StringName, rarity: int) -> void:
	if from_slot >= 0:
		if not _orb.apply_glyph_at(from_slot, glyph_id, rarity):
			_orb.apply_glyph(glyph_id, rarity)
	elif from_inv >= 0:
		if not _circle.insert_inventory_entry(from_inv, glyph_id, rarity):
			_circle.add_inventory_entry(glyph_id, rarity)
	else:
		_orb.apply_glyph(glyph_id, rarity)


func _recycle_inventory_glyph(index: int) -> void:
	if index < 0 or index >= _circle.glyph_inventory.size():
		return
	var entry: Dictionary = _circle.glyph_inventory[index]
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
	var mana_val: float = float(Glyph.MANA_BY_RARITY.get(rarity, 5.0))
	_circle.remove_inventory_entry(index)
	_circle.deposit(mana_val)


func _texture_for_glyph_id(glyph_id: StringName) -> Texture2D:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return Glyph.ELEMENT_TEXTURES["Fire"] as Texture2D
	var element: String = String((row as Dictionary).get("element", "Fire"))
	return Glyph.ELEMENT_TEXTURES.get(element, Glyph.ELEMENT_TEXTURES["Fire"]) as Texture2D


func _ensure_slot_icon(slot: TextureRect) -> void:
	if slot.has_node("Icon"):
		return
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.visible = false
	slot.add_child(icon)


func _ensure_outline(socket: Control) -> Panel:
	if socket.has_node("Outline"):
		return socket.get_node("Outline") as Panel
	var outline := Panel.new()
	outline.name = "Outline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.offset_left = -1.0
	outline.offset_top = -1.0
	outline.offset_right = 1.0
	outline.offset_bottom = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color.WHITE
	style.set_border_width_all(1)
	outline.add_theme_stylebox_override("panel", style)
	outline.visible = false
	socket.add_child(outline)
	return outline


func _on_buy_pressed() -> void:
	if _menu_mode == MenuMode.INSPECT:
		return
	if _circle == null or not _circle.spend(_new_orb_cost):
		return
	new_blank_orb_requested.emit()
	_refresh_ui()


func _on_transform_pressed() -> void:
	if _menu_mode == MenuMode.INSPECT:
		return
	if _orb == null:
		return
	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var row: Dictionary = OrbRecipes.result_for(_orb, elements)
	if not OrbRecipes.is_playable(row):
		return
	var orb_id: StringName = StringName(String(row.get("id", "")))
	transform_requested.emit(orb_id)


func _on_done_pressed() -> void:
	var was_inspect: bool = _menu_mode == MenuMode.INSPECT
	close_menu()
	if was_inspect:
		inspect_closed.emit()
	else:
		closed.emit()
