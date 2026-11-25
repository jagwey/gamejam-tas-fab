class_name EnemyStats
extends Resource
## Data definition for one enemy archetype / level.

@export var enemy_id: String = ""
@export var display_name: String = ""
@export var level: int = 1
@export var max_health: float = 40.0
@export var damage: float = 5.0
@export var attack_interval: float = 1.0
@export var windup_duration: float = 0.35
@export var move_speed: float = 3.5
@export var patrol_speed: float = 1.8
@export var detection_range: float = 18.0
@export var attack_range: float = 12.0
@export var enemy_type: String = ""
@export var sprite_prefix: String = ""
@export var can_harvest_beta: bool = true
@export var projectile_spread_deg: float = 3.5
@export var tint_color: Color = Color.WHITE
## Shots fired per attack (1 = single shot).
@export var burst_count: int = 1
## Seconds between shots inside a burst.
@export var burst_interval: float = 0.11
## 0..1 — chance-weighted reduction of hit-stagger (heavies shrug off small hits).
@export var stagger_resistance: float = 0.0
