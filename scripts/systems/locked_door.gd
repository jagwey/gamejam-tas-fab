extends StaticBody3D

signal door_unlocked

const PUZZLE_SCENE: PackedScene = preload("res://scenes/puzzles/moving_lock_puzzle.tscn")
@export var puzzle_scene: PackedScene = PUZZLE_SCENE
@export var custom_prompt: String = ""
var is_unlocked: bool = false
var overlay: CanvasLayer
var operator: Node
var previous_mouse_mode: Input.MouseMode
var status_material: StandardMaterial3D

func _ready() -> void:
	status_material = $LeftLeaf/Status.get_active_material(0).duplicate() as StandardMaterial3D
	$LeftLeaf/Status.material_override = status_material
	$RightLeaf/Status.material_override = status_material

func get_interact_prompt(_player: Node = null) -> String:
	if is_unlocked:
		return ""
	return custom_prompt if not custom_prompt.is_empty() else "[E] Güvenlik Kilidi Terminalini Aç"

func interact(player: Node) -> void:
	if is_unlocked or is_instance_valid(overlay) or get_tree().paused:
		return
	operator = player
	if DisplayServer.get_name() != "headless":
		previous_mouse_mode = Input.mouse_mode
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", false)
	overlay = CanvasLayer.new()
	overlay.layer = 20
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var scene_to_use: PackedScene = puzzle_scene if puzzle_scene != null else PUZZLE_SCENE
	var puzzle: Control = scene_to_use.instantiate() as Control
	puzzle.connect("puzzle_cancelled", _close_puzzle)
	puzzle.connect("puzzle_solved", _on_solved)
	overlay.add_child(puzzle)
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_solved() -> void:
	unlock_and_open()
	var delay: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	delay.tween_interval(0.55)
	delay.tween_callback(_close_puzzle)

func _close_puzzle() -> void:
	if not is_instance_valid(overlay):
		return
	overlay.queue_free()
	overlay = null
	get_tree().paused = false
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", true)
	operator = null
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = previous_mouse_mode

func unlock_and_open() -> void:
	if is_unlocked:
		return
	is_unlocked = true
	$DoorCollision.set_deferred("disabled", true)
	$InteractArea.remove_from_group("interactables")
	$InteractArea.set_deferred("collision_layer", 0)
	var green: Color = Color("#43ef91")
	status_material.albedo_color = green
	status_material.emission = green
	AudioManager.play_sfx("sfx_door_open")
	var slide: Tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	slide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property($LeftLeaf, "position:x", -3.05, 0.7)
	slide.tween_property($RightLeaf, "position:x", 3.05, 0.7)
	door_unlocked.emit()


## Common lifecycle of the interactive terminal screens mounted by this door.
class TerminalModal extends Control:
	signal puzzle_solved
	signal puzzle_cancelled

	const CYAN := Color("#55eee3")
	const GREEN := Color("#65f29e")
	const CRIMSON := Color("#ff6475")
	var is_solved := false

	func _ready() -> void:
		%Cancel.pressed.connect(_cancel)

	func _input(event: InputEvent) -> void:
		if is_visible_in_tree() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			_cancel()

	func _cancel() -> void:
		if is_solved or not visible:
			return
		hide()
		puzzle_cancelled.emit()
		queue_free()

	func _status(message: String, color: Color = CYAN) -> void:
		%Status.text = message
		%Status.add_theme_color_override("font_color", color)

	func _finish(message: String) -> void:
		if is_solved:
			return
		is_solved = true
		for button in find_children("*", "Button", true, false):
			(button as Button).disabled = true
		_status(message, GREEN)
		AudioManager.play_sfx("sfx_puzzle_success")
		puzzle_solved.emit()
