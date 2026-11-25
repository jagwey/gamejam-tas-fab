extends Node
## AudioManager (autoload) — pooled SFX players + single looping music player.
## Bare names resolve to res://assets/audio/<name>.wav. Missing files are a safe no-op.

const POOL_SIZE: int = 12
const AUDIO_DIR: String = "res://assets/audio/"
const EXTENSIONS: Array[String] = [".wav", ".ogg", ".mp3"]

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _cache: Dictionary = {}
var _missing: Dictionary = {}
var _current_track: String = ""
var _next_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sfx_bus: String = _bus_or_master("SFX")
	for i in POOL_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		p.bus = sfx_bus
		add_child(p)
		_sfx_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = _bus_or_master("Music")
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)


func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = _resolve(sfx_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch_scale, 0.05, 4.0)
	player.play()


func play_music(track_name: String, volume_db: float = -4.0) -> void:
	var stream: AudioStream = _resolve(track_name)
	if stream == null:
		return
	if _current_track == track_name and _music_player.playing:
		_music_player.volume_db = volume_db
		return
	_set_loop(stream)
	_current_track = track_name
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func stop_music() -> void:
	_current_track = ""
	if _music_player != null:
		_music_player.stop()


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func _on_music_finished() -> void:
	# Fallback loop for streams that do not support a loop flag.
	if _current_track != "" and _music_player.stream != null:
		_music_player.play()


func _get_free_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# All busy: steal round-robin.
	var stolen: AudioStreamPlayer = _sfx_pool[_next_index]
	_next_index = (_next_index + 1) % _sfx_pool.size()
	return stolen


func _resolve(sound_name: String) -> AudioStream:
	if sound_name.is_empty():
		return null
	if _cache.has(sound_name):
		return _cache[sound_name] as AudioStream
	if _missing.has(sound_name):
		return null
	var candidates: Array[String] = []
	if sound_name.begins_with("res://") or sound_name.begins_with("user://"):
		candidates.append(sound_name)
	elif sound_name.get_extension() != "":
		candidates.append(AUDIO_DIR + sound_name)
	else:
		for ext in EXTENSIONS:
			candidates.append(AUDIO_DIR + sound_name + ext)
	for path in candidates:
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is AudioStream:
				_cache[sound_name] = res
				return res as AudioStream
	_missing[sound_name] = true
	return null


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			var bytes_per_sample: int = 2
			if wav.format == AudioStreamWAV.FORMAT_8_BITS:
				bytes_per_sample = 1
			var channels: int = 2 if wav.stereo else 1
			var total: int = wav.data.size() / maxi(bytes_per_sample * channels, 1)
			wav.loop_end = total
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _bus_or_master(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	return "Master"
