extends Node

const GLOBAL_POOL_SIZE := 8
const WORLD_POOL_SIZE := 16

@onready var music_a: AudioStreamPlayer = %MusicA
@onready var music_b: AudioStreamPlayer = %MusicB
@onready var global_pool: Node = %GlobalPool
@onready var world_pool: Node = %WorldPool

var _active_music: AudioStreamPlayer
var _idle_music: AudioStreamPlayer
var _music_tween: Tween

## event_id -> last play msec
var _last_play_msec: Dictionary = {}
## event_id -> Array of players currently playing that event
var _active_by_event: Dictionary = {}
## player -> event_id
var _player_event: Dictionary = {}
## player -> start msec (for oldest-voice stealing)
var _player_start_msec: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active_music = music_a
	_idle_music = music_b
	_build_pool(global_pool, GLOBAL_POOL_SIZE, false)
	_build_pool(world_pool, WORLD_POOL_SIZE, true)


func play(event: SoundEvent) -> AudioStreamPlayer:
	if event == null:
		return null
	if not _can_play(event):
		return null

	var stream: AudioStream = event.pick_stream()
	if stream == null:
		return null

	var player: AudioStreamPlayer = _acquire_global()
	if player == null:
		return null

	_configure_player(player, event, stream)
	player.play()
	_register_play(event, player)
	return player


func play_at(event: SoundEvent, position: Vector2) -> AudioStreamPlayer2D:
	if event == null:
		return null
	if not _can_play(event):
		return null

	var stream: AudioStream = event.pick_stream()
	if stream == null:
		return null

	var player: AudioStreamPlayer2D = _acquire_world()
	if player == null:
		return null

	player.global_position = position
	_configure_player(player, event, stream)
	player.play()
	_register_play(event, player)
	return player


func stop_event(event: SoundEvent) -> void:
	if event == null:
		return
	var event_id: int = event.get_instance_id()
	if not _active_by_event.has(event_id):
		return
	var players: Array = _active_by_event[event_id].duplicate()
	for player in players:
		if is_instance_valid(player):
			player.stop()
			_on_player_finished(player)


func stop_all_sfx() -> void:
	for child in global_pool.get_children():
		if child.playing:
			child.stop()
			_on_player_finished(child)
	for child in world_pool.get_children():
		if child.playing:
			child.stop()
			_on_player_finished(child)


func play_music(stream: AudioStream, fade: float = 1.0, from_position: float = 0.0) -> void:
	if stream == null:
		return

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	# Already playing this stream on the active player — restart only if needed.
	if _active_music.playing and _active_music.stream == stream and fade <= 0.0:
		_active_music.play(from_position)
		return

	_idle_music.stream = stream
	_idle_music.volume_db = -80.0
	_idle_music.play(from_position)

	if fade <= 0.0 or not _active_music.playing:
		_active_music.stop()
		_idle_music.volume_db = 0.0
		var swap: AudioStreamPlayer = _active_music
		_active_music = _idle_music
		_idle_music = swap
		return

	var outgoing: AudioStreamPlayer = _active_music
	var incoming: AudioStreamPlayer = _idle_music
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(outgoing, "volume_db", -80.0, fade)
	_music_tween.tween_property(incoming, "volume_db", 0.0, fade)
	_music_tween.finished.connect(func() -> void:
		outgoing.stop()
		_active_music = incoming
		_idle_music = outgoing
	, CONNECT_ONE_SHOT)


func stop_music(fade: float = 1.0) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if not _active_music.playing and not _idle_music.playing:
		return

	if fade <= 0.0:
		_active_music.stop()
		_idle_music.stop()
		_active_music.volume_db = 0.0
		_idle_music.volume_db = 0.0
		return

	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	if _active_music.playing:
		_music_tween.tween_property(_active_music, "volume_db", -80.0, fade)
	if _idle_music.playing:
		_music_tween.tween_property(_idle_music, "volume_db", -80.0, fade)
	_music_tween.finished.connect(func() -> void:
		_active_music.stop()
		_idle_music.stop()
		_active_music.volume_db = 0.0
		_idle_music.volume_db = 0.0
	, CONNECT_ONE_SHOT)


func set_bus_volume_linear(bus: StringName, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(value, 0.0, 1.0)))


func get_bus_volume_linear(bus: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func set_bus_muted(bus: StringName, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, muted)


# ── Internals ─────────────────────────────────────────────────────────────────

func _build_pool(parent: Node, count: int, positional: bool) -> void:
	for i in count:
		var player: Node
		if positional:
			player = AudioStreamPlayer2D.new()
			(player as AudioStreamPlayer2D).bus = &"SFX"
			(player as AudioStreamPlayer2D).max_distance = 2000.0
		else:
			player = AudioStreamPlayer.new()
			(player as AudioStreamPlayer).bus = &"SFX"
		player.name = "Player%d" % (i + 1)
		parent.add_child(player)
		player.finished.connect(_on_player_finished.bind(player))


func _can_play(event: SoundEvent) -> bool:
	var event_id: int = event.get_instance_id()
	if event.retrigger_cooldown > 0.0:
		var last: int = _last_play_msec.get(event_id, -1)
		if last >= 0:
			var elapsed: float = (Time.get_ticks_msec() - last) / 1000.0
			if elapsed < event.retrigger_cooldown:
				return false

	if event.max_voices > 0:
		var active: Array = _active_by_event.get(event_id, [])
		# Prune stale entries.
		var living: Array = []
		for p in active:
			if is_instance_valid(p) and p.playing:
				living.append(p)
		_active_by_event[event_id] = living
		if living.size() >= event.max_voices:
			return false

	return true


func _configure_player(player: Node, event: SoundEvent, stream: AudioStream) -> void:
	player.stream = stream
	player.volume_db = event.volume_db
	player.pitch_scale = event.random_pitch()
	player.bus = event.bus


func _register_play(event: SoundEvent, player: Node) -> void:
	var event_id: int = event.get_instance_id()
	_last_play_msec[event_id] = Time.get_ticks_msec()
	_player_event[player] = event_id
	_player_start_msec[player] = Time.get_ticks_msec()
	if not _active_by_event.has(event_id):
		_active_by_event[event_id] = []
	_active_by_event[event_id].append(player)


func _on_player_finished(player: Node) -> void:
	var event_id = _player_event.get(player, null)
	if event_id != null and _active_by_event.has(event_id):
		_active_by_event[event_id].erase(player)
	_player_event.erase(player)
	_player_start_msec.erase(player)


func _acquire_global() -> AudioStreamPlayer:
	return _acquire_from(global_pool.get_children()) as AudioStreamPlayer


func _acquire_world() -> AudioStreamPlayer2D:
	return _acquire_from(world_pool.get_children()) as AudioStreamPlayer2D


func _acquire_from(players: Array) -> Node:
	var oldest: Node = null
	var oldest_msec: int = 0x7fffffff

	for player in players:
		if not player.playing:
			return player
		var start: int = _player_start_msec.get(player, 0)
		if start < oldest_msec:
			oldest_msec = start
			oldest = player

	# Steal the oldest voice.
	if oldest != null:
		oldest.stop()
		_on_player_finished(oldest)
		return oldest
	return null
