extends SceneTree
## BETA PROTOCOL — headless acceptance tests (28 criteria, v0.3.0).
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path <project> --script res://tests/run_tests.gd
## Uses the real autoloads under /root, real scenes and real physics steps.

const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"
const FLOOR_1: String = "res://scenes/levels/floor_01_lobby.tscn"
const FLOOR_2: String = "res://scenes/levels/floor_02_office.tscn"
const FLOOR_3: String = "res://scenes/levels/floor_03_lab.tscn"
const FLOOR_4: String = "res://scenes/levels/floor_04_vip.tscn"
const FLOOR_5: String = "res://scenes/levels/floor_05_rooftop.tscn"
const ENDING: String = "res://scenes/cutscenes/ending_cutscene.tscn"
const CIRCUIT_PUZZLE: String = "res://scenes/puzzles/circuit_puzzle.tscn"
const BIO_PUZZLE: String = "res://scenes/puzzles/bio_match_puzzle.tscn"
const SEQUENCE_PUZZLE: String = "res://scenes/puzzles/sequence_puzzle.tscn"
const VOLKOV_SCRIPT: String = "res://scripts/systems/volkov_boss.gd"
const INTEGRITY_ROOTS: Array[String] = ["res://assets", "res://scenes", "res://scripts", "res://tests"]
const INTEGRITY_EXTENSIONS: Array[String] = ["tscn", "tres", "gdshader", "png", "wav", "gd"]
const MIN_PNG: int = 141
const MIN_WAV: int = 31
const TEST_COUNT: int = 28
const CUTSCENE: String = "res://scenes/cutscenes/opening_cutscene.tscn"
const PUZZLE: String = "res://scenes/puzzles/moving_lock_puzzle.tscn"
const GUARD: String = "res://scenes/enemies/enemy_guard_lv1.tscn"
const MERC: String = "res://scenes/enemies/enemy_merc_lv2.tscn"
const SETTINGS_SCRIPT: String = "res://scripts/managers/settings_manager.gd"
const LOAD_EXTENSIONS: Array[String] = ["tscn", "tres", "gdshader", "png", "wav"]
const SCAN_ROOTS: Array[String] = ["res://assets", "res://scenes", "res://scripts", "res://shaders"]
const SETTINGS_KEYS: Array[String] = ["mouse_sensitivity", "horizontal_fov", "master_volume", "music_volume", "sfx_volume",
	"fullscreen", "camera_shake_enabled", "crt_enabled", "graphics_quality", "vsync_enabled", "show_fps", "difficulty"]
const GUARD_STATS: String = "res://scripts/resources/enemies/enemy_lv1_guard.tres"
const CRT_SHADER: String = "res://assets/shaders/crt_vhs.gdshader"
const WEAPON_DIR: String = "res://assets/sprites/weapons"
const CUTSCENE_BG_DIR: String = "res://assets/sprites/cutscenes"
const PORTRAIT_DIR: String = "res://assets/portraits"
const ENEMY_PREFIXES: Array[String] = ["guard_lv1", "merc_lv2", "heavy_lv3", "commando_lv4", "tech_lv1", "volkov_boss"]
const FLOORS: Array[String] = [FLOOR_1, FLOOR_2, FLOOR_3, FLOOR_4, FLOOR_5]
## Decorative layers allowed to overlap HUD panels / puzzle bars (viewmodel art, alignment guide).
const OVERLAP_ALLOW: Array[String] = ["HUD/WeaponSprite", "Track/Guide"]

var _results: Array[Dictionary] = []
var _current_test: String = ""
var _current_ok: bool = true
var _current_notes: PackedStringArray = []
var _settings_backup: Dictionary = {}
var _signal_hits: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


# ------------------------------------------------------------------ harness

func _begin(test_name: String) -> void:
	_current_test = test_name
	_current_ok = true
	_current_notes = PackedStringArray()


func _check(cond: bool, what: String) -> void:
	if not cond:
		_current_ok = false
		_current_notes.append(what)


func _end() -> void:
	_results.append({"name": _current_test, "ok": _current_ok, "notes": _current_notes})
	var mark: String = "PASS" if _current_ok else "FAIL"
	print("[%s] %s" % [mark, _current_test])
	for n in _current_notes:
		print("       - ", n)


func _mark(key: String) -> void:
	_signal_hits[key] = int(_signal_hits.get(key, 0)) + 1


func _hits(key: String) -> int:
	return int(_signal_hits.get(key, 0))


func _ap(n: Node, key: String) -> Variant:
	return n.get(key)


func _gm() -> Node:
	return root.get_node("GameManager")


func _sm() -> Node:
	return root.get_node("SaveManager")


func _settings() -> Node:
	return root.get_node("SettingsManager")


func _audio() -> Node:
	return root.get_node("AudioManager")


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _physics(n: int) -> void:
	for _i in n:
		await physics_frame


func _seconds(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func _wait_scene(path: String) -> bool:
	for _i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			await physics_frame
			await physics_frame
			return true
	return false


func _goto(path: String) -> bool:
	paused = false
	var err: Error = change_scene_to_file(path)
	if err != OK:
		return false
	var ok: bool = await _wait_scene(path)
	return ok


func _player() -> Node3D:
	return get_first_node_in_group("player") as Node3D


func _clear_enemies() -> void:
	var nodes: Array[Node] = get_nodes_in_group("enemies")
	nodes.append_array(get_nodes_in_group("dead_enemies"))
	for n in nodes:
		if is_instance_valid(n):
			n.free()
	await physics_frame


func _spawn(path: String, pos: Vector3, yaw_deg: float) -> EnemyBase:
	var ps: PackedScene = load(path) as PackedScene
	var e: EnemyBase = ps.instantiate() as EnemyBase
	e.position = pos
	e.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	current_scene.add_child(e)
	return e


func _place_player(pl: Node3D, pos: Vector3, yaw_deg: float) -> void:
	var body: CharacterBody3D = pl as CharacterBody3D
	body.velocity = Vector3.ZERO
	body.global_position = pos
	body.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	var cam: FpsCamera = _ap(pl, "fps_camera") as FpsCamera
	cam.set_pitch(0.0)


## Rotates the player/camera so the aim ray points at target.
func _aim_at(pl: Node3D, target: Vector3) -> void:
	var cam: FpsCamera = _ap(pl, "fps_camera") as FpsCamera
	var origin: Vector3 = cam.camera.global_position
	var flat: Vector3 = Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	var yaw: float = atan2(-flat.x, -flat.z)
	pl.rotation = Vector3(0.0, yaw, 0.0)
	cam.set_pitch(atan2(target.y - origin.y, flat.length()))


func _backup_settings() -> void:
	var s: Node = _settings()
	for key in SETTINGS_KEYS:
		_settings_backup[key] = s.get(key)


func _restore_settings() -> void:
	var s: Node = _settings()
	for key in _settings_backup.keys():
		s.set(key, _settings_backup[key])
	if s.has_method("save_settings"):
		s.call("save_settings")


# ------------------------------------------------------------------ run

func _run() -> void:
	_backup_settings()
	var save_existed: bool = bool(_sm().call("has_save"))
	var save_backup: Dictionary = {}
	if save_existed:
		save_backup = _sm().call("load_progress") as Dictionary
	_sm().call("clear_save")
	_settings().call("set_difficulty", 0)

	await _t01_main_menu()
	await _t02_fov_and_shake()
	if not await _goto(FLOOR_1):
		print("FATAL: floor_01 did not load")
	await _t03_wall()
	await _t04_weapons()
	await _t05_enemy_awareness()
	await _t06_enemy_stats_and_death()
	await _t07_player_health()
	await _t08_beta_heal()
	await _t09_single_use()
	await _t10_heal_cap()
	await _t13_locked_door()
	await _t14_floor_transition()
	await _t15_pause_restart()
	await _t11_cutscene()
	await _t12_puzzle()
	await _t17_floor2_circuit()
	await _t18_floor3_lab()
	await _t19_floor4_vip()
	await _t20_floor5_boss()
	await _t21_ending()
	await _t16_resources()
	await _t22_integrity()
	await _t23_beta_evolution()
	await _t24_difficulty()
	await _t25_sprite_dimensions()
	await _t26_ui_overlap()
	await _t27_render_performance()
	await _t28_hint_and_radio()

	# Cleanup: test saves, settings, pause state, audio.
	_sm().call("clear_save")
	if save_existed:
		_sm().call("save_progress", int(save_backup.get("current_floor", 1)), save_backup.get("player_state", {}) as Dictionary)
	_restore_settings()
	paused = false
	_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	var passed: int = 0
	for r in _results:
		if bool(r["ok"]):
			passed += 1
	print("")
	print("==== BETA PROTOCOL ACCEPTANCE: %d/%d PASSED ====" % [passed, _results.size()])

	# Leave an empty tree and let the audio server drop its playbacks before quitting.
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	_audio().call("release_all")
	await _frames(4)
	await _seconds(0.3)
	await _frames(4)
	quit(0 if passed == _results.size() and _results.size() == TEST_COUNT else 1)


# ------------------------------------------------------------------ 1. main menu

func _t01_main_menu() -> void:
	_begin("01 Main menu: 5 buttons, 4-tab settings (5 sliders/5 toggles/2 options), card hides")
	var ok: bool = await _goto(MAIN_MENU)
	_check(ok, "main menu scene loaded")
	if ok:
		var scene: Node = current_scene
		var expected: Dictionary = {
			"NewGame": "Yeni Oyun", "Continue": "Devam Et", "Settings": "Ayarlar",
			"Credits": "Geliştirici Ekibi", "Quit": "Çıkış",
		}
		var count: int = 0
		for key in expected.keys():
			var b: Button = scene.get_node_or_null("%" + str(key)) as Button
			if b != null and b.text == str(expected[key]):
				count += 1
			else:
				_check(false, "button %s missing or wrong text" % key)
		_check(count == 5, "5 menu buttons (got %d)" % count)
		var panel: Control = scene.get_node_or_null("%SettingsPanel") as Control
		_check(panel != null, "settings panel present")
		if panel != null:
			var tabs: TabContainer = panel.get_node_or_null("%Tabs") as TabContainer
			_check(tabs != null and tabs.get_tab_count() == 4, "%%Tabs has 4 tabs (got %d)" % (tabs.get_tab_count() if tabs != null else -1))
			var sliders: int = panel.find_children("*", "HSlider", true, false).size()
			var toggles: int = panel.find_children("*", "CheckButton", true, false).size()
			var options: int = panel.find_children("*", "OptionButton", true, false).size()
			_check(sliders >= 5, "HSlider >= 5 (got %d)" % sliders)
			_check(toggles >= 5, "CheckButton >= 5 (got %d)" % toggles)
			_check(options >= 2, "OptionButton >= 2 (got %d)" % options)
			var fov: HSlider = panel.get_node_or_null("%Fov") as HSlider
			_check(fov != null and is_equal_approx(fov.min_value, 75.0) and is_equal_approx(fov.max_value, 120.0), "FOV slider range 75..120")
			var card: Control = scene.get_node_or_null("%MenuCard") as Control
			var settings_btn: Button = scene.get_node_or_null("%Settings") as Button
			_check(card != null and card.visible and not panel.visible, "menu card visible, panel hidden at start")
			if card != null and settings_btn != null:
				settings_btn.pressed.emit()
				await _frames(2)
				_check(panel.visible and not card.visible, "opening settings hides %MenuCard")
				panel.call("close_panel")
				await _frames(2)
				_check(card.visible and not panel.visible, "closing settings restores %MenuCard")
	_end()


# ------------------------------------------------------------------ 2. fov / shake

func _t02_fov_and_shake() -> void:
	_begin("02 FOV default 100, conversion, clamp, sprint boost, shake off")
	var fresh: Node = (load(SETTINGS_SCRIPT) as GDScript).new() as Node
	var default_fov: float = float(fresh.get("horizontal_fov"))
	fresh.free()
	_check(is_equal_approx(default_fov, 100.0), "default horizontal_fov is 100 (got %.2f)" % default_fov)
	var v: float = FpsCamera.horizontal_to_vertical_fov(100.0, 16.0 / 9.0)
	_check(absf(v - 67.67) < 0.02, "100° h -> %.3f° v (expected ~67.67)" % v)
	_check(is_equal_approx(FpsCamera.horizontal_to_vertical_fov(40.0, 16.0 / 9.0), FpsCamera.horizontal_to_vertical_fov(75.0, 16.0 / 9.0)), "clamped to 75 minimum")
	_check(is_equal_approx(FpsCamera.horizontal_to_vertical_fov(170.0, 16.0 / 9.0), FpsCamera.horizontal_to_vertical_fov(120.0, 16.0 / 9.0)), "clamped to 120 maximum")

	var s: Node = _settings()
	s.set("horizontal_fov", 100.0)
	s.set("camera_shake_enabled", true)
	var cam: FpsCamera = FpsCamera.new()
	cam.name = "TestFpsCamera"
	root.add_child(cam)
	await _frames(2)
	cam.sprinting = true
	await _seconds(0.7)
	var boosted: float = cam._current_h_fov
	_check(boosted > 100.0 + FpsCamera.SPRINT_FOV_BOOST * 0.85, "sprint raises FOV (got %.2f)" % boosted)
	cam.sprinting = false
	await _seconds(0.7)
	_check(absf(cam._current_h_fov - 100.0) < 0.6, "FOV returns to 100 after sprint (got %.2f)" % cam._current_h_fov)

	s.set("camera_shake_enabled", false)
	cam.add_trauma(1.0)
	await _frames(6)
	_check(cam._trauma == 0.0, "no trauma accumulated with shake off")
	_check(cam.camera.position.length() < 0.0001, "camera offset stays zero with shake off")
	s.set("camera_shake_enabled", true)
	cam.add_trauma(1.0)
	await _frames(3)
	_check(cam._trauma > 0.0, "trauma accumulates with shake on (control)")
	cam.free()
	_restore_settings()
	_end()


# ------------------------------------------------------------------ 3. wall

func _t03_wall() -> void:
	_begin("03 Floor 1 wall blocks the player")
	var pl: Node3D = _player()
	_check(pl != null, "player exists in floor_01")
	if pl != null:
		await _clear_enemies()
		var wall_z: float = -36.0
		if current_scene.has_method("get_test_wall_position"):
			wall_z = (current_scene.call("get_test_wall_position") as Vector3).z
		_place_player(pl, Vector3(0.0, 0.05, -33.0), 0.0)
		await _physics(5)
		var start_z: float = pl.global_position.z
		Input.action_press("move_forward")
		await _physics(90)
		Input.action_release("move_forward")
		await _physics(3)
		var z: float = pl.global_position.z
		var inner_face: float = wall_z + 0.25
		_check(z < start_z - 1.0, "player actually moved forward (%.2f -> %.2f)" % [start_z, z])
		_check(z > inner_face + 0.3, "player stopped at the wall (z=%.2f, wall face %.2f)" % [z, inner_face])
	_end()


# ------------------------------------------------------------------ 4. weapons

func _t04_weapons() -> void:
	_begin("04 Pistol/reload/shotgun pellets/quick melee")
	var pl: Node3D = _player()
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	var wm: WeaponManager = _ap(pl, "weapon_manager") as WeaponManager
	hc.invulnerable = true
	await _clear_enemies()
	_place_player(pl, Vector3(0.0, 0.05, -14.0), 0.0)
	var guard: EnemyBase = _spawn(GUARD, Vector3(0.0, 0.0, -20.0), 0.0)
	await _physics(4)

	wm.equip("pistol")
	await _seconds(0.25)
	_check(wm.get_mag("pistol") == 12, "pistol mag starts at 12 (got %d)" % wm.get_mag("pistol"))
	_aim_at(pl, guard.global_position + Vector3(0.0, 1.0, 0.0))
	await _physics(1)
	var hp_before: float = guard.health.current_health
	var fired: bool = wm.fire()
	_check(fired, "pistol fired")
	_check(wm.get_mag("pistol") == 11, "mag 12 -> 11 (got %d)" % wm.get_mag("pistol"))
	_check(guard.health.current_health < hp_before, "hitscan hit Lv1 guard (%.0f -> %.0f)" % [hp_before, guard.health.current_health])

	await _seconds(0.25)
	_check(wm.reload(), "reload started")
	await _seconds(1.3)
	_check(not wm.is_reloading and wm.get_mag("pistol") == 12, "reload 11 -> 12 (got %d)" % wm.get_mag("pistol"))
	guard.free()
	await _physics(2)

	wm.unlock_weapon("shotgun", true)
	await _seconds(0.3)
	_check(wm.is_unlocked("shotgun") and wm.current_weapon_id == "shotgun", "shotgun unlocked and equipped")
	var merc: EnemyBase = _spawn(MERC, Vector3(0.0, 0.0, -15.8), 0.0)
	await _physics(4)
	_aim_at(pl, merc.global_position + Vector3(0.0, 1.0, 0.0))
	await _physics(1)
	_signal_hits["pellet"] = 0
	merc.damaged.connect(func(_a: float, _c: float, _m: float) -> void: _mark("pellet"))
	var shot: bool = wm.fire()
	_check(shot, "shotgun fired")
	_check(_hits("pellet") == 7, "7 pellets hit (got %d)" % _hits("pellet"))
	merc.free()
	await _physics(2)

	var target: EnemyBase = _spawn(GUARD, Vector3(0.0, 0.0, -15.6), 0.0)
	await _physics(4)
	_aim_at(pl, target.global_position + Vector3(0.0, 1.0, 0.0))
	await _seconds(0.8)
	var before_melee: float = target.health.current_health
	_check(wm.quick_melee(), "quick melee swung")
	_check(target.health.current_health < before_melee, "quick melee dealt damage (%.0f -> %.0f)" % [before_melee, target.health.current_health])
	target.free()
	await _physics(2)
	_end()


# ------------------------------------------------------------------ 5. awareness

func _t05_enemy_awareness() -> void:
	_begin("05 Enemy IDLE -> ALERT -> CHASE with LOS, calm behind wall")
	var pl: Node3D = _player()
	await _clear_enemies()
	_place_player(pl, Vector3(0.0, 0.05, -14.0), 180.0)
	var guard: EnemyBase = _spawn(GUARD, Vector3(0.0, 0.0, -20.0), 180.0)
	var first: String = guard.get_state_name()
	_check(first == "IDLE" or first == "PATROL", "starts calm (got %s)" % first)
	var seen: Dictionary = {}
	guard.state_changed.connect(func(s: int) -> void: seen[EnemyBase.State.keys()[s]] = true)
	for _i in 90:
		await physics_frame
		seen[guard.get_state_name()] = true
		if guard.get_state_name() == "CHASE":
			break
	_check(seen.has("ALERT"), "went through ALERT")
	_check(seen.has("CHASE") or guard.get_state_name() in ["CHASE", "ATTACK_WINDUP", "ATTACK"], "reached CHASE (seen %s)" % str(seen.keys()))
	guard.free()
	await _physics(2)

	_place_player(pl, Vector3(-4.0, 0.05, -6.0), 0.0)
	var hidden: EnemyBase = _spawn(GUARD, Vector3(-10.0, 0.0, -16.0), 180.0)
	await _physics(2)
	_check(not hidden.has_line_of_sight(), "wall blocks line of sight")
	var stayed_calm: bool = true
	for _i in 60:
		await physics_frame
		if not (hidden.get_state_name() in ["IDLE", "PATROL"]):
			stayed_calm = false
	_check(stayed_calm, "stays calm when a wall blocks it (got %s)" % hidden.get_state_name())
	hidden.free()
	await _physics(2)
	_end()


# ------------------------------------------------------------------ 6. stats / death

func _t06_enemy_stats_and_death() -> void:
	_begin("06 Enemy stats (40/6/0.9, 85/9/1.15 burst 2), 3-frame death -> corpse")
	var guard: EnemyBase = _spawn(GUARD, Vector3(-6.0, 0.0, -30.0), 0.0)
	var merc: EnemyBase = _spawn(MERC, Vector3(6.0, 0.0, -30.0), 0.0)
	await _physics(2)
	var g: EnemyStats = guard.stats
	var m: EnemyStats = merc.stats
	_check(is_equal_approx(g.max_health, 40.0) and is_equal_approx(g.damage, 6.0) and is_equal_approx(g.attack_interval, 0.9),
		"Lv1 guard 40/6/0.9 (got %.0f/%.1f/%.2f)" % [g.max_health, g.damage, g.attack_interval])
	_check(is_equal_approx(m.max_health, 85.0) and is_equal_approx(m.damage, 9.0) and is_equal_approx(m.attack_interval, 1.15),
		"Lv2 merc 85/9/1.15 (got %.0f/%.1f/%.2f)" % [m.max_health, m.damage, m.attack_interval])
	_check(m.burst_count == 2, "Lv2 merc burst_count 2 (got %d)" % m.burst_count)
	_check(is_equal_approx(guard.health.current_health, 40.0) and is_equal_approx(merc.health.current_health, 85.0), "spawned at full HP")
	var death_frames: int = 0
	if merc.sprite != null and merc.sprite.sprite_frames != null and merc.sprite.sprite_frames.has_animation("death"):
		death_frames = merc.sprite.sprite_frames.get_frame_count("death")
	_check(death_frames >= 3, "death animation >= 3 frames (got %d)" % death_frames)
	var killed: bool = merc.take_damage(1000.0)
	await _physics(2)
	_check(killed, "lethal damage reports kill")
	_check(merc.get_state_name() == "DEAD" and merc.is_dead, "state DEAD and is_dead")
	_check(merc.can_be_harvested(), "can_be_harvested")
	_check((merc.collision_layer & 4) == 0, "enemy layer 3 removed")
	_check(merc.corpse_area != null and merc.corpse_area.is_in_group("corpses") and merc.corpse_area.collision_layer == 8, "corpse area active in 'corpses' on layer 4 (value 8)")
	_check(not merc.is_in_group("enemies") and merc.is_in_group("dead_enemies"), "moved to dead_enemies")
	guard.free()
	merc.free()
	await _physics(2)
	_end()


# ------------------------------------------------------------------ 7. health

func _t07_player_health() -> void:
	_begin("07 No regen; lethal damage -> death screen")
	var pl: Node3D = _player()
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	await _clear_enemies()
	hc.invulnerable = false
	hc.set_health(50.0, 100.0)
	await _physics(60)
	_check(is_equal_approx(hc.current_health, 50.0), "no regen over 60 frames (got %.1f)" % hc.current_health)
	_signal_hits["died"] = 0
	pl.connect("player_died", func() -> void: _mark("died"))
	pl.call("apply_damage", 500.0)
	await _frames(2)
	_check(is_equal_approx(hc.current_health, 0.0) and hc.is_dead, "hp 0 and is_dead")
	_check(_hits("died") == 1, "player_died emitted")
	var ds: Control = _ap(pl, "death_screen") as Control
	_check(ds != null and ds.visible, "death screen visible")
	_check(paused, "tree paused on death")
	if ds != null:
		ds.remove_from_group("active_game_modal")
		ds.hide()
	paused = false
	var ok: bool = await _goto(FLOOR_1)
	_check(ok, "floor reloaded after death")
	_end()


# ------------------------------------------------------------------ 8. heal

func _prep_beta(hp: float) -> Array:
	var pl: Node3D = _player()
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	var beta: BetaDeviceController = _ap(pl, "beta_device") as BetaDeviceController
	hc.invulnerable = true
	hc.set_health(hp, 100.0)
	_place_player(pl, Vector3(0.0, 0.05, -14.0), 0.0)
	return [pl, hc, beta]


func _spawn_corpse(path: String, pos: Vector3) -> EnemyBase:
	var e: EnemyBase = _spawn(path, pos, 0.0)
	await _physics(2)
	e.take_damage(1000.0)
	await _physics(3)
	return e


func _t08_beta_heal() -> void:
	_begin("08 BETA heal table, Lv2 absorption rewards, real 0.85 s channel 50/100 -> 71/106")
	var table: Array[float] = []
	for lvl in range(1, 7):
		table.append(BetaDeviceController.calculate_heal_amount(100.0, lvl))
	var expected: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0, 25.0]
	var table_ok: bool = true
	for i in expected.size():
		if not is_equal_approx(table[i], expected[i]):
			table_ok = false
	_check(table_ok, "heal table 5,10,15,20,25,25 (got %s)" % str(table))
	var rw: Dictionary = BetaDeviceController.calculate_absorption_rewards(100.0, 2)
	var rw_bonus: float = float(rw.get("max_hp_bonus", 0.0))
	var rw_heal: float = float(rw.get("heal_amount", 0.0))
	var rw_ess: int = int(rw.get("essence", 0))
	_check(is_equal_approx(rw_bonus, 6.0) and is_equal_approx(rw_heal, 21.0) and rw_ess == 25,
		"Lv2 rewards +6 max / +21 heal / 25 essence (got %.1f/%.1f/%d)" % [rw_bonus, rw_heal, rw_ess])
	await _clear_enemies()
	var refs: Array = _prep_beta(50.0)
	var hc: HealthComponent = refs[1] as HealthComponent
	var beta: BetaDeviceController = refs[2] as BetaDeviceController
	_reset_beta(beta)
	var corpse: EnemyBase = await _spawn_corpse(MERC, Vector3(0.0, 0.0, -15.6))
	_check(beta.find_nearest_corpse() == corpse, "corpse found in range")
	_check(beta.try_start_beta(), "BETA channel started")
	await _seconds(0.4)
	_check(beta.is_channeling and is_equal_approx(hc.current_health, 50.0), "still channeling at 0.4 s, no heal yet")
	await _seconds(0.7)
	_check(not beta.is_channeling, "channel completed before 1.1 s")
	_check(is_equal_approx(hc.current_health, 71.0) and is_equal_approx(hc.max_health, 106.0),
		"Lv2 absorption 50/100 -> 71/106 (got %.1f/%.1f)" % [hc.current_health, hc.max_health])
	_check(beta.bio_essence == 25, "bio_essence 25 (got %d)" % beta.bio_essence)
	_end()


func _t09_single_use() -> void:
	_begin("09 Corpse can only be used once")
	var refs: Array = _prep_beta(60.0)
	var hc: HealthComponent = refs[1] as HealthComponent
	var beta: BetaDeviceController = refs[2] as BetaDeviceController
	beta.overdrive_time = 0.0
	var corpses: Array[Node] = get_nodes_in_group("dead_enemies")
	var used: EnemyBase = null
	for n in get_tree_nodes_enemies():
		if n.is_harvested:
			used = n
	_check(used != null and used.is_harvested and not used.can_be_harvested(), "harvested corpse marked drained")
	_check(corpses.size() == 0, "drained corpse left dead_enemies")
	_check(not beta.try_start_beta(), "second BETA attempt refused")
	await _seconds(1.2)
	_check(is_equal_approx(hc.current_health, 60.0), "no extra heal (got %.1f)" % hc.current_health)
	_end()


func _reset_beta(beta: BetaDeviceController) -> void:
	beta.cancel_beta("test_reset")
	beta.bio_essence = 0
	beta.beta_tier = 1
	beta.overdrive_time = 0.0


func get_tree_nodes_enemies() -> Array[EnemyBase]:
	var out: Array[EnemyBase] = []
	for n in current_scene.get_children():
		if n is EnemyBase:
			out.append(n as EnemyBase)
	return out


## One real Lv2 absorption from the given HP state; returns true when the channel completed.
func _absorb_lv2(hc: HealthComponent, beta: BetaDeviceController, hp: float, max_hp: float) -> bool:
	await _clear_enemies()
	hc.set_health(hp, max_hp)
	beta.overdrive_time = 0.0
	var corpse: EnemyBase = await _spawn_corpse(MERC, Vector3(0.0, 0.0, -15.6))
	var started: bool = beta.try_start_beta()
	await _seconds(1.1)
	var done: bool = started and not beta.is_channeling and corpse.is_harvested
	corpse.free()
	await _physics(2)
	return done


func _t10_heal_cap() -> void:
	_begin("10 Absorb at full HP (100 -> 106/106), 250 cap, absorb at cap still grants essence/overdrive")
	var refs: Array = _prep_beta(100.0)
	var hc: HealthComponent = refs[1] as HealthComponent
	var beta: BetaDeviceController = refs[2] as BetaDeviceController
	_reset_beta(beta)
	var ok1: bool = await _absorb_lv2(hc, beta, 100.0, 100.0)
	_check(ok1, "BETA allowed and completed at 100/100")
	_check(is_equal_approx(hc.current_health, 106.0) and is_equal_approx(hc.max_health, 106.0),
		"100/100 -> 106/106 (got %.1f/%.1f)" % [hc.current_health, hc.max_health])
	var ok2: bool = await _absorb_lv2(hc, beta, 248.0, 248.0)
	_check(ok2, "absorption completed at 248/248")
	_check(is_equal_approx(hc.current_health, 250.0) and is_equal_approx(hc.max_health, 250.0),
		"248/248 + Lv2 caps at 250/250 (got %.1f/%.1f)" % [hc.current_health, hc.max_health])
	var ess_before: int = beta.bio_essence
	var ok3: bool = await _absorb_lv2(hc, beta, 250.0, 250.0)
	_check(ok3, "absorption still allowed at 250/250")
	_check(beta.bio_essence == ess_before + 25, "essence awarded at cap (%d -> %d)" % [ess_before, beta.bio_essence])
	_check(beta.is_overdrive_active(), "overdrive active after capped absorption")
	_check(is_equal_approx(hc.max_health, 250.0) and is_equal_approx(hc.current_health, 250.0),
		"max stays 250 (got %.1f/%.1f)" % [hc.current_health, hc.max_health])
	_reset_beta(beta)
	hc.set_health(100.0, 100.0)
	hc.invulnerable = false
	await _physics(2)
	_end()


# ------------------------------------------------------------------ 13. door

func _t13_locked_door() -> void:
	_begin("13 LockedDoor collision and unlock")
	var door: Node = current_scene.get_node_or_null("Interactables/ElevatorSecurityDoor")
	_check(door != null, "security door present")
	if door != null:
		var col: CollisionShape3D = door.get_node("DoorCollision") as CollisionShape3D
		_check(not col.disabled, "DoorCollision enabled at start")
		_check(not bool(door.get("is_unlocked")), "starts locked")
		_signal_hits["door"] = 0
		door.connect("door_unlocked", func() -> void: _mark("door"))
		door.call("unlock_and_open")
		await _physics(3)
		_check(bool(door.get("is_unlocked")), "is_unlocked")
		_check(col.disabled, "DoorCollision disabled")
		_check(_hits("door") == 1, "door_unlocked emitted once")
	_end()


# ------------------------------------------------------------------ 14. floor transition

func _t14_floor_transition() -> void:
	_begin("14 load_floor(2) -> floor_02, save, carryover")
	var pl: Node3D = _player()
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	var wm: WeaponManager = _ap(pl, "weapon_manager") as WeaponManager
	hc.invulnerable = false
	hc.set_health(73.0, 100.0)
	wm.unlock_weapon("shotgun", false)
	_sm().call("clear_save")
	_gm().call("load_floor", 2, true)
	var ok: bool = await _wait_scene(FLOOR_2)
	_check(ok and current_scene.scene_file_path == FLOOR_2, "floor_02 is current scene")
	_check(int(_gm().get("current_floor")) == 2, "GameManager.current_floor == 2")
	_check(bool(_sm().call("has_save")), "has_save() true")
	var data: Dictionary = _sm().call("load_progress") as Dictionary
	_check(int(data.get("current_floor", 0)) == 2, "saved floor is 2 (got %s)" % str(data.get("current_floor")))
	var np: Node3D = _player()
	_check(np != null and np != pl, "new player spawned")
	if np != null:
		var nhc: HealthComponent = _ap(np, "health_component") as HealthComponent
		var nwm: WeaponManager = _ap(np, "weapon_manager") as WeaponManager
		_check(is_equal_approx(nhc.current_health, 73.0), "health carried over (got %.1f)" % nhc.current_health)
		_check(nwm.is_unlocked("shotgun"), "shotgun unlock carried over")
	_end()


# ------------------------------------------------------------------ 15. pause

func _t15_pause_restart() -> void:
	_begin("15 Pause toggle and restart unpause")
	var pl: Node3D = _player()
	var pm: Control = _ap(pl, "pause_menu") as Control
	_check(pm != null, "pause menu attached")
	if pm != null:
		var opened: bool = bool(pm.call("toggle_pause"))
		_check(opened and paused and pm.visible, "toggle_pause pauses and shows menu")
		var closed: bool = bool(pm.call("toggle_pause"))
		_check(closed and not paused and not pm.visible, "toggle_pause resumes")
		pm.call("toggle_pause")
		_check(paused, "paused again before restart")
		_gm().call("restart_current_floor")
		_check(not paused, "restart_current_floor unpauses immediately")
		var ok: bool = await _wait_scene(FLOOR_2)
		_check(ok, "floor reloaded")
		_check(not paused, "tree unpaused after restart")
	_end()


# ------------------------------------------------------------------ 11. cutscene

func _t11_cutscene() -> void:
	_begin("11 Cutscene skip hold (3.2 s -> 0.64, release -> 0, 5 s -> skipped)")
	var ok: bool = await _goto(CUTSCENE)
	_check(ok, "cutscene loaded")
	if ok:
		var cs: Node = current_scene
		cs.call("simulate_space_hold", 3.2, true)
		var p: float = float(cs.call("get_skip_progress"))
		_check(absf(p - 0.64) < 0.01, "3.2 s hold -> %.3f progress" % p)
		cs.call("simulate_space_hold", 0.1, false)
		_check(is_zero_approx(float(cs.call("get_skip_progress"))), "release resets progress")
		_signal_hits["skip"] = 0
		cs.connect("cutscene_skipped", func() -> void: _mark("skip"))
		cs.call("simulate_space_hold", 5.0, true)
		_check(_hits("skip") == 1, "cutscene_skipped emitted")
		var moved: bool = await _wait_scene(FLOOR_1)
		_check(moved, "skip loads floor 1")
	_end()


# ------------------------------------------------------------------ 12. puzzle

func _t12_puzzle() -> void:
	_begin("12 Moving-lock puzzle (fail, 3 stages, solved, ESC cancel)")
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 40
	root.add_child(layer)
	var ps: PackedScene = load(PUZZLE) as PackedScene
	var puzzle: Control = ps.instantiate() as Control
	layer.add_child(puzzle)
	await _frames(2)
	_signal_hits["solved"] = 0
	puzzle.connect("puzzle_solved", func() -> void: _mark("solved"))
	puzzle.call("force_misalign_current_bar_for_test")
	_check(not bool(puzzle.call("attempt_advance")), "misaligned attempt fails")
	_check(int(puzzle.get("current_stage")) == 0, "stage stays 0 after fail")
	var stages: Array[int] = []
	for _i in 3:
		puzzle.call("force_align_current_bar_for_test")
		puzzle.call("attempt_advance")
		stages.append(int(puzzle.get("current_stage")))
	_check(str(stages) == "[1, 2, 3]", "stages 1,2,3 (got %s)" % str(stages))
	_check(bool(puzzle.get("is_solved")), "is_solved")
	_check(_hits("solved") == 1, "puzzle_solved emitted")
	puzzle.free()

	var second: Control = ps.instantiate() as Control
	layer.add_child(second)
	await _frames(2)
	_signal_hits["cancel"] = 0
	second.connect("puzzle_cancelled", func() -> void: _mark("cancel"))
	var esc: InputEventAction = InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	root.push_input(esc)
	await _frames(2)
	_check(_hits("cancel") == 1, "ESC emits puzzle_cancelled")
	layer.queue_free()
	await _frames(2)
	_end()


# ------------------------------------------------------------------ 16. resources

func _collect(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect(full, out)
			elif entry.get_extension() in LOAD_EXTENSIONS:
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _t16_resources() -> void:
	_begin("16 All tscn/tres/gdshader/png/wav resources load")
	var files: Array[String] = []
	for r in SCAN_ROOTS:
		_collect(r, files)
	var failed: PackedStringArray = []
	var counts: Dictionary = {}
	for f in files:
		var res: Resource = ResourceLoader.load(f)
		if res == null:
			failed.append(f)
		var ext: String = f.get_extension()
		counts[ext] = int(counts.get(ext, 0)) + 1
	print("       loaded: ", counts, " total=", files.size())
	_check(files.size() > 0, "found resources")
	_check(failed.is_empty(), "failed: %s" % ", ".join(failed))
	_end()


# ------------------------------------------------------------------ 17-19. floors 2-4 helpers

func _check_exit(target: int) -> void:
	var ex: Node = current_scene.get_node_or_null("Interactables/LevelExit")
	_check(ex != null, "LevelExit present")
	if ex == null:
		return
	var tf: int = int(ex.get("target_floor"))
	_check(tf == target, "LevelExit targets floor %d (got %d)" % [target, tf])
	var scenes: Dictionary = _gm().get("floor_scenes") as Dictionary
	var path: String = str(scenes.get(target, ""))
	_check(path != "" and ResourceLoader.exists(path), "GameManager maps floor %d -> %s" % [target, path])


## Opens the door's terminal the way the player does (E), checks the unsolved state,
## then solves it and verifies puzzle_solved + unlock + overlay close/unpause.
func _check_door_puzzle(door_path: String, puzzle_path: String) -> void:
	var door: Node = current_scene.get_node_or_null(door_path)
	_check(door != null, "%s present" % door_path.get_file())
	if door == null:
		return
	var ps: PackedScene = door.get("puzzle_scene") as PackedScene
	var got: String = ps.resource_path if ps != null else "<null>"
	_check(got == puzzle_path, "door uses %s (got %s)" % [puzzle_path.get_file(), got])
	_check(not bool(door.get("is_unlocked")), "door starts locked")
	var col: CollisionShape3D = door.get_node("DoorCollision") as CollisionShape3D
	_check(not col.disabled, "DoorCollision enabled while locked")
	door.call("interact", _player())
	await _frames(2)
	var overlay: CanvasLayer = door.get("overlay") as CanvasLayer
	_check(overlay != null and paused, "terminal overlay opened and tree paused")
	if overlay == null or overlay.get_child_count() == 0:
		paused = false
		return
	var puzzle: Control = overlay.get_child(0) as Control
	_check(puzzle.scene_file_path == puzzle_path, "mounted puzzle is %s" % puzzle_path.get_file())
	_check(not bool(puzzle.get("is_solved")), "puzzle starts unsolved")
	_check(not bool(door.get("is_unlocked")), "door still locked before solve")
	_signal_hits["psolved"] = 0
	_signal_hits["punlock"] = 0
	puzzle.connect("puzzle_solved", func() -> void: _mark("psolved"))
	door.connect("door_unlocked", func() -> void: _mark("punlock"))
	puzzle.call("solve_for_test")
	await _frames(2)
	_check(_hits("psolved") == 1, "puzzle_solved emitted once (got %d)" % _hits("psolved"))
	_check(bool(puzzle.get("is_solved")), "puzzle is_solved")
	_check(bool(door.get("is_unlocked")) and _hits("punlock") == 1, "door unlocked (door_unlocked emitted)")
	await _seconds(0.8)
	await _physics(2)
	_check(not is_instance_valid(overlay) and not paused, "overlay closed and tree unpaused")
	_check(col.disabled, "DoorCollision disabled after unlock")


## Counts enemies under Enemies/ with this sprite prefix and checks their stats + real sprite frames.
func _check_enemy_kind(prefix: String, hp: float, dmg: float, interval: float, label: String) -> void:
	var root_node: Node = current_scene.get_node_or_null("Enemies")
	var count: int = 0
	var stats_ok: bool = true
	var sprite_ok: bool = true
	var width: int = 0
	if root_node != null:
		for n in root_node.get_children():
			var e: EnemyBase = n as EnemyBase
			if e == null or e.stats == null or e.stats.sprite_prefix != prefix:
				continue
			count += 1
			if not (is_equal_approx(e.stats.max_health, hp) and is_equal_approx(e.stats.damage, dmg) \
					and is_equal_approx(e.stats.attack_interval, interval) and is_equal_approx(e.health.max_health, hp)):
				stats_ok = false
			var tex: Texture2D = null
			if e.sprite != null and e.sprite.sprite_frames != null and e.sprite.sprite_frames.has_animation("idle"):
				tex = e.sprite.sprite_frames.get_frame_texture("idle", 0)
			if tex == null or tex.get_width() < 64:
				sprite_ok = false
			else:
				width = tex.get_width()
	_check(count > 0, "%s present (found %d)" % [label, count])
	_check(stats_ok, "%s stats %.0f HP / %.0f dmg / %.2fs" % [label, hp, dmg, interval])
	_check(sprite_ok, "%s non-placeholder %s sprite (width %d)" % [label, prefix, width])


func _arm_player() -> void:
	var pl: Node3D = _player()
	if pl == null:
		return
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	hc.invulnerable = true
	hc.set_health(100.0, 100.0)


# ------------------------------------------------------------------ 17. floor 2

func _t17_floor2_circuit() -> void:
	_begin("17 Floor 2 circuit-locked executive door + exit to Floor 3")
	var ok: bool = await _goto(FLOOR_2)
	_check(ok, "floor_02 loaded")
	if ok:
		_arm_player()
		await _check_door_puzzle("Interactables/ExecutiveSecurityDoor", CIRCUIT_PUZZLE)
		_check_exit(3)
	_end()


# ------------------------------------------------------------------ 18. floor 3

func _t18_floor3_lab() -> void:
	_begin("18 Floor 3 lab: Lv3 heavies + Lv1 techs, bio-match door, exit to Floor 4")
	var ok: bool = await _goto(FLOOR_3)
	_check(ok, "floor_03 loaded")
	if ok:
		_arm_player()
		_check_enemy_kind("heavy_lv3", 155.0, 16.0, 1.4, "Lv3 Heavy Guard")
		_check_enemy_kind("tech_lv1", 48.0, 7.0, 0.9, "Lv1 Armed Technician")
		await _check_door_puzzle("Interactables/LabSecurityDoor", BIO_PUZZLE)
		_check_exit(4)
	_end()


# ------------------------------------------------------------------ 19. floor 4

func _t19_floor4_vip() -> void:
	_begin("19 Floor 4 VIP: Lv4 commandos + Lv2 mercs, sequence door, exit to Floor 5")
	var ok: bool = await _goto(FLOOR_4)
	_check(ok, "floor_04 loaded")
	if ok:
		_arm_player()
		_check_enemy_kind("commando_lv4", 220.0, 19.0, 1.55, "Lv4 Elite Commando")
		_check_enemy_kind("merc_lv2", 85.0, 9.0, 1.15, "Lv2 Mercenary")
		await _check_door_puzzle("Interactables/VaultSecurityDoor", SEQUENCE_PUZZLE)
		_check_exit(5)
	_end()


# ------------------------------------------------------------------ 20. floor 5 boss

func _t20_floor5_boss() -> void:
	_begin("20 Floor 5: Volkov 800 HP 3-phase boss, Lv5 absorption 60/100 -> 110/120, reactor console, rain <= 160")
	var ok: bool = await _goto(FLOOR_5)
	_check(ok, "floor_05 loaded")
	if not ok:
		_end()
		return
	_arm_player()
	var enemies_root: Node = current_scene.get_node_or_null("Enemies")
	var boss: EnemyBase = current_scene.get_node_or_null("Enemies/VolkovBoss") as EnemyBase
	var console: Node = current_scene.get_node_or_null("Interactables/ReactorConsole")
	_check(boss != null, "Enemies/VolkovBoss spawned")
	_check(console != null, "Interactables/ReactorConsole spawned")
	var rain: CPUParticles3D = current_scene.get_node_or_null("Rain") as CPUParticles3D
	_check(rain != null, "rain particles spawned")
	_check(rain != null and rain.amount <= 160, "rain amount <= 160 (got %d)" % (rain.amount if rain != null else -1))
	if boss == null or console == null or enemies_root == null:
		_end()
		return
	var script_path: String = (boss.get_script() as Script).resource_path
	_check(script_path == VOLKOV_SCRIPT, "boss uses volkov_boss.gd (got %s)" % script_path)
	_check(boss.is_boss, "is_boss flag")
	_check(is_equal_approx(boss.health.max_health, 800.0), "Volkov max_health 800 (got %.0f)" % boss.health.max_health)
	var tex: Texture2D = null
	if boss.sprite != null and boss.sprite.sprite_frames != null and boss.sprite.sprite_frames.has_animation("idle"):
		tex = boss.sprite.sprite_frames.get_frame_texture("idle", 0)
	_check(tex != null and tex.get_width() == 96 and tex.get_height() == 128,
		"volkov_boss 96x128 sprite (got %s)" % (str(tex.get_size()) if tex != null else "null"))
	_check(not bool(console.get("is_active")), "ReactorConsole starts locked")
	_check(int(boss.get("phase")) == 1, "boss starts in phase 1")
	var base_speed: float = boss.stats.move_speed
	var probe: Node = (load("res://scenes/enemies/boss_volkov.tscn") as PackedScene).instantiate()
	var shared: EnemyStats = probe.get("stats") as EnemyStats
	probe.free()

	_signal_hits["phase"] = 0
	_signal_hits["boss_dead"] = 0
	boss.connect("phase_changed", func(_p: int) -> void: _mark("phase"))
	boss.connect("boss_defeated", func() -> void: _mark("boss_dead"))
	var maxhp: float = boss.health.max_health
	var count0: int = enemies_root.get_child_count()

	boss.take_damage(maxhp * 0.36)
	await _physics(2)
	var count2: int = enemies_root.get_child_count()
	_check(int(boss.get("phase")) == 2, "64%% HP -> phase 2 (got %d)" % int(boss.get("phase")))
	_check(count2 == count0 + 2, "phase 2 reinforcements +2 (enemies %d -> %d)" % [count0, count2])
	_check(not is_equal_approx(boss.stats.move_speed, base_speed), "phase 2 boosts move_speed")

	boss.take_damage(maxhp * 0.35)
	await _physics(2)
	var count3: int = enemies_root.get_child_count()
	_check(int(boss.get("phase")) == 3, "29%% HP -> phase 3 (got %d)" % int(boss.get("phase")))
	_check(count3 == count2 + 2, "phase 3 reinforcements +2 (enemies %d -> %d)" % [count2, count3])
	_check(_hits("phase") == 2, "phase_changed emitted twice (got %d)" % _hits("phase"))

	boss.take_damage(maxhp * 0.36)
	await _physics(2)
	_check(enemies_root.get_child_count() == count3, "no extra waves after phase 3")
	_check(boss.is_dead, "boss is dead")
	_check(_hits("boss_dead") == 1, "boss_defeated emitted once")
	_check(bool(console.get("is_active")), "ReactorConsole activated")
	_check(boss.can_be_harvested(), "Lv5 corpse harvestable")
	var rw5: Dictionary = BetaDeviceController.calculate_absorption_rewards(100.0, boss.stats.level)
	_check(boss.stats.level == 5 and is_equal_approx(float(rw5.get("max_hp_bonus", 0.0)), 20.0)
		and is_equal_approx(float(rw5.get("heal_amount", 0.0)), 50.0) and int(rw5.get("essence", 0)) == 100,
		"Lv5 rewards +20 max / +50 heal / 100 essence")
	if shared != null:
		_check(not is_equal_approx(boss.stats.move_speed, shared.move_speed), "phase tweaks did not mutate shared stats")

	# Real 1 s BETA channel on the boss corpse.
	var pl: Node3D = _player()
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	var beta: BetaDeviceController = _ap(pl, "beta_device") as BetaDeviceController
	hc.set_health(60.0, 100.0)
	beta.overdrive_time = 0.0
	var ess0: int = beta.bio_essence
	_place_player(pl, boss.global_position + Vector3(0.0, 0.05, 1.6), 0.0)
	await _physics(2)
	_check(beta.find_nearest_corpse() == boss, "BETA finds Volkov corpse")
	_check(beta.try_start_beta(), "BETA channel started on Volkov")
	await _seconds(1.25)
	_check(is_equal_approx(hc.current_health, 110.0) and is_equal_approx(hc.max_health, 120.0),
		"Volkov absorption 60/100 -> 110/120 (got %.1f/%.1f)" % [hc.current_health, hc.max_health])
	_check(beta.bio_essence == ess0 + 100, "Volkov essence +100 (%d -> %d)" % [ess0, beta.bio_essence])
	_check(boss.is_harvested and not boss.can_be_harvested(), "Volkov corpse drained")
	hc.invulnerable = false
	_end()


# ------------------------------------------------------------------ 21. ending

func _t21_ending() -> void:
	_begin("21 Ending cutscene: epilogue, skip hold (2.5 s -> 0.5, reset, 5 s -> summary)")
	var ok: bool = await _goto(ENDING)
	_check(ok, "ending_cutscene loaded")
	if not ok:
		_end()
		return
	var cs: Node = current_scene
	await _frames(2)
	var dialogue: Label = cs.get_node_or_null("%Dialogue") as Label
	var bg: TextureRect = cs.get_node_or_null("%Background") as TextureRect
	var summary: Control = cs.get_node_or_null("%Summary") as Control
	_check(int(cs.get("shot_index")) == 0, "epilogue starts at shot 0")
	_check(dialogue != null and dialogue.text.length() > 0, "epilogue dialogue shown")
	_check(bg != null and bg.texture != null, "epilogue background loaded")
	_check(summary != null and not summary.visible, "summary hidden at start")
	cs.call("simulate_space_hold", 2.5, true)
	var p: float = float(cs.call("get_skip_progress"))
	_check(absf(p - 0.5) < 0.01, "2.5 s hold -> %.3f progress" % p)
	cs.call("simulate_space_hold", 0.1, false)
	_check(is_zero_approx(float(cs.call("get_skip_progress"))), "release resets progress")
	_signal_hits["ending"] = 0
	cs.connect("cutscene_finished", func() -> void: _mark("ending"))
	cs.call("simulate_space_hold", 5.0, true)
	await _frames(3)
	_check(_hits("ending") == 1, "cutscene_finished emitted once (got %d)" % _hits("ending"))
	_check(summary != null and summary.visible, "%Summary visible")
	_check(current_scene == cs, "ending stays on summary (no auto scene change)")
	_end()


# ------------------------------------------------------------------ 22. integrity

func _t22_integrity() -> void:
	_begin("22 Full project integrity (every tscn/tres/gdshader/png/wav/gd loads; scenes instantiate)")
	var files: Array[String] = []
	for r in INTEGRITY_ROOTS:
		_collect_ext(r, files, INTEGRITY_EXTENSIONS)
	if FileAccess.file_exists("res://default_bus_layout.tres"):
		files.append("res://default_bus_layout.tres")
	var failed: PackedStringArray = []
	var bad_scenes: PackedStringArray = []
	var counts: Dictionary = {}
	for f in files:
		var ext: String = f.get_extension()
		counts[ext] = int(counts.get(ext, 0)) + 1
		var res: Resource = ResourceLoader.load(f)
		if res == null:
			failed.append(f)
			continue
		if res is PackedScene:
			var ps: PackedScene = res as PackedScene
			if not ps.can_instantiate():
				bad_scenes.append(f)
				continue
			var inst: Node = ps.instantiate()
			if inst == null:
				bad_scenes.append(f)
			else:
				inst.free()
		elif res is GDScript:
			if not (res as GDScript).can_instantiate():
				failed.append(f + " (script)")
	print("       integrity: ", counts, " total=", files.size())
	_check(int(counts.get("png", 0)) >= MIN_PNG, "png >= %d (got %d)" % [MIN_PNG, int(counts.get("png", 0))])
	_check(int(counts.get("wav", 0)) >= MIN_WAV, "wav >= %d (got %d)" % [MIN_WAV, int(counts.get("wav", 0))])
	_check(int(counts.get("tscn", 0)) > 0 and int(counts.get("tres", 0)) > 0 and int(counts.get("gdshader", 0)) > 0,
		"tscn/tres/gdshader present")
	_check(failed.is_empty(), "failed to load: %s" % ", ".join(failed))
	_check(bad_scenes.is_empty(), "failed to instantiate: %s" % ", ".join(bad_scenes))
	for i in range(1, 6):
		var path: String = str((_gm().get("floor_scenes") as Dictionary).get(i, ""))
		_check(ResourceLoader.exists(path), "floor %d scene registered" % i)
	_end()


func _collect_ext(dir_path: String, out: Array[String], exts: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				_collect_ext(full, out, exts)
			elif entry.get_extension() in exts:
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


# ------------------------------------------------------------------ 23. BETA evolution

func _t23_beta_evolution() -> void:
	_begin("23 BETA evolution: tiers 0/45/120/230/370, T5 multipliers, fast channel, overdrive, T5 leech, carryover")
	var ok: bool = await _goto(FLOOR_1)
	_check(ok, "floor_01 loaded")
	var pl: Node3D = _player()
	if not ok or pl == null:
		_end()
		return
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	var beta: BetaDeviceController = _ap(pl, "beta_device") as BetaDeviceController
	var wm: WeaponManager = _ap(pl, "weapon_manager") as WeaponManager
	hc.invulnerable = true
	_reset_beta(beta)

	_check(str(BetaDeviceController.TIER_THRESHOLDS) == "[0, 45, 120, 230, 370]",
		"TIER_THRESHOLDS [0,45,120,230,370] (got %s)" % str(BetaDeviceController.TIER_THRESHOLDS))
	var cases: Array[Vector2i] = [Vector2i(0, 1), Vector2i(44, 1), Vector2i(45, 2), Vector2i(119, 2), Vector2i(120, 3),
		Vector2i(229, 3), Vector2i(230, 4), Vector2i(369, 4), Vector2i(370, 5), Vector2i(5000, 5)]
	var tier_ok: bool = true
	for c in cases:
		if BetaDeviceController.tier_for_essence(c.x) != c.y:
			tier_ok = false
			_check(false, "tier_for_essence(%d) == %d (got %d)" % [c.x, c.y, BetaDeviceController.tier_for_essence(c.x)])
	_check(tier_ok, "tier_for_essence thresholds")

	beta.beta_tier = 1
	var d1: float = beta.get_damage_multiplier()
	var r1: float = beta.get_reload_speed_multiplier()
	var m1: float = beta.get_move_speed_multiplier()
	beta.beta_tier = 5
	var d5: float = beta.get_damage_multiplier()
	var r5: float = beta.get_reload_speed_multiplier()
	var m5: float = beta.get_move_speed_multiplier()
	_check(is_equal_approx(d5 / d1, 1.45), "T5/T1 damage x1.45 (got %.3f)" % (d5 / d1))
	_check(is_equal_approx(r5 / r1, 1.35), "T5/T1 reload x1.35 (got %.3f)" % (r5 / r1))
	_check(is_equal_approx(m5 / m1, 1.15), "T5/T1 move x1.15 (got %.3f)" % (m5 / m1))

	beta.beta_tier = 3
	var ch3: float = beta.get_channel_duration()
	beta.beta_tier = 4
	var ch4: float = beta.get_channel_duration()
	beta.beta_tier = 5
	var ch5: float = beta.get_channel_duration()
	_check(is_equal_approx(ch3, 0.85) and is_equal_approx(ch4, 0.60) and is_equal_approx(ch5, 0.60),
		"channel 0.85 s below T4, 0.60 s at T4+ (got %.2f/%.2f/%.2f)" % [ch3, ch4, ch5])

	beta.overdrive_time = BetaDeviceController.OVERDRIVE_DURATION
	_check(is_equal_approx(BetaDeviceController.OVERDRIVE_DURATION, 5.0), "OVERDRIVE_DURATION 5.0 s")
	_check(beta.is_overdrive_active(), "overdrive active at 5.0 s")
	_check(is_equal_approx(beta.get_move_speed_multiplier(), m5 * 1.12), "overdrive boosts move speed x1.12")
	beta.process_overdrive(2.0)
	_check(absf(beta.overdrive_time - 3.0) < 0.05, "overdrive decays 5.0 -> 3.0 (got %.2f)" % beta.overdrive_time)
	beta.process_overdrive(10.0)
	_check(is_zero_approx(beta.overdrive_time) and not beta.is_overdrive_active(), "overdrive expires")

	# Tier 5 melee kill leeches +6 HP.
	await _clear_enemies()
	beta.bio_essence = 370
	beta.beta_tier = 5
	hc.set_health(100.0, 200.0)
	_place_player(pl, Vector3(0.0, 0.05, -14.0), 0.0)
	var target: EnemyBase = _spawn(GUARD, Vector3(0.0, 0.0, -15.6), 0.0)
	await _physics(4)
	_aim_at(pl, target.global_position + Vector3(0.0, 1.0, 0.0))
	await _seconds(0.8)
	target.health.current_health = 1.0
	hc.set_health(100.0, 200.0)
	_check(wm.quick_melee(), "T5 quick melee swung")
	await _physics(2)
	_check(target.is_dead, "melee killed the target")
	_check(is_equal_approx(hc.current_health, 106.0), "T5 melee kill leeched +6 HP (got %.1f)" % hc.current_health)
	await _clear_enemies()

	# load_floor carries max_health, bio_essence and beta_tier.
	hc.set_health(150.0, 180.0)
	beta.bio_essence = 380
	beta.beta_tier = 5
	beta.overdrive_time = 0.0
	_gm().call("load_floor", 2, false)
	var moved: bool = await _wait_scene(FLOOR_2)
	_check(moved, "load_floor(2) reached floor_02")
	var np: Node3D = _player()
	_check(np != null and np != pl, "new player spawned")
	if np != null:
		var nhc: HealthComponent = _ap(np, "health_component") as HealthComponent
		var nbeta: BetaDeviceController = _ap(np, "beta_device") as BetaDeviceController
		_check(is_equal_approx(nhc.max_health, 180.0) and is_equal_approx(nhc.current_health, 150.0),
			"max_health/health carried (got %.1f/%.1f)" % [nhc.current_health, nhc.max_health])
		_check(nbeta.bio_essence == 380 and nbeta.beta_tier == 5,
			"bio_essence/beta_tier carried (got %d / T%d)" % [nbeta.bio_essence, nbeta.beta_tier])
		nhc.invulnerable = true
	_gm().set("player_carryover", {})
	_end()


# ------------------------------------------------------------------ 24. difficulty

func _t24_difficulty() -> void:
	_begin("24 Bordo Bereli difficulty: new enemy HP x1.25 / dmg x1.30 / speed x1.12, shared .tres untouched")
	var shared: EnemyStats = load(GUARD_STATS) as EnemyStats
	_check(shared != null, "guard stats .tres loads")
	if shared == null or current_scene == null:
		_end()
		return
	var base_hp: float = shared.max_health
	var base_dmg: float = shared.damage
	var base_speed: float = shared.move_speed
	_settings().call("set_difficulty", 1)
	_check(int(_settings().get("difficulty")) == 1, "difficulty set to 1")
	var hard: EnemyBase = _spawn(GUARD, Vector3(0.0, 0.0, 30.0), 0.0)
	await _physics(2)
	_check(is_equal_approx(hard.stats.max_health, base_hp * 1.25) and is_equal_approx(hard.health.max_health, base_hp * 1.25),
		"HP x1.25 (%.1f -> %.1f)" % [base_hp, hard.health.max_health])
	_check(is_equal_approx(hard.stats.damage, base_dmg * 1.30), "damage x1.30 (%.2f -> %.2f)" % [base_dmg, hard.stats.damage])
	_check(is_equal_approx(hard.stats.move_speed, base_speed * 1.12), "speed x1.12 (%.2f -> %.2f)" % [base_speed, hard.stats.move_speed])
	_check(hard.stats != shared, "enemy uses a per-instance stats copy")
	_check(is_equal_approx(shared.max_health, base_hp) and is_equal_approx(shared.damage, base_dmg) and is_equal_approx(shared.move_speed, base_speed),
		"shared .tres unchanged (%.0f/%.1f/%.2f)" % [shared.max_health, shared.damage, shared.move_speed])
	hard.free()
	await _physics(1)
	_settings().call("set_difficulty", 0)
	var normal: EnemyBase = _spawn(GUARD, Vector3(0.0, 0.0, 30.0), 0.0)
	await _physics(2)
	_check(int(_settings().get("difficulty")) == 0 and is_equal_approx(normal.health.max_health, base_hp),
		"difficulty restored to Normal (HP %.1f)" % normal.health.max_health)
	normal.free()
	await _physics(2)
	_end()


# ------------------------------------------------------------------ 25. sprite dimensions

func _png_files(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f in DirAccess.get_files_at(dir_path):
		if f.get_extension().to_lower() == "png":
			out.append(dir_path.path_join(f))
	return out


func _t25_sprite_dimensions() -> void:
	_begin("25 Sprites: 17 weapons 320x200, HUD weapon not flipped, 3-frame deaths, BG 480x270, portraits 160x160")
	var weapons: PackedStringArray = _png_files(WEAPON_DIR)
	_check(weapons.size() == 17, "17 weapon PNGs (got %d)" % weapons.size())
	for f in weapons:
		var t: Texture2D = load(f) as Texture2D
		_check(t != null and t.get_width() == 320 and t.get_height() == 200,
			"%s is 320x200 (got %s)" % [f.get_file(), str(t.get_size()) if t != null else "null"])
	var hud: Control = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as Control
	var ws: TextureRect = hud.get_node_or_null("%WeaponSprite") as TextureRect
	_check(ws != null and not ws.flip_h, "HUD %WeaponSprite.flip_h == false")
	hud.free()
	for prefix in ENEMY_PREFIXES:
		var sf: SpriteFrames = EnemyBase.get_sprite_frames(prefix)
		var n: int = sf.get_frame_count("death") if sf != null and sf.has_animation("death") else 0
		_check(n == 3, "%s death animation 3 frames (got %d)" % [prefix, n])
	var bgs: PackedStringArray = PackedStringArray()
	for f in _png_files(CUTSCENE_BG_DIR):
		if f.get_file().begins_with("bg_"):
			bgs.append(f)
	_check(bgs.size() >= 4, "cutscene backgrounds present (got %d)" % bgs.size())
	for f in bgs:
		var t: Texture2D = load(f) as Texture2D
		_check(t != null and t.get_width() == 480 and t.get_height() == 270,
			"%s is 480x270 (got %s)" % [f.get_file(), str(t.get_size()) if t != null else "null"])
	var portraits: int = 0
	for f in _png_files(PORTRAIT_DIR):
		var t: Texture2D = load(f) as Texture2D
		if f.get_file() == "beta_device_closeup.png":
			# Full-frame cutscene insert, not a radio portrait.
			_check(t != null and t.get_width() == 480 and t.get_height() == 270, "beta_device_closeup is 480x270")
			continue
		portraits += 1
		_check(t != null and t.get_width() == 160 and t.get_height() == 160,
			"%s is 160x160 (got %s)" % [f.get_file(), str(t.get_size()) if t != null else "null"])
	_check(portraits >= 4, "radio portraits present (got %d)" % portraits)
	_end()


# ------------------------------------------------------------------ 26. zero-overlap UI audit

func _overlap_allowed(c: Control) -> bool:
	var path: String = str(c.get_path())
	for a in OVERLAP_ALLOW:
		if path.ends_with(a):
			return true
	return false


## Sibling Controls must not partially overlap (containment = layering, which is fine).
func _audit_overlaps(node: Node, label: String, issues: PackedStringArray) -> void:
	var kids: Array[Control] = []
	for c in node.get_children():
		var ctl: Control = c as Control
		if ctl != null and ctl.is_visible_in_tree() and not _overlap_allowed(ctl):
			kids.append(ctl)
	for i in kids.size():
		var a: Rect2 = kids[i].get_global_rect()
		if a.size.x < 1.0 or a.size.y < 1.0:
			continue
		for j in range(i + 1, kids.size()):
			var b: Rect2 = kids[j].get_global_rect()
			if b.size.x < 1.0 or b.size.y < 1.0:
				continue
			var inter: Rect2 = a.intersection(b)
			if inter.size.x <= 1.0 or inter.size.y <= 1.0:
				continue
			if a.grow(1.0).encloses(b) or b.grow(1.0).encloses(a):
				continue
			issues.append("%s: %s x %s" % [label, kids[i].name, kids[j].name])
	for c in node.get_children():
		var ci: CanvasItem = c as CanvasItem
		if ci == null or ci.visible:
			_audit_overlaps(c, label, issues)


func _rects_clear(scene: Node, names: Array[String], label: String) -> void:
	var rects: Array[Rect2] = []
	for n in names:
		var c: Control = scene.get_node_or_null("%" + n) as Control
		_check(c != null, "%s %%%s present" % [label, n])
		rects.append(c.get_global_rect() if c != null else Rect2())
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].has_area() and rects[j].has_area():
				_check(not rects[i].intersects(rects[j]), "%s %%%s vs %%%s do not intersect (%s / %s)" % [label, names[i], names[j], str(rects[i]), str(rects[j])])


func _mount_ui(vp: SubViewport, path: String) -> Node:
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var inst: Node = ps.instantiate()
	vp.add_child(inst)
	var ctl: Control = inst as Control
	if ctl != null:
		ctl.show()
	await _frames(3)
	return inst


func _t26_ui_overlap() -> void:
	_begin("26 Zero-overlap UI audit at 1280x720 (menus, settings tabs, HUD, cutscenes, 4 puzzles)")
	var vp: SubViewport = SubViewport.new()
	vp.name = "OverlapAudit"
	vp.size = Vector2i(1280, 720)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var issues: PackedStringArray = PackedStringArray()
	var simple: Array[String] = [
		"res://scenes/ui/pause_menu.tscn", "res://scenes/ui/credits_panel.tscn", "res://scenes/ui/death_screen.tscn",
		"res://scenes/ui/hud.tscn", CUTSCENE, ENDING, PUZZLE, CIRCUIT_PUZZLE, BIO_PUZZLE, SEQUENCE_PUZZLE,
	]
	var audited: int = 0

	# Main menu, then the settings panel opened from it (card must hide).
	var menu: Node = await _mount_ui(vp, MAIN_MENU)
	if menu != null:
		_audit_overlaps(menu, "MainMenu", issues)
		audited += 1
		var card: Control = menu.get_node_or_null("%MenuCard") as Control
		var btn: Button = menu.get_node_or_null("%Settings") as Button
		if btn != null:
			btn.pressed.emit()
		await _frames(2)
		_check(card != null and not card.visible, "MainMenu %MenuCard hidden while SettingsPanel open")
		_audit_overlaps(menu, "MainMenu+Settings", issues)
		menu.free()
	await _frames(1)

	var panel: Node = await _mount_ui(vp, "res://scenes/ui/settings_panel.tscn")
	if panel != null:
		var tabs: TabContainer = panel.get_node_or_null("%Tabs") as TabContainer
		var tab_n: int = tabs.get_tab_count() if tabs != null else 0
		for t in tab_n:
			tabs.current_tab = t
			await _frames(2)
			_audit_overlaps(panel, "SettingsPanel[tab %d]" % t, issues)
			audited += 1
		_check(tab_n == 4, "SettingsPanel audited on 4 tabs (got %d)" % tab_n)
		panel.free()
	await _frames(1)

	for path in simple:
		var inst: Node = await _mount_ui(vp, path)
		_check(inst != null, "%s mounts" % path.get_file())
		if inst == null:
			continue
		_audit_overlaps(inst, path.get_file().get_basename(), issues)
		audited += 1
		if path == SEQUENCE_PUZZLE:
			_rects_clear(inst, ["Pattern", "Replay"] as Array[String], "sequence_puzzle")
		elif path == CUTSCENE or path == ENDING:
			_rects_clear(inst, ["Portrait", "Radio", "Advance", "Skip"] as Array[String], path.get_file().get_basename())
		inst.free()
		await _frames(1)
	print("       overlap audit: %d layouts, %d issues" % [audited, issues.size()])
	_check(audited == 15, "15 layouts audited (got %d)" % audited)
	_check(issues.is_empty(), "overlaps: %s" % "; ".join(issues))
	vp.free()
	await _frames(2)
	_end()


# ------------------------------------------------------------------ 27. render performance

func _t27_render_performance() -> void:
	_begin("27 Render/perf: CRT nearest filter, quality 0/1/2 glow off/off/on, OmniLight3D distance fade on Floors 1-5")
	var shader_text: String = FileAccess.get_file_as_string(CRT_SHADER)
	_check(shader_text.length() > 0, "crt_vhs.gdshader readable")
	_check(not shader_text.contains("filter_linear_mipmap"), "CRT shader has no filter_linear_mipmap")
	_check(shader_text.contains("filter_nearest"), "CRT shader uses filter_nearest")
	var quality_before: int = int(_settings().get("graphics_quality"))
	var ok: bool = await _goto(FLOOR_1)
	_check(ok, "floor_01 loaded")
	if ok:
		var envs: Array[Node] = current_scene.find_children("*", "WorldEnvironment", true, false)
		_check(envs.size() > 0, "WorldEnvironment present")
		if envs.size() > 0:
			var env: Environment = (envs[0] as WorldEnvironment).environment
			var got: Array[bool] = []
			for q in [0, 1, 2]:
				_settings().call("set_graphics_quality", q)
				await _frames(1)
				got.append(env.glow_enabled)
			_check(str(got) == "[false, false, true]", "glow per quality 0/1/2 = false/false/true (got %s)" % str(got))
		_settings().call("set_graphics_quality", quality_before)
	for i in FLOORS.size():
		var floor_ok: bool = await _goto(FLOORS[i])
		_check(floor_ok, "floor %d loaded" % (i + 1))
		if not floor_ok:
			continue
		_arm_player()
		var lights: Array[Node] = current_scene.find_children("*", "OmniLight3D", true, false)
		var unfaded: int = 0
		for n in lights:
			if not (n as OmniLight3D).distance_fade_enabled:
				unfaded += 1
		print("       floor %d: %d OmniLight3D, %d without distance fade" % [i + 1, lights.size(), unfaded])
		_check(lights.size() > 0, "floor %d has OmniLight3D nodes" % (i + 1))
		_check(unfaded == 0, "floor %d: every OmniLight3D distance_fade_enabled (%d missing)" % [i + 1, unfaded])
	_end()


# ------------------------------------------------------------------ 28. hint banner + radio

func _t28_hint_and_radio() -> void:
	_begin("28 Floor 1 hint banner above y=220; radio comms box (speaker, portrait, < 320 px, no HUD overlap)")
	var ok: bool = await _goto(FLOOR_1)
	_check(ok, "floor_01 loaded")
	var pl: Node3D = _player()
	if not ok or pl == null:
		_end()
		return
	_arm_player()
	await _frames(3)
	var banner: Control = current_scene.get_node_or_null("ControlsHint/HintBanner") as Control
	_check(banner != null, "ControlsHint/HintBanner present")
	if banner != null:
		var bottom: float = banner.position.y + banner.size.y
		_check(bottom < 220.0, "HintBanner bottom %.1f < 220" % bottom)
	var hud: Control = _ap(pl, "hud") as Control
	_check(hud != null, "HUD attached")
	if hud == null:
		_end()
		return
	_gm().call("send_radio", "GENERAL DEMİR", "general_portrait", "Test telsiz mesajı — BETA hazır.", 3.0)
	await _frames(4)
	var box: Control = hud.get_node_or_null("%RadioBox") as Control
	var speaker: Label = hud.get_node_or_null("%RadioSpeaker") as Label
	var portrait: TextureRect = hud.get_node_or_null("%RadioPortrait") as TextureRect
	var mission: Control = hud.get_node_or_null("%MissionPlate") as Control
	var ammo: Control = hud.get_node_or_null("Margins/Bands/Bottom/AmmoPlate") as Control
	_check(box != null and box.visible, "%RadioBox visible")
	_check(speaker != null and speaker.text == "GENERAL DEMİR", "%%RadioSpeaker 'GENERAL DEMİR' (got '%s')" % (speaker.text if speaker != null else "null"))
	_check(portrait != null and portrait.texture != null, "%RadioPortrait texture loaded")
	if box != null:
		var r: Rect2 = box.get_global_rect()
		_check(box.size.y < 320.0, "%%RadioBox height %.1f < 320" % box.size.y)
		if mission != null:
			_check(not r.intersects(mission.get_global_rect()), "RadioBox vs MissionPlate clear (%s / %s)" % [str(r), str(mission.get_global_rect())])
		_check(ammo != null, "bottom-right AmmoPlate present")
		if ammo != null:
			_check(not r.intersects(ammo.get_global_rect()), "RadioBox vs AmmoPlate clear (%s / %s)" % [str(r), str(ammo.get_global_rect())])
	_end()
