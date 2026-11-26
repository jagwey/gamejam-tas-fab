extends Area3D

@export var target_floor: int = 2
@export var prompt_text: String = "[E] Asansörle Üst Kata Çık"
var _triggered: bool = false

func get_interact_prompt(_player: Node = null) -> String:
	return prompt_text

func interact(_player: Node) -> void:
	if _triggered:
		return
	_triggered = true
	GameManager.load_floor(target_floor, true)
