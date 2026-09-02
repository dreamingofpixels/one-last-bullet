class_name RitualMenu
extends CanvasLayer

signal closed
signal new_blank_orb_requested

const STAT_KEYS: Array[String] = [
	"damage", "self_damage", "splash", "speed", "weight",
	"crit_chance", "crit_damage", "glyph_drop",
	"burn", "chill", "shock", "poison",
]

@onready var panel: PanelContainer = %Panel
@onready var orb_name_label: Label = %OrbNameLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var slots_container: HBoxContainer = %SlotsContainer
@onready var mana_label: Label = %ManaLabel
@onready var inventory_container: VBoxContainer = %InventoryContainer
@onready var new_orb_button: Button = %NewOrbButton
@onready var done_button: Button = %DoneButton

var _orb: RigidBody2D = null
var _circle: SummoningCircle = null
var _new_orb_cost: float = 20.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_center_panel()
	visible = false
	done_button.pressed.connect(_on_done_pressed)
	new_orb_button.pressed.connect(_on_new_orb_pressed)


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


func open(orb: RigidBody2D, circle: SummoningCircle, new_orb_cost: float = 20.0) -> void:
	_orb = orb
	_circle = circle
	_new_orb_cost = new_orb_cost
	visible = true

	if not _circle.inventory_changed.is_connected(_refresh_ui):
		_circle.inventory_changed.connect(_refresh_ui)

	new_orb_button.text = "New Blank Orb (%d mana)" % int(_new_orb_cost)
	_refresh_ui()


func close_menu() -> void:
	if _circle != null and is_instance_valid(_circle) and _circle.inventory_changed.is_connected(_refresh_ui):
		_circle.inventory_changed.disconnect(_refresh_ui)
	_orb = null
	_circle = null
	visible = false


func _refresh_ui() -> void:
	if _orb == null or not is_instance_valid(_orb) or _circle == null or not is_instance_valid(_circle):
		return

	orb_name_label.text = _orb.get_display_name()
	mana_label.text = "Mana: %d" % int(_circle.mana_pool)

	_refresh_stats()
	_refresh_slots()
	_refresh_inventory()
	new_orb_button.disabled = _circle.mana_pool < _new_orb_cost


func _refresh_stats() -> void:
	for child in stats_container.get_children():
		child.queue_free()

	var stats: Dictionary = _orb.get_stat_snapshot()
	for key in STAT_KEYS:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = _stat_display_name(key)
		name_label.custom_minimum_size = Vector2(90, 0)
		var value_label := Label.new()
		var val: Variant = stats.get(key, 0)
		if key in ["crit_chance", "splash", "glyph_drop"]:
			value_label.text = "%.0f%%" % (float(val) * 100.0)
		elif key in ["burn", "chill", "shock", "poison"]:
			value_label.text = str(int(val))
		else:
			value_label.text = str(snappedf(float(val), 0.01))
		row.add_child(name_label)
		row.add_child(value_label)
		stats_container.add_child(row)


func _refresh_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()

	for i in _orb.glyph_slots:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(28, 28)
		if i < _orb.socketed_glyphs.size():
			var entry: Dictionary = _orb.socketed_glyphs[i]
			var glyph_id: StringName = StringName(String(entry.get("id", "")))
			var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
			var icon := TextureRect.new()
			icon.texture = _texture_for_glyph_id(glyph_id)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(20, 20)
			icon.modulate = Glyph.RARITY_MODULATE.get(rarity, Color.WHITE) as Color
			slot.add_child(icon)
		else:
			var empty := Label.new()
			empty.text = "+"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(empty)
		slots_container.add_child(slot)


func _refresh_inventory() -> void:
	for child in inventory_container.get_children():
		child.queue_free()

	for i in _circle.glyph_inventory.size():
		var entry: Dictionary = _circle.glyph_inventory[i]
		var glyph_id: StringName = StringName(String(entry.get("id", "")))
		var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
		var row_data: Variant = GameData.get_row(&"glyphs", glyph_id)
		var attr: String = ""
		var value: float = 0.0
		var display_name: String = String(glyph_id)
		if row_data != null and typeof(row_data) == TYPE_DICTIONARY:
			var data: Dictionary = row_data
			display_name = String(data.get("name", glyph_id))
			attr = String(data.get("attribute", ""))
			match rarity:
				Glyph.Rarity.RARE:
					value = float(data.get("rarity_rare", 0.0))
				Glyph.Rarity.UNIQUE:
					value = float(data.get("rarity_unique", 0.0))
				_:
					value = float(data.get("rarity_common", 0.0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var icon := TextureRect.new()
		icon.texture = _texture_for_glyph_id(glyph_id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Glyph.RARITY_MODULATE.get(rarity, Color.WHITE) as Color
		row.add_child(icon)

		var info := Label.new()
		info.text = "%s (%s) %s %s" % [
			display_name,
			Glyph.rarity_to_string(rarity),
			_stat_display_name(attr),
			_format_stat_bonus(attr, value),
		]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var socket_btn := Button.new()
		socket_btn.text = "Socket"
		socket_btn.disabled = _orb.get_open_glyph_slots() <= 0
		var idx: int = i
		socket_btn.pressed.connect(_on_socket_pressed.bind(idx))
		row.add_child(socket_btn)

		var mana_val: float = float(Glyph.MANA_BY_RARITY.get(rarity, 5.0))
		var discard_btn := Button.new()
		discard_btn.text = "Discard (+%d)" % int(mana_val)
		discard_btn.pressed.connect(_on_discard_pressed.bind(idx, mana_val))
		row.add_child(discard_btn)

		inventory_container.add_child(row)


func _stat_display_name(key: String) -> String:
	return key.capitalize()


func _format_stat_bonus(attr: String, value: float) -> String:
	if attr in ["crit_chance", "splash", "glyph_drop"]:
		var pct: int = int(round(value * 100.0))
		return "%s%d%%" % ["+" if pct >= 0 else "", pct]
	var snapped: float = snappedf(value, 0.01)
	return "%s%s" % ["+" if snapped >= 0.0 else "", str(snapped)]


func _texture_for_glyph_id(glyph_id: StringName) -> Texture2D:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return Glyph.ELEMENT_TEXTURES["Fire"] as Texture2D
	var element: String = String((row as Dictionary).get("element", "Fire"))
	return Glyph.ELEMENT_TEXTURES.get(element, Glyph.ELEMENT_TEXTURES["Fire"]) as Texture2D


func _on_socket_pressed(index: int) -> void:
	if _orb == null or _circle == null:
		return
	var entry: Dictionary = _circle.remove_inventory_entry(index)
	if entry.is_empty():
		return
	var glyph_id: StringName = StringName(String(entry.get("id", "")))
	var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
	if not _orb.apply_glyph(glyph_id, rarity):
		_circle.glyph_inventory.insert(mini(index, _circle.glyph_inventory.size()), entry)
		_circle.inventory_changed.emit()
	_refresh_ui()


func _on_discard_pressed(index: int, mana_value: float) -> void:
	if _circle == null:
		return
	_circle.remove_inventory_entry(index)
	_circle.deposit(mana_value)
	_refresh_ui()


func _on_new_orb_pressed() -> void:
	if _circle == null or not _circle.spend(_new_orb_cost):
		return
	new_blank_orb_requested.emit()
	_refresh_ui()


func _on_done_pressed() -> void:
	close_menu()
	closed.emit()
