class_name WeaponManager
extends Node
## Hitscan / melee weapon handling for the player. Center-screen rays, mask World|Enemies.

signal weapon_changed(weapon_id: String, display_name: String)
signal ammo_changed(mag: int, reserve: int, is_melee: bool)
signal weapon_fired(weapon_id: String)
signal reload_started(weapon_id: String, duration: float)
signal reload_finished(weapon_id: String)
signal hit_confirmed(killed: bool)
signal weapon_unlocked(weapon_id: String)

const HIT_MASK: int = 1 | 4
const IMPACT_SCENE_PATH: String = "res://scenes/weapons/bullet_impact.tscn"
const SWITCH_DELAY: float = 0.14
const MELEE_SWEEP_RADIUS: float = 0.9
const MELEE_CONE_DOT: float = 0.45
const IMPACT_POOL_SIZE: int = 16
const KILL_PUNCH_TRAUMA: float = 0.06
const TIER5_MELEE_LEECH: float = 6.0

const WEAPON_PATHS: Array[String] = [
	"res://scripts/resources/weapons/pistol.tres",
	"res://scripts/resources/weapons/shotgun.tres",
	"res://scripts/resources/weapons/melee_knife.tres",
]

@export var player: CharacterBody3D
@export var fps_camera: FpsCamera
@export var muzzle_light: OmniLight3D
@export var muzzle_flash_energy: float = 4.0

## weapon_id -> WeaponStats
var weapons: Dictionary = {}
## weapon_id -> {"unlocked": bool, "mag": int, "reserve": int}
var weapon_state: Dictionary = {}
var current_weapon_id: String = "pistol"
var is_reloading: bool = false
var ads_active: bool = false

var _cooldown: float = 0.0
var _melee_cooldown: float = 0.0
var _reload_timer: float = 0.0
var _switch_timer: float = 0.0
var _impact_scene: PackedScene = null
var _impact_pool: Array[Node] = []
var _impact_next: int = 0
var _beta: BetaDeviceController = null


func _ready() -> void:
	if player == null:
		player = get_parent() as CharacterBody3D
	for path in WEAPON_PATHS:
		if ResourceLoader.exists(path):
			var ws: WeaponStats = load(path) as WeaponStats
			if ws != null:
				weapons[ws.weapon_id] = ws
	for id in weapons.keys():
		var ws2: WeaponStats = weapons[id] as WeaponStats
		var unlocked: bool = ws2.weapon_id == "pistol" or ws2.is_melee
		weapon_state[id] = {"unlocked": unlocked, "mag": ws2.magazine_size, "reserve": ws2.magazine_size * 2}
	if ResourceLoader.exists(IMPACT_SCENE_PATH):
		_impact_scene = load(IMPACT_SCENE_PATH) as PackedScene
	if muzzle_light != null:
		muzzle_light.light_energy = 0.0
	if not weapons.has(current_weapon_id) and not weapons.is_empty():
		current_weapon_id = str(weapons.keys()[0])
	call_deferred("_emit_full_state")


func setup(p: CharacterBody3D, cam: FpsCamera, light: OmniLight3D) -> void:
	player = p
	fps_camera = cam
	muzzle_light = light


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	_switch_timer = maxf(_switch_timer - delta, 0.0)
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	if muzzle_light != null and muzzle_light.light_energy > 0.0:
		muzzle_light.light_energy = maxf(muzzle_light.light_energy - delta * muzzle_flash_energy * 18.0, 0.0)


# ------------------------------------------------------------------ queries

func get_current_stats() -> WeaponStats:
	return weapons.get(current_weapon_id) as WeaponStats


func get_stats(weapon_id: String) -> WeaponStats:
	return weapons.get(weapon_id) as WeaponStats


func is_unlocked(weapon_id: String) -> bool:
	if not weapon_state.has(weapon_id):
		return false
	var st: Dictionary = weapon_state[weapon_id] as Dictionary
	return bool(st.get("unlocked", false))


func get_mag(weapon_id: String) -> int:
	if not weapon_state.has(weapon_id):
		return 0
	return int((weapon_state[weapon_id] as Dictionary).get("mag", 0))


func get_reserve(weapon_id: String) -> int:
	if not weapon_state.has(weapon_id):
		return 0
	return int((weapon_state[weapon_id] as Dictionary).get("reserve", 0))


func can_fire() -> bool:
	var ws: WeaponStats = get_current_stats()
	if ws == null or is_reloading or _cooldown > 0.0 or _switch_timer > 0.0:
		return false
	return ws.is_melee or get_mag(current_weapon_id) > 0


func _beta_device() -> BetaDeviceController:
	if _beta != null and is_instance_valid(_beta):
		return _beta
	_beta = null
	if player != null:
		var b: Variant = player.get("beta_device") if "beta_device" in player else null
		if b is BetaDeviceController:
			_beta = b as BetaDeviceController
		else:
			_beta = player.get_node_or_null("BetaDeviceController") as BetaDeviceController
	return _beta


func get_damage_multiplier() -> float:
	var b: BetaDeviceController = _beta_device()
	return b.get_damage_multiplier() if b != null else 1.0


func get_fire_rate_multiplier() -> float:
	var b: BetaDeviceController = _beta_device()
	return maxf(b.get_fire_rate_multiplier(), 0.1) if b != null else 1.0


func get_reload_speed_multiplier() -> float:
	var b: BetaDeviceController = _beta_device()
	return maxf(b.get_reload_speed_multiplier(), 0.1) if b != null else 1.0


# ------------------------------------------------------------------ actions

## Returns true if a shot/swing happened.
func fire() -> bool:
	var ws: WeaponStats = get_current_stats()
	if ws == null or is_reloading or _cooldown > 0.0 or _switch_timer > 0.0:
		return false
	if ws.is_melee:
		return _melee_attack(ws)
	var mag: int = get_mag(current_weapon_id)
	if mag <= 0:
		if get_reserve(current_weapon_id) > 0:
			reload()
		else:
			_cooldown = 0.25
			_sfx("sfx_dry_fire")
		return false
	_set_mag(current_weapon_id, mag - 1)
	_cooldown = ws.fire_cooldown / get_fire_rate_multiplier()
	var dmg: float = ws.damage * get_damage_multiplier()

	var origin: Vector3 = _aim_origin()
	var forward: Vector3 = _aim_direction()
	var spread: float = ws.spread_deg * (0.45 if ads_active else 1.0)
	var any_hit: bool = false
	var any_kill: bool = false
	for _i in maxi(ws.pellets, 1):
		var dir: Vector3 = _apply_spread(forward, spread) if (ws.pellets > 1 or spread > 0.0) else forward
		var result: Dictionary = _hitscan(origin, dir, ws.range_meters, dmg)
		if bool(result.get("hit_enemy", false)):
			any_hit = true
		if bool(result.get("killed", false)):
			any_kill = true
	if fps_camera != null:
		fps_camera.add_recoil(ws.recoil_pitch_deg * (0.6 if ads_active else 1.0), ws.recoil_kick)
		fps_camera.add_trauma(0.08 if ws.pellets > 1 else 0.03)
	if muzzle_light != null:
		muzzle_light.light_energy = muzzle_flash_energy
	_sfx(ws.fire_sfx, 0.0, randf_range(0.96, 1.04))
	weapon_fired.emit(ws.weapon_id)
	if any_hit:
		hit_confirmed.emit(any_kill)
	if any_kill:
		_kill_punch()
	_emit_ammo()
	if get_mag(current_weapon_id) <= 0 and get_reserve(current_weapon_id) > 0:
		reload()
	return true


## Q: knife swing without switching weapons.
func quick_melee() -> bool:
	if _melee_cooldown > 0.0:
		return false
	var ws: WeaponStats = _find_melee_stats()
	if ws == null:
		return false
	return _melee_attack(ws)


func reload() -> bool:
	var ws: WeaponStats = get_current_stats()
	if ws == null or ws.is_melee or is_reloading:
		return false
	var mag: int = get_mag(current_weapon_id)
	if mag >= ws.magazine_size or get_reserve(current_weapon_id) <= 0:
		return false
	is_reloading = true
	_reload_timer = ws.reload_duration / get_reload_speed_multiplier()
	_sfx(ws.reload_sfx)
	reload_started.emit(ws.weapon_id, _reload_timer)
	return true


func cancel_reload() -> void:
	is_reloading = false
	_reload_timer = 0.0


func switch_weapon(slot_index: int) -> bool:
	for id in weapons.keys():
		var ws: WeaponStats = weapons[id] as WeaponStats
		if ws.slot_index == slot_index:
			return equip(ws.weapon_id)
	return false


func equip(weapon_id: String) -> bool:
	if not weapons.has(weapon_id) or not is_unlocked(weapon_id):
		return false
	if weapon_id == current_weapon_id:
		return false
	cancel_reload()
	current_weapon_id = weapon_id
	_switch_timer = SWITCH_DELAY
	var ws: WeaponStats = get_current_stats()
	if ws.is_melee and ads_active:
		set_ads(false)
	_sfx("sfx_weapon_switch", -6.0)
	weapon_changed.emit(ws.weapon_id, ws.display_name)
	_emit_ammo()
	if fps_camera != null:
		fps_camera.ads_fov_offset = ws.ads_fov_offset
	return true


func set_ads(active: bool) -> void:
	var ws: WeaponStats = get_current_stats()
	var allowed: bool = active and ws != null and not ws.is_melee
	ads_active = allowed
	if fps_camera != null:
		fps_camera.ads_active = allowed
		fps_camera.ads_fov_offset = ws.ads_fov_offset if ws != null else 0.0


func unlock_weapon(weapon_id: String, auto_equip: bool = true) -> bool:
	if not weapon_state.has(weapon_id):
		return false
	var st: Dictionary = weapon_state[weapon_id] as Dictionary
	var was: bool = bool(st.get("unlocked", false))
	st["unlocked"] = true
	if not was:
		var ws: WeaponStats = weapons[weapon_id] as WeaponStats
		st["mag"] = ws.magazine_size
		weapon_unlocked.emit(weapon_id)
	if auto_equip:
		equip(weapon_id)
	return not was


## Returns how many rounds were actually added to reserve.
func add_ammo(weapon_id: String, amount: int) -> int:
	if not weapon_state.has(weapon_id) or amount <= 0:
		return 0
	var ws: WeaponStats = weapons[weapon_id] as WeaponStats
	if ws.is_melee:
		return 0
	var st: Dictionary = weapon_state[weapon_id] as Dictionary
	var reserve: int = int(st.get("reserve", 0))
	var new_reserve: int = mini(reserve + amount, ws.max_reserve)
	st["reserve"] = new_reserve
	if weapon_id == current_weapon_id:
		_emit_ammo()
	return new_reserve - reserve


func get_weapon_state_dict() -> Dictionary:
	var out_weapons: Dictionary = {}
	for id in weapon_state.keys():
		var st: Dictionary = weapon_state[id] as Dictionary
		out_weapons[id] = {
			"unlocked": bool(st.get("unlocked", false)),
			"mag": int(st.get("mag", 0)),
			"reserve": int(st.get("reserve", 0)),
		}
	return {"current": current_weapon_id, "weapons": out_weapons}


func apply_weapon_state_dict(d: Dictionary) -> void:
	var raw: Variant = d.get("weapons", {})
	if raw is Dictionary:
		var in_weapons: Dictionary = raw as Dictionary
		for id in in_weapons.keys():
			var key: String = str(id)
			if not weapon_state.has(key):
				continue
			var ws: WeaponStats = weapons[key] as WeaponStats
			var src_raw: Variant = in_weapons[id]
			if not (src_raw is Dictionary):
				continue
			var src: Dictionary = src_raw as Dictionary
			var st: Dictionary = weapon_state[key] as Dictionary
			st["unlocked"] = bool(src.get("unlocked", st.get("unlocked", false)))
			st["mag"] = clampi(int(src.get("mag", st.get("mag", 0))), 0, ws.magazine_size)
			st["reserve"] = clampi(int(src.get("reserve", st.get("reserve", 0))), 0, ws.max_reserve)
	var cur: String = str(d.get("current", current_weapon_id))
	cancel_reload()
	if weapons.has(cur) and is_unlocked(cur):
		current_weapon_id = cur
	_emit_full_state()


# ------------------------------------------------------------------ internals

func _melee_attack(ws: WeaponStats) -> bool:
	_melee_cooldown = ws.fire_cooldown
	if get_current_stats() == ws:
		_cooldown = ws.fire_cooldown
	else:
		# Quick melee also briefly blocks the gun.
		_cooldown = maxf(_cooldown, ws.fire_cooldown * 0.6)
	var origin: Vector3 = _aim_origin()
	var forward: Vector3 = _aim_direction()
	var hits: Array[Node] = _melee_sweep(origin, forward, ws.range_meters)
	var any_kill: bool = false
	var melee_dmg: float = ws.damage * get_damage_multiplier()
	for target in hits:
		if target.has_method("take_damage"):
			var killed: Variant = target.call("take_damage", melee_dmg, player)
			if killed is bool and bool(killed):
				any_kill = true
			_spawn_impact((target as Node3D).global_position + Vector3(0.0, 1.1, 0.0), -forward, true)
	if hits.is_empty():
		# Spark on a wall if the knife hits geometry.
		var wall: Dictionary = _ray(origin, origin + forward * ws.range_meters, 1)
		if not wall.is_empty():
			_spawn_impact(wall.get("position") as Vector3, wall.get("normal") as Vector3, false)
	if fps_camera != null:
		fps_camera.add_recoil(ws.recoil_pitch_deg, ws.recoil_kick)
		if not hits.is_empty():
			fps_camera.add_trauma(0.12)
	_sfx(ws.fire_sfx, 0.0, randf_range(0.94, 1.08))
	weapon_fired.emit(ws.weapon_id)
	if not hits.is_empty():
		hit_confirmed.emit(any_kill)
	if any_kill:
		_kill_punch()
		_melee_leech()
	return true


## Subtle kill feedback: camera micro-punch.
func _kill_punch() -> void:
	if fps_camera != null:
		fps_camera.add_trauma(KILL_PUNCH_TRAUMA)
		fps_camera.add_recoil(0.35, 0.01)


## Evolution tier 5: melee kills leech HP.
func _melee_leech() -> void:
	var b: BetaDeviceController = _beta_device()
	if b == null or b.beta_tier < 5 or b.health_component == null:
		return
	b.health_component.heal(TIER5_MELEE_LEECH)


## Forgiving sweep: sphere overlap ahead + cone/LOS filter + center/offset rays fallback.
func _melee_sweep(origin: Vector3, forward: Vector3, reach: float) -> Array[Node]:
	var found: Array[Node] = []
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null:
		return found
	var exclude: Array[RID] = _exclude()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = MELEE_SWEEP_RADIUS
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = 4
	params.exclude = exclude
	params.transform = Transform3D(Basis.IDENTITY, origin + forward * (reach * 0.55))
	var results: Array[Dictionary] = space.intersect_shape(params, 8)
	for r in results:
		var col: Object = r.get("collider") as Object
		if not (col is Node3D) or found.has(col as Node):
			continue
		var n3: Node3D = col as Node3D
		var to_t: Vector3 = (n3.global_position + Vector3(0.0, 1.0, 0.0)) - origin
		if to_t.length() > reach + 0.8:
			continue
		var flat_f: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
		var flat_t: Vector3 = Vector3(to_t.x, 0.0, to_t.z).normalized()
		if flat_f.dot(flat_t) < MELEE_CONE_DOT and to_t.length() > 1.0:
			continue
		var wall: Dictionary = _ray(origin, n3.global_position + Vector3(0.0, 1.0, 0.0), 1)
		if not wall.is_empty():
			continue
		found.append(n3)
	if found.is_empty():
		var right: Vector3 = forward.cross(Vector3.UP).normalized()
		var offsets: Array[Vector3] = [Vector3.ZERO, right * 0.35, -right * 0.35, Vector3.DOWN * 0.35]
		for off in offsets:
			var hit: Dictionary = _ray(origin + off, origin + off + forward * reach, HIT_MASK)
			if hit.is_empty():
				continue
			var c: Object = hit.get("collider") as Object
			if c is Node and (c as Node).is_in_group("enemies") and not found.has(c as Node):
				found.append(c as Node)
				break
	return found


func _hitscan(origin: Vector3, dir: Vector3, reach: float, dmg: float) -> Dictionary:
	var out: Dictionary = {"hit_enemy": false, "killed": false}
	var hit: Dictionary = _ray(origin, origin + dir * reach, HIT_MASK)
	if hit.is_empty():
		return out
	var pos: Vector3 = hit.get("position") as Vector3
	var normal: Vector3 = hit.get("normal") as Vector3
	var col: Object = hit.get("collider") as Object
	var is_enemy: bool = col is Node and (col as Node).is_in_group("enemies") and col.has_method("take_damage")
	if is_enemy:
		var killed: Variant = col.call("take_damage", dmg, player)
		out["hit_enemy"] = true
		out["killed"] = killed is bool and bool(killed)
	_spawn_impact(pos, normal, is_enemy)
	return out


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = _space()
	if space == null:
		return {}
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask, _exclude())
	return space.intersect_ray(q)


func _space() -> PhysicsDirectSpaceState3D:
	if player == null or not player.is_inside_tree():
		return null
	return player.get_world_3d().direct_space_state


func _exclude() -> Array[RID]:
	var ex: Array[RID] = []
	if player != null:
		ex.append(player.get_rid())
	return ex


func _aim_origin() -> Vector3:
	if fps_camera != null and fps_camera.camera != null:
		return fps_camera.get_aim_origin()
	if player != null:
		return player.global_position + Vector3(0.0, 1.6, 0.0)
	return Vector3.ZERO


func _aim_direction() -> Vector3:
	if fps_camera != null and fps_camera.camera != null:
		return fps_camera.get_aim_direction()
	if player != null:
		return -player.global_basis.z
	return Vector3.FORWARD


func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right: Vector3 = dir.cross(up).normalized()
	var true_up: Vector3 = right.cross(dir).normalized()
	# Uniform-ish disc sample inside the cone.
	var r: float = sqrt(randf()) * deg_to_rad(spread_deg)
	var theta: float = randf() * TAU
	var out: Vector3 = dir.rotated(true_up, r * cos(theta))
	out = out.rotated(right, r * sin(theta))
	return out.normalized()


func _spawn_impact(pos: Vector3, normal: Vector3, flesh: bool) -> void:
	if _impact_scene == null or not is_inside_tree():
		return
	var inst: Node = _acquire_impact()
	if inst == null:
		return
	if inst is Node3D:
		(inst as Node3D).global_position = pos + normal * 0.02
	if inst.has_method("setup"):
		inst.call("setup", normal, flesh)


## Ring pool of IMPACT_POOL_SIZE impacts: idle ones first, otherwise the oldest is recycled.
func _acquire_impact() -> Node:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	# Drop entries freed by a scene change or reparented elsewhere.
	var alive: Array[Node] = []
	for n in _impact_pool:
		if is_instance_valid(n) and n.get_parent() == parent:
			alive.append(n)
	if alive.size() != _impact_pool.size():
		_impact_pool = alive
		_impact_next = 0
	for n in _impact_pool:
		if "active" in n and not bool(n.get("active")):
			return n
	if _impact_pool.size() < IMPACT_POOL_SIZE:
		var inst: Node = _impact_scene.instantiate()
		if "pooled" in inst:
			inst.set("pooled", true)
		parent.add_child(inst)
		_impact_pool.append(inst)
		return inst
	var reused: Node = _impact_pool[_impact_next % _impact_pool.size()]
	_impact_next = (_impact_next + 1) % _impact_pool.size()
	return reused


func _finish_reload() -> void:
	is_reloading = false
	_reload_timer = 0.0
	var ws: WeaponStats = get_current_stats()
	if ws == null:
		return
	var mag: int = get_mag(current_weapon_id)
	var reserve: int = get_reserve(current_weapon_id)
	var need: int = ws.magazine_size - mag
	var take: int = mini(need, reserve)
	_set_mag(current_weapon_id, mag + take)
	var st: Dictionary = weapon_state[current_weapon_id] as Dictionary
	st["reserve"] = reserve - take
	reload_finished.emit(ws.weapon_id)
	_emit_ammo()


func _find_melee_stats() -> WeaponStats:
	for id in weapons.keys():
		var ws: WeaponStats = weapons[id] as WeaponStats
		if ws.is_melee and is_unlocked(ws.weapon_id):
			return ws
	return null


func _set_mag(weapon_id: String, value: int) -> void:
	if weapon_state.has(weapon_id):
		(weapon_state[weapon_id] as Dictionary)["mag"] = value


func _emit_ammo() -> void:
	var ws: WeaponStats = get_current_stats()
	if ws == null:
		return
	ammo_changed.emit(get_mag(current_weapon_id), get_reserve(current_weapon_id), ws.is_melee)


func _emit_full_state() -> void:
	var ws: WeaponStats = get_current_stats()
	if ws == null:
		return
	if fps_camera != null:
		fps_camera.ads_fov_offset = ws.ads_fov_offset
	weapon_changed.emit(ws.weapon_id, ws.display_name)
	_emit_ammo()


func _sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sfx_name == "":
		return
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play_sfx", sfx_name, volume_db, pitch_scale)
