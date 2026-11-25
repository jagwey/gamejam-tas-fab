extends Node3D
## Floor 1 — Lobby. Drives objectives, music and the on-screen controls hint.

const OBJ_START: String = "GÖREV: Lobi güvenlik hattını aş ve üst kat asansörüne ulaş"
const OBJ_BETA: String = "GÖREV: Cesedin yanında [F] BETA PROTOKOLÜ ile can topla — doğu koridoruna ilerle"
const OBJ_DOOR: String = "GÖREV: Asansör salonundaki güvenlik kilidini aç"
const OBJ_ELEVATOR: String = "GÖREV: Asansörle 2. Kata çık"
const CONTROLS_HINT: String = "WASD: Hareket   Sol Tık: Ateş   Q: Bıçak   F: BETA Protokolü   E: Etkileşim   R: Şarjör"
const HINT_DURATION: float = 12.0

@onready var first_guard: Node = get_node_or_null("Enemies/LobbyGuardA")
@onready var hall_entry_guard: Node = get_node_or_null("Enemies/CorridorMerc")
@onready var security_door: Node = get_node_or_null("Interactables/ElevatorSecurityDoor")
@onready var test_wall: Node3D = get_node_or_null("Geometry/NorthBoundaryWall") as Node3D

var hint_layer: CanvasLayer = null
var hint_label: Label = null
var _beta_hint_shown: bool = false


func _ready() -> void:
	AudioManager.play_music("bgm_floor1_lobby")
	GameManager.set_objective(OBJ_START)
	if first_guard != null and first_guard.has_signal("died"):
		first_guard.connect("died", _on_first_guard_died)
	if hall_entry_guard != null and hall_entry_guard.has_signal("died"):
		hall_entry_guard.connect("died", _on_hall_reached)
	if security_door != null and security_door.has_signal("door_unlocked"):
		security_door.connect("door_unlocked", _on_door_unlocked)
	_show_controls_hint()


func get_test_wall_position() -> Vector3:
	## World position just inside the lobby's north boundary wall (used by acceptance tests).
	if test_wall != null:
		return test_wall.global_position
	return Vector3(0.0, 0.0, -36.0)


func _on_first_guard_died(_enemy: Node = null) -> void:
	if _beta_hint_shown:
		return
	_beta_hint_shown = true
	GameManager.set_objective(OBJ_BETA)


func _on_hall_reached(_enemy: Node = null) -> void:
	if security_door != null and not bool(security_door.get("is_unlocked")):
		GameManager.set_objective(OBJ_DOOR)


func _on_door_unlocked() -> void:
	GameManager.set_objective(OBJ_ELEVATOR)


func _show_controls_hint() -> void:
	hint_layer = CanvasLayer.new()
	hint_layer.name = "ControlsHint"
	hint_layer.layer = 12
	add_child(hint_layer)
	hint_label = Label.new()
	hint_label.text = CONTROLS_HINT
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(140.0, 600.0)
	hint_label.size = Vector2(1000.0, 32.0)
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
	hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.05, 1.0))
	hint_label.add_theme_constant_override("outline_size", 6)
	hint_layer.add_child(hint_label)
	var tw: Tween = create_tween()
	tw.tween_interval(HINT_DURATION)
	tw.tween_property(hint_label, "modulate:a", 0.0, 1.5)
	tw.tween_callback(hint_layer.queue_free)
