@tool
extends Node

const DATA_PATH: String = "res://data/game_data.json"

## sheet name -> Array of row dictionaries
var tables: Dictionary = {}
## sheet name -> id string -> row dictionary
var tables_by_id: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	tables = {}
	tables_by_id = {}

	var text: Variant = _read_text(DATA_PATH)
	if text == null:
		return

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: Failed to parse %s as JSON object." % DATA_PATH)
		return

	var root: Dictionary = parsed
	for sheet_name in root.keys():
		var key := str(sheet_name)
		var value: Variant = root[sheet_name]
		if typeof(value) != TYPE_ARRAY:
			push_error("GameData: Key '%s' is not an Array in %s" % [key, DATA_PATH])
			continue
		tables[key] = value
		tables_by_id[key] = _index_by_id(value, key)


func get_table(sheet: StringName) -> Array:
	var key := String(sheet)
	if tables.has(key):
		return tables[key]
	return []


func get_row(sheet: StringName, id: StringName) -> Variant:
	var key := String(sheet)
	var id_key := String(id)
	var by_id: Variant = tables_by_id.get(key, null)
	if by_id == null or typeof(by_id) != TYPE_DICTIONARY:
		return null
	return (by_id as Dictionary).get(id_key, null)


func has_row(sheet: StringName, id: StringName) -> bool:
	return get_row(sheet, id) != null


func _read_text(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: Missing file %s" % path)
		return null

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: Could not open %s for reading." % path)
		return null

	return f.get_as_text()


func _index_by_id(records: Array, label: String) -> Dictionary:
	var out: Dictionary = {}
	for i in range(records.size()):
		var rec_v: Variant = records[i]
		if typeof(rec_v) != TYPE_DICTIONARY:
			push_error("GameData: %s[%d] is not a Dictionary." % [label, i])
			continue
		var rec: Dictionary = rec_v
		if not rec.has("id"):
			continue
		var id_v: Variant = rec["id"]
		if id_v == null:
			continue
		if typeof(id_v) != TYPE_STRING:
			push_error("GameData: %s[%d].id must be a string (got %s)." % [label, i, type_string(typeof(id_v))])
			continue
		var id_s := String(id_v).strip_edges()
		if id_s.is_empty():
			continue
		if out.has(id_s):
			push_error("GameData: Duplicate %s id '%s' (keeping the first occurrence)." % [label, id_s])
			continue
		out[id_s] = rec
	return out
