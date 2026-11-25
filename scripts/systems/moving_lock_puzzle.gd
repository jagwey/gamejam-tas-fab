extends Control

signal puzzle_solved
signal puzzle_cancelled

const TRACK_WIDTH: float = 564.0
const BAR_SPEEDS: Array[float] = [175.0, 235.0, 295.0]
const READY_COLOR: Color = Color("#55ece3")
const ERROR_COLOR: Color = Color("#ff5668")

var gap_widths: Array[float] = [76.0, 66.0, 58.0]
var bar_gap_x: Array[float] = [110.0, 420.0, 185.0]
var directions: Array[float] = [1.0, -1.0, 1.0]
var pin_x: float = TRACK_WIDTH * 0.5
var current_stage: int = 0
var last_attempt_succeeded: bool = false
var is_solved: bool = false
var pin_tween: Tween
var status_tween: Tween
@onready var bars: Array[Control] = [%bar_0, %bar_1, %bar_2]

func _ready() -> void:
	add_to_group("active_game_modal")
	%Reset.pressed.connect(reset_puzzle)
	%Cancel.pressed.connect(_cancel)
	reset_puzzle()

func _process(delta: float) -> void:
	for index in range(current_stage, 3):
		var half_width: float = gap_widths[index] * 0.5
		var travel: float = TRACK_WIDTH - gap_widths[index]
		var phase: float = bar_gap_x[index] - half_width
		if directions[index] < 0.0:
			phase = 2.0 * travel - phase
		phase = fposmod(phase + BAR_SPEEDS[index] * delta, 2.0 * travel)
		bar_gap_x[index] = half_width + pingpong(phase, travel)
		directions[index] = 1.0 if phase < travel else -1.0
		_draw_bar(index)

func _draw_bar(index: int) -> void:
	var bar: Control = bars[index]
	var left: float = bar_gap_x[index] - gap_widths[index] * 0.5
	var right: float = left + gap_widths[index]
	bar.get_node("Left").size.x = left
	bar.get_node("Right").position.x = right
	bar.get_node("Right").size.x = TRACK_WIDTH - right
	bar.get_node("Gap").position.x = left
	bar.get_node("Gap").size.x = gap_widths[index]
	bar.get_node("LipL").position.x = left
	bar.get_node("LipR").position.x = right - 3.0

func attempt_advance() -> bool:
	if is_solved:
		return false
	if pin_tween:
		pin_tween.kill()
	if status_tween:
		status_tween.kill()
	var stage: int = current_stage
	last_attempt_succeeded = absf(bar_gap_x[stage] - pin_x) <= gap_widths[stage] * 0.5
	pin_tween = create_tween()
	if not last_attempt_succeeded:
		AudioManager.play_sfx("sfx_puzzle_fail")
		%Status.add_theme_color_override("font_color", ERROR_COLOR)
		%Status.text = "ZAMANLAMA HATASI! PİM GÜVENLİ KONUMA DÖNDÜ"
		pin_tween.tween_property($Track/Pin, "position:y", _dock_y() - 18.0, 0.06)
		pin_tween.tween_property($Track/Pin, "position:y", _dock_y(), 0.14)
		status_tween = create_tween()
		status_tween.tween_interval(0.85)
		status_tween.tween_callback(_show_stage)
		return false
	AudioManager.play_sfx("sfx_puzzle_bar_pass")
	current_stage += 1
	($Track.get_node("LED%d" % stage) as ColorRect).color = READY_COLOR
	pin_tween.tween_property($Track/Pin, "position:y", _dock_y(), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	is_solved = current_stage >= 3
	_show_stage()
	if is_solved:
		%Reset.disabled = true
		%Cancel.disabled = true
		AudioManager.play_sfx("sfx_puzzle_success")
		puzzle_solved.emit()
	return true

func _dock_y() -> float:
	return 188.0 - 65.0 * current_stage

func _show_stage() -> void:
	%Status.add_theme_color_override("font_color", READY_COLOR)
	%Status.text = "KİLİT AÇILDI!" if is_solved else "PİM HAZIR     %d / 3" % current_stage

func reset_puzzle() -> void:
	if pin_tween:
		pin_tween.kill()
	if status_tween:
		status_tween.kill()
	current_stage = 0
	is_solved = false
	last_attempt_succeeded = false
	bar_gap_x.assign([110.0, 420.0, 185.0])
	directions.assign([1.0, -1.0, 1.0])
	if not is_node_ready():
		return
	%Reset.disabled = false
	%Cancel.disabled = false
	for index in range(3):
		($Track.get_node("LED%d" % index) as ColorRect).color = Color("#344f52")
		_draw_bar(index)
	$Track/Pin.position = Vector2(pin_x - 5.0, _dock_y())
	_show_stage()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_solved:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_cancel()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_W, KEY_UP, KEY_ENTER, KEY_KP_ENTER] or event.is_action_pressed("move_forward"):
			get_viewport().set_input_as_handled()
			attempt_advance()
		elif event.keycode == KEY_R or event.is_action_pressed("reload"):
			get_viewport().set_input_as_handled()
			reset_puzzle()

func _cancel() -> void:
	if is_solved or not visible:
		return
	hide()
	puzzle_cancelled.emit()
	queue_free()

func get_current_stage() -> int:
	return current_stage

func force_align_current_bar_for_test() -> void:
	if not is_solved:
		bar_gap_x[current_stage] = pin_x
		if is_node_ready():
			_draw_bar(current_stage)

func force_misalign_current_bar_for_test() -> void:
	if not is_solved:
		bar_gap_x[current_stage] = gap_widths[current_stage] * 0.5
		if is_node_ready():
			_draw_bar(current_stage)
