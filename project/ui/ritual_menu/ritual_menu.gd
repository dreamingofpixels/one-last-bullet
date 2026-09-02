class_name RitualMenu
extends CanvasLayer

signal closed
signal new_blank_orb_requested
signal transform_requested(orb_id: StringName)

const MAX_ORBS := 3
const DROP_RECYCLE := 0
const DROP_SLOT_0 := 1
const DROP_SLOT_1 := 2
const DROP_SLOT_2 := 3

@onready var panel: PanelContainer = %Panel
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
@onready var recycle_socket: TextureRect = %RecycleSocket
@onready var recycle_label: Label = %RecycleLabel
@onready var transform_button: Button = %TransformButton
@onready var hint_container: GridContainer = %HintContainer
@onready var hint_1: Label = %Hint1
@onready var hint_2: Label = %Hint2
@onready var hint_3: Label = %Hint3
@onready var hint_4: Label = %Hint4
@onready var hint_info_container: VBoxContainer = %HintInfoContainer
@onready var buy_button: Button = %BuyButton
@onready var buy_label: Label = %BuyLabel
@onready var done_button: Button = %DoneButton
@onready var inventory: OrbInventoryBar = %Inventory
@onready var drag_preview: Panel = %DragPreview
@onready var drag_icon: TextureRect = %DragIcon

var _orb: BlankOrb = null
var _circle: SummoningCircle = null
var _orbs: Array = []
var _new_orb_cost: float = 20.0
var _orb_slots: Array[TextureRect] = []
var _hint_labels: Array[Label] = []
var _slot_icons: Array[TextureRect] = []

var _held_index: int = -1
var _target_index: int = DROP_SLOT_0
var _dragging_mouse: bool = false
var _controller_mode: bool = false
var _showing_transform_preview: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_orb_slots = [orb_slot_1, orb_slot_2, orb_slot_3]
	_hint_labels = [hint_1, hint_2, hint_3, hint_4]
	for slot in _orb_slots:
		_ensure_slot_icon(slot)
		_slot_icons.append(slot.get_node("Icon") as TextureRect)
	_center_panel()
	visible = false
	drag_preview.visible = false
	done_button.pressed.connect(_on_done_pressed)
	buy_button.pressed.connect(_on_buy_pressed)
	transform_button.pressed.connect(_on_transform_pressed)
	transform_button.mouse_entered.connect(_on_transform_hover.bind(true))
	transform_button.mouse_exited.connect(_on_transform_hover.bind(false))
	transform_button.focus_entered.connect(_on_transform_hover.bind(true))
	transform_button.focus_exited.connect(_on_transform_hover.bind(false))
	inventory.glyph_grab_requested.connect(_on_inventory_glyph_grab)


func _center_panel() -> void:
	var designed_size: Vector2 = _editor_panel_size()
	designed_size.x = maxf(designed_size.x, 1.0)
	designed_size.y = maxf(designed_size.y, 1.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
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
	_orb = orb as BlankOrb
	_circle = circle
	_new_orb_cost = new_orb_cost
	_orbs = orbs.duplicate()
	_cancel_drag()
	visible = true

	if _circle != null:
		if not _circle.inventory_changed.is_connected(_refresh_ui):
			_circle.inventory_changed.connect(_refresh_ui)
		if not _circle.mana_deposited.is_connected(_on_mana_changed):
			_circle.mana_deposited.connect(_on_mana_changed)
		if not _circle.mana_spent.is_connected(_on_mana_changed):
			_circle.mana_spent.connect(_on_mana_changed)

	buy_label.text = "Blank Orb\n(%d mana)" % int(_new_orb_cost)
	_refresh_ui()


func close_menu() -> void:
	_cancel_drag()
	if _circle != null and is_instance_valid(_circle):
		if _circle.inventory_changed.is_connected(_refresh_ui):
			_circle.inventory_changed.disconnect(_refresh_ui)
		if _circle.mana_deposited.is_connected(_on_mana_changed):
			_circle.mana_deposited.disconnect(_on_mana_changed)
		if _circle.mana_spent.is_connected(_on_mana_changed):
			_circle.mana_spent.disconnect(_on_mana_changed)
	_orb = null
	_circle = null
	_orbs.clear()
	visible = false


func set_orbs(orbs: Array) -> void:
	_orbs = orbs.duplicate()
	if visible:
		_refresh_inventory_bar()


func _process(_delta: float) -> void:
	if not visible or _held_index < 0:
		return
	if _dragging_mouse:
		_update_drag_preview_position(get_viewport().get_mouse_position())
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_finish_mouse_drop()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _held_index >= 0 and _dragging_mouse:
		return

	if event.is_action_pressed("dash"):
		if _held_index < 0:
			_try_controller_grab()
		else:
			_confirm_controller_drop()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tether"):
		if _held_index >= 0:
			_cancel_drag()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_up"):
		if _held_index >= 0:
			_snap_to_first_empty_orb_slot()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left"):
		if _held_index >= 0:
			_move_drop_target(-1)
		else:
			_move_controller_glyph(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		if _held_index >= 0:
			_move_drop_target(1)
		else:
			_move_controller_glyph(1)
		get_viewport().set_input_as_handled()
		return


func _on_mana_changed(_amount: float, _total: float) -> void:
	_refresh_ui()


func _refresh_ui() -> void:
	if _orb == null or not is_instance_valid(_orb) or _circle == null or not is_instance_valid(_circle):
		return

	orb_name_label.text = _orb.get_display_name()
	effect_label.text = _effect_text_for_orb(_orb)
	_refresh_stats()
	_refresh_orb_slots()
	_refresh_inventory_bar()
	_refresh_hints()
	_refresh_transform()
	_refresh_buy()
	recycle_label.text = "Drop to\nrecycle"


func _refresh_stats() -> void:
	var stats: Dictionary = _orb.get_stat_snapshot()
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


func _refresh_orb_slots() -> void:
	for i in _orb_slots.size():
		var icon: TextureRect = _slot_icons[i]
		if i < _orb.socketed_glyphs.size():
			var entry: Dictionary = _orb.socketed_glyphs[i]
			var glyph_id: StringName = StringName(String(entry.get("id", "")))
			var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
			icon.visible = true
			icon.texture = _texture_for_glyph_id(glyph_id)
			icon.modulate = Glyph.RARITY_MODULATE.get(rarity, Color.WHITE) as Color
		else:
			icon.visible = false
			icon.texture = null
	_refresh_drop_target_outline()


func _refresh_inventory_bar() -> void:
	inventory.set_orbs(_orbs, _orb)
	inventory.set_glyphs(_circle.glyph_inventory)
	inventory.set_mana(_circle.mana_pool)


func _refresh_hints() -> void:
	_clear_hint_info()
	var socketed_count: int = _orb.socketed_glyphs.size()
	hint_container.visible = socketed_count == 2
	if socketed_count != 2:
		return

	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var hints: Array = OrbRecipes.hints_for(_orb, elements)
	for i in _hint_labels.size():
		if i < hints.size():
			var hint: Dictionary = hints[i]
			_hint_labels[i].text = String(hint.get("label", "???"))
			if bool(hint.get("discovered", false)):
				_add_hint_info_box(hint)
		else:
			_hint_labels[i].text = "???"


func _refresh_transform() -> void:
	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var can_transform: bool = (
		_orb.socketed_glyphs.size() >= 3
		and OrbRecipes.is_playable(OrbRecipes.result_for(_orb, elements))
	)
	transform_button.disabled = not can_transform
	if _showing_transform_preview:
		_show_transform_preview()


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


func _clear_hint_info() -> void:
	for child in hint_info_container.get_children():
		child.queue_free()


func _add_hint_info_box(hint: Dictionary) -> void:
	var row: Dictionary = hint.get("row", {}) as Dictionary
	if row.is_empty():
		return
	var box := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	var vbox := VBoxContainer.new()
	var title := Label.new()
	title.text = String(row.get("name", "???"))
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(160, 0)
	var desc: String = String(row.get("desc", ""))
	if desc.is_empty():
		desc = String(row.get("effect", ""))
	body.text = desc if not desc.is_empty() else "???"
	vbox.add_child(title)
	vbox.add_child(body)
	margin.add_child(vbox)
	box.add_child(margin)
	hint_info_container.add_child(box)


func _show_transform_preview() -> void:
	_clear_hint_info()
	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var row: Dictionary = OrbRecipes.result_for(_orb, elements)
	if row.is_empty() or not OrbRecipes.is_discovered(StringName(String(row.get("id", "")))):
		_add_unknown_preview_box()
		return
	var hint := {"row": row, "discovered": true}
	_add_hint_info_box(hint)


func _add_unknown_preview_box() -> void:
	var box := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	var label := Label.new()
	label.text = "???\n???"
	margin.add_child(label)
	box.add_child(margin)
	hint_info_container.add_child(box)


func _on_transform_hover(active: bool) -> void:
	_showing_transform_preview = active
	if active:
		_show_transform_preview()
	else:
		_refresh_hints()


func _on_inventory_glyph_grab(index: int) -> void:
	_begin_drag(index, true)


func _begin_drag(index: int, from_mouse: bool) -> void:
	if _circle == null or index < 0 or index >= _circle.glyph_inventory.size():
		return
	_held_index = index
	_dragging_mouse = from_mouse
	_controller_mode = not from_mouse
	_target_index = DROP_SLOT_0
	inventory.set_held_glyph_index(_held_index)
	var entry: Dictionary = _circle.glyph_inventory[index]
	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
	drag_icon.texture = _texture_for_glyph_id(glyph_id)
	drag_icon.modulate = Glyph.RARITY_MODULATE.get(rarity, Color.WHITE) as Color
	drag_preview.visible = true
	if from_mouse:
		_update_drag_preview_position(get_viewport().get_mouse_position())
	else:
		_snap_to_first_empty_orb_slot()
	_refresh_drop_target_outline()


func _cancel_drag() -> void:
	_held_index = -1
	_dragging_mouse = false
	_controller_mode = false
	_target_index = DROP_SLOT_0
	drag_preview.visible = false
	inventory.set_held_glyph_index(-1)
	_refresh_drop_target_outline()


func _update_drag_preview_position(pos: Vector2) -> void:
	drag_preview.global_position = pos - drag_preview.size * 0.5


func _finish_mouse_drop() -> void:
	if _held_index < 0:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var target: int = _hit_test_drop_target(mouse_pos)
	if target >= 0:
		_resolve_drop(target)
	else:
		_cancel_drag()


func _hit_test_drop_target(pos: Vector2) -> int:
	var targets: Array[Control] = [recycle_socket, orb_slot_1, orb_slot_2, orb_slot_3]
	for i in targets.size():
		var control: Control = targets[i]
		var rect := Rect2(control.global_position, control.size)
		if rect.has_point(pos):
			return i
	return -1


func _try_controller_grab() -> void:
	var index: int = inventory.get_controller_glyph_index()
	if _circle == null or index < 0 or index >= _circle.glyph_inventory.size():
		return
	_begin_drag(index, false)


func _confirm_controller_drop() -> void:
	if _held_index < 0:
		return
	_resolve_drop(_target_index)


func _move_controller_glyph(delta: int) -> void:
	if _circle == null or _circle.glyph_inventory.is_empty():
		return
	var count: int = _circle.glyph_inventory.size()
	var next: int = inventory.get_controller_glyph_index() + delta
	next = clampi(next, 0, count - 1)
	inventory.set_controller_glyph_index(next)


func _move_drop_target(delta: int) -> void:
	_target_index = clampi(_target_index + delta, DROP_RECYCLE, DROP_SLOT_2)
	_place_preview_on_target()
	_refresh_drop_target_outline()


func _snap_to_first_empty_orb_slot() -> void:
	var open_index: int = 0
	if _orb != null:
		open_index = mini(_orb.socketed_glyphs.size(), 2)
	_target_index = DROP_SLOT_0 + open_index
	_place_preview_on_target()
	_refresh_drop_target_outline()


func _place_preview_on_target() -> void:
	var targets: Array[Control] = [recycle_socket, orb_slot_1, orb_slot_2, orb_slot_3]
	if _target_index < 0 or _target_index >= targets.size():
		return
	var target: Control = targets[_target_index]
	drag_preview.global_position = target.global_position + (target.size - drag_preview.size) * 0.5


func _refresh_drop_target_outline() -> void:
	var targets: Array[Control] = [recycle_socket, orb_slot_1, orb_slot_2, orb_slot_3]
	for i in targets.size():
		var control: Control = targets[i]
		if _held_index >= 0 and i == _target_index and not _dragging_mouse:
			control.self_modulate = Color(1.4, 1.4, 1.4, 1.0)
		else:
			control.self_modulate = Color.WHITE


func _resolve_drop(target: int) -> void:
	if _held_index < 0 or _circle == null or _orb == null:
		_cancel_drag()
		return
	var held: int = _held_index
	if target == DROP_RECYCLE:
		_recycle_glyph(held)
	elif target >= DROP_SLOT_0 and target <= DROP_SLOT_2:
		_socket_glyph(held)
	_cancel_drag()
	_refresh_ui()


func _socket_glyph(index: int) -> void:
	var entry: Dictionary = _circle.remove_inventory_entry(index)
	if entry.is_empty():
		return
	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
	if not _orb.apply_glyph(glyph_id, rarity):
		_circle.glyph_inventory.insert(mini(index, _circle.glyph_inventory.size()), entry)
		_circle.inventory_changed.emit()


func _recycle_glyph(index: int) -> void:
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


func _on_buy_pressed() -> void:
	if _circle == null or not _circle.spend(_new_orb_cost):
		return
	new_blank_orb_requested.emit()
	_refresh_ui()


func _on_transform_pressed() -> void:
	if _orb == null:
		return
	var elements: Array[String] = OrbRecipes.elements_from_socketed(_orb.socketed_glyphs)
	var row: Dictionary = OrbRecipes.result_for(_orb, elements)
	if not OrbRecipes.is_playable(row):
		return
	var orb_id: StringName = StringName(String(row.get("id", "")))
	transform_requested.emit(orb_id)


func _on_done_pressed() -> void:
	close_menu()
	closed.emit()
