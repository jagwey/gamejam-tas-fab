extends Node
## SettingsManager (autoload) — persists player options to user://settings.cfg.

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const FOV_MIN: float = 75.0
const FOV_MAX: float = 120.0

var mouse_sensitivity: float = 0.22
var horizontal_fov: float = 100.0
var master_volume: float = 0.85
var music_volume: float = 0.65
var sfx_volume: float = 0.85
var fullscreen: bool = false
var camera_shake_enabled: bool = true
var crt_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func set_horizontal_fov(deg: float) -> void:
	horizontal_fov = clampf(deg, FOV_MIN, FOV_MAX)
	_commit()


func set_mouse_sensitivity(val: float) -> void:
	mouse_sensitivity = clampf(val, 0.01, 2.0)
	_commit()


func set_bus_volume(bus_name: String, linear_val: float) -> void:
	var v: float = clampf(linear_val, 0.0, 1.0)
	match bus_name:
		"Master":
			master_volume = v
		"Music":
			music_volume = v
		"SFX":
			sfx_volume = v
		_:
			pass
	_apply_bus(bus_name, v)
	_commit()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_fullscreen()
	_commit()


func set_camera_shake(enabled: bool) -> void:
	camera_shake_enabled = enabled
	_commit()


func set_crt_enabled(enabled: bool) -> void:
	crt_enabled = enabled
	_commit()


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "horizontal_fov", horizontal_fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "camera_shake_enabled", camera_shake_enabled)
	cfg.set_value("video", "crt_enabled", crt_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	var err: Error = cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsManager: could not save settings (%d)" % err)


func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SETTINGS_PATH)
	if err == OK:
		mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.01, 2.0)
		horizontal_fov = clampf(float(cfg.get_value("video", "horizontal_fov", horizontal_fov)), FOV_MIN, FOV_MAX)
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		camera_shake_enabled = bool(cfg.get_value("video", "camera_shake_enabled", camera_shake_enabled))
		crt_enabled = bool(cfg.get_value("video", "crt_enabled", crt_enabled))
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	apply_all()
	settings_changed.emit()


func apply_all() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("Music", music_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_fullscreen()


func _commit() -> void:
	save_settings()
	settings_changed.emit()


func _apply_bus(bus_name: String, linear_val: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var v: float = clampf(linear_val, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
