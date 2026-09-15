@tool
class_name GlyphEntryConfig
extends Resource

@export var glyph_id: StringName = &"static"

@export var rarity: Glyph.Rarity = Glyph.Rarity.COMMON


func _validate_property(property: Dictionary) -> void:
	if property.name != &"glyph_id":
		return
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(Glyph.glyph_ids_for_inspector())
