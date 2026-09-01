class_name RotOrb extends BlankOrb


func on_hitbox_hit(victim: Node) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	if not victim.is_in_group("enemies"):
		return

	var comp = victim.get("COMPONENTS")
	if comp == null or not comp.has(StatusComponent):
		return

	var status: StatusComponent = comp[StatusComponent] as StatusComponent
	status.add_stacks(StatusComponent.StatusId.POISON, 3)
