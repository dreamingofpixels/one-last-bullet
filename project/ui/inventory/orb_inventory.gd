class_name OrbInventoryBar
extends Control

signal glyph_grab_requested(index: int)

const BLANK_ORB_TEXTURE := preload("res://entities/orbs/blank/blank_orb.png")
const FOCUS_TINT := Color(1.45, 1.45, 1.45, 1.0)
const OUTLINE_TINT := Color(1.0, 1.0, 1.0, 1.0)

@onready var orb_socket_1: TextureRect = %OrbSocket1
@onready var orb_socket_2: TextureRect = %OrbSocket2
@onready var orb_socket_3: TextureRect = %OrbSocket3
@onready var glyph_socket_1: TextureRect = %GlyphSocket1
@onready var glyph_socket_2: TextureRect = %GlyphSocket2
@onready var glyph_socket_3: TextureRect = %GlyphSocket3
@onready var mana_label: Label = %ManaLabel

var _orb_sockets: Array[TextureRect] = []
var _glyph_sockets: Array[TextureRect] = []
var _glyph_icons: Array[TextureRect] = []
var _orb_outlines: Array[Panel] = []
var _glyph_outlines: Array[Panel] = []
var _controller_glyph_index: int = 0
var _controller_orb_index: int = 0
var _held_glyph_index: int = -1
var _menu_focus_on_glyphs: bool = true
var _menu_focus_on_orbs: bool = false


func _ready() -> void:
	_orb_sockets = [orb_socket_1, orb_socket_2, orb_socket_3]
	_glyph_sockets = [glyph_socket_1, glyph_socket_2, glyph_socket_3]
	for socket in _orb_sockets:
		_ensure_orb_icon(socket)
		_orb_outlines.append(_ensure_outline(socket))
	for i in _glyph_sockets.size():
		var socket: TextureRect = _glyph_sockets[i]
		socket.gui_input.connect(_on_glyph_socket_gui_input.bind(i))
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.visible = false
		socket.add_child(icon)
		_glyph_icons.append(icon)
		_glyph_outlines.append(_ensure_outline(socket))


func set_orbs(orbs: Array, focused: Node) -> void:
	for i in _orb_sockets.size():
		var socket: TextureRect = _orb_sockets[i]
		var icon: TextureRect = socket.get_node("Icon") as TextureRect
		var outline: Panel = _orb_outlines[i]
		socket.self_modulate = Color.WHITE
		outline.visible = false
		if i < orbs.size() and is_instance_valid(orbs[i]):
			var orb: Node = orbs[i]
			icon.visible = true
			icon.texture = BLANK_ORB_TEXTURE
			if orb.get("base_modulate") != null:
				icon.modulate = orb.base_modulate
			else:
				icon.modulate = Color.WHITE
			var is_focused_orb: bool = orb == focused
			var is_menu_focus: bool = _menu_focus_on_orbs and i == _controller_orb_index
			if is_focused_orb:
				socket.self_modulate = FOCUS_TINT
			outline.visible = is_focused_orb or is_menu_focus
		else:
			icon.visible = false
			icon.texture = null


func set_glyphs(entries: Array, hide_index: int = -1) -> void:
	_held_glyph_index = hide_index
	for i in _glyph_sockets.size():
		var icon: TextureRect = _glyph_icons[i]
		if i == hide_index:
			# Source socket shows empty while that glyph is being dragged.
			icon.visible = false
			icon.texture = null
			icon.modulate = Color.WHITE
			continue
		if i < entries.size() and typeof(entries[i]) == TYPE_DICTIONARY:
			var entry: Dictionary = entries[i]
			var glyph_id: StringName = StringName(String(entry.get("id", "")))
			var rarity: int = int(entry.get("rarity", Glyph.Rarity.COMMON))
			icon.visible = true
			icon.texture = _texture_for_glyph_id(glyph_id)
			icon.modulate = Glyph.RARITY_MODULATE.get(rarity, Color.WHITE) as Color
		else:
			icon.visible = false
			icon.texture = null
			icon.modulate = Color.WHITE
	_refresh_glyph_outlines()


func set_mana(value: float) -> void:
	mana_label.text = "Mana: %d" % int(value)


func get_glyph_socket(index: int) -> Control:
	if index < 0 or index >= _glyph_sockets.size():
		return null
	return _glyph_sockets[index]


func get_orb_socket(index: int) -> Control:
	if index < 0 or index >= _orb_sockets.size():
		return null
	return _orb_sockets[index]


func get_glyph_socket_rect(index: int) -> Rect2:
	if index < 0 or index >= _glyph_sockets.size():
		return Rect2()
	var socket: TextureRect = _glyph_sockets[index]
	return Rect2(socket.global_position, socket.size)


func set_controller_glyph_index(index: int) -> void:
	_controller_glyph_index = clampi(index, 0, maxi(_glyph_sockets.size() - 1, 0))
	_refresh_glyph_outlines()


func get_controller_glyph_index() -> int:
	return _controller_glyph_index


func set_controller_orb_index(index: int) -> void:
	_controller_orb_index = clampi(index, 0, maxi(_orb_sockets.size() - 1, 0))


func get_controller_orb_index() -> int:
	return _controller_orb_index


func set_menu_focus(on_glyphs: bool, on_orbs: bool) -> void:
	_menu_focus_on_glyphs = on_glyphs
	_menu_focus_on_orbs = on_orbs
	_refresh_glyph_outlines()


func set_held_glyph_index(index: int) -> void:
	_held_glyph_index = index
	# Hide the source icon immediately so it does not look duplicated next to the drag preview.
	for i in _glyph_icons.size():
		if i == index:
			_glyph_icons[i].visible = false
	_refresh_glyph_outlines()


func _ensure_orb_icon(socket: TextureRect) -> void:
	if socket.has_node("Icon"):
		return
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.visible = false
	socket.add_child(icon)


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
	style.border_color = OUTLINE_TINT
	style.set_border_width_all(1)
	outline.add_theme_stylebox_override("panel", style)
	outline.visible = false
	socket.add_child(outline)
	return outline


func _refresh_glyph_outlines() -> void:
	for i in _glyph_sockets.size():
		var outline: Panel = _glyph_outlines[i]
		var has_glyph: bool = _glyph_icons[i].visible
		var outlined: bool = false
		if _held_glyph_index >= 0:
			outlined = i == _held_glyph_index
		elif _menu_focus_on_glyphs and has_glyph:
			outlined = i == _controller_glyph_index
		outline.visible = outlined


func _texture_for_glyph_id(glyph_id: StringName) -> Texture2D:
	var row: Variant = GameData.get_row(&"glyphs", glyph_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return Glyph.ELEMENT_TEXTURES["Fire"] as Texture2D
	var element: String = String((row as Dictionary).get("element", "Fire"))
	return Glyph.ELEMENT_TEXTURES.get(element, Glyph.ELEMENT_TEXTURES["Fire"]) as Texture2D


func _on_glyph_socket_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	if index >= _glyph_icons.size() or not _glyph_icons[index].visible:
		return
	accept_event()
	glyph_grab_requested.emit(index)
