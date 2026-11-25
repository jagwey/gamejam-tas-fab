extends Area3D

@export var terminal_title: String = "Güvenlik Kaydı"
@export_multiline var terminal_body: String = "Reaktör sevkiyatı üst kata ulaştı. Asansör yetkileri güvenlik merkezinden sınırlandırıldı."
var operator: Node
var previous_mouse_mode: Input.MouseMode

func _ready() -> void:
	%Reader.close_requested.connect(_close)
	%Close.pressed.connect(_close)

func get_interact_prompt(_player: Node = null) -> String:
	return "[E] " + terminal_title

func interact(player: Node) -> void:
	if %Reader.visible or get_tree().paused:
		return
	operator = player
	previous_mouse_mode = Input.mouse_mode
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", false)
	%Title.text = terminal_title
	%Body.text = terminal_body
	%Scroll.scroll_vertical = 0
	%Reader.add_to_group("active_game_modal")
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Reader.show()
	%Close.grab_focus()

func _close() -> void:
	if not %Reader.visible:
		return
	%Reader.hide()
	%Reader.remove_from_group("active_game_modal")
	get_tree().paused = false
	if is_instance_valid(operator) and operator.has_method("set_controls_enabled"):
		operator.call("set_controls_enabled", true)
	operator = null
	Input.mouse_mode = previous_mouse_mode
