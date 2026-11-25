class_name BetaDeviceController
extends Node
## BETA device: channel on a fresh armed corpse to absorb it — permanent max-HP bonus, heal,
## Bio-Essence (5 evolution tiers) and a 5 s Overdrive. Never heals passively.
## Works at full health too (max-HP growth / overdrive); max HP is capped by
## HealthComponent.ABSOLUTE_MAX_HEALTH_CAP.

signal prompt_changed(visible_flag: bool, text: String, can_use: bool)
signal channel_progress(active: bool, ratio: float)
signal beta_completed(heal_amount: float)
signal beta_cancelled(reason: String)
signal evolution_changed(tier: int, essence: int, next_threshold: int)
signal overdrive_changed(active: bool, remaining: float, duration: float)
signal absorption_toast(max_hp_gained: float, healed: float, essence_gained: int, tier_up: bool)

## Legacy upper bound of a channel (actual duration: get_channel_duration(), always <= this).
const BETA_DURATION: float = 1.0
const CHANNEL_DURATION_BASE: float = 0.85
const CHANNEL_DURATION_FAST: float = 0.60
const INTERACT_RANGE: float = 2.8
const CANCEL_RANGE: float = 3.3
const TIER_THRESHOLDS: Array[int] = [0, 45, 120, 230, 370]
const MAX_TIER: int = 5
const OVERDRIVE_DURATION: float = 5.0
const PROMPT_SCAN_INTERVAL: float = 0.06
const DAMAGE_MULTS: Array[float] = [1.0, 1.10, 1.20, 1.32, 1.45]
const RELOAD_MULTS: Array[float] = [1.0, 1.12, 1.20, 1.28, 1.35]
const MOVE_MULTS: Array[float] = [1.0, 1.03, 1.07, 1.11, 1.15]

const TEXT_FULL: String = "SAĞLIK TAM DOLU — BETA GEREKMİYOR"
const TEXT_READY: String = "[F] BETA PROTOKOLÜ  +%d HP"
const TEXT_ABSORB: String = "[F] BETA EMİLİMİ  +%d MAKS HP · +%d ÖZ"
const TEXT_OVERLOAD: String = "[F] BETA AŞIRI YÜKLEME  +%d HP · OVERDRIVE"
const TEXT_CHANNEL: String = "BETA AKTARILIYOR..."

## Body whose position is used for range checks. Defaults to parent.
@export var player: Node3D
@export var health_component: HealthComponent
## When false, _process does nothing; tests call update_prompt()/process_channel() manually.
@export var auto_process: bool = true

var is_channeling: bool = false
var channel_time: float = 0.0
var target_corpse: EnemyBase = null
var bio_essence: int = 0
var beta_tier: int = 1
var overdrive_time: float = 0.0

var _prompt_visible: bool = false
var _prompt_text: String = ""
var _prompt_can_use: bool = false
var _prompt_scan_timer: float = 0.0


static func calculate_heal_amount(max_hp: float, enemy_level: int) -> float:
	return max_hp * 0.05 * float(mini(maxi(enemy_level, 0), 5))


## Rewards for absorbing a corpse of the given level (Lv5+ uses the Lv5 row).
static func calculate_absorption_rewards(base_max_hp: float, enemy_level: int) -> Dictionary:
	var lvl: int = clampi(enemy_level, 1, 5)
	match lvl:
		1:
			return {"max_hp_bonus": 4.0, "heal_amount": base_max_hp * 0.12 + 4.0, "essence": 15}
		2:
			return {"max_hp_bonus": 6.0, "heal_amount": base_max_hp * 0.15 + 6.0, "essence": 25}
		3:
			return {"max_hp_bonus": 9.0, "heal_amount": base_max_hp * 0.18 + 9.0, "essence": 40}
		4:
			return {"max_hp_bonus": 12.0, "heal_amount": base_max_hp * 0.22 + 12.0, "essence": 65}
		_:
			return {"max_hp_bonus": 20.0, "heal_amount": base_max_hp * 0.30 + 20.0, "essence": 100}


## Evolution tier (1..5) reached with the given Bio-Essence total.
static func tier_for_essence(essence: int) -> int:
	var tier: int = 1
	for i in range(TIER_THRESHOLDS.size()):
		if essence >= TIER_THRESHOLDS[i]:
			tier = i + 1
	return clampi(tier, 1, MAX_TIER)


func _ready() -> void:
	if player == null:
		player = get_parent() as Node3D
	if health_component == null and player != null:
		health_component = player.get_node_or_null("HealthComponent") as HealthComponent


func setup(p: Node3D, hc: HealthComponent) -> void:
	player = p
	health_component = hc


func _process(delta: float) -> void:
	if not auto_process:
		return
	process_overdrive(delta)
	process_channel(delta)
	# Corpse scan is throttled; manual update_prompt() calls stay immediate.
	_prompt_scan_timer -= delta
	if is_channeling or _prompt_scan_timer <= 0.0:
		_prompt_scan_timer = PROMPT_SCAN_INTERVAL
		update_prompt()


func process_overdrive(delta: float) -> void:
	if overdrive_time <= 0.0:
		return
	overdrive_time = maxf(overdrive_time - delta, 0.0)
	overdrive_changed.emit(overdrive_time > 0.0, overdrive_time, OVERDRIVE_DURATION)


# ---------------------------------------------------------------- evolution / multipliers

func get_channel_duration() -> float:
	return CHANNEL_DURATION_FAST if beta_tier >= 4 else CHANNEL_DURATION_BASE


func get_next_threshold() -> int:
	if beta_tier >= MAX_TIER:
		return TIER_THRESHOLDS[MAX_TIER - 1]
	return TIER_THRESHOLDS[beta_tier]


func is_overdrive_active() -> bool:
	return overdrive_time > 0.0


func _tier_index() -> int:
	return clampi(beta_tier, 1, MAX_TIER) - 1


func get_damage_multiplier() -> float:
	return DAMAGE_MULTS[_tier_index()]


func get_reload_speed_multiplier() -> float:
	return RELOAD_MULTS[_tier_index()]


func get_fire_rate_multiplier() -> float:
	return (1.20 if overdrive_time > 0.0 else 1.0) * (1.0 + 0.03 * float(clampi(beta_tier, 1, MAX_TIER) - 1))


func get_move_speed_multiplier() -> float:
	return MOVE_MULTS[_tier_index()] * (1.12 if overdrive_time > 0.0 else 1.0)


func export_state() -> Dictionary:
	return {"bio_essence": bio_essence, "beta_tier": beta_tier, "overdrive_time": overdrive_time}


func import_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	bio_essence = maxi(int(d.get("bio_essence", bio_essence)), 0)
	beta_tier = clampi(int(d.get("beta_tier", beta_tier)), 1, MAX_TIER)
	beta_tier = maxi(beta_tier, tier_for_essence(bio_essence))
	overdrive_time = clampf(float(d.get("overdrive_time", 0.0)), 0.0, OVERDRIVE_DURATION)
	evolution_changed.emit(beta_tier, bio_essence, get_next_threshold())
	overdrive_changed.emit(overdrive_time > 0.0, overdrive_time, OVERDRIVE_DURATION)


# ---------------------------------------------------------------- channel

## Nearest harvestable corpse within INTERACT_RANGE, or null.
func find_nearest_corpse() -> EnemyBase:
	if player == null or not is_inside_tree():
		return null
	var origin: Vector3 = player.global_position
	var best: EnemyBase = null
	var best_d: float = INTERACT_RANGE
	var seen: Dictionary = {}
	var candidates: Array[Node] = get_tree().get_nodes_in_group("corpses")
	candidates.append_array(get_tree().get_nodes_in_group("dead_enemies"))
	for n in candidates:
		var e: EnemyBase = _resolve_enemy(n)
		if e == null or seen.has(e.get_instance_id()):
			continue
		seen[e.get_instance_id()] = true
		if not e.can_be_harvested():
			continue
		var d: float = _flat_distance(origin, e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


## Starts absorbing the nearest fresh corpse. Allowed at full HP (max-HP growth + overdrive).
func try_start_beta() -> bool:
	if is_channeling or health_component == null or player == null:
		return false
	if health_component.is_dead:
		return false
	var corpse: EnemyBase = find_nearest_corpse()
	if corpse == null:
		return false
	target_corpse = corpse
	is_channeling = true
	channel_time = 0.0
	_sfx("sfx_beta_start")
	channel_progress.emit(true, 0.0)
	_set_prompt(true, TEXT_CHANNEL, false)
	return true


func cancel_beta(reason: String = "cancelled") -> void:
	if not is_channeling:
		return
	is_channeling = false
	channel_time = 0.0
	target_corpse = null
	channel_progress.emit(false, 0.0)
	beta_cancelled.emit(reason)
	_sfx("sfx_beta_cancel")


func process_channel(delta: float) -> void:
	if not is_channeling:
		return
	if health_component == null or health_component.is_dead:
		cancel_beta("player_dead")
		return
	if target_corpse == null or not is_instance_valid(target_corpse) or not target_corpse.can_be_harvested():
		cancel_beta("corpse_invalid")
		return
	if player == null or _flat_distance(player.global_position, target_corpse.global_position) > CANCEL_RANGE:
		cancel_beta("out_of_range")
		return
	channel_time += delta
	var dur: float = get_channel_duration()
	var ratio: float = clampf(channel_time / dur, 0.0, 1.0)
	channel_progress.emit(true, ratio)
	if channel_time >= dur:
		_complete()


func _complete() -> void:
	var corpse: EnemyBase = target_corpse
	var level: int = 0
	if corpse.stats != null:
		level = corpse.stats.level
	var rewards: Dictionary = calculate_absorption_rewards(health_component.max_health, level)
	corpse.mark_harvested()
	var max_gained: float = health_component.increase_max_health(float(rewards["max_hp_bonus"]), false)
	var healed_amount: float = health_component.heal(float(rewards["heal_amount"]))
	var essence_gained: int = int(rewards["essence"])
	var old_tier: int = beta_tier
	bio_essence += essence_gained
	beta_tier = maxi(beta_tier, tier_for_essence(bio_essence))
	var tier_up: bool = beta_tier > old_tier
	overdrive_time = OVERDRIVE_DURATION
	is_channeling = false
	channel_time = 0.0
	target_corpse = null
	channel_progress.emit(false, 1.0)
	_sfx("sfx_beta_complete")
	evolution_changed.emit(beta_tier, bio_essence, get_next_threshold())
	overdrive_changed.emit(true, overdrive_time, OVERDRIVE_DURATION)
	absorption_toast.emit(max_gained, healed_amount, essence_gained, tier_up)
	beta_completed.emit(healed_amount)


func update_prompt() -> void:
	if is_channeling:
		_set_prompt(true, TEXT_CHANNEL, false)
		return
	if health_component == null or health_component.is_dead:
		_set_prompt(false, "", false)
		return
	var corpse: EnemyBase = find_nearest_corpse()
	if corpse == null:
		_set_prompt(false, "", false)
		return
	var level: int = 0
	if corpse.stats != null:
		level = corpse.stats.level
	var rewards: Dictionary = calculate_absorption_rewards(health_component.max_health, level)
	if health_component.max_health < HealthComponent.ABSOLUTE_MAX_HEALTH_CAP:
		_set_prompt(true, TEXT_ABSORB % [int(rewards["max_hp_bonus"]), int(rewards["essence"])], true)
	else:
		_set_prompt(true, TEXT_OVERLOAD % int(roundf(float(rewards["heal_amount"]))), true)


func get_channel_ratio() -> float:
	if not is_channeling:
		return 0.0
	return clampf(channel_time / get_channel_duration(), 0.0, 1.0)


func _set_prompt(v: bool, text: String, can_use: bool) -> void:
	if v == _prompt_visible and text == _prompt_text and can_use == _prompt_can_use:
		return
	_prompt_visible = v
	_prompt_text = text
	_prompt_can_use = can_use
	prompt_changed.emit(v, text, can_use)


func _resolve_enemy(n: Node) -> EnemyBase:
	var cur: Node = n
	var depth: int = 0
	while cur != null and depth < 4:
		if cur is EnemyBase:
			return cur as EnemyBase
		cur = cur.get_parent()
		depth += 1
	return null


func _flat_distance(a: Vector3, b: Vector3) -> float:
	# Mostly horizontal check; vertical counts half so corpses on floor below eye level still register.
	var d: Vector3 = b - a
	return Vector3(d.x, d.y * 0.5, d.z).length()


func _sfx(sfx_name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play_sfx", sfx_name)
