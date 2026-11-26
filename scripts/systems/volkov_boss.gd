extends EnemyBase

signal phase_changed(new_phase: int)
signal boss_defeated

const SLAM_RADIUS := 4.5
const PLASMA := Color("#4caeff")
const DEFAULT_MAX_HEALTH := 800.0
const TRACER_POOL_SIZE := 8
const TRACER_LIFETIME := 0.07
var phase := 1
var _slam := false
var _shots_left := 0
var _burst_size := 0
var _shot_timer := 0.0
var _burst_phase := 1
var _dash_cooldown := 2.0
var _dash_left := 0.0
var _dash_side := 1.0
var _beam_material := StandardMaterial3D.new()
var _base_move_speed := 3.2
var _base_attack_interval := 2.1
var _base_windup := 0.8
var _tracers: Array[MeshInstance3D] = []
var _tracer_ttl: PackedFloat32Array = PackedFloat32Array()
var _tracer_next := 0

func _ready() -> void:
	# Per-instance copy: phase 2/3 tweaks must not mutate the shared .tres.
	if stats == null:
		stats = EnemyStats.new()
		stats.level = 5
		stats.display_name = "Viktor Volkov"
		stats.sprite_prefix = "volkov_boss"
	stats = stats.duplicate() as EnemyStats
	stats.max_health = maxf(stats.max_health, DEFAULT_MAX_HEALTH)
	super()
	# Captured after difficulty scaling (EnemyBase._ready) so phase boosts stack on top of it.
	_base_move_speed = stats.move_speed
	_base_attack_interval = stats.attack_interval
	_base_windup = stats.windup_duration
	var idle := sprite.sprite_frames.get_frame_texture("idle", 0)
	sprite.pixel_size = 2.6 / float(idle.get_height())
	sprite.position.y = 1.3
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.albedo_color = Color("#ff6879")
	damaged.connect(_on_damaged)
	state_changed.connect(_on_state_changed)

func _on_damaged(_amount: float, current: float, maximum: float) -> void:
	if current <= 0:
		return
	var ratio := current / maximum
	var next_phase := 3 if ratio <= 0.30 else (2 if ratio <= 0.65 else 1)
	while phase < next_phase:
		phase += 1
		_shots_left = 0
		stats.move_speed = _base_move_speed * (1.45 if phase == 2 else 1.75)
		stats.attack_interval = minf(_base_attack_interval * (0.62 if phase == 2 else 0.45), 1.35 if phase == 2 else 0.95)
		stats.windup_duration = minf(_base_windup * (0.75 if phase == 2 else 0.58), 0.6 if phase == 2 else 0.46)
		if phase == 3:
			_base_modulate = Color("#9ddfff")
			bio_light.light_color = PLASMA
			bio_light.visible = true
			telegraph_light.light_color = PLASMA
			_beam_material.albedo_color = PLASMA
			($ShockRadius.material_override as StandardMaterial3D).albedo_color = PLASMA
		_sfx("sfx_boss_phase")
		phase_changed.emit(phase)

func _on_state_changed(new_state: int) -> void:
	if new_state == State.ATTACK_WINDUP:
		_slam = is_instance_valid(player) and global_position.distance_to(player.global_position) <= SLAM_RADIUS
		$ShockRadius.visible = _slam
		$ShockRadius.scale = Vector3.ONE
		telegraph_light.visible = true
		_sfx("sfx_boss_charge")
	else:
		$ShockRadius.hide()
	if new_state == State.HURT or new_state == State.DEAD:
		_shots_left = 0
		_dash_left = 0

func _tick_chase(delta: float) -> Vector3:
	if phase >= 2 and is_instance_valid(player):
		_dash_cooldown -= delta
		if _dash_cooldown <= 0.0 and has_line_of_sight():
			_dash_left = 0.32
			_dash_cooldown = 2.7
			_dash_side *= -1
		if _dash_left > 0.0:
			_dash_left -= delta
			_face_towards(player.global_position)
			var lateral := Vector3(-_facing.z, 0, _facing.x)
			return (lateral * _dash_side + _facing * 0.25).normalized() * 9.0
	return super(delta)

func _physics_process(delta: float) -> void:
	if _shots_left > 0 and not is_dead:
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_fire_round()
	_tick_tracers(delta)
	super(delta)

func _fire_attack() -> void:
	_set_state(State.ATTACK)
	_attack_cooldown = stats.attack_interval
	if not is_instance_valid(player):
		return
	if _slam:
		_sfx("sfx_boss_slam")
		$ShockRadius.show()
		$ShockRadius.scale = Vector3(0.1, 1, 0.1)
		var wave := create_tween()
		wave.tween_property($ShockRadius, "scale", Vector3.ONE, 0.18)
		if global_position.distance_to(player.global_position) <= SLAM_RADIUS and has_line_of_sight():
			if player.has_method("apply_damage"):
				player.call("apply_damage", (24.0 if phase == 3 else 18.0) * _damage_mult(), global_position)
		return
	_burst_phase = phase
	_burst_size = [3, 4, 6][phase - 1]
	_shots_left = _burst_size
	_fire_round()

func _fire_round() -> void:
	if not is_inside_tree():
		return
	var world: World3D = get_world_3d()
	if world == null:
		return
	var origin := global_position + Vector3.UP * 1.7
	var direction := origin.direction_to(_aim_point)
	if _burst_phase == 2:
		var shot_index := _burst_size - _shots_left
		direction = direction.rotated(Vector3.UP, deg_to_rad(-4.5 + 3.0 * shot_index))
	_shots_left -= 1
	_shot_timer = 0.075 if _burst_phase == 3 else 0.13
	_sfx("sfx_enemy_attack", -5.0, 1.35 if _burst_phase == 3 else 0.9)
	var endpoint := origin + direction * (stats.attack_range + 5.0)
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, 1 | 2, [get_rid()])
	var hit := world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position
		var target := hit.collider as Node
		if target and target.is_in_group("player") and target.has_method("apply_damage"):
			target.call("apply_damage", stats.damage, global_position)
	_draw_tracer(origin, endpoint)

func _damage_mult() -> float:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm != null and sm.has_method("get_enemy_damage_mult"):
		return float(sm.call("get_enemy_damage_mult"))
	return 1.0

## Reuses a ring of TRACER_POOL_SIZE beams instead of allocating/freeing one per shot.
func _acquire_tracer() -> MeshInstance3D:
	if _tracers.size() < TRACER_POOL_SIZE:
		var t := MeshInstance3D.new()
		var beam := BoxMesh.new()
		beam.size = Vector3(0.035, 0.035, 1.0)
		t.mesh = beam
		t.material_override = _beam_material
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.top_level = true
		t.visible = false
		add_child(t)
		_tracers.append(t)
		_tracer_ttl.append(0.0)
		return t
	var reused := _tracers[_tracer_next]
	_tracer_next = (_tracer_next + 1) % TRACER_POOL_SIZE
	return reused

func _tick_tracers(delta: float) -> void:
	for i in range(_tracers.size()):
		if _tracer_ttl[i] <= 0.0:
			continue
		_tracer_ttl[i] -= delta
		if _tracer_ttl[i] <= 0.0 and is_instance_valid(_tracers[i]):
			_tracers[i].visible = false

func _draw_tracer(origin: Vector3, endpoint: Vector3) -> void:
	var length := origin.distance_to(endpoint)
	if length < 0.01:
		return
	var tracer := _acquire_tracer()
	(tracer.mesh as BoxMesh).size = Vector3(0.035, 0.035, length)
	var up := Vector3.RIGHT if absf(origin.direction_to(endpoint).dot(Vector3.UP)) > 0.98 else Vector3.UP
	tracer.look_at_from_position(origin.lerp(endpoint, 0.5), endpoint, up)
	tracer.visible = true
	_tracer_ttl[_tracers.find(tracer)] = TRACER_LIFETIME

func _die() -> void:
	for t in _tracers:
		if is_instance_valid(t):
			t.visible = false
	super()
	boss_defeated.emit()
