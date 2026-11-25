extends SceneTree
## v0.3.0 Forward+ render smoke: main menu, settings tabs, Floor 1 combat HUD, Floor 3 radio comms,
## Floor 5 Volkov and the ending OVA, rendered in a real window. Screenshots land in
## <OS temp>/beta_protocol_render_smoke/v030_*.png, then the run exits through GameManager.quit_game().
## Run (non-headless): Godot_v4.7.2-stable_win64_console.exe --path <project> --script res://tests/render_smoke.gd

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const FLOOR_1: String = "res://scenes/levels/floor_01_lobby.tscn"
const FLOOR_3: String = "res://scenes/levels/floor_03_lab.tscn"
const FLOOR_5: String = "res://scenes/levels/floor_05_rooftop.tscn"
const ENDING: String = "res://scenes/cutscenes/ending_cutscene.tscn"
const FPS_FRAMES: int = 75

var out_dir: String = ""
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _load(path: String) -> bool:
	var err: Error = change_scene_to_file(path)
	if err != OK:
		print("LOAD FAIL ", path, " ", error_string(err))
		failures += 1
		return false
	await _frames(2)
	return current_scene != null


func _shot(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(name)
	var err: Error = img.save_png(path)
	if err != OK:
		failures += 1
	print("shot ", name, " ", img.get_size(), " -> ", path, " (", error_string(err), ")")


## Lets the scene settle for a second and reports the measured frame rate.
func _fps(label: String) -> void:
	await _frames(FPS_FRAMES)
	print("fps ", label, " = ", Engine.get_frames_per_second())


func _run() -> void:
	var driver: String = str(ProjectSettings.get_setting("rendering/rendering_device/driver"))
	print("renderer: ", RenderingServer.get_current_rendering_method(), " / ", RenderingServer.get_video_adapter_name(), " / driver: ", driver)
	out_dir = OS.get_temp_dir().path_join("beta_protocol_render_smoke")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gm: Node = root.get_node("GameManager")

	if await _load(MAIN_MENU):
		await _frames(30)
		_shot("v030_main_menu.png")
		await _fps("main_menu")
		var btn: Button = current_scene.get_node_or_null("%Settings") as Button
		if btn != null:
			btn.pressed.emit()
		var panel: Control = current_scene.get_node_or_null("%SettingsPanel") as Control
		if panel != null:
			panel.show()
		else:
			print("WARN-SMOKE: %SettingsPanel not found")
			failures += 1
		await _frames(10)
		_shot("v030_settings_tabs.png")

	if await _load(FLOOR_1):
		await _frames(15)
		_shot("v030_floor_01_combat_hud.png")
		await _fps("floor_01")

	if await _load(FLOOR_3):
		await _frames(5)
		gm.call("send_radio", "GENERAL DEMİR", "general_portrait", "BETA mimarisi Volkov'un prototipinden kopyalandı. Dikkatli ol Aydın.", 6.0)
		await _frames(45)
		_shot("v030_floor_03_radio.png")
		await _fps("floor_03")

	if await _load(FLOOR_5):
		await _frames(60)
		_shot("v030_floor_05_volkov.png")
		await _fps("floor_05")

	if await _load(ENDING):
		await _frames(60)
		_shot("v030_ending_ova.png")
		await _fps("ending")

	print("RENDER SMOKE DONE: failures=", failures)
	gm.call("quit_game")
