extends Control

func _ready() -> void:
	%Restart.pressed.connect(_leave.bind(true))
	%Menu.pressed.connect(_leave.bind(false))

func show_death_screen() -> void:
	if visible:
		return
	add_to_group("active_game_modal")
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	%Restart.grab_focus()

func show_death() -> void:
	show_death_screen()

func _leave(restart: bool) -> void:
	AudioManager.play_sfx("sfx_puzzle_move", -16.0)
	remove_from_group("active_game_modal")
	get_tree().paused = false
	hide()
	if restart:
		GameManager.restart_current_floor()
	else:
		GameManager.return_to_main_menu()
