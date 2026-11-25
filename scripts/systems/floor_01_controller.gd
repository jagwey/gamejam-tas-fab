extends Node3D
## Floor 1 — Lobby. Drives objectives, music and the on-screen controls hint.

const OBJ_START: String = "GÖREV: Lobi güvenlik hattını aş ve üst kat asansörüne ulaş"
const OBJ_BETA: String = "GÖREV: Cesedin yanında [F] BETA PROTOKOLÜ ile can topla — doğu koridoruna ilerle"
const OBJ_DOOR: String = "GÖREV: Asansör salonundaki güvenlik kilidini aç"
const OBJ_ELEVATOR: String = "GÖREV: Asansörle 2. Kata çık"
const CONTROLS_HINT: String = "WASD Hareket · Sol Tık Ateş · Sağ Tık Nişan · R Şarjör\n1-2-3 Silah · Q Bıçak · E Etkileşim · F BETA Protokolü"
const HINT_DURATION: float = 12.0
const HINT_TOP: float = 90.0
const HINT_WIDTH: float = 396.0
const THEME_PATH: String = "res://scenes/ui/protocol_theme.tres"
const GENERAL: String = "GENERAL DEMİR"
const AYDIN: String = "AYDIN"

@onready var first_guard: Node = get_node_or_null("Enemies/LobbyGuardA")
@onready var hall_entry_guard: Node = get_node_or_null("Enemies/CorridorMerc")
@onready var security_door: Node = get_node_or_null("Interactables/ElevatorSecurityDoor")
@onready var test_wall: Node3D = get_node_or_null("Geometry/NorthBoundaryWall") as Node3D

var hint_layer: CanvasLayer = null
var hint_panel: PanelContainer = null
var hint_label: Label = null
var _beta_hint_shown: bool = false
var _hall_radio_sent: bool = false


func _ready() -> void:
	_apply_light_fade()
	AudioManager.play_music("bgm_floor1_lobby")
	GameManager.set_objective(OBJ_START)
	if first_guard != null and first_guard.has_signal("died"):
		first_guard.connect("died", _on_first_guard_died)
	if hall_entry_guard != null and hall_entry_guard.has_signal("died"):
		hall_entry_guard.connect("died", _on_hall_reached)
	if security_door != null and security_door.has_signal("door_unlocked"):
		security_door.connect("door_unlocked", _on_door_unlocked)
	_show_controls_hint()
	_radio_later(1.0, GENERAL, "general_portrait",
		"Aydın, lobi güvenliği devrede. Düşen her silahlı elemandan [F] ile BETA biyolojik özü topla; hem maks canın hem gücün artar.", 7.0)


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
	GameManager.send_radio(AYDIN, "aydin_visor",
		"İlk temas temiz. BETA kalıcı adaptasyon sağlıyor — doğu koridoruna ilerliyorum.", 5.5)


func _on_hall_reached(_enemy: Node = null) -> void:
	if security_door != null and not bool(security_door.get("is_unlocked")):
		GameManager.set_objective(OBJ_DOOR)
	if not _hall_radio_sent:
		_hall_radio_sent = true
		GameManager.send_radio(GENERAL, "general_portrait",
			"Asansör güvenlik kapısı kilitli. Terminalden hareketli kilidi kır.", 5.5)


func _on_door_unlocked() -> void:
	GameManager.set_objective(OBJ_ELEVATOR)


func _radio_later(delay: float, speaker: String, portrait: String, text: String, duration: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		GameManager.send_radio(speaker, portrait, text, duration)


## Top-centre banner (y = 90) inside the HUD's centre column: clear of the mission plate (left),
## radio box (right), boss bar / toast (top centre band), prompts (screen centre) and weapon art.
func _show_controls_hint() -> void:
	hint_layer = CanvasLayer.new()
	hint_layer.name = "ControlsHint"
	hint_layer.layer = 12
	add_child(hint_layer)
	hint_panel = PanelContainer.new()
	hint_panel.name = "HintBanner"
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(THEME_PATH):
		hint_panel.theme = load(THEME_PATH) as Theme
	hint_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_panel.offset_left = -HINT_WIDTH * 0.5
	hint_panel.offset_right = HINT_WIDTH * 0.5
	hint_panel.offset_top = HINT_TOP
	hint_panel.offset_bottom = HINT_TOP + 58.0
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_panel.custom_minimum_size = Vector2(HINT_WIDTH, 0.0)
	hint_layer.add_child(hint_panel)
	hint_label = Label.new()
	hint_label.name = "HintText"
	hint_label.text = CONTROLS_HINT
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
	hint_panel.add_child(hint_label)
	hint_panel.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(hint_panel, "modulate:a", 1.0, 0.35)
	tw.tween_interval(HINT_DURATION)
	tw.tween_property(hint_panel, "modulate:a", 0.0, 1.2)
	tw.tween_callback(hint_layer.queue_free)

## Perf: distance-fade every OmniLight3D in the floor, including lights inside instanced
## enemies / pickups / consoles that the level builder does not generate.
func _apply_light_fade() -> void:
	for found in find_children("*", "OmniLight3D", true, false):
		var omni: OmniLight3D = found as OmniLight3D
		if omni == null:
			continue
		omni.distance_fade_enabled = true
		omni.distance_fade_begin = 16.0
		omni.distance_fade_length = 8.0
