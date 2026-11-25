extends "res://scripts/systems/locked_door.gd".TerminalModal

# Port bits turn clockwise: north, east, south, west.
const PORTS := [10, 12, 3, 3, 3, 14, 6, 10, 3]
const STEPS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var rotations: Array[int] = [3, 3, 0, 0, 3, 3, 0, 0, 3]
var powered: Array[int] = []
var tiles: Array[Button] = []

func _ready() -> void:
	super()
	for i in PORTS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(74, 74)
		button.tooltip_text = "Satır %d, sütun %d — saat yönünde çevir" % [1 + floori(i / 3.0), 1 + i % 3]
		%Grid.add_child(button)
		tiles.append(button)
		button.draw.connect(_draw_pipe.bind(button, i))
		button.pressed.connect(_rotate_tile.bind(i))
	_refresh_power()

func _ports(i: int) -> int:
	var bits: int = PORTS[i] << rotations[i]
	return (bits | (bits >> 4)) & 15

func _rotate_tile(i: int) -> void:
	if is_solved:
		return
	rotations[i] = (rotations[i] + 1) % 4
	AudioManager.play_sfx("sfx_puzzle_move")
	_refresh_power()

func _refresh_power() -> void:
	powered.clear()
	if _ports(0) & 8:
		powered.append(0)
	var cursor := 0
	while cursor < powered.size():
		var i := powered[cursor]
		cursor += 1
		var cell := Vector2i(i % 3, floori(i / 3.0))
		for side in 4:
			if not (_ports(i) & (1 << side)):
				continue
			var neighbor: Vector2i = cell + STEPS[side]
			if not Rect2i(0, 0, 3, 3).has_point(neighbor):
				continue
			var j := neighbor.y * 3 + neighbor.x
			var opposite := (side + 2) % 4
			if not powered.has(j) and (_ports(j) & (1 << opposite)):
				powered.append(j)
	for button in tiles:
		button.queue_redraw()
	if powered.has(8) and (_ports(8) & 2):
		_finish("DEVRE BAĞLANDI — KİLİT AÇILDI!")
	else:
		_status("GERİLİM ALTINDA     %d / 9" % powered.size())

func _draw_pipe(button: Button, i: int) -> void:
	var center := button.size * 0.5
	var color := CYAN if powered.has(i) else Color("#74848d")
	for side in 4:
		if _ports(i) & (1 << side):
			var end := center + Vector2(STEPS[side]) * center
			button.draw_line(center, end, Color("#17242e"), 15.0, true)
			button.draw_line(center, end, color, 7.0, true)
	button.draw_circle(center, 7, color, true, -1, true)

func solve_for_test() -> void:
	for i in rotations.size():
		while rotations[i] != 0 and not is_solved:
			_rotate_tile(i)
