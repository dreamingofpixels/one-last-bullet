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
static func hints_for(orb: BlankOrb, two_elements: Array[String]) -> Array:
	var hints: Array = []
	for element in ELEMENTS:
		var candidate: Array[String] = two_elements.duplicate()
		candidate.append(element)
		var row: Dictionary = result_for(orb, candidate)
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


static func is_playable(row: Dictionary) -> bool:
	if row.is_empty():
		return false
	var scene_path: Variant = row.get("scene_path", null)
	if scene_path == null:
		return false
	var path: String = String(scene_path)
	return not path.is_empty()


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
