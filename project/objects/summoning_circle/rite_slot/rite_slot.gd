@tool
class_name RiteSlot
extends Sprite2D

const PLACEHOLDER_TEXTURE: Texture2D = preload("res://ui/rites/placeholder_rite.png")

@export var rite_id: StringName = &"":
	set(value):
		if rite_id == value:
			return
		rite_id = value
		_apply_rite_visual()

@onready var _focus_overlay: ColorRect = %FocusOverlay
var _focused: bool = false


static func rite_ids_for_inspector(current: StringName = &"") -> PackedStringArray:
	var active_ids: PackedStringArray = []
	if Engine.get_main_loop() != null:
		for row_variant in GameData.get_table(&"rites"):
			if typeof(row_variant) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = row_variant as Dictionary
			if row.get("active") != true:
				continue
			var id_s: String = String(row.get("id", "")).strip_edges()
			if id_s.is_empty():
				continue
			if not active_ids.has(id_s):
				active_ids.append(id_s)
	var current_s: String = String(current).strip_edges()
	if not current_s.is_empty() and not active_ids.has(current_s):
		active_ids.append(current_s)
	active_ids.sort()
	var ids: PackedStringArray = PackedStringArray([""])
	ids.append_array(active_ids)
	return ids


static func resolve_texture(id: StringName) -> Texture2D:
	var id_s: String = String(id).strip_edges()
	if id_s.is_empty():
		return null
	var named_path: String = "res://ui/rites/%s_rite.png" % id_s
	if ResourceLoader.exists(named_path):
		var named_tex: Texture2D = load(named_path) as Texture2D
		if named_tex != null:
			return named_tex
	var row: Variant = GameData.get_row(&"rites", id)
	if row != null and typeof(row) == TYPE_DICTIONARY:
		var png_path: String = String((row as Dictionary).get("png_path", "")).strip_edges()
		if not png_path.is_empty() and ResourceLoader.exists(png_path):
			var row_tex: Texture2D = load(png_path) as Texture2D
			if row_tex != null:
				return row_tex
	return PLACEHOLDER_TEXTURE


static func rite_display_name(id: StringName) -> String:
	var row: Variant = GameData.get_row(&"rites", id)
	if row != null and typeof(row) == TYPE_DICTIONARY:
		var n: String = String((row as Dictionary).get("name", "")).strip_edges()
		if not n.is_empty():
			return n
	return String(id)


static func rite_description(id: StringName) -> String:
	var row: Variant = GameData.get_row(&"rites", id)
	if row != null and typeof(row) == TYPE_DICTIONARY:
		return String((row as Dictionary).get("desc", ""))
	return ""


func _validate_property(property: Dictionary) -> void:
	if property.name != &"rite_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(rite_ids_for_inspector(rite_id))


func _ready() -> void:
	_apply_rite_visual()
	set_focused(false)


func is_filled() -> bool:
	return not String(rite_id).strip_edges().is_empty()


func set_focused(focused: bool) -> void:
	_focused = focused
	if not is_node_ready():
		return
	_focus_overlay.visible = focused and is_filled()


func _apply_rite_visual() -> void:
	if not is_filled():
		texture = null
		visible = false
		if is_node_ready():
			set_focused(false)
		return
	visible = true
	texture = resolve_texture(rite_id)
	if is_node_ready() and _focused:
		set_focused(true)
