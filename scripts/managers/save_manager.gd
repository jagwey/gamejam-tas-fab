extends Node
## SaveManager (autoload) — single-slot checkpoint save in user://savegame.cfg.

const SAVE_PATH: String = "user://savegame.cfg"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_progress(floor_number: int, state: Dictionary = {}) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("progress", "current_floor", floor_number)
	cfg.set_value("progress", "player_state", state.duplicate(true))
	cfg.set_value("progress", "timestamp", Time.get_unix_time_from_system())
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("SaveManager: save failed (%d)" % err)


func load_progress() -> Dictionary:
	var result: Dictionary = {"current_floor": 1, "player_state": {}}
	if not has_save():
		return result
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return result
	var floor_num: int = int(cfg.get_value("progress", "current_floor", 1))
	var raw_state: Variant = cfg.get_value("progress", "player_state", {})
	var state: Dictionary = {}
	if raw_state is Dictionary:
		state = (raw_state as Dictionary).duplicate(true)
	result["current_floor"] = maxi(floor_num, 1)
	result["player_state"] = state
	return result


func clear_save() -> void:
	if has_save():
		var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			push_warning("SaveManager: could not delete save (%d)" % err)
