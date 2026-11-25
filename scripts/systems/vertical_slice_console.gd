extends Area3D
## Floor 2 completion console. Opens the "vertical slice complete" report modal.
## Interactable contract: get_interact_prompt(player) / interact(player).

signal report_opened
signal report_closed

const THEME_PATH: String = "res://scenes/ui/protocol_theme.tres"
const REPORT_TITLE: String = "BETA PROTOCOL — DİKEY KESİT TAMAMLANDI"
const REPORT_BODY: String = (
	"KAT 1 — LOBİ: Güvenlik hattı aşıldı, asansör kilidi hizalama terminaliyle kırıldı.\n"
	+ "KAT 2 — OFİS VE ARŞİV: Volkov'un çalınan BETA araştırma verileri bulundu.\n\n"
	+ "Ajan Aydın, BETA Cihazı ile düşmüş düşmanlardan enerji toplayarak hayatta kaldı.\n\n"
	+ "SIRADAKİ:\n"
	+ "KAT 3 — LABORATUVAR: Reaktör rölelerinin ilk istasyonu.\n"
	+ "KAT 4 — SUNUCU ÇEKİRDEĞİ: Volkov'un paralı askerleri ve ağır zırhlılar.\n"
	+ "KAT 5 — YÖNETİM KATI: Beta Reaktörü ve Viktor Volkov ile son yüzleşme.\n\n"
	+ "Dikey kesiti oynadığınız için teşekkürler."
)

@export var prompt_text: String = "[E] Dikey Kesit Raporunu Aç"

var operator: Node = null
var overlay: CanvasLayer = null
var modal_root: Control = null
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var menu_button: Button = null
var replay_button: Button = null


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group("interactables")


func get_interact_prompt(_player: Node = null) -> String:
	return prompt_text


func is_open() -> bool:
	return is_instance_valid(modal_root)


func interact(player: Node) -> void:
	if is_open() or get_tree().paused:
		return
	operator = player
	previous_mouse_mode = Input.mouse_mode
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", false)
	_build_modal()
	get_tree().paused = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_sfx("sfx_beta_complete")
	menu_button.grab_focus()
	report_opened.emit()


func close_report() -> void:
	if not is_open():
		return
	overlay.queue_free()
	overlay = null
	modal_root = null
	get_tree().paused = false
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", true)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = previous_mouse_mode
	operator = null
	report_closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_report()


func _on_menu_pressed() -> void:
	_teardown_for_scene_change()
	GameManager.return_to_main_menu()


func _on_replay_pressed() -> void:
	_teardown_for_scene_change()
	GameManager.restart_current_floor()


func _teardown_for_scene_change() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	modal_root = null
	operator = null
	get_tree().paused = false


func _build_modal() -> void:
	overlay = CanvasLayer.new()
	overlay.name = "ReportOverlay"
	overlay.layer = 25
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	modal_root = Control.new()
	modal_root.name = "Report"
	modal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_root.process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(THEME_PATH):
		modal_root.theme = load(THEME_PATH) as Theme
	modal_root.add_to_group("active_game_modal")
	overlay.add_child(modal_root)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.03, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.add_child(dim)

	var frame: Panel = Panel.new()
	frame.position = Vector2(190.0, 70.0)
	frame.size = Vector2(900.0, 580.0)
	modal_root.add_child(frame)

	var accent: ColorRect = ColorRect.new()
	accent.position = Vector2(190.0, 70.0)
	accent.size = Vector2(900.0, 4.0)
	accent.color = Color(1.0, 0.6, 0.26, 1.0)
	modal_root.add_child(accent)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = REPORT_TITLE
	title.position = Vector2(230.0, 100.0)
	title.size = Vector2(820.0, 60.0)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.66, 0.32, 1.0))
	modal_root.add_child(title)

	var body: Label = Label.new()
	body.name = "Body"
	body.text = REPORT_BODY
	body.position = Vector2(230.0, 175.0)
	body.size = Vector2(820.0, 360.0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 21)
	modal_root.add_child(body)

	menu_button = Button.new()
	menu_button.name = "MainMenuButton"
	menu_button.text = "Ana Menüye Dön"
	menu_button.position = Vector2(230.0, 568.0)
	menu_button.size = Vector2(380.0, 52.0)
	menu_button.pressed.connect(_on_menu_pressed)
	modal_root.add_child(menu_button)

	replay_button = Button.new()
	replay_button.name = "ReplayButton"
	replay_button.text = "Katı Tekrar Oyna"
	replay_button.position = Vector2(670.0, 568.0)
	replay_button.size = Vector2(380.0, 52.0)
	replay_button.pressed.connect(_on_replay_pressed)
	modal_root.add_child(replay_button)
