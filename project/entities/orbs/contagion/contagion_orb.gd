class_name ContagionOrb extends BlankOrb

const DISEASE_CHANCE := 0.2


func on_hitbox_hit(victim: Node) -> void:
	super.on_hitbox_hit(victim)
	if victim == null or not is_instance_valid(victim):
		return
	if not victim.is_in_group("enemies"):
		return
	if randf() >= DISEASE_CHANCE:
		return

	var comp = victim.get("COMPONENTS")
	if comp == null or not comp.has(StatusComponent):
		return
	(comp[StatusComponent] as StatusComponent).add_stacks(
		StatusComponent.StatusId.DISEASE,
		1,
		self
	)
