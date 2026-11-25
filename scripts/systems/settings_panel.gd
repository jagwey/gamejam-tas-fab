extends Control

signal closed

func _ready() -> void:
	%Tabs.tab_clicked.connect(func(_index: int) -> void: _click())
	for button in [%Back, %Reset, %Fullscreen, %Shake, %CRT, %Difficulty, %Quality, %Vsync, %ShowFps]:
		button.pressed.connect(_click)
	for binding in [[%Difficulty, "difficulty"], [%Quality, "graphics_quality"], [%Vsync, "vsync_enabled"], [%ShowFps, "show_fps"]]:
		var control: BaseButton = binding[0]
		var setter := StringName("set_" + str(binding[1]))
		control.disabled = not SettingsManager.has_method(setter)
		if not control.disabled:
			var callback := Callable(SettingsManager, setter)
			if control is OptionButton:
				(control as OptionButton).item_selected.connect(callback)
			else:
				control.toggled.connect(callback)
	%Reset.pressed.connect(_reset_defaults)
	%Sensitivity.value_changed.connect(_sensitivity_changed)
	%Fov.value_changed.connect(_fov_changed)
	%Master.value_changed.connect(_volume_changed.bind("Master", %MasterValue))
	%Music.value_changed.connect(_volume_changed.bind("Music", %MusicValue))
	%Sfx.value_changed.connect(_volume_changed.bind("SFX", %SfxValue))
	%Fullscreen.toggled.connect(SettingsManager.set_fullscreen)
	%Shake.toggled.connect(SettingsManager.set_camera_shake)
	%CRT.toggled.connect(SettingsManager.set_crt_enabled)
	%Back.pressed.connect(close_panel)
	SettingsManager.settings_changed.connect(_refresh)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()
		%Tabs.get_tab_bar().grab_focus()

func _refresh() -> void:
	%Sensitivity.set_value_no_signal(SettingsManager.mouse_sensitivity)
	%SensitivityValue.text = "%.2f" % SettingsManager.mouse_sensitivity
	%Fov.set_value_no_signal(SettingsManager.horizontal_fov)
	%FovValue.text = "%d°" % roundi(SettingsManager.horizontal_fov)
	_show_volume(%Master, %MasterValue, SettingsManager.master_volume)
	_show_volume(%Music, %MusicValue, SettingsManager.music_volume)
	_show_volume(%Sfx, %SfxValue, SettingsManager.sfx_volume)
	%Fullscreen.set_pressed_no_signal(SettingsManager.fullscreen)
	%Shake.set_pressed_no_signal(SettingsManager.camera_shake_enabled)
	%CRT.set_pressed_no_signal(SettingsManager.crt_enabled)
	%Quality.select(int(SettingsManager.get("graphics_quality")) if "graphics_quality" in SettingsManager else 1)
	%Difficulty.select(int(SettingsManager.get("difficulty")) if "difficulty" in SettingsManager else 0)
	%ShowFps.set_pressed_no_signal("show_fps" in SettingsManager and bool(SettingsManager.get("show_fps")))
	%Vsync.set_pressed_no_signal(not "vsync_enabled" in SettingsManager or bool(SettingsManager.get("vsync_enabled")))

func _click() -> void:
	AudioManager.play_sfx("sfx_puzzle_move", -16.0)

func _reset_defaults() -> void:
	if SettingsManager.has_method("reset_to_defaults"):
		SettingsManager.call("reset_to_defaults")
		return
	SettingsManager.set_mouse_sensitivity(0.22)
	SettingsManager.set_horizontal_fov(100)
	SettingsManager.set_fullscreen(false)
	SettingsManager.set_camera_shake(true)
	SettingsManager.set_crt_enabled(true)
	SettingsManager.set_bus_volume("Master", 0.85)
	SettingsManager.set_bus_volume("Music", 0.65)
	SettingsManager.set_bus_volume("SFX", 0.85)
	var defaults := {"set_difficulty": 0, "set_graphics_quality": 1, "set_vsync_enabled": true, "set_show_fps": false}
	for setter: String in defaults:
		if SettingsManager.has_method(setter):
			SettingsManager.call(setter, defaults[setter])

func _show_volume(slider: HSlider, label: Label, value: float) -> void:
	slider.set_value_no_signal(value)
	label.text = "%%%d" % roundi(value * 100.0)

func _sensitivity_changed(value: float) -> void:
	%SensitivityValue.text = "%.2f" % value
	SettingsManager.set_mouse_sensitivity(value)

func _fov_changed(value: float) -> void:
	%FovValue.text = "%d°" % roundi(value)
	SettingsManager.set_horizontal_fov(value)

func _volume_changed(value: float, bus: String, label: Label) -> void:
	label.text = "%%%d" % roundi(value * 100.0)
	SettingsManager.set_bus_volume(bus, value)

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_panel()

func close_panel() -> void:
	SettingsManager.save_settings()
	hide()
	closed.emit()
