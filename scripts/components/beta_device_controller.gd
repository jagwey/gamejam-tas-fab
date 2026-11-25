class_name BetaDeviceController
extends Node
## BETA device: channel 1.0s on a fresh corpse to heal 5% max HP per enemy level (cap 5).
## Never heals passively. Full-health use is refused without consuming the corpse.

signal prompt_changed(visible_flag: bool, text: String, can_use: bool)
signal channel_progress(active: bool, ratio: float)
signal beta_completed(heal_amount: float)
signal beta_cancelled(reason: String)

const BETA_DURATION: float = 1.0
const INTERACT_RANGE: float = 2.8
const CANCEL_RANGE: float = 3.3

const TEXT_FULL: String = "SAĞLIK TAM DOLU — BETA GEREKMİYOR"
const TEXT_READY: String = "[F] BETA PROTOKOLÜ  +%d HP"
const TEXT_CHANNEL: String = "BETA AKTARILIYOR..."

## Body whose position is used for range checks. Defaults to parent.
@export var player: Node3D
@export var health_component: HealthComponent
## When false, _process does nothing; tests call update_prompt()/process_channel() manually.
@export var auto_process: bool = true

var is_channeling: bool = false
var channel_time: float = 0.0
var target_corpse: EnemyBase = null

var _prompt_visible: bool = false
var _prompt_text: String = ""
var _prompt_can_use: bool = false


static func calculate_heal_amount(max_hp: float, enemy_level: int) -> float:
	return max_hp * 0.05 * float(mini(maxi(enemy_level, 0), 5))


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
	process_channel(delta)
	update_prompt()


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


func try_start_beta() -> bool:
	if is_channeling or health_component == null or player == null:
		return false
	if health_component.is_dead:
		return false
	var corpse: EnemyBase = find_nearest_corpse()
	if corpse == null:
		return false
	if health_component.current_health >= health_component.max_health:
		_set_prompt(true, TEXT_FULL, false)
		_sfx("sfx_ui_deny")
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
	var ratio: float = clampf(channel_time / BETA_DURATION, 0.0, 1.0)
	channel_progress.emit(true, ratio)
	if channel_time >= BETA_DURATION:
		_complete()


func _complete() -> void:
	var corpse: EnemyBase = target_corpse
	var level: int = 0
	if corpse.stats != null:
		level = corpse.stats.level
	var amount: float = calculate_heal_amount(health_component.max_health, level)
	corpse.mark_harvested()
	var healed_amount: float = health_component.heal(amount)
	is_channeling = false
	channel_time = 0.0
	target_corpse = null
	channel_progress.emit(false, 1.0)
	_sfx("sfx_beta_complete")
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
	if health_component.current_health >= health_component.max_health:
		_set_prompt(true, TEXT_FULL, false)
		return
	var level: int = 0
	if corpse.stats != null:
		level = corpse.stats.level
	var amount: float = calculate_heal_amount(health_component.max_health, level)
	var missing: float = health_component.max_health - health_component.current_health
	_set_prompt(true, TEXT_READY % int(roundf(minf(amount, missing))), true)


func get_channel_ratio() -> float:
	if not is_channeling:
		return 0.0
	return clampf(channel_time / BETA_DURATION, 0.0, 1.0)


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
