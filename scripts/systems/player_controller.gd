class_name PlayerController
extends CharacterBody3D
## Arcade FPS player: snappy movement, crouch with ceiling check, [E] interact, [F] BETA, weapons.
## UI scenes (hud / pause_menu / death_screen) are attached if they exist and receive this player via
## setup(player) / bind_player(player) / a `player` property — whichever the UI script exposes.

signal interact_prompt_changed(visible_flag: bool, text: String)
signal player_died
signal pause_requested
signal controls_enabled_changed(enabled: bool)

const WALK_SPEED: float = 8.5
const SPRINT_SPEED: float = 12.5
const CROUCH_SPEED: float = 5.0
const ACCELERATION: float = 18.0
const AIR_CONTROL: float = 0.35
const JUMP_VELOCITY: float = 6.8
const GRAVITY: float = 20.0
const COYOTE_TIME: float = 0.1
const JUMP_BUFFER: float = 0.12

const STAND_HEIGHT: float = 1.78
const CROUCH_HEIGHT: float = 1.1
const CAPSULE_RADIUS: float = 0.38
const STAND_HEAD_Y: float = 1.62
const CROUCH_HEAD_Y: float = 0.98
const HEAD_LERP: float = 14.0

const INTERACT_RANGE: float = 2.6
const INTERACT_PROXIMITY: float = 1.5
const INTERACT_MASK: int = 1 | 8

const HUD_SCENE: String = "res://scenes/ui/hud.tscn"
const PAUSE_SCENE: String = "res://scenes/ui/pause_menu.tscn"
const DEATH_SCENE: String = "res://scenes/ui/death_screen.tscn"

@export var auto_attach_ui: bool = true

var controls_enabled: bool = true
var is_crouching: bool = false
var is_sprinting: bool = false
var interact_target: Node = null

var hud: Node = null
var pause_menu: Node = null
var death_screen: Node = null

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = true
var _fall_speed: float = 0.0
var _step_timer: float = 0.0
var _prompt_visible: bool = false
var _prompt_text: String = ""
var _ads_held: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var fps_camera: FpsCamera = $Head
@onready var health_component: HealthComponent = $HealthComponent
@onready var weapon_manager: WeaponManager = $WeaponManager
@onready var beta_device: BetaDeviceController = $BetaDeviceController
@onready var muzzle_light: OmniLight3D = get_node_or_null("Head/Camera3D/MuzzleLight") as OmniLight3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("player")
	if collision_shape.shape is CapsuleShape3D:
		# Own the shape so crouch resizing never touches a shared resource.
		collision_shape.shape = (collision_shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	_apply_capsule(STAND_HEIGHT)
	fps_camera.position.y = STAND_HEAD_Y
	weapon_manager.setup(self, fps_camera, muzzle_light)
	beta_device.setup(self, health_component)
	health_component.died.connect(_on_died)
	_import_carryover()
	if auto_attach_ui:
		call_deferred("attach_ui")
	set_controls_enabled(true)


# ------------------------------------------------------------------ public API

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if fps_camera != null:
		fps_camera.input_enabled = enabled
	if not enabled:
		if weapon_manager != null:
			weapon_manager.set_ads(false)
		_ads_held = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
	controls_enabled_changed.emit(enabled)


func apply_damage(amount: float) -> void:
	if health_component.is_dead:
		return
	var dealt: float = health_component.take_damage(amount)
	if dealt <= 0.0:
		return
	_sfx("sfx_player_hurt", 0.0, randf_range(0.95, 1.05))
	if _shake_enabled():
		fps_camera.add_trauma(clampf(0.25 + dealt * 0.02, 0.25, 0.7))


func is_dead() -> bool:
	return health_component.is_dead


func export_state() -> Dictionary:
	return {
		"health": health_component.current_health,
		"max_health": health_component.max_health,
		"weapons": weapon_manager.get_weapon_state_dict(),
	}


func import_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	var max_hp: float = float(d.get("max_health", health_component.max_health))
	var hp: float = float(d.get("health", max_hp))
	if hp <= 0.0:
		hp = max_hp
	health_component.set_health(hp, max_hp)
	var w: Variant = d.get("weapons", {})
	if w is Dictionary:
		weapon_manager.apply_weapon_state_dict(w as Dictionary)


func attach_ui() -> void:
	if hud == null:
		hud = _instance_ui(HUD_SCENE)
	if pause_menu == null:
		pause_menu = _instance_ui(PAUSE_SCENE)
	if death_screen == null:
		death_screen = _instance_ui(DEATH_SCENE)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_handle_pause()
		get_viewport().set_input_as_handled()
		return
	if not controls_enabled or health_component.is_dead:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("weapon_1"):
		weapon_manager.switch_weapon(1)
	elif event.is_action_pressed("weapon_2"):
		weapon_manager.switch_weapon(2)
	elif event.is_action_pressed("weapon_3"):
		weapon_manager.switch_weapon(3)
	elif event.is_action_pressed("reload"):
		weapon_manager.reload()
	elif event.is_action_pressed("melee"):
		weapon_manager.quick_melee()
	elif event.is_action_pressed("use_beta"):
		beta_device.try_start_beta()
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("jump"):
		_jump_buffer = JUMP_BUFFER


func _handle_pause() -> void:
	if health_component.is_dead:
		return
	if pause_menu != null and pause_menu.has_method("toggle_pause"):
		pause_menu.call("toggle_pause")
	pause_requested.emit()


# ------------------------------------------------------------------ movement

func _physics_process(delta: float) -> void:
	var input_vec: Vector2 = Vector2.ZERO
	var wants_crouch: bool = false
	var wants_sprint: bool = false
	var active: bool = controls_enabled and not health_component.is_dead
	if active:
		input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wants_crouch = Input.is_action_pressed("crouch")
		wants_sprint = Input.is_action_pressed("sprint")
		_handle_combat_input()

	# Crouch / uncrouch with ceiling check.
	if wants_crouch and not is_crouching:
		is_crouching = true
		_apply_capsule(CROUCH_HEIGHT)
	elif not wants_crouch and is_crouching and _can_stand():
		is_crouching = false
		_apply_capsule(STAND_HEIGHT)
	var head_target: float = CROUCH_HEAD_Y if is_crouching else STAND_HEAD_Y
	fps_camera.position.y = lerpf(fps_camera.position.y, head_target, clampf(HEAD_LERP * delta, 0.0, 1.0))

	is_sprinting = wants_sprint and input_vec.y < -0.1 and not is_crouching and not weapon_manager.ads_active
	var speed: float = WALK_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif is_sprinting:
		speed = SPRINT_SPEED

	var wish: Vector3 = global_basis * Vector3(input_vec.x, 0.0, input_vec.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target_h: Vector3 = wish * speed
	var on_floor: bool = is_on_floor()
	var accel: float = ACCELERATION if on_floor else ACCELERATION * AIR_CONTROL
	var h: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	h = h.lerp(target_h, clampf(accel * delta, 0.0, 1.0))
	velocity.x = h.x
	velocity.z = h.z

	# Gravity, coyote time, buffered jump.
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y -= GRAVITY * delta
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if active and _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_sfx("sfx_jump", -8.0)

	_fall_speed = minf(velocity.y, 0.0)
	move_and_slide()

	var landed: bool = is_on_floor() and not _was_on_floor
	if landed and _fall_speed < -9.0:
		fps_camera.add_trauma(clampf(-_fall_speed * 0.015, 0.05, 0.25))
		_sfx("sfx_land", -6.0)
	_was_on_floor = is_on_floor()

	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	fps_camera.move_ratio = h_speed / WALK_SPEED
	fps_camera.grounded = is_on_floor()
	fps_camera.sprinting = is_sprinting and h_speed > WALK_SPEED * 0.8
	_update_footsteps(delta, h_speed)
	_update_interact_target()


func _handle_combat_input() -> void:
	var ads: bool = Input.is_action_pressed("alt_aim")
	if ads != _ads_held:
		_ads_held = ads
		weapon_manager.set_ads(ads)
	if Input.is_action_pressed("shoot"):
		weapon_manager.fire()


func _apply_capsule(height: float) -> void:
	var cap: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if cap == null:
		return
	cap.radius = CAPSULE_RADIUS
	cap.height = height
	collision_shape.position = Vector3(0.0, height * 0.5, 0.0)


func _can_stand() -> bool:
	var box: BoxShape3D = BoxShape3D.new()
	var gap: float = STAND_HEIGHT - CROUCH_HEIGHT
	box.size = Vector3(CAPSULE_RADIUS * 1.8, gap - 0.04, CAPSULE_RADIUS * 1.8)
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.collision_mask = 1
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, CROUCH_HEIGHT + gap * 0.5 + 0.02, 0.0))
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


func _update_footsteps(delta: float, h_speed: float) -> void:
	if not is_on_floor() or h_speed < 1.5:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.3 if is_sprinting else (0.5 if is_crouching else 0.4)
		_sfx("sfx_footstep", -14.0, randf_range(0.9, 1.1))


# ------------------------------------------------------------------ interact

func try_interact() -> bool:
	var target: Node = interact_target
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("interact"):
		target.call("interact", self)
		_update_interact_target()
		return true
	return false


func _update_interact_target() -> void:
	var found: Node = null
	if controls_enabled and not health_component.is_dead:
		found = _ray_interactable()
		if found == null:
			found = _proximity_interactable()
	interact_target = found
	var text: String = ""
	if found != null:
		if found.has_method("get_interact_prompt"):
			text = str(found.call("get_interact_prompt", self))
		else:
			text = "[E] ETKİLEŞİM"
	_set_prompt(found != null and text != "", text)


func _ray_interactable() -> Node:
	var origin: Vector3 = fps_camera.get_aim_origin()
	var dir: Vector3 = fps_camera.get_aim_direction()
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * INTERACT_RANGE, INTERACT_MASK, [get_rid()])
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return _resolve_interactable(hit.get("collider") as Object)


func _proximity_interactable() -> Node:
	var best: Node = null
	var best_d: float = INTERACT_PROXIMITY
	var fwd: Vector3 = -global_basis.z
	for n in get_tree().get_nodes_in_group("interactables"):
		if not (n is Node3D):
			continue
		var n3: Node3D = n as Node3D
		var to_n: Vector3 = n3.global_position - global_position
		to_n.y = 0.0
		var d: float = to_n.length()
		if d > best_d:
			continue
		if d > 0.5 and fwd.dot(to_n.normalized()) < 0.2:
			continue
		var resolved: Node = _resolve_interactable(n3)
		if resolved != null:
			best = resolved
			best_d = d
	return best


func _resolve_interactable(obj: Object) -> Node:
	if not (obj is Node):
		return null
	var cur: Node = obj as Node
	var depth: int = 0
	while cur != null and depth < 4:
		if cur.has_method("interact") and (cur.is_in_group("interactables") or depth == 0):
			if cur.has_method("can_interact") and not bool(cur.call("can_interact", self)):
				return null
			return cur
		cur = cur.get_parent()
		depth += 1
	return null


func _set_prompt(v: bool, text: String) -> void:
	if v == _prompt_visible and text == _prompt_text:
		return
	_prompt_visible = v
	_prompt_text = text
	interact_prompt_changed.emit(v, text)


# ------------------------------------------------------------------ death / ui / misc

func _on_died() -> void:
	beta_device.cancel_beta("player_dead")
	weapon_manager.set_ads(false)
	weapon_manager.cancel_reload()
	_set_prompt(false, "")
	set_controls_enabled(false)
	_sfx("sfx_player_die")
	var tw: Tween = create_tween()
	tw.tween_property(fps_camera, "position:y", 0.35, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if death_screen != null and death_screen.has_method("show_death"):
		death_screen.call("show_death")
	player_died.emit()


func _instance_ui(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	add_child(inst)
	if inst.has_method("setup"):
		inst.call("setup", self)
	elif inst.has_method("bind_player"):
		inst.call("bind_player", self)
	elif "player" in inst:
		inst.set("player", self)
	return inst


func _import_carryover() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var raw: Variant = gm.get("player_carryover")
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		import_state((raw as Dictionary).duplicate(true))


func _shake_enabled() -> bool:
	var s: Node = get_node_or_null("/root/SettingsManager")
	if s == null:
		return true
	return bool(s.get("camera_shake_enabled"))


func _sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play_sfx", sfx_name, volume_db, pitch_scale)
