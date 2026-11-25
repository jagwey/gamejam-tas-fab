extends Control

signal closed

func _ready() -> void:
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
		%Sensitivity.grab_focus()

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
