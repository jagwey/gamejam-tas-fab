class_name PickupItem
extends Area3D
## Layer-4 interactable pickup. [E] to collect (or auto_pickup on touch).
## Interactable contract (shared with LockedDoor / LoreTerminal / LevelExit):
##   get_interact_prompt(player: Node) -> String
##   can_interact(player: Node) -> bool
##   interact(player: Node) -> void

signal picked_up(pickup: PickupItem, player: Node)

enum PickupType { AMMO, WEAPON, HEALTH }

@export var pickup_type: PickupType = PickupType.AMMO
@export var weapon_id: String = "pistol"
@export var amount: int = 12
@export var auto_pickup: bool = false
@export var prompt_override: String = ""
@export var bob_height: float = 0.12
@export var spin_speed: float = 1.6

var _collected: bool = false
var _t: float = 0.0
var _visual_base_y: float = 0.0

@onready var visual: Node3D = get_node_or_null("Visual") as Node3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitorable = true
	monitoring = auto_pickup
	add_to_group("interactables")
	if auto_pickup:
		body_entered.connect(_on_body_entered)
	_t = randf() * TAU
	if visual != null:
		_visual_base_y = visual.position.y


func _process(delta: float) -> void:
	if visual == null:
		return
	_t += delta
	visual.position.y = _visual_base_y + sin(_t * 2.2) * bob_height
	visual.rotate_y(spin_speed * delta)


func get_interact_prompt(_player: Node) -> String:
	if prompt_override != "":
		return prompt_override
	match pickup_type:
		PickupType.WEAPON:
			return "[E] SİLAHI AL"
		PickupType.HEALTH:
			return "[E] MEDKİT AL"
		_:
			return "[E] MÜHİMMAT AL (+%d)" % amount


func can_interact(_player: Node) -> bool:
	return not _collected


func interact(player: Node) -> void:
	if _collected or player == null:
		return
	if _apply_to(player):
		_collected = true
		picked_up.emit(self, player)
		_sfx("sfx_pickup")
		queue_free()
	else:
		_sfx("sfx_ui_deny")


func _apply_to(player: Node) -> bool:
	var wm: Node = player.get("weapon_manager") as Node
	match pickup_type:
		PickupType.WEAPON:
			if wm == null:
				return false
			wm.call("unlock_weapon", weapon_id, true)
			if amount > 0:
				wm.call("add_ammo", weapon_id, amount)
			return true
		PickupType.HEALTH:
			var hc: HealthComponent = player.get("health_component") as HealthComponent
			if hc == null:
				return false
			return hc.heal(float(amount)) > 0.0
		_:
			if wm == null:
				return false
			var added: int = int(wm.call("add_ammo", weapon_id, amount))
			return added > 0


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		interact(body)


func _sfx(sfx_name: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play_sfx", sfx_name)
