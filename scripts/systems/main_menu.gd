extends Control

@onready var buttons: Array[Button] = [%NewGame, %Continue, %Settings, %Credits, %Quit]

func _ready() -> void:
	for button in buttons:
		button.pressed.connect(func() -> void: AudioManager.play_sfx("sfx_puzzle_move", -16.0))
	get_tree().paused = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var art_path: String = "res://assets/portraits/poster_key_art.jpg"
	if ResourceLoader.exists(art_path):
		%Poster.texture = load(art_path)
	%Continue.disabled = not SaveManager.has_save()
	%NewGame.pressed.connect(GameManager.start_new_game)
	%Continue.pressed.connect(GameManager.continue_game)
	%Settings.pressed.connect(_open_panel.bind(%SettingsPanel))
	%Credits.pressed.connect(_open_panel.bind(%CreditsPanel))
	%SettingsPanel.closed.connect(_restore_buttons.bind(%Settings))
	%CreditsPanel.closed.connect(_restore_buttons.bind(%Credits))
	%Quit.pressed.connect(GameManager.quit_game)
	%NewGame.grab_focus()
	AudioManager.play_music("bgm_menu_cutscene")

func _open_panel(panel: Control) -> void:
	%MenuCard.hide()
	panel.show()

func _restore_buttons(opener: Button) -> void:
	%MenuCard.show()
	opener.grab_focus()
