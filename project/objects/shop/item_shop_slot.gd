@tool
class_name ItemShopSlot
extends Sprite2D

enum StockKind { GLYPH, RITE }

const TABLET_TEXTURE: Texture2D = preload("res://objects/shop/rite_tablet.png")
const FOCUS_LIFT_PX := 3.0
const FOCUS_MOVE_DURATION := 0.08
const FLOAT_AMPLITUDE_PX := 1.0
const FLOAT_PERIOD_SEC := 2.2
const RARITY_PARTICLES_NODE := &"RarityParticles"

@export var stock_kind: StockKind = StockKind.GLYPH

var item_id: StringName = &""
var rarity: Glyph.Rarity = Glyph.Rarity.COMMON
var cost: float = 0.0

var _stocked: bool = false
var _focused: bool = false
var _focus_offset: float = 0.0
var _float_phase: float = 0.0
var _float_period: float = FLOAT_PERIOD_SEC
var _focus_tween: Tween

@onready var _icon: Sprite2D = %Icon


func _ready() -> void:
	_float_phase = randf() * TAU
	_float_period = FLOAT_PERIOD_SEC * randf_range(0.85, 1.15)
	if not _stocked:
		_apply_empty_visual()
	set_focused(false)
	_sync_float_process()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_float_phase += delta * (TAU / maxf(_float_period, 0.01))
	_apply_visual_y()


func stock_glyph(id: StringName, glyph_rarity: Glyph.Rarity, glyph_cost: float) -> void:
	stock_kind = StockKind.GLYPH
	item_id = id
	rarity = glyph_rarity
	cost = glyph_cost
	_stocked = true
	_apply_stock_visual()
	_sync_float_process()


func stock_rite(id: StringName, rite_cost: float) -> void:
	stock_kind = StockKind.RITE
	item_id = id
	rarity = Glyph.Rarity.COMMON
	cost = rite_cost
	_stocked = true
	_apply_stock_visual()
	_sync_float_process()


func clear_stock() -> void:
	item_id = &""
	cost = 0.0
	_stocked = false
	_apply_empty_visual()
	set_focused(false)
	_sync_float_process()


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
	_tween_focus_lift(focused and is_stocked())


func _apply_stock_visual() -> void:
	visible = true
	if stock_kind == StockKind.RITE:
		Glyph.clear_rarity_visual(self)
		texture = TABLET_TEXTURE
		_icon.texture = RiteSlot.resolve_texture(item_id)
		_icon.visible = true
	else:
		_icon.visible = false
		_icon.texture = null
		texture = Glyph.texture_for_id(item_id)
		Glyph.apply_rarity_visual(self, rarity)
	if is_node_ready() and _focused:
		set_focused(true)
	_apply_visual_y()


func _apply_empty_visual() -> void:
	Glyph.clear_rarity_visual(self)
	texture = null
	if is_node_ready():
		_icon.visible = false
		_icon.texture = null
		set_focused(false)
		_apply_visual_y()
	visible = false


func _tween_focus_lift(lifted: bool) -> void:
	var target_offset: float = FOCUS_LIFT_PX if lifted else 0.0
	if is_equal_approx(_focus_offset, target_offset):
		_apply_visual_y()
		return
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC)
	_focus_tween.set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_set_focus_offset, _focus_offset, target_offset, FOCUS_MOVE_DURATION)


func _set_focus_offset(value: float) -> void:
	_focus_offset = value
	_apply_visual_y()


## Float / focus lift only the drawn art (`offset` + icon). Node `position` stays
## fixed so shop interact distance does not flicker at the ellipse edge.
func _apply_visual_y() -> void:
	var visual_y: float = 0.0
	if is_stocked():
		visual_y = -_focus_offset - sin(_float_phase) * FLOAT_AMPLITUDE_PX
	offset = Vector2(0.0, visual_y)
	if is_node_ready():
		_icon.position = Vector2(0.0, visual_y)
	var particles: Node = get_node_or_null(NodePath(String(RARITY_PARTICLES_NODE)))
	if particles is Node2D:
		(particles as Node2D).position = Vector2(0.0, visual_y)


func _sync_float_process() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	set_process(is_stocked())
	_apply_visual_y()
