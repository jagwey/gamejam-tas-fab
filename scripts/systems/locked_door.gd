extends StaticBody3D

signal door_unlocked

const PUZZLE_SCENE: PackedScene = preload("res://scenes/puzzles/moving_lock_puzzle.tscn")
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
	return "" if is_unlocked else "[E] Güvenlik Kilidi Terminalini Aç"

func interact(player: Node) -> void:
	if is_unlocked or is_instance_valid(overlay) or get_tree().paused:
		return
	operator = player
	previous_mouse_mode = Input.mouse_mode
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", false)
	overlay = CanvasLayer.new()
	overlay.layer = 20
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	var puzzle: Control = PUZZLE_SCENE.instantiate() as Control
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
