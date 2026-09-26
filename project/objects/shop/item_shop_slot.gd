@tool
class_name ItemShopSlot
extends Sprite2D

enum StockKind { GLYPH, RITE }

@export var stock_kind: StockKind = StockKind.GLYPH

var item_id: StringName = &""
var rarity: Glyph.Rarity = Glyph.Rarity.COMMON
var cost: float = 0.0

var _stocked: bool = false
var _focused: bool = false

@onready var _focus_overlay: ColorRect = %FocusOverlay


func _ready() -> void:
	if not _stocked:
		_apply_empty_visual()
	set_focused(false)


func stock_glyph(id: StringName, glyph_rarity: Glyph.Rarity, glyph_cost: float) -> void:
	stock_kind = StockKind.GLYPH
	item_id = id
	rarity = glyph_rarity
	cost = glyph_cost
	_stocked = true
	_apply_stock_visual()


func stock_rite(id: StringName, rite_cost: float) -> void:
	stock_kind = StockKind.RITE
	item_id = id
	rarity = Glyph.Rarity.COMMON
	cost = rite_cost
	_stocked = true
	_apply_stock_visual()


func clear_stock() -> void:
	item_id = &""
	cost = 0.0
	_stocked = false
	_apply_empty_visual()
	set_focused(false)


func is_stocked() -> bool:
	return _stocked and not String(item_id).strip_edges().is_empty()


func get_display_name() -> String:
	if not is_stocked():
		return ""
	if stock_kind == StockKind.RITE:
		return RiteSlot.rite_display_name(item_id)
	var row: Variant = GameData.get_row(&"glyphs", item_id)
	if row != null and typeof(row) == TYPE_DICTIONARY:
		var n: String = String((row as Dictionary).get("name", "")).strip_edges()
		if not n.is_empty():
			return n
	return String(item_id)


func get_description() -> String:
	if not is_stocked():
		return ""
	if stock_kind == StockKind.RITE:
		return RiteSlot.rite_description(item_id)
	var row: Variant = GameData.get_row(&"glyphs", item_id)
	if row != null and typeof(row) == TYPE_DICTIONARY:
		return String((row as Dictionary).get("desc", ""))
	return ""


func get_cost() -> float:
	return cost


func set_focused(focused: bool) -> void:
	_focused = focused
	if not is_node_ready():
		return
	_focus_overlay.visible = focused and is_stocked()


func _apply_stock_visual() -> void:
	visible = true
	if stock_kind == StockKind.RITE:
		Glyph.clear_rarity_visual(self)
		texture = RiteSlot.resolve_texture(item_id)
	else:
		texture = Glyph.texture_for_id(item_id)
		Glyph.apply_rarity_visual(self, rarity)
	if is_node_ready() and _focused:
		set_focused(true)


func _apply_empty_visual() -> void:
	Glyph.clear_rarity_visual(self)
	texture = null
	visible = false
	if is_node_ready():
		set_focused(false)
