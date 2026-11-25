class_name BulletImpact
extends Node3D
## One-shot spark burst + light flash at a hit point. Frees itself.

const LIFETIME: float = 0.45
const SPARK_COLOR: Color = Color(1.0, 0.78, 0.35, 1.0)
const FLESH_COLOR: Color = Color(0.95, 0.12, 0.18, 1.0)

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
	var col: Color = FLESH_COLOR if _flesh else SPARK_COLOR
	if sparks != null:
		sparks.local_coords = false
		sparks.direction = _normal
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 3.0
		sparks.material_override = mat
		sparks.restart()
		sparks.emitting = true
	if flash != null:
		flash.light_color = col
		flash.light_energy = _flash_energy


func _process(delta: float) -> void:
	_age += delta
	if flash != null:
		flash.light_energy = maxf(_flash_energy * (1.0 - _age / 0.12), 0.0)
	if _age >= LIFETIME:
		queue_free()
