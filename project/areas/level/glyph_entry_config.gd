@tool
class_name GlyphEntryConfig
extends Resource

@export var glyph_id: StringName = &"static"

@export var rarity: Glyph.Rarity = Glyph.Rarity.COMMON


func _validate_property(property: Dictionary) -> void:
	if property.name != &"glyph_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(_glyph_ids())


func _glyph_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	for row_variant in GameData.get_table(&"glyphs"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var id_s: String = String((row_variant as Dictionary).get("id", "")).strip_edges()
		if not id_s.is_empty():
			ids.append(id_s)
	ids.sort()
	if ids.is_empty():
		ids.append("static")
	return ids
