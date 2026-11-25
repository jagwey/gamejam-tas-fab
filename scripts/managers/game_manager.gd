extends Node
## GameManager (autoload) — floor flow, objective text, boss bar relay, input safety net, CRT overlay.

signal floor_changed(floor_num: int, floor_title: String)
signal objective_changed(objective_text: String)
signal boss_bar_updated(boss_name: String, hp: float, max_hp: float, show_bar: bool)

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const OPENING_CUTSCENE: String = "res://scenes/cutscenes/opening_cutscene.tscn"
const ENDING_SCENE: String = "res://scenes/cutscenes/ending_cutscene.tscn"
const CRT_OVERLAY_SCENE: String = "res://scenes/ui/crt_overlay.tscn"

const FLOOR_TITLES: Dictionary = {
	1: "KAT 1: LOBİ VE GÜVENLİK",
	2: "KAT 2: OFİS VE ARŞİV",
	3: "KAT 3: BİYOTEKNOLOJİ LABORATUVARI",
	4: "KAT 4: VIP VE KUMARHANE",
	5: "KAT 5: ÇATI VE REAKTÖR",
}

## action -> Array of [type, code]. type "key" uses physical keycode, "mouse" uses button index.
const DEFAULT_INPUTS: Dictionary = {
	"move_forward": [["key", KEY_W]],
	"move_back": [["key", KEY_S]],
	"move_left": [["key", KEY_A]],
	"move_right": [["key", KEY_D]],
	"shoot": [["mouse", MOUSE_BUTTON_LEFT]],
	"alt_aim": [["mouse", MOUSE_BUTTON_RIGHT]],
	"sprint": [["key", KEY_SHIFT]],
	"crouch": [["key", KEY_CTRL]],
	"jump": [["key", KEY_SPACE]],
	"reload": [["key", KEY_R]],
	"interact": [["key", KEY_E]],
	"use_beta": [["key", KEY_F]],
	"melee": [["key", KEY_Q]],
	"weapon_1": [["key", KEY_1]],
	"weapon_2": [["key", KEY_2]],
	"weapon_3": [["key", KEY_3]],
	"pause": [["key", KEY_ESCAPE]],
}

var current_floor: int = 1
var current_objective: String = ""
var player_carryover: Dictionary = {}
var floor_scenes: Dictionary = {
	1: "res://scenes/levels/floor_01_lobby.tscn",
	2: "res://scenes/levels/floor_02_office.tscn",
	3: "res://scenes/levels/floor_03_lab.tscn",
	4: "res://scenes/levels/floor_04_vip.tscn",
	5: "res://scenes/levels/floor_05_rooftop.tscn",
}

var crt_layer: CanvasLayer = null
var _floor_entry_carryover: Dictionary = {}
var _pending_announce: bool = false
var _quitting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_input_actions()
	_attach_crt_overlay()
	var tree: SceneTree = get_tree()
	if tree.has_signal("scene_changed"):
		tree.connect("scene_changed", _on_scene_changed)
	var settings: Node = get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_signal("settings_changed"):
		settings.connect("settings_changed", _on_settings_changed)
	# Window close goes through quit_game() so audio playbacks are released cleanly.
	tree.auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Graceful exit: stop audio, give the AudioServer a few frames to drop its playbacks, then quit.
func quit_game() -> void:
	if _quitting:
		return
	_quitting = true
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("release_all"):
		audio.call("release_all")
	var tree: SceneTree = get_tree()
	tree.paused = false
	for _i in 3:
		await tree.process_frame
	await tree.create_timer(0.06, true, false, true).timeout
	tree.quit()


# ---------------------------------------------------------------- input safety

func ensure_input_actions() -> void:
	for action_key in DEFAULT_INPUTS.keys():
		var action: StringName = StringName(str(action_key))
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		if not InputMap.action_get_events(action).is_empty():
			continue
		var bindings: Array = DEFAULT_INPUTS[action_key] as Array
		for b in bindings:
			var binding: Array = b as Array
			var kind: String = str(binding[0])
			var code: int = int(binding[1])
			if kind == "mouse":
				var mb: InputEventMouseButton = InputEventMouseButton.new()
				mb.button_index = code as MouseButton
				InputMap.action_add_event(action, mb)
			else:
				var ev: InputEventKey = InputEventKey.new()
				ev.physical_keycode = code as Key
				InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- CRT overlay

func _attach_crt_overlay() -> void:
	if not ResourceLoader.exists(CRT_OVERLAY_SCENE):
		return
	var packed: PackedScene = load(CRT_OVERLAY_SCENE) as PackedScene
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	if inst is CanvasLayer:
		crt_layer = inst as CanvasLayer
	else:
		crt_layer = CanvasLayer.new()
		crt_layer.name = "CrtOverlayLayer"
		crt_layer.add_child(inst)
	crt_layer.layer = 100
	crt_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(crt_layer)
	_on_settings_changed()


func _on_settings_changed() -> void:
	if crt_layer == null:
		return
	var settings: Node = get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	crt_layer.visible = bool(settings.get("crt_enabled"))


# ---------------------------------------------------------------- floor flow

func get_floor_title(floor_num: int) -> String:
	if FLOOR_TITLES.has(floor_num):
		return str(FLOOR_TITLES[floor_num])
	return "KAT %d" % floor_num


func get_current_floor_title() -> String:
	return get_floor_title(current_floor)


func start_new_game() -> void:
	get_tree().paused = false
	player_carryover = {}
	_floor_entry_carryover = {}
	current_floor = 1
	current_objective = ""
	if ResourceLoader.exists(OPENING_CUTSCENE):
		_change_scene(OPENING_CUTSCENE)
	else:
		load_floor(1, true)


func continue_game() -> void:
	get_tree().paused = false
	var data: Dictionary = {}
	var sm: Node = _save_manager()
	if sm != null:
		var loaded: Variant = sm.call("load_progress")
		if loaded is Dictionary:
			data = loaded as Dictionary
	var floor_num: int = int(data.get("current_floor", 1))
	var raw_state: Variant = data.get("player_state", {})
	player_carryover = {}
	if raw_state is Dictionary:
		player_carryover = (raw_state as Dictionary).duplicate(true)
	_enter_floor(floor_num)


func load_floor(floor_num: int, save_checkpoint: bool = true) -> void:
	get_tree().paused = false
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("export_state"):
		var exported: Variant = player.call("export_state")
		if exported is Dictionary:
			player_carryover = (exported as Dictionary).duplicate(true)
	if save_checkpoint:
		var sm: Node = _save_manager()
		if sm != null:
			sm.call("save_progress", floor_num, player_carryover)
	_enter_floor(floor_num)


func restart_current_floor() -> void:
	get_tree().paused = false
	player_carryover = _floor_entry_carryover.duplicate(true)
	_enter_floor(current_floor)


func return_to_main_menu() -> void:
	get_tree().paused = false
	update_boss_bar("", 0.0, 1.0, false)
	_change_scene(MAIN_MENU_SCENE)


func has_floor(floor_num: int) -> bool:
	return floor_scenes.has(floor_num)


## Returns the carryover dictionary for the player to import, then keeps it as the floor-entry snapshot.
func get_player_carryover() -> Dictionary:
	return player_carryover.duplicate(true)


func _save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")


func _enter_floor(floor_num: int) -> void:
	if not floor_scenes.has(floor_num):
		# Past the last built floor: go to ending (if present) or main menu.
		if ResourceLoader.exists(ENDING_SCENE):
			_change_scene(ENDING_SCENE)
		else:
			return_to_main_menu()
		return
	current_floor = floor_num
	_floor_entry_carryover = player_carryover.duplicate(true)
	current_objective = ""
	update_boss_bar("", 0.0, 1.0, false)
	floor_changed.emit(floor_num, get_floor_title(floor_num))
	_pending_announce = true
	_change_scene(str(floor_scenes[floor_num]))


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("GameManager: scene missing: %s" % path)
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_warning("GameManager: change_scene failed (%d) for %s" % [err, path])


func _on_scene_changed() -> void:
	# A floor scene opened directly (editor F6 / CLI) keeps the floor number in sync.
	var scene: Node = get_tree().current_scene
	if scene != null and not _pending_announce:
		for key in floor_scenes:
			if str(floor_scenes[key]) == scene.scene_file_path and int(key) != current_floor:
				current_floor = int(key)
				floor_changed.emit(current_floor, get_floor_title(current_floor))
				break
	# Re-announce for UI that only exists in the newly loaded scene.
	if _pending_announce:
		_pending_announce = false
		floor_changed.emit(current_floor, get_floor_title(current_floor))
		objective_changed.emit(current_objective)


# ---------------------------------------------------------------- HUD relays

func set_objective(text: String) -> void:
	current_objective = text
	objective_changed.emit(text)


func update_boss_bar(boss_name: String, hp: float, max_hp: float, show_bar: bool) -> void:
	boss_bar_updated.emit(boss_name, hp, max_hp, show_bar)
