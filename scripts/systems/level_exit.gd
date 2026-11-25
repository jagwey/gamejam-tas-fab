extends Area3D

@export var target_floor: int = 2
@export var prompt_text: String = "[E] Asansörle Üst Kata Çık"

func get_interact_prompt(_player: Node = null) -> String:
	return prompt_text

func interact(_player: Node) -> void:
	GameManager.load_floor(target_floor, true)
