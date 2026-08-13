class_name SoundEvent
extends Resource

## One or more interchangeable takes; a random one is picked per play.
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export_range(-40.0, 12.0) var volume_db: float = 0.0
@export_range(0.1, 4.0) var pitch_min: float = 1.0
@export_range(0.1, 4.0) var pitch_max: float = 1.0
## Ignore repeat plays of this event within this window (0 = no limit).
@export var retrigger_cooldown: float = 0.0
## Max simultaneous voices of this event (0 = unlimited).
@export var max_voices: int = 0
## Never pick the same take twice in a row.
@export var avoid_repeat: bool = true

var _last_stream_index: int = -1


func pick_stream() -> AudioStream:
	if streams.is_empty():
		return null
	if streams.size() == 1:
		_last_stream_index = 0
		return streams[0]

	var index: int = randi() % streams.size()
	if avoid_repeat and index == _last_stream_index:
		index = (index + 1) % streams.size()
	_last_stream_index = index
	return streams[index]


func random_pitch() -> float:
	if is_equal_approx(pitch_min, pitch_max):
		return pitch_min
	return randf_range(pitch_min, pitch_max)
