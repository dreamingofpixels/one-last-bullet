class_name RiteCatalog
extends RefCounted

const SCRIPTS: Dictionary = {
	&"frostburn": preload("res://items/rites/frostburn_rite.gd"),
	&"ward": preload("res://items/rites/ward_rite.gd"),
	&"clash": preload("res://items/rites/clash_rite.gd"),
	&"tempered": preload("res://items/rites/tempered_rite.gd"),
}


static func create(rite_id: StringName) -> Rite:
	var script: Script = SCRIPTS.get(rite_id, null) as Script
	if script == null:
		return null
	var instance: Rite = script.new() as Rite
	if instance == null:
		return null
	instance.rite_id = rite_id
	instance.prio = _prio_for(rite_id)
	return instance


static func _prio_for(rite_id: StringName) -> int:
	var row: Variant = GameData.get_row(&"rites", rite_id)
	if row == null or typeof(row) != TYPE_DICTIONARY:
		return 999
	var prio_v: Variant = (row as Dictionary).get("prio", null)
	if prio_v == null:
		return 999
	if typeof(prio_v) == TYPE_FLOAT or typeof(prio_v) == TYPE_INT:
		return int(prio_v)
	var prio_s: String = String(prio_v).strip_edges()
	if prio_s.is_empty():
		return 999
	return int(prio_s)
