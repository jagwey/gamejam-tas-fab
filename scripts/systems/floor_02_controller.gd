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
	_apply_light_fade()
	AudioManager.play_music("bgm_floor2_office")
	GameManager.set_objective(OBJ_START)
	_setup_door(security_door, PUZZLE_PATH, DOOR_PROMPT)
	_radio_later(1.2, "GENERAL DEMİR", "general_portrait",
		"Aydın, burası Volkov'un sunucu arşivleri. Paralı asker timleri ikişerli devriye atıyor — siper al, tek tek avla.", 6.5)
	_radio_later(1.6, "AYDIN", "aydin_visor",
		"Anlaşıldı Komutanım. Arşivi temizleyip yönetici kapısının devre kilidini kıracağım.", 5.0)


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
	GameManager.send_radio("GENERAL DEMİR", "general_portrait",
		"Devre kilidi çözüldü. Arşiv kayıtları bize indiriliyor — asansörle laboratuvar katına çık.", 5.5)


func _radio_later(delay: float, speaker: String, portrait: String, text: String, duration: float = 5.5) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		GameManager.send_radio(speaker, portrait, text, duration)

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
