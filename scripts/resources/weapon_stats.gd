class_name WeaponStats
extends Resource
## Data definition for one player weapon.

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var slot_index: int = 1
@export var is_melee: bool = false
@export var damage: float = 10.0
@export var pellets: int = 1
@export var spread_deg: float = 0.0
@export var fire_cooldown: float = 0.25
@export var reload_duration: float = 1.0
@export var magazine_size: int = 0
@export var max_reserve: int = 0
@export var range_meters: float = 60.0
@export var recoil_pitch_deg: float = 1.0
@export var recoil_kick: float = 0.05
@export var ads_fov_offset: float = 0.0
@export var fire_sfx: String = ""
@export var reload_sfx: String = ""
