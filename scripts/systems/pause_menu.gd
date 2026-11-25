extends Control

@onready var buttons: Array[Button] = [%Resume, %Restart, %Settings, %Menu, %Quit]
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	%Resume.pressed.connect(_resume)
	%Restart.pressed.connect(_leave.bind(true))
	%Menu.pressed.connect(_leave.bind(false))
	%Settings.pressed.connect(_open_settings)
	%SettingsPanel.closed.connect(_close_settings)
	%Quit.pressed.connect(get_tree().quit)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or get_viewport().is_input_handled():
		return
	if toggle_pause():
		get_viewport().set_input_as_handled()

func toggle_pause() -> bool:
	if get_tree().get_first_node_in_group("active_game_modal") != null:
		return false
	if %SettingsPanel.visible or (get_tree().paused and not visible):
		return false
	if visible:
		_resume()
	else:
		previous_mouse_mode = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show()
		%Resume.grab_focus()
	return true

func _open_settings() -> void:
	for button in buttons:
		button.focus_mode = Control.FOCUS_NONE
	%SettingsPanel.show()

func _close_settings() -> void:
	for button in buttons:
		button.focus_mode = Control.FOCUS_ALL
	%Settings.grab_focus()

func _resume() -> void:
	hide()
	get_tree().paused = false
	Input.mouse_mode = previous_mouse_mode

func _leave(restart: bool) -> void:
	get_tree().paused = false
	hide()
	if restart:
		GameManager.restart_current_floor()
	else:
		GameManager.return_to_main_menu()
