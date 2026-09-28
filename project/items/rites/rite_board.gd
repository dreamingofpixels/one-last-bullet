class_name RiteBoard
extends Node

## Live owned rites for the summoning circle. Combat code calls modify / notify / resolve.

static var active: RiteBoard = null

var _rites: Array[Rite] = []
var _by_id: Dictionary = {}


func _ready() -> void:
	active = self
	set_process(true)


func _exit_tree() -> void:
	if active == self:
		active = null


func _process(delta: float) -> void:
	for rite in _rites:
		rite.tick(delta)


func sync_from_ids(ids: Array[StringName]) -> void:
	var wanted: Dictionary = {}
	for id in ids:
		wanted[id] = true

	var to_remove: Array[StringName] = []
	for id in _by_id.keys():
		if not wanted.has(id):
			to_remove.append(id as StringName)
	for id in to_remove:
		_remove_rite(id)

	for id in ids:
		if _by_id.has(id):
			continue
		_add_rite(id)


func activate_rite(rite_id: StringName) -> void:
	if String(rite_id).strip_edges().is_empty():
		return
	if _by_id.has(rite_id):
		return
	_add_rite(rite_id)


func has_rite(rite_id: StringName) -> bool:
	return _by_id.has(rite_id)


func modify(stat: StringName, value: float, subject: Node = null) -> float:
	var result: float = value
	for rite in _rites:
		result = rite.modify(stat, result, subject)
	return result


func notify(event: StringName, ctx: RiteContext) -> void:
	if ctx == null:
		return
	for rite in _rites:
		rite.notify(event, ctx)


func resolve(event: StringName, value: float, ctx: RiteContext) -> float:
	if ctx == null:
		ctx = RiteContext.new()
	var result: float = value
	for rite in _rites:
		result = rite.resolve(event, result, ctx)
		if ctx.blocked:
			return 0.0
	return result


func _add_rite(rite_id: StringName) -> void:
	var rite: Rite = RiteCatalog.create(rite_id)
	if rite == null:
		return
	_by_id[rite_id] = rite
	_rites.append(rite)
	_sort_rites()
	rite.activate()


func _remove_rite(rite_id: StringName) -> void:
	var rite: Rite = _by_id.get(rite_id, null) as Rite
	if rite == null:
		return
	rite.deactivate()
	_by_id.erase(rite_id)
	_rites.erase(rite)


func _sort_rites() -> void:
	_rites.sort_custom(func(a: Rite, b: Rite) -> bool:
		if a.prio == b.prio:
			return String(a.rite_id) < String(b.rite_id)
		return a.prio < b.prio
	)
