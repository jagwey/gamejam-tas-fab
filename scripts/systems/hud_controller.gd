extends Control

const SPRITE_DIR: String = "res://assets/sprites/weapons/"
const WEAPON_ORIGIN: Vector2 = Vector2(694, 360)
const HAND_ORIGIN: Vector2 = Vector2(267, 360)
const ADS_SCALE: float = 2.14
const SHOT_FRAMES: Dictionary = {
	"pistol": ["pistol_fire_1", "pistol_fire_2"],
	"shotgun": ["shotgun_fire_1", "shotgun_pump_1", "shotgun_pump_2"],
	"melee": ["melee_slash_1", "melee_slash_2"],
}
const SHOT_TIMES: Dictionary = {"pistol": 0.15, "shotgun": 0.46, "melee": 0.26}

var bound_player: Node
var weapons: Node
var connections: Array[Dictionary] = []
var sprites: Dictionary = {}
var active_weapon: String = "pistol"
var shot_weapon: String = ""
var shot_elapsed: float = 0.0
var reload_elapsed: float = 0.0
var reload_duration: float = 0.0
var recoil: float = 0.0
var bob_phase: float = 0.0
var hit_time: float = 0.0

func _ready() -> void:
	GameManager.floor_changed.connect(_on_floor)
	GameManager.objective_changed.connect(_on_objective)
	GameManager.boss_bar_updated.connect(_on_boss)
	_on_floor(GameManager.current_floor, GameManager.get_floor_title(GameManager.current_floor))
	_on_objective(GameManager.current_objective)
	%WeaponSprite.texture = _sprite("pistol_idle")
	%BetaHand.hide()
	if is_instance_valid(bound_player):
		bind_player(bound_player)

func bind_player(player: Node) -> void:
	for item in connections:
		var source: Node = item["source"] as Node
		if is_instance_valid(source) and source.is_connected(item["signal"], item["handler"]):
			source.disconnect(item["signal"], item["handler"])
	connections.clear()
	bound_player = player
	if not is_node_ready() or not is_instance_valid(player):
		return
	var health: Node = player.get_node_or_null("HealthComponent")
	weapons = player.get_node_or_null("WeaponManager")
	var beta: Node = player.get_node_or_null("BetaDeviceController")
	_listen(player, "interact_prompt_changed", _on_interact)
	_listen(health, "health_changed", _on_health)
	_listen(weapons, "weapon_changed", _on_weapon)
	_listen(weapons, "ammo_changed", _on_ammo)
	_listen(weapons, "weapon_fired", _on_fire)
	_listen(weapons, "reload_started", _on_reload)
	_listen(weapons, "reload_finished", _on_reload_finished)
	_listen(weapons, "hit_confirmed", _on_hit)
	_listen(beta, "prompt_changed", _on_beta_prompt)
	_listen(beta, "channel_progress", _on_beta_progress)
	if health:
		_on_health(float(health.get("current_health")), float(health.get("max_health")))
	if weapons:
		var stats: Resource = weapons.call("get_current_stats") as Resource
		if stats:
			_on_weapon(str(stats.get("weapon_id")), str(stats.get("display_name")))
			_on_ammo(int(weapons.call("get_mag", active_weapon)), int(weapons.call("get_reserve", active_weapon)), bool(stats.get("is_melee")))

func _listen(source: Node, event: StringName, handler: Callable) -> void:
	if source and source.has_signal(event):
		source.connect(event, handler)
		connections.append({"source": source, "signal": event, "handler": handler})

func _sprite(stem: String) -> Texture2D:
	if not sprites.has(stem):
		var path: String = SPRITE_DIR + stem + ".png"
		sprites[stem] = load(path) if ResourceLoader.exists(path) else null
	return sprites[stem] as Texture2D

func _on_floor(_floor_number: int, title: String) -> void:
	%Floor.text = title

func _on_objective(objective: String) -> void:
	%Objective.text = objective

func _on_boss(boss_name: String, hp: float, maximum: float, show_bar: bool) -> void:
	%Boss.visible = show_bar
	%BossTitle.text = boss_name
	%BossHP.max_value = maxf(1.0, maximum)
	%BossHP.value = hp

func _on_health(hp: float, maximum: float) -> void:
	%HP.text = "%d / %d HP" % [ceili(hp), ceili(maximum)]
	%HealthBar.max_value = maxf(1.0, maximum)
	%HealthBar.value = hp

func _on_weapon(id: String, display_name: String) -> void:
	active_weapon = id
	%Weapon.text = display_name
	shot_weapon = ""
	reload_duration = 0.0
	%Reload.hide()
	%WeaponSprite.texture = _sprite(active_weapon + "_idle")

func _on_ammo(mag: int, reserve: int, melee: bool) -> void:
	%Ammo.text = "YAKIN DÖVÜŞ" if melee else "%d / %d" % [mag, reserve]

func _on_fire(id: String) -> void:
	shot_weapon = id
	shot_elapsed = 0.0
	recoil = 18.0 if id == "shotgun" else 10.0

func _on_reload(_id: String, duration: float) -> void:
	reload_duration = maxf(0.001, duration)
	reload_elapsed = 0.0
	%Reload.show()

func _on_reload_finished(_id: String) -> void:
	reload_duration = 0.0
	%Reload.hide()

func _on_hit(killed: bool) -> void:
	hit_time = 0.17
	%Hit.modulate = Color("#ff415d") if killed else Color.WHITE
	%Hit.show()

func _on_interact(show_prompt: bool, prompt: String) -> void:
	%InteractPrompt.text = prompt if show_prompt else ""

func _on_beta_prompt(show_prompt: bool, prompt: String, can_use: bool) -> void:
	%BetaPrompt.text = prompt if show_prompt else ""
	%BetaPrompt.modulate = Color("#ff9fa5") if can_use else Color.WHITE

func _on_beta_progress(active: bool, ratio: float) -> void:
	%BetaBar.visible = active
	%BetaBar.value = clampf(ratio, 0.0, 1.0) * 100.0
	%BetaHand.visible = active
	if active:
		var index: int = clampi(1 + floori(ratio * 3.0), 1, 3)
		%BetaHand.texture = _sprite("beta_hand_%d" % index)

func _process(delta: float) -> void:
	if hit_time > 0.0:
		hit_time = maxf(0.0, hit_time - delta)
		%Hit.visible = hit_time > 0.0
	var aiming: bool = is_instance_valid(weapons) and bool(weapons.get("ads_active"))
	var stem: String = active_weapon + "_idle"
	if aiming and active_weapon == "pistol":
		stem = "pistol_ads"
	if reload_duration > 0.0:
		reload_elapsed += delta
		if reload_elapsed >= reload_duration or (is_instance_valid(weapons) and not bool(weapons.get("is_reloading"))):
			_on_reload_finished(active_weapon)
		elif active_weapon == "shotgun":
			stem = "shotgun_reload"
		else:
			stem = "pistol_reload_1" if reload_elapsed < reload_duration * 0.5 else "pistol_reload_2"
	if SHOT_FRAMES.has(shot_weapon):
		var duration: float = float(SHOT_TIMES[shot_weapon])
		var frames: Array = SHOT_FRAMES[shot_weapon] as Array
		var index: int = mini(floori(shot_elapsed * frames.size() / duration), frames.size() - 1)
		if not (aiming and shot_weapon == "pistol"):
			stem = str(frames[index])
		shot_elapsed += delta
		if shot_elapsed >= duration:
			shot_weapon = ""
	%WeaponSprite.texture = _sprite(stem)
	var speed: float = 0.0
	var body: CharacterBody3D = bound_player as CharacterBody3D
	if is_instance_valid(body) and body.is_on_floor():
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	bob_phase = fmod(bob_phase + speed * delta * 1.45, TAU)
	var strength: float = minf(speed / 8.5, 1.35) * (0.3 if aiming else 1.0)
	var bob: Vector2 = Vector2(sin(bob_phase) * 5.0, absf(cos(bob_phase)) * 5.0) * strength
	recoil = move_toward(recoil, 0.0, delta * 72.0)
	var sighted: bool = stem == "pistol_ads"
	%WeaponSprite.flip_h = not sighted
	%WeaponSprite.scale = Vector2.ONE * ADS_SCALE if sighted else Vector2.ONE
	# The front sight is pixel (121, 96) in the 240 x 180 ADS artwork.
	var origin: Vector2 = Vector2(640, 360) - Vector2(121, 96) * 2.0 * ADS_SCALE if sighted else WEAPON_ORIGIN
	%WeaponSprite.position = (origin + bob + Vector2(0.0, recoil)).round()
	%BetaHand.position = (HAND_ORIGIN + bob * 0.7).round()
