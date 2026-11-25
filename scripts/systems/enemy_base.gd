class_name EnemyBase
extends CharacterBody3D
## Billboard-sprite enemy with a telegraphed hitscan attack. Leaves a harvestable corpse for the BETA device.
## patrol_points are offsets relative to the spawn position.

signal died(enemy: EnemyBase)
signal damaged(amount: float, current: float, maximum: float)
signal state_changed(new_state: int)

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK_WINDUP, ATTACK, HURT, DEAD }

const SPRITE_DIR: String = "res://assets/sprites/enemies/"
const ANIMS: Array[String] = ["idle", "walk", "windup", "attack", "hurt", "death", "corpse_fresh", "corpse_drained"]
const LOOPING: Array[String] = ["idle", "walk", "corpse_fresh", "corpse_drained"]
const GRAVITY: float = 20.0
const EYE_HEIGHT: float = 1.45
const TARGET_HEIGHT: float = 1.25
const SPRITE_HEIGHT_M: float = 1.85
const DETECT_INTERVAL: float = 0.15
const VISION_HALF_ANGLE_DEG: float = 65.0
const HEARING_RADIUS: float = 4.0
const ALERT_REACTION: float = 0.35
const ALERT_SHARE_RADIUS: float = 9.0
const HURT_DURATION: float = 0.16
const HURT_STAGGER_COOLDOWN: float = 0.8
const ATTACK_RECOVER: float = 0.28
const AIM_LOCK_FRACTION: float = 0.6
const LOSE_TARGET_TIME: float = 7.0

static var _frames_cache: Dictionary = {}

@export var stats: EnemyStats
@export var patrol_points: Array[Vector3] = []
@export var start_alerted: bool = false
@export var is_boss: bool = false
@export var boss_name: String = ""

var state: int = State.IDLE
var is_dead: bool = false
var is_harvested: bool = false
var player: Node3D = null

var _spawn_position: Vector3
var _state_time: float = 0.0
var _detect_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _stagger_cooldown: float = 0.0
var _patrol_index: int = 0
var _patrol_wait: float = 0.0
var _facing: Vector3 = Vector3.FORWARD
var _aim_point: Vector3 = Vector3.ZERO
var _last_seen_time: float = 0.0
var _last_known_pos: Vector3 = Vector3.ZERO
var _base_modulate: Color = Color.WHITE
var _resume_after_hurt: int = State.CHASE

@onready var sprite: AnimatedSprite3D = get_node_or_null("Sprite") as AnimatedSprite3D
@onready var body_collider: CollisionShape3D = get_node_or_null("BodyCollider") as CollisionShape3D
@onready var corpse_area: Area3D = get_node_or_null("CorpseArea") as Area3D
@onready var bio_light: OmniLight3D = get_node_or_null("BioLight") as OmniLight3D
@onready var telegraph_light: OmniLight3D = get_node_or_null("TelegraphLight") as OmniLight3D
@onready var health: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("enemies")
	_spawn_position = global_position
	_facing = -global_basis.z
	if stats == null:
		stats = EnemyStats.new()
	if health == null:
		health = HealthComponent.new()
		health.name = "HealthComponent"
		add_child(health)
	health.max_health = stats.max_health
	health.current_health = stats.max_health
	health.is_dead = false
	_base_modulate = stats.tint_color
	_setup_sprite()
	_setup_corpse_area(false)
	if bio_light != null:
		bio_light.visible = false
	if telegraph_light != null:
		telegraph_light.visible = false
	_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
	if start_alerted:
		call_deferred("alert")


# ------------------------------------------------------------------ public API

func alert(share: bool = true) -> void:
	if is_dead:
		return
	if player == null:
		player = _find_player()
	if player == null:
		return
	_last_known_pos = player.global_position
	_last_seen_time = 0.0
	if state == State.IDLE or state == State.PATROL:
		_set_state(State.ALERT)
		_sfx("sfx_enemy_alert", -3.0, randf_range(0.92, 1.08))
		if share:
			_share_alert()
	if is_boss:
		_update_boss_bar(true)


## Returns true if this hit killed the enemy.
func take_damage(amount: float, _source: Node = null) -> bool:
	if is_dead or amount <= 0.0:
		return false
	health.take_damage(amount)
	damaged.emit(amount, health.current_health, health.max_health)
	if is_boss:
		_update_boss_bar(true)
	if health.is_dead:
		_die()
		return true
	_flash_hit()
	_sfx("sfx_enemy_hurt", -4.0, randf_range(0.9, 1.1))
	if state == State.IDLE or state == State.PATROL:
		alert()
	elif _stagger_cooldown <= 0.0 and state != State.HURT:
		# Interrupts windup — reward for aggressive play.
		_resume_after_hurt = State.CHASE
		_stagger_cooldown = HURT_STAGGER_COOLDOWN
		_set_state(State.HURT)
	return false


func can_be_harvested() -> bool:
	return is_dead and not is_harvested and stats != null and stats.can_harvest_beta


func mark_harvested() -> void:
	if is_harvested:
		return
	is_harvested = true
	remove_from_group("dead_enemies")
	if corpse_area != null:
		corpse_area.remove_from_group("corpses")
	if bio_light != null:
		bio_light.visible = false
	_play_anim("corpse_drained")
	if sprite != null:
		sprite.modulate = Color(0.42, 0.42, 0.45, 1.0)


func get_state_name() -> String:
	return State.keys()[state] as String


# ------------------------------------------------------------------ loop

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_stagger_cooldown = maxf(_stagger_cooldown - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = _find_player()

	var desired: Vector3 = Vector3.ZERO
	match state:
		State.IDLE:
			_tick_detection(delta)
		State.PATROL:
			desired = _tick_patrol(delta)
			_tick_detection(delta)
		State.ALERT:
			_face_towards(_player_pos())
			if _state_time >= ALERT_REACTION:
				_set_state(State.CHASE)
		State.CHASE:
			desired = _tick_chase(delta)
		State.ATTACK_WINDUP:
			_tick_windup()
		State.ATTACK:
			if _state_time >= ATTACK_RECOVER:
				_set_state(State.CHASE)
		State.HURT:
			if _state_time >= HURT_DURATION:
				_set_state(_resume_after_hurt)

	velocity.x = desired.x
	velocity.z = desired.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	_update_move_anim(desired)


func _tick_detection(delta: float) -> void:
	_detect_timer -= delta
	if _detect_timer > 0.0:
		return
	_detect_timer = DETECT_INTERVAL
	if player == null:
		return
	var to_p: Vector3 = player.global_position - global_position
	var dist: float = to_p.length()
	if dist > stats.detection_range:
		return
	var flat: Vector3 = Vector3(to_p.x, 0.0, to_p.z).normalized()
	var in_cone: bool = _facing.dot(flat) >= cos(deg_to_rad(VISION_HALF_ANGLE_DEG))
	if (in_cone or dist <= HEARING_RADIUS) and has_line_of_sight():
		alert()


func _tick_patrol(delta: float) -> Vector3:
	if patrol_points.is_empty():
		return Vector3.ZERO
	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		return Vector3.ZERO
	var target: Vector3 = _spawn_position + patrol_points[_patrol_index % patrol_points.size()]
	var to_t: Vector3 = target - global_position
	to_t.y = 0.0
	if to_t.length() < 0.4:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_patrol_wait = 1.2
		return Vector3.ZERO
	return _steer_towards(target, stats.patrol_speed)


func _tick_chase(delta: float) -> Vector3:
	if player == null:
		_set_state(State.IDLE)
		return Vector3.ZERO
	var ppos: Vector3 = _player_pos()
	var dist: float = global_position.distance_to(ppos)
	var los: bool = has_line_of_sight()
	if los:
		_last_known_pos = ppos
		_last_seen_time = 0.0
	else:
		_last_seen_time += delta
		if _last_seen_time > LOSE_TARGET_TIME:
			_set_state(State.PATROL if not patrol_points.is_empty() else State.IDLE)
			return Vector3.ZERO
	if los and dist <= stats.attack_range:
		_face_towards(ppos)
		if _attack_cooldown <= 0.0:
			_set_state(State.ATTACK_WINDUP)
			return Vector3.ZERO
		# Cooling down in range: slow strafe so they don't freeze.
		var side: Vector3 = Vector3(-_facing.z, 0.0, _facing.x)
		var s: float = sin(Time.get_ticks_msec() * 0.0015 + float(get_instance_id() % 7))
		return side * s * stats.move_speed * 0.35
	return _steer_towards(_last_known_pos, stats.move_speed)


func _tick_windup() -> void:
	var ppos: Vector3 = _player_pos()
	_face_towards(ppos)
	# Aim tracks early in the windup, then locks so lateral movement dodges.
	if _state_time <= stats.windup_duration * AIM_LOCK_FRACTION:
		_aim_point = ppos + Vector3(0.0, TARGET_HEIGHT, 0.0)
	if telegraph_light != null:
		telegraph_light.visible = true
		telegraph_light.light_energy = 1.5 + 2.5 * absf(sin(_state_time * 40.0))
	if sprite != null:
		var pulse: float = absf(sin(_state_time * 30.0))
		sprite.modulate = _base_modulate.lerp(Color(1.0, 0.35, 0.25, 1.0), pulse * 0.6)
	if _state_time >= stats.windup_duration:
		_fire_attack()


func _fire_attack() -> void:
	_set_state(State.ATTACK)
	_attack_cooldown = stats.attack_interval
	_sfx("sfx_enemy_attack", -2.0, randf_range(0.95, 1.05))
	if player == null:
		return
	var origin: Vector3 = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var dir: Vector3 = (_aim_point - origin).normalized()
	dir = _apply_spread(dir, stats.projectile_spread_deg)
	var to: Vector3 = origin + dir * (stats.attack_range + 6.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, to, 1 | 2, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider") as Object
	if collider is Node and (collider as Node).is_in_group("player") and collider.has_method("apply_damage"):
		collider.call("apply_damage", stats.damage)


# ------------------------------------------------------------------ death

func _die() -> void:
	is_dead = true
	_set_state(State.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	if body_collider != null:
		body_collider.set_deferred("disabled", true)
	remove_from_group("enemies")
	add_to_group("dead_enemies")
	_setup_corpse_area(true)
	if telegraph_light != null:
		telegraph_light.visible = false
	if bio_light != null:
		bio_light.visible = true
	if sprite != null:
		sprite.modulate = _base_modulate
	_play_anim("death")
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("death") \
			and sprite.sprite_frames.get_frame_count("death") > 1:
		sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		_play_anim("corpse_fresh")
	_sfx("sfx_enemy_die", 0.0, randf_range(0.9, 1.1))
	if is_boss:
		_update_boss_bar(false)
	died.emit(self)


func _on_death_anim_finished() -> void:
	if not is_harvested:
		_play_anim("corpse_fresh")


func _setup_corpse_area(enabled: bool) -> void:
	if corpse_area == null:
		return
	corpse_area.collision_layer = 8 if enabled else 0
	corpse_area.collision_mask = 0
	corpse_area.monitoring = false
	corpse_area.set_deferred("monitorable", enabled)
	for c in corpse_area.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", not enabled)
	if enabled:
		corpse_area.add_to_group("corpses")
	else:
		corpse_area.remove_from_group("corpses")


# ------------------------------------------------------------------ helpers

func has_line_of_sight() -> bool:
	if player == null or not is_inside_tree():
		return false
	var origin: Vector3 = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var target: Vector3 = player.global_position + Vector3(0.0, TARGET_HEIGHT, 0.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _steer_towards(target: Vector3, speed: float) -> Vector3:
	var next: Vector3 = target
	if nav_agent != null and _nav_available():
		nav_agent.target_position = target
		if not nav_agent.is_navigation_finished():
			next = nav_agent.get_next_path_position()
	var to_n: Vector3 = next - global_position
	to_n.y = 0.0
	if to_n.length() < 0.15:
		return Vector3.ZERO
	var dir: Vector3 = to_n.normalized()
	_facing = _facing.slerp(dir, 0.25).normalized() if _facing.dot(dir) > -0.99 else dir
	return dir * speed


func _nav_available() -> bool:
	var map_rid: RID = nav_agent.get_navigation_map()
	if not map_rid.is_valid():
		return false
	return not NavigationServer3D.map_get_regions(map_rid).is_empty()


func _face_towards(pos: Vector3) -> void:
	var d: Vector3 = pos - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_facing = d.normalized()


func _player_pos() -> Vector3:
	if player == null:
		return global_position
	return player.global_position


func _find_player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node3D


func _share_alert() -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == self or not (n is EnemyBase):
			continue
		var e: EnemyBase = n as EnemyBase
		if e.global_position.distance_to(global_position) <= ALERT_SHARE_RADIUS:
			e.alert(false)


func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var right: Vector3 = dir.cross(up).normalized()
	var true_up: Vector3 = right.cross(dir).normalized()
	var a: float = deg_to_rad(spread_deg)
	var out: Vector3 = dir.rotated(true_up, randf_range(-a, a))
	out = out.rotated(right, randf_range(-a, a) * 0.6)
	return out.normalized()


func _set_state(s: int) -> void:
	var prev: int = state
	state = s
	_state_time = 0.0
	if prev == State.ATTACK_WINDUP and s != State.ATTACK_WINDUP:
		if telegraph_light != null:
			telegraph_light.visible = false
		if sprite != null and not is_dead:
			sprite.modulate = _base_modulate
	match s:
		State.IDLE, State.ALERT:
			_play_anim("idle")
		State.ATTACK_WINDUP:
			if player != null:
				_aim_point = player.global_position + Vector3(0.0, TARGET_HEIGHT, 0.0)
			_play_anim("windup")
		State.ATTACK:
			_play_anim("attack")
		State.HURT:
			_play_anim("hurt")
		_:
			pass
	state_changed.emit(s)


func _update_move_anim(desired: Vector3) -> void:
	if sprite == null or is_dead:
		return
	if state == State.PATROL or state == State.CHASE:
		if Vector2(desired.x, desired.z).length() > 0.2:
			_play_anim("walk")
		else:
			_play_anim("idle")


func _flash_hit() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", _base_modulate, 0.12)


func _update_boss_bar(show_bar: bool) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null or not gm.has_method("update_boss_bar"):
		return
	var bname: String = boss_name if boss_name != "" else stats.display_name
	gm.call("update_boss_bar", bname, health.current_health, health.max_health, show_bar)


func _sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play_sfx", sfx_name, volume_db, pitch_scale)


# ------------------------------------------------------------------ sprites

func _setup_sprite() -> void:
	if sprite == null:
		return
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = _base_modulate
	var frames: SpriteFrames = get_sprite_frames(stats.sprite_prefix)
	sprite.sprite_frames = frames
	var tex: Texture2D = null
	if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		tex = frames.get_frame_texture("idle", 0)
	if tex != null and tex.get_height() > 0:
		sprite.pixel_size = SPRITE_HEIGHT_M / float(tex.get_height())
	sprite.centered = true
	sprite.position.y = SPRITE_HEIGHT_M * 0.5
	_play_anim("idle")


func _play_anim(anim: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var a: String = anim
	if not sprite.sprite_frames.has_animation(a):
		a = "idle"
	if sprite.animation == StringName(a) and sprite.is_playing():
		return
	sprite.play(StringName(a))


static func get_sprite_frames(prefix: String) -> SpriteFrames:
	var key: String = prefix if prefix != "" else "__placeholder__"
	if _frames_cache.has(key):
		return _frames_cache[key] as SpriteFrames
	var frames: SpriteFrames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var files: PackedStringArray = _list_sprite_files()
	var found: Dictionary = {}
	for anim in ANIMS:
		var textures: Array[Texture2D] = _collect_textures(files, prefix, anim)
		if not textures.is_empty():
			found[anim] = textures
	if found.is_empty():
		var ph: Array[Texture2D] = [_placeholder_texture()]
		found["idle"] = ph
	# Fallback chains for missing animations.
	var fallbacks: Dictionary = {
		"idle": ["walk", "attack"],
		"walk": ["idle"],
		"windup": ["attack", "idle"],
		"attack": ["windup", "idle"],
		"hurt": ["idle"],
		"death": ["corpse_fresh", "hurt", "idle"],
		"corpse_fresh": ["death", "hurt", "idle"],
		"corpse_drained": ["corpse_fresh", "death", "idle"],
	}
	for anim in ANIMS:
		var tex_list: Array[Texture2D] = []
		if found.has(anim):
			tex_list = found[anim] as Array[Texture2D]
		else:
			var chain: Array = fallbacks[anim] as Array
			for alt in chain:
				if found.has(str(alt)):
					tex_list = found[str(alt)] as Array[Texture2D]
					if anim == "corpse_fresh" or anim == "corpse_drained":
						# Corpse holds the final frame of the source.
						var last: Array[Texture2D] = [tex_list[tex_list.size() - 1]]
						tex_list = last
					break
		if tex_list.is_empty():
			continue
		frames.add_animation(anim)
		frames.set_animation_loop(anim, LOOPING.has(anim))
		var fps: float = 8.0
		if anim == "windup" or anim == "attack":
			fps = 12.0
		elif anim == "death":
			fps = 10.0
		frames.set_animation_speed(anim, fps)
		for t in tex_list:
			frames.add_frame(anim, t)
	_frames_cache[key] = frames
	return frames


static func _list_sprite_files() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(SPRITE_DIR):
		return out
	var raw: PackedStringArray = ResourceLoader.list_directory(SPRITE_DIR)
	for f in raw:
		var clean: String = f.trim_suffix(".import").trim_suffix(".remap")
		if clean.get_extension().to_lower() == "png" and not out.has(clean):
			out.append(clean)
	return out


static func _collect_textures(files: PackedStringArray, prefix: String, anim: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if prefix == "":
		return result
	var base: String = prefix + "_" + anim
	var numbered: Dictionary = {}
	var single: String = ""
	for f in files:
		var stem: String = f.get_basename()
		if stem == base:
			single = f
		elif stem.begins_with(base + "_"):
			var suffix: String = stem.substr(base.length() + 1)
			if suffix.is_valid_int():
				numbered[int(suffix)] = f
	if not numbered.is_empty():
		var keys: Array = numbered.keys()
		keys.sort()
		for k in keys:
			var tex: Texture2D = _load_tex(SPRITE_DIR + str(numbered[k]))
			if tex != null:
				result.append(tex)
	elif single != "":
		var tex_single: Texture2D = _load_tex(SPRITE_DIR + single)
		if tex_single != null:
			result.append(tex_single)
	return result


static func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _placeholder_texture() -> Texture2D:
	var img: Image = Image.create_empty(24, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.85, 0.2, 0.25, 1.0))
	img.fill_rect(Rect2i(6, 4, 12, 10), Color(0.95, 0.85, 0.75, 1.0))
	img.fill_rect(Rect2i(4, 16, 16, 20), Color(0.15, 0.18, 0.28, 1.0))
	return ImageTexture.create_from_image(img)
