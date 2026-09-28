class_name Rite
extends RefCounted

var rite_id: StringName = &""
var prio: int = 999


func activate() -> void:
	pass


func deactivate() -> void:
	pass


func modify(_stat: StringName, value: float, _subject: Node) -> float:
	return value


func notify(_event: StringName, _ctx: RiteContext) -> void:
	pass


func resolve(_event: StringName, value: float, _ctx: RiteContext) -> float:
	return value


func tick(_delta: float) -> void:
	pass
