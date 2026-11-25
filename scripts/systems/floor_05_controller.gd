extends Node3D
## Floor 5 — Rooftop & Beta Reactor. Spawns the Volkov boss and the reactor console at runtime,
## calls in reinforcements on boss phases 2 and 3, and unlocks the console once Volkov falls.

const OBJ_START: String = "GÖREV: Viktor Volkov'u etkisiz hale getir!"
const OBJ_CONSOLE: String = "GÖREV: Beta Reaktörü konsolunu kullan ve savunma sistemini kapat!"
const BOSS_PATH: String = "res://scenes/enemies/boss_volkov.tscn"
const CONSOLE_PATH: String = "res://scenes/puzzles/reactor_console.tscn"
const FALLBACK_BOSS_PATH: String = "res://scenes/enemies/enemy_base.tscn"
const FALLBACK_BOSS_STATS: String = "res://scripts/resources/enemies/enemy_lv5_exo.tres"
const EXIT_PATH: String = "res://scenes/puzzles/level_exit.tscn"
const GUARD_PATH: String = "res://scenes/enemies/enemy_guard_lv1.tscn"
const TECH_PATH: String = "res://scenes/enemies/enemy_tech_lv1.tscn"
const TEXTURES: Dictionary = {
	"tex_f5_roof_grate": {"scale": 0.25, "roughness": 0.7, "metallic": 0.5},
	"tex_f5_industrial_wall": {"scale": 0.25, "roughness": 0.75, "metallic": 0.3},
	"tex_f5_reactor_core": {"scale": 0.5, "roughness": 0.2, "metallic": 0.3,
		"emission": Color(0.25, 0.65, 1.0), "energy": 2.4},
}
## Reinforcement waves keyed by boss phase: [scene path, marker name].
const WAVES: Dictionary = {
	2: [[GUARD_PATH, "ReinforceA"], [TECH_PATH, "ReinforceB"]],
	3: [[TECH_PATH, "ReinforceC"], [GUARD_PATH, "ReinforceD"]],
}

var boss: Node = null
var reactor_console: Node = null
var _defeated: bool = false
var _spawned_waves: Dictionary = {}
var _reactor_lights: Array[Dictionary] = []
var _beacon_lights: Array[Dictionary] = []
var _time: float = 0.0

@onready var enemies_root: Node3D = get_node_or_null("Enemies") as Node3D
@onready var interactables_root: Node3D = get_node_or_null("Interactables") as Node3D


func _ready() -> void:
	_play_music("bgm_floor5_boss", "bgm_floor1_lobby")
	GameManager.set_objective(OBJ_START)
	_apply_textures(TEXTURES)
	_collect_lights("reactor_light", _reactor_lights)
	_collect_lights("beacon_light", _beacon_lights)
	_spawn_rain()
	_spawn_console()
	_spawn_boss()


func _process(delta: float) -> void:
	_time += delta
	var reactor_pulse: float = 0.75 + 0.25 * sin(_time * 3.2) + 0.08 * sin(_time * 17.0)
	if _defeated:
		reactor_pulse = 0.55 + 0.1 * sin(_time * 1.4)
	for entry in _reactor_lights:
		if is_instance_valid(entry["light"]):
			(entry["light"] as Light3D).light_energy = entry["base"] * reactor_pulse
	var beacon_on: bool = fmod(_time, 1.6) < 0.8
	for entry in _beacon_lights:
		if is_instance_valid(entry["light"]):
			(entry["light"] as Light3D).light_energy = entry["base"] if beacon_on else entry["base"] * 0.08


func get_boss() -> Node:
	return boss


func get_reactor_console() -> Node:
	return reactor_console


# ------------------------------------------------------------------ encounter
func _marker_position(marker_name: String, fallback: Vector3) -> Vector3:
	var marker: Node3D = get_node_or_null("Markers/" + marker_name) as Node3D
	return marker.position if marker != null else fallback


func _spawn_boss() -> void:
	if enemies_root == null:
		return
	var scene: PackedScene = _load_scene(BOSS_PATH)
	var is_fallback: bool = scene == null
	if is_fallback:
		scene = _load_scene(FALLBACK_BOSS_PATH)
	if scene == null:
		return
	boss = scene.instantiate()
	if is_fallback:
		if ResourceLoader.exists(FALLBACK_BOSS_STATS) and "stats" in boss:
			boss.set("stats", load(FALLBACK_BOSS_STATS))
		if "is_boss" in boss:
			boss.set("is_boss", true)
		if "boss_name" in boss:
			boss.set("boss_name", "VİKTOR VOLKOV")
		boss.add_to_group("bosses")
	boss.name = "VolkovBoss"
	if boss is Node3D:
		(boss as Node3D).position = _marker_position("BossSpawn", Vector3(0, 0, -44))
	enemies_root.add_child(boss)
	if boss.has_signal("phase_changed"):
		boss.connect("phase_changed", _on_boss_phase_changed)
	if boss.has_signal("boss_defeated"):
		boss.connect("boss_defeated", _on_boss_defeated)
	if boss.has_signal("died"):
		boss.connect("died", _on_boss_defeated)


func _spawn_console() -> void:
	if interactables_root == null:
		return
	var scene: PackedScene = _load_scene(CONSOLE_PATH)
	if scene == null:
		return
	reactor_console = scene.instantiate()
	reactor_console.name = "ReactorConsole"
	if reactor_console is Node3D:
		(reactor_console as Node3D).position = _marker_position("ConsoleSpawn", Vector3(0, 0, -28.1))
	interactables_root.add_child(reactor_console)


func _on_boss_phase_changed(new_phase: int = 0, _a: Variant = null, _b: Variant = null) -> void:
	if not WAVES.has(new_phase) or _spawned_waves.has(new_phase) or enemies_root == null:
		return
	_spawned_waves[new_phase] = true
	for entry in WAVES[new_phase]:
		var scene: PackedScene = _load_scene(entry[0])
		if scene == null:
			continue
		var enemy: Node = scene.instantiate()
		if "start_alerted" in enemy:
			enemy.set("start_alerted", true)
		if enemy is Node3D:
			(enemy as Node3D).position = _marker_position(entry[1], Vector3.ZERO)
		enemies_root.add_child(enemy)


func _on_boss_defeated(_a: Variant = null) -> void:
	if _defeated:
		return
	_defeated = true
	GameManager.set_objective(OBJ_CONSOLE)
	if is_instance_valid(reactor_console):
		if reactor_console.has_method("activate_console"):
			reactor_console.call("activate_console")
	elif interactables_root != null:
		# Reactor console scene unavailable: fall back to a plain exit into the ending.
		var exit_scene: PackedScene = _load_scene(EXIT_PATH)
		if exit_scene != null:
			var exit: Node = exit_scene.instantiate()
			exit.name = "ReactorShutdownExit"
			if "target_floor" in exit:
				exit.set("target_floor", 6)
			if "prompt_text" in exit:
				exit.set("prompt_text", "[E] Beta Reaktörünü Kapat")
			if exit is Node3D:
				(exit as Node3D).position = _marker_position("ConsoleSpawn", Vector3(0, 0, -28.1))
			interactables_root.add_child.call_deferred(exit)


# ------------------------------------------------------------------ ambience
func _spawn_rain() -> void:
	var rain := CPUParticles3D.new()
	rain.name = "Rain"
	rain.position = _marker_position("RainOrigin", Vector3(0, 18, -32))
	rain.amount = 900
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(30, 0.5, 30)
	rain.direction = Vector3(0.08, -1, 0.04)
	rain.spread = 2.0
	rain.gravity = Vector3(0, -30, 0)
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 18.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.45, 0.02)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.75, 1.0, 0.35)
	drop.material = mat
	rain.mesh = drop
	add_child(rain)


func _collect_lights(group_name: String, into: Array[Dictionary]) -> void:
	for light in get_tree().get_nodes_in_group(group_name):
		if light is Light3D and is_ancestor_of(light):
			into.append({"light": light, "base": (light as Light3D).light_energy})


# ------------------------------------------------------------------ helpers
func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


func _play_music(primary: String, fallback: String) -> void:
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists("res://assets/audio/%s%s" % [primary, ext]):
			AudioManager.play_music(primary)
			return
	AudioManager.play_music(fallback)


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
