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
const DROP_INV_0 := 4
const DROP_INV_1 := 5
const DROP_INV_2 := 6

enum FocusZone {
	INV_GLYPH,
	INV_ORB,
	RECYCLE,
	ORB_SLOT,
	TRANSFORM,
	BUY,
	DONE,
}

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
var _slot_outlines: Array[Panel] = []

## Held glyph: from inventory index, or from an orb slot (-1 / -1 = nothing held).
var _held_inv_index: int = -1
var _held_orb_slot: int = -1
var _held_entry: Dictionary = {}
var _target_index: int = DROP_SLOT_0
var _dragging_mouse: bool = false
var _showing_transform_preview: bool = false

var _focus_zone: FocusZone = FocusZone.INV_GLYPH
var _focus_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_orb_slots = [orb_slot_1, orb_slot_2, orb_slot_3]
	_hint_labels = [hint_1, hint_2, hint_3, hint_4]
	for i in _orb_slots.size():
		var slot: TextureRect = _orb_slots[i]
		_ensure_slot_icon(slot)
		_slot_icons.append(slot.get_node("Icon") as TextureRect)
		_slot_outlines.append(_ensure_outline(slot))
		slot.gui_input.connect(_on_orb_slot_gui_input.bind(i))
	_ensure_outline(recycle_socket)
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
	_orb = orb as BlankOrb
	_circle = circle
	_new_orb_cost = new_orb_cost
	_orbs = orbs.duplicate()
	_cancel_drag()
	visible = true
	_focus_zone = FocusZone.INV_GLYPH
	_focus_index = 0

	if _circle != null:
		if not _circle.inventory_changed.is_connected(_refresh_ui):
			_circle.inventory_changed.connect(_refresh_ui)
		if not _circle.mana_deposited.is_connected(_on_mana_changed):
			_circle.mana_deposited.connect(_on_mana_changed)
		if not _circle.mana_spent.is_connected(_on_mana_changed):
			_circle.mana_spent.connect(_on_mana_changed)

	buy_label.text = "Blank Orb\n(%d mana)" % int(_new_orb_cost)
	_refresh_ui()
	_apply_focus_visuals()


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
		_apply_focus_visuals()


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
	if _is_holding() and _dragging_mouse:
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

	if event.is_action_pressed("move_up"):
		if _is_holding():
			_snap_to_first_empty_orb_slot()
		else:
			_navigate_focus(Vector2.UP)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_down"):
		if _is_holding():
			_target_index = DROP_INV_0
			_place_preview_on_target()
			_refresh_drop_target_outline()
		else:
			_navigate_focus(Vector2.DOWN)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_left"):
		if _is_holding():
			_move_drop_target(-1)
		else:
			_navigate_focus(Vector2.LEFT)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("move_right"):
		if _is_holding():
			_move_drop_target(1)
		else:
			_navigate_focus(Vector2.RIGHT)
		get_viewport().set_input_as_handled()
		return


func _is_holding() -> bool:
	return _held_inv_index >= 0 or _held_orb_slot >= 0


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
	_apply_focus_visuals()


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
		# Hide the slot being dragged so it does not look duplicated.
		if i == _held_orb_slot:
			icon.visible = false
			icon.texture = null
			continue
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
	inventory.set_glyphs(_circle.glyph_inventory, _held_inv_index)
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
	_begin_drag_from_inventory(index, true)


func _on_orb_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if _orb == null or slot_index < 0 or slot_index >= _orb.socketed_glyphs.size():
		return
	get_viewport().set_input_as_handled()
	_begin_drag_from_orb_slot(slot_index, true)


func _begin_drag_from_inventory(index: int, from_mouse: bool) -> void:
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
	if _orb == null or slot_index < 0 or slot_index >= _orb.socketed_glyphs.size():
		return
	var entry: Dictionary = _orb.remove_glyph(slot_index)
	if entry.is_empty():
		return
	_held_inv_index = -1
	_held_orb_slot = slot_index
	_held_entry = entry
	_dragging_mouse = from_mouse
	_target_index = DROP_INV_0
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
	drag_icon.modulate = Glyph.RARITY_MODULATE.get(rarity, Color.WHITE) as Color
	drag_preview.visible = true


func _cancel_drag() -> void:
	# If we pulled a glyph off an orb slot, put it back.
	if _held_orb_slot >= 0 and not _held_entry.is_empty() and _orb != null and is_instance_valid(_orb):
		var glyph_id: StringName = StringName(String(_held_entry.get("id", "")))
		var rarity: int = int(_held_entry.get("rarity", Glyph.Rarity.COMMON))
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
	if _is_holding():
		_resolve_drop(_target_index)
		return

	match _focus_zone:
		FocusZone.INV_GLYPH:
			_begin_drag_from_inventory(_focus_index, false)
		FocusZone.ORB_SLOT:
			if _orb != null and _focus_index < _orb.socketed_glyphs.size():
				# Remove placed glyph back to inventory when possible.
				if _circle != null and _circle.has_inventory_space():
					var entry: Dictionary = _orb.remove_glyph(_focus_index)
					if not entry.is_empty():
						_circle.add_inventory_entry(
							StringName(String(entry.get("id", ""))),
							int(entry.get("rarity", Glyph.Rarity.COMMON))
						)
						_refresh_ui()
				else:
					# No inventory space: start a hold so the player can recycle / place elsewhere.
					_begin_drag_from_orb_slot(_focus_index, false)
		FocusZone.TRANSFORM:
			if not transform_button.disabled:
				_on_transform_pressed()
		FocusZone.BUY:
			if not buy_button.disabled:
				_on_buy_pressed()
		FocusZone.DONE:
			_on_done_pressed()
		_:
			pass


func _navigate_focus(dir: Vector2) -> void:
	match _focus_zone:
		FocusZone.INV_GLYPH:
			if dir.x < 0.0:
				if _focus_index <= 0:
					_focus_zone = FocusZone.INV_ORB
					_focus_index = maxi(_count_live_orbs() - 1, 0)
				else:
					_focus_index -= 1
			elif dir.x > 0.0:
				var max_g: int = maxi((_circle.glyph_inventory.size() if _circle else 1) - 1, 0)
				_focus_index = mini(_focus_index + 1, max_g)
			elif dir.y < 0.0:
				_focus_zone = FocusZone.ORB_SLOT
				_focus_index = mini(_focus_index, 2)
			inventory.set_controller_glyph_index(_focus_index)
		FocusZone.INV_ORB:
			if dir.x < 0.0:
				_focus_index = maxi(_focus_index - 1, 0)
			elif dir.x > 0.0:
				var max_o: int = maxi(_count_live_orbs() - 1, 0)
				if _focus_index >= max_o:
					_focus_zone = FocusZone.INV_GLYPH
					_focus_index = 0
				else:
					_focus_index += 1
			elif dir.y < 0.0:
				_focus_zone = FocusZone.RECYCLE
				_focus_index = 0
			inventory.set_controller_orb_index(_focus_index)
		FocusZone.RECYCLE:
			if dir.x > 0.0:
				_focus_zone = FocusZone.ORB_SLOT
				_focus_index = 0
			elif dir.y > 0.0:
				_focus_zone = FocusZone.INV_ORB
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
				_focus_zone = FocusZone.INV_GLYPH
				_focus_index = 0
			elif dir.y < 0.0:
				_focus_zone = FocusZone.DONE
				_focus_index = 0
			_showing_transform_preview = true
			_show_transform_preview()
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

	if _focus_zone != FocusZone.TRANSFORM:
		_showing_transform_preview = false
		_refresh_hints()
	_apply_focus_visuals()


func _apply_focus_visuals() -> void:
	var on_glyphs: bool = _focus_zone == FocusZone.INV_GLYPH and not _is_holding()
	var on_orbs: bool = _focus_zone == FocusZone.INV_ORB and not _is_holding()
	inventory.set_menu_focus(on_glyphs, on_orbs)
	if on_glyphs:
		inventory.set_controller_glyph_index(_focus_index)
	if on_orbs:
		inventory.set_controller_orb_index(_focus_index)
	inventory.set_orbs(_orbs, _orb)

	for i in _slot_outlines.size():
		_slot_outlines[i].visible = (
			not _is_holding()
			and _focus_zone == FocusZone.ORB_SLOT
			and i == _focus_index
		)

	var recycle_outline: Panel = recycle_socket.get_node_or_null("Outline") as Panel
	if recycle_outline:
		recycle_outline.visible = not _is_holding() and _focus_zone == FocusZone.RECYCLE

	transform_button.modulate = (
		Color(1.35, 1.35, 1.35, 1.0)
		if _focus_zone == FocusZone.TRANSFORM and not _is_holding()
		else Color.WHITE
	)
	buy_button.modulate = (
		Color(1.35, 1.35, 1.35, 1.0)
		if _focus_zone == FocusZone.BUY and not _is_holding()
		else Color.WHITE
	)
	done_button.modulate = (
		Color(1.35, 1.35, 1.35, 1.0)
		if _focus_zone == FocusZone.DONE and not _is_holding()
		else Color.WHITE
	)


func _move_drop_target(delta: int) -> void:
	var max_target: int = DROP_INV_2
	_target_index = clampi(_target_index + delta, DROP_RECYCLE, max_target)
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
		if from_inv >= 0:
			_socket_from_inventory(from_inv)
		elif not entry.is_empty():
			var glyph_id: StringName = StringName(String(entry.get("id", "")))
			var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
			if not _orb.apply_glyph(glyph_id, rarity):
				if not _circle.add_inventory_entry(glyph_id, rarity):
					_orb.apply_glyph(glyph_id, rarity)
	elif target >= DROP_INV_0 and target <= DROP_INV_2:
		if from_slot >= 0 and not entry.is_empty():
			if not _circle.add_inventory_entry(
				StringName(String(entry.get("id", ""))),
				int(entry.get("rarity", Glyph.Rarity.COMMON))
			):
				# Inventory full — restore onto the orb.
				_orb.apply_glyph(
					StringName(String(entry.get("id", ""))),
					int(entry.get("rarity", Glyph.Rarity.COMMON))
				)
		elif from_inv >= 0:
			# Dropped back onto inventory — leave as-is.
			pass
	else:
		# Unknown target: restore.
		if from_slot >= 0 and not entry.is_empty():
			_orb.apply_glyph(
				StringName(String(entry.get("id", ""))),
				int(entry.get("rarity", Glyph.Rarity.COMMON))
			)

	_refresh_ui()


func _socket_from_inventory(index: int) -> void:
	var entry: Dictionary = _circle.remove_inventory_entry(index)
	if entry.is_empty():
		return
	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
	if not _orb.apply_glyph(glyph_id, rarity):
		_circle.glyph_inventory.insert(mini(index, _circle.glyph_inventory.size()), entry)
		_circle.inventory_changed.emit()


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
