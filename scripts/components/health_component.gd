class_name HealthComponent
extends Node
## Plain health pool. No passive regeneration — healing only through heal().

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0
@export var current_health: float = 100.0
var is_dead: bool = false
## When true, take_damage() is ignored (cutscenes, debug).
var invulnerable: bool = false


func _ready() -> void:
	max_health = maxf(max_health, 1.0)
	current_health = clampf(current_health, 0.0, max_health)
	is_dead = current_health <= 0.0


func take_damage(amount: float) -> float:
	if is_dead or invulnerable or amount <= 0.0:
		return 0.0
	var before: float = current_health
	current_health = maxf(current_health - amount, 0.0)
	var dealt: float = before - current_health
	damaged.emit(dealt)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		died.emit()
	return dealt


func heal(amount: float) -> float:
	if is_dead or amount <= 0.0 or current_health >= max_health:
		return 0.0
	var before: float = current_health
	current_health = minf(current_health + amount, max_health)
	var gained: float = current_health - before
	if gained > 0.0:
		healed.emit(gained)
		health_changed.emit(current_health, max_health)
	return gained


func is_full() -> bool:
	return current_health >= max_health


func get_ratio() -> float:
	return current_health / maxf(max_health, 0.001)


## Hard set (used for carryover / setup). Does not emit damaged/healed.
func set_health(value: float, new_max: float = -1.0) -> void:
	if new_max > 0.0:
		max_health = new_max
	current_health = clampf(value, 0.0, max_health)
	is_dead = current_health <= 0.0
	health_changed.emit(current_health, max_health)


func reset_full(new_max: float = -1.0) -> void:
	if new_max > 0.0:
		max_health = new_max
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)
