class_name OrbRecipes
extends RefCounted

const ELEMENTS: Array[String] = ["Fire", "Water", "Air", "Earth"]


static func elements_match(row: Dictionary, elements: Array[String]) -> bool:
	var needed: Array[String] = []
	for key in ["element_1", "element_2", "element_3"]:
		var value: Variant = row.get(key, null)
		if value == null:
			continue
		var element: String = String(value)
		if element.is_empty():
			continue
		needed.append(element)
	if needed.size() != elements.size():
		return false
	var remaining: Array[String] = elements.duplicate()
	for element in needed:
		var idx: int = remaining.find(element)
		if idx < 0:
			return false
		remaining.remove_at(idx)
	return remaining.is_empty()


static func find_orb(elements: Array[String]) -> Dictionary:
	for row_variant in GameData.get_table(&"orbs"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		if elements_match(row, elements):
			return row
	return {}


static func find_attunement(orb_id: StringName, elements: Array[String]) -> Dictionary:
	for row_variant in GameData.get_table(&"attunements"):
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_variant
		if StringName(String(row.get("orb_id", ""))) != orb_id:
			continue
		if elements_match(row, elements):
			return row
	return {}


## Blank orbs upgrade into specialist orbs; non-blank orbs look up Attunements.
static func result_for(orb: BlankOrb, elements: Array[String]) -> Dictionary:
	if orb == null or not is_instance_valid(orb):
		return {}
	if String(orb.orb_id) == "blank" or orb.orb_id == &"blank":
		return find_orb(elements)
	return find_attunement(orb.orb_id, elements)


## After two glyphs, return one hint per possible third element (Fire/Water/Air/Earth).
## Rows with GameData `active == false` are omitted (treated as no recipe).
static func hints_for(orb: BlankOrb, two_elements: Array[String]) -> Array:
	var hints: Array = []
	for element in ELEMENTS:
		var candidate: Array[String] = two_elements.duplicate()
		candidate.append(element)
		var row: Dictionary = result_for(orb, candidate)
		if not row.is_empty() and row.get("active") == false:
			row = {}
		var entry: Dictionary = {
			"element": element,
			"row": row,
			"label": "???",
			"discovered": false,
		}
		if not row.is_empty():
			var row_id: StringName = StringName(String(row.get("id", "")))
			if is_discovered(row_id):
				entry["label"] = String(row.get("name", "???"))
				entry["discovered"] = true
			else:
				entry["label"] = "???"
		hints.append(entry)
	return hints


## Authored `scene_path` if that file exists, else `res://entities/orbs/{id}/{id}_orb.tscn`.
static func resolved_scene_path(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var authored: String = String(row.get("scene_path", ""))
	if not authored.is_empty() and ResourceLoader.exists(authored):
		return authored
	var id: String = String(row.get("id", ""))
	if id.is_empty():
		return ""
	var fallback: String = "res://entities/orbs/%s/%s_orb.tscn" % [id, id]
	if ResourceLoader.exists(fallback):
		return fallback
	return ""


static func is_playable(row: Dictionary) -> bool:
	return not resolved_scene_path(row).is_empty()


static func effect_text(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var effect: String = String(row.get("effect", ""))
	if effect.is_empty():
		effect = String(row.get("desc", ""))
	return effect


static func stats_from_row(row: Dictionary) -> Dictionary:
	return {
		"damage": _row_float(row, "damage"),
		"self_damage": _row_float(row, "self_damage"),
		"splash": _row_float(row, "splash"),
		"speed": _row_float(row, "speed"),
		"weight": _row_float(row, "weight"),
		"crit_chance": _row_float(row, "crit_chance"),
		"crit_damage": _row_float(row, "crit_damage"),
		"glyph_drop": _row_float(row, "glyph_drop"),
		"burn": _row_float(row, "burn"),
		"chill": _row_float(row, "chill"),
		"shock": _row_float(row, "shock"),
		"poison": _row_float(row, "poison"),
	}


static func _row_float(row: Dictionary, key: String) -> float:
	var value: Variant = row.get(key, 0.0)
	if value == null:
		return 0.0
	return float(value)


## Provisional: all authored recipes are treated as discovered. Swap seam for a future registry.
static func is_discovered(_id: StringName) -> bool:
	return true


static func elements_from_socketed(socketed: Array) -> Array[String]:
	var elements: Array[String] = []
	for entry_variant in socketed:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var glyph_id: StringName = StringName(String(entry.get("id", "")))
		var row: Variant = GameData.get_row(&"glyphs", glyph_id)
		if row == null or typeof(row) != TYPE_DICTIONARY:
			continue
		var element: String = String((row as Dictionary).get("element", ""))
		if not element.is_empty():
			elements.append(element)
	return elements
