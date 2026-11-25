class_name FpsCamera
extends Node3D
## Head pivot: pitch on this node, yaw on yaw_target (the player body).
## Camera3D child carries cosmetic offsets: head-bob, recoil kick, trauma shake.

const PITCH_LIMIT_DEG: float = 86.0
const SPRINT_FOV_BOOST: float = 6.0
const MAX_RECOIL_DEG: float = 14.0

@export var yaw_target: Node3D
@export var bob_frequency: float = 10.0
@export var bob_amplitude: float = 0.045
@export var fov_lerp_speed: float = 10.0
@export var recoil_return_speed: float = 13.0
@export var kick_return_speed: float = 18.0
@export var trauma_decay: float = 1.7
@export var max_shake_offset: float = 0.09
@export var max_shake_roll_deg: float = 2.2
## Mouse sensitivity scale: degrees per pixel = mouse_sensitivity * this.
@export var sensitivity_scale: float = 0.5

var camera: Camera3D
var input_enabled: bool = true
var pitch: float = 0.0

## Driven by PlayerController each frame.
var sprinting: bool = false
var ads_active: bool = false
var ads_fov_offset: float = 0.0
var move_ratio: float = 0.0
var grounded: bool = true

var _bob_time: float = 0.0
var _bob_offset: Vector3 = Vector3.ZERO
var _recoil_pitch: float = 0.0
var _recoil_kick: float = 0.0
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _current_h_fov: float = 100.0


static func horizontal_to_vertical_fov(h_fov_deg: float, aspect: float) -> float:
	var clamped_h: float = clampf(h_fov_deg, 75.0, 120.0)
	var half_h_rad: float = deg_to_rad(clamped_h) * 0.5
	var v_rad: float = 2.0 * atan(tan(half_h_rad) / maxf(aspect, 0.1))
	return rad_to_deg(v_rad)


## Same conversion with a wider clamp so ADS / sprint offsets can leave 75..120.
static func _h_to_v_loose(h_fov_deg: float, aspect: float) -> float:
	var clamped_h: float = clampf(h_fov_deg, 40.0, 135.0)
	var half_h_rad: float = deg_to_rad(clamped_h) * 0.5
	var v_rad: float = 2.0 * atan(tan(half_h_rad) / maxf(aspect, 0.1))
	return rad_to_deg(v_rad)


func _ready() -> void:
	camera = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	if yaw_target == null:
		yaw_target = get_parent() as Node3D
	_current_h_fov = _settings_float("horizontal_fov", 100.0)
	_apply_fov()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look((event as InputEventMouseMotion).relative)


func apply_look(relative: Vector2) -> void:
	var sens: float = _settings_float("mouse_sensitivity", 0.22) * sensitivity_scale
	if ads_active:
		sens *= 0.7
	if yaw_target != null:
		yaw_target.rotate_y(-deg_to_rad(relative.x * sens))
	pitch = clampf(pitch - deg_to_rad(relative.y * sens), deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	rotation.x = pitch


func set_pitch(radians: float) -> void:
	pitch = clampf(radians, deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	rotation.x = pitch


func add_recoil(pitch_deg: float, kick: float) -> void:
	_recoil_pitch = minf(_recoil_pitch + deg_to_rad(pitch_deg), deg_to_rad(MAX_RECOIL_DEG))
	_recoil_kick = minf(_recoil_kick + kick, 0.35)
	# Small permanent climb so sustained fire drifts up (arcade feel).
	set_pitch(pitch + deg_to_rad(pitch_deg) * 0.12)


func add_trauma(amount: float) -> void:
	if not _settings_bool("camera_shake_enabled", true):
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_aim_origin() -> Vector3:
	return camera.global_position


func get_aim_direction() -> Vector3:
	return -camera.global_basis.z.normalized()


func _process(delta: float) -> void:
	rotation.x = pitch
	_apply_fov_lerp(delta)
	_update_bob(delta)
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, clampf(recoil_return_speed * delta, 0.0, 1.0))
	_recoil_kick = lerpf(_recoil_kick, 0.0, clampf(kick_return_speed * delta, 0.0, 1.0))

	var shake_pos: Vector3 = Vector3.ZERO
	var shake_rot: Vector3 = Vector3.ZERO
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	if _trauma > 0.0 and _settings_bool("camera_shake_enabled", true):
		_shake_time += delta * 38.0
		var amt: float = _trauma * _trauma
		shake_pos = Vector3(sin(_shake_time * 1.13), sin(_shake_time * 1.71 + 1.3), 0.0) * max_shake_offset * amt
		shake_rot = Vector3(
			sin(_shake_time * 0.93 + 2.1) * 0.6,
			sin(_shake_time * 1.37 + 0.4) * 0.6,
			sin(_shake_time * 1.09 + 3.3)
		) * deg_to_rad(max_shake_roll_deg) * amt
	elif _trauma <= 0.0:
		_trauma = 0.0

	camera.position = _bob_offset + Vector3(0.0, 0.0, _recoil_kick) + shake_pos
	camera.rotation = Vector3(_recoil_pitch, 0.0, 0.0) + shake_rot


func _update_bob(delta: float) -> void:
	var target: Vector3 = Vector3.ZERO
	if grounded and move_ratio > 0.08:
		var freq_mul: float = 1.25 if sprinting else 1.0
		_bob_time += delta * bob_frequency * freq_mul
		var amp: float = bob_amplitude * clampf(move_ratio, 0.0, 1.3)
		if ads_active:
			amp *= 0.3
		target = Vector3(cos(_bob_time * 0.5) * amp * 0.6, absf(sin(_bob_time)) * amp - amp * 0.5, 0.0)
	_bob_offset = _bob_offset.lerp(target, clampf(12.0 * delta, 0.0, 1.0))


func _apply_fov_lerp(delta: float) -> void:
	var target: float = _settings_float("horizontal_fov", 100.0)
	if sprinting and not ads_active:
		target += SPRINT_FOV_BOOST
	if ads_active:
		target += ads_fov_offset
	_current_h_fov = lerpf(_current_h_fov, target, clampf(fov_lerp_speed * delta, 0.0, 1.0))
	_apply_fov()


func _apply_fov() -> void:
	if camera == null:
		return
	var aspect: float = 16.0 / 9.0
	var vp: Viewport = get_viewport()
	if vp != null:
		var size: Vector2 = vp.get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
	camera.fov = _h_to_v_loose(_current_h_fov, aspect)


func _settings_float(key: String, fallback: float) -> float:
	var s: Node = get_node_or_null("/root/SettingsManager")
	if s == null:
		return fallback
	var v: Variant = s.get(key)
	if v == null:
		return fallback
	return float(v)


func _settings_bool(key: String, fallback: bool) -> bool:
	var s: Node = get_node_or_null("/root/SettingsManager")
	if s == null:
		return fallback
	var v: Variant = s.get(key)
	if v == null:
		return fallback
	return bool(v)
