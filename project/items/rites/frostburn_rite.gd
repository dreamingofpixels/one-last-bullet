class_name FrostburnRite
extends Rite


func notify(event: StringName, ctx: RiteContext) -> void:
	if event != &"status_applied":
		return
	if ctx.status_id != StatusComponent.StatusId.CHILL:
		return
	if ctx.stacks < 3:
		return
	if ctx.victim == null or not is_instance_valid(ctx.victim):
		return
	var comp = ctx.victim.get("COMPONENTS")
	if comp == null or not comp.has(StatusComponent):
		return
	var status: StatusComponent = comp[StatusComponent] as StatusComponent
	status.add_stacks(StatusComponent.StatusId.BURN, 1, ctx.source, true)
