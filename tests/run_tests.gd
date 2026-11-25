extends SceneTree
## BETA PROTOCOL — headless acceptance tests (22 criteria).
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
const MIN_PNG: int = 123
const MIN_WAV: int = 31
const TEST_COUNT: int = 22
const CUTSCENE: String = "res://scenes/cutscenes/opening_cutscene.tscn"
const PUZZLE: String = "res://scenes/puzzles/moving_lock_puzzle.tscn"
const GUARD: String = "res://scenes/enemies/enemy_guard_lv1.tscn"
const MERC: String = "res://scenes/enemies/enemy_merc_lv2.tscn"
const SETTINGS_SCRIPT: String = "res://scripts/managers/settings_manager.gd"
const LOAD_EXTENSIONS: Array[String] = ["tscn", "tres", "gdshader", "png", "wav"]
const SCAN_ROOTS: Array[String] = ["res://assets", "res://scenes", "res://scripts", "res://shaders"]

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
	for key in ["mouse_sensitivity", "horizontal_fov", "master_volume", "music_volume", "sfx_volume", "fullscreen", "camera_shake_enabled", "crt_enabled"]:
		_settings_backup[key] = s.get(key)


func _restore_settings() -> void:
	var s: Node = _settings()
	for key in _settings_backup.keys():
		s.set(key, _settings_backup[key])


# ------------------------------------------------------------------ run

func _run() -> void:
	_backup_settings()
	var save_existed: bool = bool(_sm().call("has_save"))
	var save_backup: Dictionary = {}
	if save_existed:
		save_backup = _sm().call("load_progress") as Dictionary
	_sm().call("clear_save")

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
	_begin("01 Main menu: 5 buttons + 8 settings controls")
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
			var controls: int = 0
			for c in panel.get_children():
				if c is HSlider or c is CheckButton:
					controls += 1
			_check(controls == 8, "8 settings controls (got %d)" % controls)
			var fov: HSlider = panel.get_node_or_null("%Fov") as HSlider
			_check(fov != null and is_equal_approx(fov.min_value, 75.0) and is_equal_approx(fov.max_value, 120.0), "FOV slider range 75..120")
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
	_begin("06 Enemy stats (40/5/0.9, 65/8/1.2) and death -> corpse")
	var guard: EnemyBase = _spawn(GUARD, Vector3(-6.0, 0.0, -30.0), 0.0)
	var merc: EnemyBase = _spawn(MERC, Vector3(6.0, 0.0, -30.0), 0.0)
	await _physics(2)
	var g: EnemyStats = guard.stats
	var m: EnemyStats = merc.stats
	_check(is_equal_approx(g.max_health, 40.0) and is_equal_approx(g.damage, 5.0) and is_equal_approx(g.attack_interval, 0.9), "Lv1 guard 40/5/0.9")
	_check(is_equal_approx(m.max_health, 65.0) and is_equal_approx(m.damage, 8.0) and is_equal_approx(m.attack_interval, 1.2), "Lv2 merc 65/8/1.2")
	_check(is_equal_approx(guard.health.current_health, 40.0) and is_equal_approx(merc.health.current_health, 65.0), "spawned at full HP")
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
	_begin("08 BETA heal table + real 1 s channel on Lv2 corpse")
	var table: Array[float] = []
	for lvl in range(1, 7):
		table.append(BetaDeviceController.calculate_heal_amount(100.0, lvl))
	var expected: Array[float] = [5.0, 10.0, 15.0, 20.0, 25.0, 25.0]
	var table_ok: bool = true
	for i in expected.size():
		if not is_equal_approx(table[i], expected[i]):
			table_ok = false
	_check(table_ok, "heal table 5,10,15,20,25,25 (got %s)" % str(table))
	await _clear_enemies()
	var refs: Array = _prep_beta(50.0)
	var hc: HealthComponent = refs[1] as HealthComponent
	var beta: BetaDeviceController = refs[2] as BetaDeviceController
	var corpse: EnemyBase = await _spawn_corpse(MERC, Vector3(0.0, 0.0, -15.6))
	_check(beta.find_nearest_corpse() == corpse, "corpse found in range")
	_check(beta.try_start_beta(), "BETA channel started")
	await _seconds(0.5)
	_check(beta.is_channeling and is_equal_approx(hc.current_health, 50.0), "still channeling at 0.5 s, no heal yet")
	await _seconds(0.75)
	_check(not beta.is_channeling, "channel completed")
	_check(is_equal_approx(hc.current_health, 60.0), "Lv2 corpse healed +10 (got %.1f)" % hc.current_health)
	_end()


func _t09_single_use() -> void:
	_begin("09 Corpse can only be used once")
	var refs: Array = _prep_beta(60.0)
	var hc: HealthComponent = refs[1] as HealthComponent
	var beta: BetaDeviceController = refs[2] as BetaDeviceController
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


func get_tree_nodes_enemies() -> Array[EnemyBase]:
	var out: Array[EnemyBase] = []
	for n in current_scene.get_children():
		if n is EnemyBase:
			out.append(n as EnemyBase)
	return out


func _t10_heal_cap() -> void:
	_begin("10 Heal caps at 100; full HP refuses without consuming")
	await _clear_enemies()
	var refs: Array = _prep_beta(95.0)
	var hc: HealthComponent = refs[1] as HealthComponent
	var beta: BetaDeviceController = refs[2] as BetaDeviceController
	var corpse: EnemyBase = await _spawn_corpse(MERC, Vector3(0.0, 0.0, -15.6))
	_check(beta.try_start_beta(), "channel started at 95 HP")
	await _seconds(1.25)
	_check(is_equal_approx(hc.current_health, 100.0), "capped at 100 (got %.1f)" % hc.current_health)
	_check(corpse.is_harvested, "first corpse consumed")
	corpse.free()
	await _physics(2)
	var fresh: EnemyBase = await _spawn_corpse(MERC, Vector3(0.0, 0.0, -15.6))
	_check(not beta.try_start_beta(), "try_start_beta false at 100 HP")
	_check(not beta.is_channeling and fresh.can_be_harvested() and not fresh.is_harvested, "corpse left intact")
	fresh.free()
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
	_check(stats_ok, "%s stats %.0f HP / %.0f dmg / %.1fs" % [label, hp, dmg, interval])
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
		_check_enemy_kind("heavy_lv3", 100.0, 12.0, 1.5, "Lv3 Heavy Guard")
		_check_enemy_kind("tech_lv1", 40.0, 5.0, 0.9, "Lv1 Armed Technician")
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
		_check_enemy_kind("commando_lv4", 140.0, 17.0, 1.9, "Lv4 Elite Commando")
		_check_enemy_kind("merc_lv2", 65.0, 8.0, 1.2, "Lv2 Mercenary")
		await _check_door_puzzle("Interactables/VaultSecurityDoor", SEQUENCE_PUZZLE)
		_check_exit(5)
	_end()


# ------------------------------------------------------------------ 20. floor 5 boss

func _t20_floor5_boss() -> void:
	_begin("20 Floor 5: Volkov 3-phase boss, reinforcements, Lv5 corpse heal, reactor console")
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
	_check(current_scene.get_node_or_null("Rain") is CPUParticles3D, "rain particles spawned")
	if boss == null or console == null or enemies_root == null:
		_end()
		return
	var script_path: String = (boss.get_script() as Script).resource_path
	_check(script_path == VOLKOV_SCRIPT, "boss uses volkov_boss.gd (got %s)" % script_path)
	_check(boss.is_boss, "is_boss flag")
	_check(boss.health.max_health >= 400.0, "max_health >= 400 (got %.0f)" % boss.health.max_health)
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
	_check(boss.stats.level == 5 and is_equal_approx(BetaDeviceController.calculate_heal_amount(100.0, boss.stats.level), 25.0),
		"Lv5 heal amount = 25")
	if shared != null:
		_check(not is_equal_approx(boss.stats.move_speed, shared.move_speed), "phase tweaks did not mutate shared stats")

	# Real 1 s BETA channel on the boss corpse.
	var pl: Node3D = _player()
	var hc: HealthComponent = _ap(pl, "health_component") as HealthComponent
	var beta: BetaDeviceController = _ap(pl, "beta_device") as BetaDeviceController
	hc.set_health(60.0, 100.0)
	_place_player(pl, boss.global_position + Vector3(0.0, 0.05, 1.6), 0.0)
	await _physics(2)
	_check(beta.find_nearest_corpse() == boss, "BETA finds Volkov corpse")
	_check(beta.try_start_beta(), "BETA channel started on Volkov")
	await _seconds(1.25)
	_check(is_equal_approx(hc.current_health, 85.0), "Volkov corpse healed +25 (got %.1f)" % hc.current_health)
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
