extends Control

signal cutscene_finished
signal cutscene_skipped

const SKIP_HOLD_REQUIRED: float = 5.0
const SHOTS: Array[Array] = [
	["General", "Aydın. Seni rahatsız etmek istemezdim.", "general_portrait"],
	["Aydın", "Beni burada bulduysanız önemli bir şey olmuş demektir.", "aydin_village"],
	["General", "Beta Reaktörü çalındı. Volkov'un elinde.", "general_portrait"],
	["Aydın", "Ben artık asker değilim, komutanım.", "aydin_village"],
	["General", "Biliyorum. Ama bu görevi tamamlayabilecek çok az insan kaldı.", "general_portrait"],
	["", "General, deneysel yenilenme cihazını Aydın'a gösterir.", "beta_device_closeup"],
	["Aydın", "Bunu daha önce bir insan üzerinde denediniz mi?", "aydin_village"],
	["General", "Başarılı sonuç aldığımız bir insan üzerinde mi? Hayır.", "general_portrait"],
	["Aydın", "İçimi rahatlattınız, komutanım.", "aydin_village"],
	["General (Telsiz)", "Hedef beş katlı holding binası. Çatıdaki deneysel savunma sistemi hava desteğini engelliyor. Reaktörü en üst kattan geri al.", "general_portrait"],
	["", "Aydın binaya doğru bakar.", "aydin_visor"],
	["Aydın", "Beş kat. Bir reaktör. Bir de eve dönmek var.", "aydin_visor"],
]
var skip_hold_time: float = 0.0
var has_finished: bool = false
var shot_index: int = 0
var remaining: float = 0.0
var pan: Tween
var textures: Dictionary = {}

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_music("bgm_menu_cutscene")
	_show_shot()
	_update_skip_display()

func _art(stem: String) -> Texture2D:
	if not textures.has(stem):
		var texture: Texture2D = null
		for directory in ["res://assets/sprites/cutscenes/", "res://assets/portraits/", "res://assets/textures/"]:
			var path: String = str(directory) + stem + ".png"
			if ResourceLoader.exists(path):
				texture = load(path) as Texture2D
				break
		textures[stem] = texture
	return textures[stem] as Texture2D

func _show_shot() -> void:
	var tower: bool = shot_index >= 9
	if shot_index == 0 or shot_index == 9:
		%Location.text = "Holding Binasının Önü" if tower else "Köy Evi"
		%Background.texture = _art("bg_tower_exterior" if tower else "bg_village_house")
		%Rain.visible = tower
		if pan:
			pan.kill()
		%Background.position = Vector2(-15, -14)
		%Background.scale = Vector2.ONE
		pan = create_tween().set_parallel(true)
		var duration: float = 17.0 if tower else 38.0
		pan.tween_property(%Background, "position", Vector2(-66, -35), duration)
		pan.tween_property(%Background, "scale", Vector2(1.045, 1.045), duration)
	var line: Array = SHOTS[shot_index]
	%Radio.visible = shot_index == 9
	%Speaker.text = str(line[0]).to_upper()
	%Dialogue.text = str(line[1])
	%Portrait.texture = _art(str(line[2]))
	remaining = maxf(3.4, 1.6 + float(str(line[1]).length()) / 15.0)
	if shot_index == 5:
		AudioManager.play_sfx("sfx_beta_start")

func _process(delta: float) -> void:
	if has_finished:
		return
	var pressed: bool = Input.is_key_pressed(KEY_SPACE)
	simulate_space_hold(delta, pressed)
	if pressed or has_finished:
		return
	remaining -= delta
	if remaining <= 0.0:
		advance_line()

func _input(event: InputEvent) -> void:
	if has_finished:
		return
	if event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		if not event.pressed:
			simulate_space_hold(0.0, false)
		return
	var enter: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if click or enter or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance_line()

func advance_line() -> void:
	if has_finished:
		return
	shot_index += 1
	if shot_index >= SHOTS.size():
		finish_cutscene()
	else:
		_show_shot()

func simulate_space_hold(dt: float, pressed: bool) -> void:
	if has_finished:
		return
	skip_hold_time = minf(SKIP_HOLD_REQUIRED, skip_hold_time + maxf(dt, 0.0)) if pressed else 0.0
	_update_skip_display()
	if skip_hold_time >= SKIP_HOLD_REQUIRED:
		cutscene_skipped.emit()
		finish_cutscene()

func get_skip_progress() -> float:
	return skip_hold_time / SKIP_HOLD_REQUIRED

func _update_skip_display() -> void:
	%SkipBar.value = get_skip_progress() * 100.0
	%Skip.text = "SAHNEYİ ATLAMAK İÇİN [SPACE] BASILI TUTUN (%.1f / 5.0 sn)" % skip_hold_time

func finish_cutscene() -> void:
	if has_finished:
		return
	has_finished = true
	cutscene_finished.emit()
	GameManager.load_floor(1, true)
