class_name WardRite
extends Rite

const COOLDOWN_SECONDS := 20.0

var _cooldown_remaining: float = 0.0


func tick(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func resolve(event: StringName, value: float, ctx: RiteContext) -> float:
	if event != &"self_damage":
		return value
	if value <= 0.0:
		return value
	if _cooldown_remaining > 0.0:
		return value
	ctx.blocked = true
	_cooldown_remaining = COOLDOWN_SECONDS
	return 0.0
