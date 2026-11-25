extends Node3D
## Floor 2 — Office & Archive. Objectives, music, and the vertical-slice completion console.

const OBJ_START: String = "GÖREV: Ofis ve arşiv katını incele — Volkov'un verilerine ulaş"
const OBJ_CONSOLE: String = "GÖREV: Yönetici odasındaki konsoldan dikey kesit raporunu aç"

@onready var archive_terminal: Node = get_node_or_null("Interactables/ArchiveLoreTerminal")
@onready var console: Node = get_node_or_null("Interactables/VerticalSliceConsole")
@onready var archive_merc: Node = get_node_or_null("Enemies/ArchiveMerc")

var _console_hint_shown: bool = false


func _ready() -> void:
	AudioManager.play_music("bgm_floor2_office")
	GameManager.set_objective(OBJ_START)
	if archive_merc != null and archive_merc.has_signal("died"):
		archive_merc.connect("died", _on_archive_cleared)


func get_console() -> Node:
	return console


func _on_archive_cleared(_enemy: Node = null) -> void:
	if _console_hint_shown:
		return
	_console_hint_shown = true
	GameManager.set_objective(OBJ_CONSOLE)
