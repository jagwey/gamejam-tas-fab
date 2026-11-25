extends "res://scripts/systems/locked_door.gd".TerminalModal

const NAMES := ["KIRMIZI  [Δ]", "YEŞİL  [Φ]", "MAVİ  [Ψ]", "ALTIN  [Ω]"]
const COLORS := [Color("#ff7988"), Color("#96e690"), Color("#7ebeff"), Color("#ffcf76")]
var samples: Array[Button] = []
var chambers: Array[Button] = []
var selected := -1
var matches := 0
var warning_flash: Tween

func _ready() -> void:
	super()
	var order := [0, 1, 2, 3]
	order.shuffle()
	if order == [0, 1, 2, 3]:
		order.push_back(order.pop_front())
	chambers.resize(NAMES.size())
	for i in NAMES.size():
		var sample := _make_button(i, %Samples)
		samples.append(sample)
		sample.pressed.connect(_select_sample.bind(i))
		var target: int = order[i]
		var chamber := _make_button(target, %Chambers)
		chambers[target] = chamber
		chamber.pressed.connect(_match_chamber.bind(target))
	_progress()

func _make_button(id: int, column: VBoxContainer) -> Button:
	var button := Button.new()
	button.text = NAMES[id]
	button.custom_minimum_size.y = 47
	button.add_theme_color_override("font_color", COLORS[id])
	column.add_child(button)
	return button

func _select_sample(id: int) -> void:
	if is_solved or samples[id].disabled:
		return
	if selected >= 0:
		samples[selected].text = NAMES[selected]
	selected = id
	samples[id].text = "▶   " + NAMES[id]
	AudioManager.play_sfx("sfx_puzzle_move")
	_status("HAZNE SEÇ     " + NAMES[id])

func _match_chamber(id: int) -> void:
	if is_solved or chambers[id].disabled:
		return
	if selected < 0:
		_status("ÖNCE BİR NUMUNE SEÇ", CRIMSON)
		return
	if selected != id:
		AudioManager.play_sfx("sfx_puzzle_fail")
		_status("UYUMSUZ HAZNE — TEKRAR DENE", CRIMSON)
		if warning_flash:
			warning_flash.kill()
		%Status.modulate = Color("#ff7383")
		warning_flash = create_tween()
		warning_flash.tween_property(%Status, "modulate", Color.WHITE, 0.4)
		return
	if warning_flash:
		warning_flash.kill()
	%Status.modulate = Color.WHITE
	for button: Button in [samples[id], chambers[id]]:
		button.text = "✓   " + NAMES[id]
		button.disabled = true
		button.add_theme_color_override("font_disabled_color", GREEN)
	selected = -1
	matches += 1
	AudioManager.play_sfx("sfx_puzzle_bar_pass")
	if matches == NAMES.size():
		_finish("BİYO-ŞİFRE DOĞRULANDI!")
	else:
		_progress()

func _progress() -> void:
	_status("DOĞRULANAN NUMUNE     %d / 4" % matches)

func solve_for_test() -> void:
	for i in NAMES.size():
		if not samples[i].disabled:
			_select_sample(i)
			_match_chamber(i)
