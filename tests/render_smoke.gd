extends SceneTree
## Forward+ render smoke: loads Floors 3-5 + ending in a real window, renders frames,
## saves screenshots to the OS temp dir, then exits through GameManager.quit_game().
## Run (non-headless): Godot_v4.7.2-stable_win64_console.exe --path <project> --script res://tests/render_smoke.gd

const SCENES: Array[String] = [
	"res://scenes/levels/floor_03_lab.tscn",
	"res://scenes/levels/floor_04_vip.tscn",
	"res://scenes/levels/floor_05_rooftop.tscn",
	"res://scenes/cutscenes/ending_cutscene.tscn",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("renderer: ", RenderingServer.get_current_rendering_method(), " / ", RenderingServer.get_video_adapter_name(),
		" / driver: ", OS.get_environment("GODOT_DRIVER") if OS.has_environment("GODOT_DRIVER") else ProjectSettings.get_setting("rendering/rendering_device/driver"))
	var out_dir: String = OS.get_temp_dir().path_join("beta_protocol_render_smoke")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for path in SCENES:
		var err: Error = change_scene_to_file(path)
		if err != OK:
			print("LOAD FAIL ", path, " ", error_string(err))
			continue
		for _i in 90:
			await process_frame
		var img: Image = root.get_texture().get_image()
		var shot: String = out_dir.path_join(path.get_file().get_basename() + ".png")
		img.save_png(shot)
		print("rendered ", path, " fps=", Engine.get_frames_per_second(), " -> ", shot, " ", img.get_size())
	root.get_node("GameManager").call("quit_game")
