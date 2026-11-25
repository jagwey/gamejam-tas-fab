extends Area3D

const ENDING := "res://scenes/cutscenes/ending_cutscene.tscn"
var is_active := false
var _shutting_down := false

func _ready() -> void:
	_bind_volkov.call_deferred()

func _bind_volkov() -> void:
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss.has_signal("boss_defeated"):
			if boss.get("is_dead") == true:
				activate_console()
			elif not boss.is_connected("boss_defeated", activate_console):
				boss.connect("boss_defeated", activate_console)

func get_interact_prompt(_player: Node = null) -> String:
	if is_active:
		return "[E] BETA REAKTÖRÜNÜ GÜVENCEYE AL VE SAVUNMAYI KAPAT"
	return "BETA REAKTÖRÜ KİLİTLİ — ÖNCE VOLKOV'U YEN"

func activate_console() -> void:
	is_active = true
	$Indicator.light_color = Color("#54fff2")
	$Indicator.light_energy = 3.0
	var screen := $Display.material_override as StandardMaterial3D
	screen.emission = Color("#46f7e0")
	screen.albedo_color = Color("#46f7e0")
	$Readout.text = "ERİŞİM AÇIK"
	$Readout.modulate = Color("#042323")

func interact(_player: Node) -> void:
	if not is_active or _shutting_down:
		return
	_shutting_down = true
	AudioManager.play_sfx("sfx_reactor_shutdown")
	GameManager.update_boss_bar("", 0.0, 1.0, false)
	_shutdown.call_deferred()

func _shutdown() -> void:
	var result := get_tree().change_scene_to_file(ENDING)
	if result != OK:
		_shutting_down = false
		push_error("Reaktör kapanış sahnesi açılamadı: %s" % error_string(result))
