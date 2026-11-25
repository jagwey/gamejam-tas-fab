extends "res://scripts/systems/cutscene_player.gd"

const EPILOGUE := [
	["Çatı • Savunma Kulesi", "", "Aydın Beta Reaktörü'nü güvenceye alır. Çatıdaki deneysel savunma kulesi kapanır.", "aydin_visor"],
	["Çatı • Tahliye Hattı", "GENERAL (TELSİZ)", "Savunma ağı düştü! Tahliye helikopterleri çatıya iniyor. Harika iş çıkardın, Aydın.", "general_portrait"],
	["Çatı • Tahliye Hattı", "AYDIN", "Reaktör güvende. Bu teknoloji kimsenin eline geçmemeliydi.", "aydin_visor"],
	["Köy Evi • Şafak", "", "Haftalar sonra... Aydın köyündeki sakin hayatına döner.", "aydin_village"],
]

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var track := "bgm_menu_cutscene"
	for ext in AudioManager.EXTENSIONS:
		if ResourceLoader.exists(AudioManager.AUDIO_DIR + "bgm_ending" + ext):
			track = "bgm_ending"
			break
	AudioManager.play_music(track)
	%MenuButton.pressed.connect(GameManager.return_to_main_menu)
	_show_shot()
	_update_skip_display()

func _show_shot() -> void:
	var line: Array = EPILOGUE[shot_index]
	var village := shot_index == 3
	if shot_index == 0 or village:
		var background := _art("bg_ending_village" if village else "bg_ending_rooftop")
		if background == null:
			background = _art("bg_village_house" if village else "bg_tower_exterior")
		%Background.texture = background
		if pan:
			pan.kill()
		%Background.position = Vector2(-12, -10)
		pan = create_tween()
		pan.tween_property(%Background, "position", Vector2(-52, -18), 8.0 if village else 20.0)
	%Rain.visible = not village
	%Radio.visible = shot_index == 1
	%Location.text = line[0]
	%Speaker.text = line[1]
	_begin_dialogue(str(line[2]))
	%Portrait.texture = _art(str(line[3]))
	remaining = maxf(4.0, 1.6 + float(str(line[2]).length()) / 15.0)

func advance_line() -> void:
	if has_finished:
		return
	shot_index += 1
	if shot_index == EPILOGUE.size():
		finish_cutscene()
	else:
		_show_shot()

func finish_cutscene() -> void:
	if has_finished:
		return
	has_finished = true
	if pan:
		pan.kill()
	for child in get_children():
		if child is Control and child != %Summary:
			child.hide()
	%Summary.show()
	cutscene_finished.emit()
	# A held skip key also maps to ui_accept. Focus only after its release.
	if not Input.is_key_pressed(KEY_SPACE):
		%MenuButton.grab_focus()

func _input(event: InputEvent) -> void:
	if has_finished and event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed:
		if not %MenuButton.has_focus():
			get_viewport().set_input_as_handled()
			%MenuButton.grab_focus()
		return
	super(event)
