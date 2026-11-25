extends Node3D
## Floor 4 — VIP & Casino. Runtime textures, chandelier shimmer, sequence-locked vault door.

const OBJ_START: String = "GÖREV: Kumarhaneyi geç — kasa koridorundaki sıra kilidini çözüp çatı asansörüne ulaş"
const OBJ_EXIT: String = "GÖREV: Asansörle Çatıya çık"
const PUZZLE_PATH: String = "res://scenes/puzzles/sequence_puzzle.tscn"
const DOOR_PROMPT: String = "[E] Sıra Kilidi Terminalini Aç"
const TEXTURES: Dictionary = {
	"tex_f4_red_carpet": {"scale": 0.25, "roughness": 0.9},
	"tex_f4_vip_wall": {"scale": 0.25, "roughness": 0.6, "metallic": 0.1},
	"tex_f4_casino_felt": {"scale": 0.5, "roughness": 0.95},
}

@onready var security_door: Node = get_node_or_null("Interactables/VaultSecurityDoor")
@onready var level_exit: Node = get_node_or_null("Interactables/LevelExit")


func _ready() -> void:
	_apply_light_fade()
	_play_music("bgm_floor4_vip", "bgm_floor2_office")
	GameManager.set_objective(OBJ_START)
	_apply_textures(TEXTURES)
	_setup_door(security_door, PUZZLE_PATH, DOOR_PROMPT)
	_radio_later(1.5, "VİKTOR VOLKOV", "volkov_portrait",
		"Kumarhaneme hoş geldin, Yüzbaşı. Her BETA emiliminde seni biraz daha benim tasarımıma çeviriyorum. Kazanan hep kasadır.", 7.5)
	_radio_later(2.0, "AYDIN", "aydin_visor",
		"Kanalımdan çık Volkov. Kasan da, kulen de bu gece çöküyor.", 5.0)


func get_security_door() -> Node:
	return security_door


func _play_music(primary: String, fallback: String) -> void:
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists("res://assets/audio/%s%s" % [primary, ext]):
			AudioManager.play_music(primary)
			return
	AudioManager.play_music(fallback)


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
		"Kasa koridoru açıldı. Volkov çatıda, Beta Reaktörü'nün başında. Bitir bu işi Aydın.", 5.5)


## Swaps the solid-colour fallback for a pixel texture on every mesh in `tex_<name>` groups, if the PNG exists.
func _apply_textures(specs: Dictionary) -> void:
	for group_name in specs:
		var path: String = "res://assets/textures/%s.png" % String(group_name).trim_prefix("tex_")
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		var spec: Dictionary = specs[group_name]
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = spec.get("tint", Color.WHITE)
		mat.roughness = spec.get("roughness", 0.8)
		mat.metallic = spec.get("metallic", 0.0)
		var s: float = spec.get("scale", 0.25)
		mat.uv1_scale = Vector3(s, s, s)
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if spec.get("transparent", false):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if spec.has("emission"):
			mat.emission_enabled = true
			mat.emission = spec["emission"]
			mat.emission_energy_multiplier = spec.get("energy", 1.0)
			mat.emission_texture = tex
		for node in get_tree().get_nodes_in_group(group_name):
			if node is GeometryInstance3D and is_ancestor_of(node):
				(node as GeometryInstance3D).material_override = mat


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
