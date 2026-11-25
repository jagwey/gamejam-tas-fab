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
## 0 = Düşük, 1 = Orta, 2 = Yüksek
var graphics_quality: int = 1
var vsync_enabled: bool = true
var show_fps: bool = false
## 0 = Normal, 1 = Bordo Bereli
var difficulty: int = 0


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


func set_graphics_quality(q: int) -> void:
	graphics_quality = clampi(q, 0, 2)
	apply_video_settings()
	_commit()


func set_vsync_enabled(enabled: bool) -> void:
	vsync_enabled = enabled
	apply_video_settings()
	_commit()


func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	_commit()


func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, 1)
	_commit()


func get_difficulty_name() -> String:
	return "Bordo Bereli (Zor)" if difficulty == 1 else "Normal"


func get_enemy_hp_mult() -> float:
	return 1.25 if difficulty == 1 else 1.0


func get_enemy_damage_mult() -> float:
	return 1.30 if difficulty == 1 else 1.0


func get_enemy_speed_mult() -> float:
	return 1.12 if difficulty == 1 else 1.0


## VSync + 3D render scale. No-op on the headless display server.
func apply_video_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.scaling_3d_scale = 0.80 if graphics_quality <= 0 else 1.0


## Full-screen glow (bloom) only on High quality — big FPS win on Low/Medium.
func apply_environment_quality(env: Environment) -> void:
	if env == null:
		return
	env.glow_enabled = graphics_quality >= 2


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "horizontal_fov", horizontal_fov)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "camera_shake_enabled", camera_shake_enabled)
	cfg.set_value("video", "crt_enabled", crt_enabled)
	cfg.set_value("video", "graphics_quality", graphics_quality)
	cfg.set_value("video", "vsync_enabled", vsync_enabled)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("gameplay", "difficulty", difficulty)
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
		graphics_quality = clampi(int(cfg.get_value("video", "graphics_quality", graphics_quality)), 0, 2)
		vsync_enabled = bool(cfg.get_value("video", "vsync_enabled", vsync_enabled))
		show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
		difficulty = clampi(int(cfg.get_value("gameplay", "difficulty", difficulty)), 0, 1)
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
	apply_video_settings()


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
