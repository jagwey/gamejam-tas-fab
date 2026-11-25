extends Node3D
## Floor 2 — Office & Archive. Music, objectives and the circuit-locked executive security door.

const OBJ_START: String = "GÖREV: Ofis ve arşivi temizle — yönetici güvenlik kapısının devre kilidini çöz"
const OBJ_EXIT: String = "GÖREV: Asansörle 3. Kata çık"
const PUZZLE_PATH: String = "res://scenes/puzzles/circuit_puzzle.tscn"
const DOOR_PROMPT: String = "[E] Devre Kilidi Terminalini Aç"

@onready var archive_terminal: Node = get_node_or_null("Interactables/ArchiveLoreTerminal")
@onready var security_door: Node = get_node_or_null("Interactables/ExecutiveSecurityDoor")
@onready var level_exit: Node = get_node_or_null("Interactables/LevelExit")


func _ready() -> void:
	AudioManager.play_music("bgm_floor2_office")
	GameManager.set_objective(OBJ_START)
	_setup_door(security_door, PUZZLE_PATH, DOOR_PROMPT)


func get_security_door() -> Node:
	return security_door


func _setup_door(door: Node, puzzle_path: String, prompt: String) -> void:
	if door == null:
		return
	if ResourceLoader.exists(puzzle_path) and "puzzle_scene" in door:
		var scene: Resource = load(puzzle_path)
		if scene is PackedScene:
			door.set("puzzle_scene", scene)
	if "custom_prompt" in door:
		door.set("custom_prompt", prompt)
	if door.has_signal("door_unlocked"):
		door.connect("door_unlocked", _on_door_unlocked)


func _on_door_unlocked() -> void:
	GameManager.set_objective(OBJ_EXIT)
