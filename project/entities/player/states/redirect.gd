extends State

# We stash the ignore-confirm window so the same Space that entered redirect
# doesn't instantly confirm it.
var _ignore_confirm_until_msec: int = 0


func enter() -> void:
	owner.movement_component.stop()
	# Only start a redirect if the bullet is flying; during the opening aim the
	# bullet is already in AIMING state (set by level.gd before forcing this state).
	if owner.redirect_component.can_redirect():
		owner.redirect_component.begin_redirect()
	_ignore_confirm_until_msec = Time.get_ticks_msec() + 200


func exit() -> void:
	pass


func update(_delta: float) -> void:
	if not owner.redirect_component.can_aim():
		# Bullet launched or window expired – return to idle.
		emit_signal("finished", "idle")
		return

	var controls: Controls = owner.controls
	# Convert aim input to world-space direction then feed the bullet.
	# get_aim_vector returns a canvas-local direction, which equals world direction
	# at scale 1 with no camera rotation. If camera ever transforms, revisit.
	var local_dir := controls.get_aim_vector(owner.global_position)
	if local_dir.length_squared() > 0.0001:
		owner.redirect_component.set_aim_direction(local_dir)

	if Time.get_ticks_msec() >= _ignore_confirm_until_msec:
		if controls.is_confirm_just_pressed():
			owner.redirect_component.confirm_aim()


func handle_input(_event: InputEvent) -> void:
	pass
