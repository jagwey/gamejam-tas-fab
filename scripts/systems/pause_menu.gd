extends Control

@onready var buttons: Array[Button] = [%Resume, %Restart, %Settings, %Menu, %Quit]
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var player: Node = null

func _ready() -> void:
	%Resume.pressed.connect(_resume)
	%Restart.pressed.connect(_leave.bind(true))
	%Menu.pressed.connect(_leave.bind(false))
	%Settings.pressed.connect(_open_settings)
	%SettingsPanel.closed.connect(_close_settings)
	%Quit.pressed.connect(GameManager.quit_game)

func bind_player(p: Node) -> void:
	player = p

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or get_viewport().is_input_handled():
		return
	# Consume ESC first so the bound player never toggles the same keypress a second time.
	get_viewport().set_input_as_handled()
	var was_visible: bool = visible
	if toggle_pause() and not was_visible and visible:
		_set_player_controls(false)

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
		if DisplayServer.get_name() != "headless":
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
	if is_instance_valid(player) and player.has_method("set_controls_enabled"):
		# Restores look input and recaptures the mouse (guarded for headless inside the player).
		_set_player_controls(true)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = previous_mouse_mode

func _set_player_controls(enabled: bool) -> void:
	if is_instance_valid(player) and player.has_method("set_controls_enabled"):
		if player.has_method("is_dead") and bool(player.call("is_dead")):
			return
		player.call("set_controls_enabled", enabled)

func _leave(restart: bool) -> void:
	get_tree().paused = false
	hide()
	if restart:
		GameManager.restart_current_floor()
	else:
		GameManager.return_to_main_menu()
