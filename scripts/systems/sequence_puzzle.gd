extends "res://scripts/systems/locked_door.gd".TerminalModal

const SYMBOLS := ["♣", "★", "♠", "◆"]
const CODE := [2, 3, 1, 0]
var entered := 0
var keys: Array[Button] = []
var stages: Array[Label] = []
var replay: Tween

func _ready() -> void:
	super()
	var pattern := PackedStringArray()
	for i in CODE.size():
		pattern.append(SYMBOLS[CODE[i]])
		var key := Button.new()
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.add_theme_font_size_override("font_size", 31)
		key.text = SYMBOLS[i]
		%Keys.add_child(key)
		keys.append(key)
		key.pressed.connect(_enter_symbol.bind(i))
		var stage := Label.new()
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		%Stages.add_child(stage)
		stages.append(stage)
	%Pattern.text = "   →   ".join(pattern)
	%Replay.pressed.connect(_replay)
	_update_stages()
	_status("İLK SEMBOLÜ GİR")

func _replay() -> void:
	if is_solved:
		return
	_stop_replay()
	replay = create_tween()
	for symbol: int in CODE:
		replay.tween_callback(_highlight.bind(symbol))
		replay.tween_interval(0.55)
		replay.tween_callback(_highlight.bind(-1))
		replay.tween_interval(0.13)

func _highlight(id: int) -> void:
	for i in keys.size():
		keys[i].self_modulate = CYAN if i == id else Color.WHITE

func _stop_replay() -> void:
	if replay:
		replay.kill()
	_highlight(-1)

func _enter_symbol(id: int) -> void:
	if is_solved:
		return
	_stop_replay()
	if CODE[entered] != id:
		entered = 0
		_update_stages()
		AudioManager.play_sfx("sfx_puzzle_fail")
		_status("YANLIŞ SIRA — BAŞA DÖNÜLDÜ", CRIMSON)
		var flash := create_tween()
		flash.tween_property(keys[id], "self_modulate", CRIMSON, 0.05)
		flash.tween_property(keys[id], "self_modulate", Color.WHITE, 0.25)
		return
	entered += 1
	AudioManager.play_sfx("sfx_puzzle_bar_pass")
	_update_stages()
	if entered == CODE.size():
		_finish("VIP KİLİT AÇILDI!")
	else:
		_status("DOĞRULANAN ADIM     %d / 4" % entered)

func _update_stages() -> void:
	for i in stages.size():
		stages[i].text = "%d   %s" % [i + 1, SYMBOLS[CODE[i]] if i < entered else "○"]
		stages[i].modulate = GREEN if i < entered else Color("#788d98")

func solve_for_test() -> void:
	while entered < CODE.size():
		_enter_symbol(CODE[entered])
