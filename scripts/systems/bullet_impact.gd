class_name BulletImpact
extends Node3D
## Spark burst + light flash at a hit point. One-shot instances free themselves;
## pooled instances (WeaponManager impact pool) just go idle and get re-armed via setup().

const LIFETIME: float = 0.45
const FLASH_TIME: float = 0.12
const SPARK_COLOR: Color = Color(1.0, 0.78, 0.35, 1.0)
const FLESH_COLOR: Color = Color(0.95, 0.12, 0.18, 1.0)

static var _mat_spark: StandardMaterial3D = null
static var _mat_flesh: StandardMaterial3D = null

## When true the node is reused instead of freed at the end of its lifetime.
var pooled: bool = false
## True while the burst is playing.
var active: bool = false

@onready var sparks: CPUParticles3D = get_node_or_null("Sparks") as CPUParticles3D
@onready var flash: OmniLight3D = get_node_or_null("Flash") as OmniLight3D

var _age: float = 0.0
var _normal: Vector3 = Vector3.UP
var _flesh: bool = false
var _flash_energy: float = 2.5


func setup(normal: Vector3, is_flesh: bool = false) -> void:
	_normal = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	_flesh = is_flesh
	if is_node_ready():
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	_age = 0.0
	active = true
	visible = true
	set_process(true)
	var col: Color = FLESH_COLOR if _flesh else SPARK_COLOR
	if sparks != null:
		sparks.local_coords = false
		sparks.direction = _normal
		sparks.material_override = _shared_material(_flesh)
		sparks.restart()
		sparks.emitting = true
	if flash != null:
		flash.light_color = col
		flash.light_energy = _flash_energy
		flash.visible = true


static func _shared_material(is_flesh: bool) -> StandardMaterial3D:
	if is_flesh and _mat_flesh != null:
		return _mat_flesh
	if not is_flesh and _mat_spark != null:
		return _mat_spark
	var col: Color = FLESH_COLOR if is_flesh else SPARK_COLOR
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	if is_flesh:
		_mat_flesh = mat
	else:
		_mat_spark = mat
	return mat


func _process(delta: float) -> void:
	_age += delta
	if flash != null:
		flash.light_energy = maxf(_flash_energy * (1.0 - _age / FLASH_TIME), 0.0)
		if _age >= FLASH_TIME:
			flash.visible = false
	if _age >= LIFETIME:
		if pooled:
			_go_idle()
		else:
			queue_free()


func _go_idle() -> void:
	active = false
	visible = false
	if sparks != null:
		sparks.emitting = false
	set_process(false)
