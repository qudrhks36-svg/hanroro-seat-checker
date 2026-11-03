extends CanvasLayer
# 설정 창 (GDD 4번 [확정], 사용자 요청 2026-10-19): Esc 또는 O로 열고 닫음. 열려 있는 동안 시간이 멈추고 마우스가 보임(도감과 같은 방식).
# 마우스 감도(×0.3~×3.0, 기본 ×1.0 = 0.1도/픽셀)·소리 크기(0~100%)·그림 품질(하/중/상). 값은 저장에 포함(SaveData의 mouseSens·volume·quality).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")

const PANEL := Vector2(560, 440)
const QUALITY_NAMES := ["하", "중", "상"]
const QUALITY_SCALE := [0.65, 0.8, 1.0]   # 3D 그림 크기 배율
const SENS_MIN := 0.3
const SENS_MAX := 3.0

static var is_open := false

var root: Control
var slider: HSlider
var value_text: Label
var vol_slider: HSlider
var vol_text: Label
var q_slider: HSlider
var q_text: Label

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS   # 시간이 멈춰도(일시정지) 입력을 받음
	_build()
	root.visible = false
	apply_volume.call_deferred()
	apply_quality.call_deferred()   # 저장에서 읽은 값을 처음에 적용 (해 빛이 만들어진 뒤)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Game.modal != "" and Game.modal != "settings":
		return   # 다른 창(도감·대화)이 열려 있으면 그 창이 Esc를 처리
	if event.keycode == KEY_O:
		set_open(not is_open, true)
		get_viewport().set_input_as_handled()
	elif is_open and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT):   # ← → 로 감도 바꾸기(마우스를 잠근 채로 쓰게)
		slider.value = clampf(slider.value + (0.1 if event.keycode == KEY_RIGHT else -0.1), SENS_MIN, SENS_MAX)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		set_open(not is_open, false)   # Esc는 브라우저가 이미 마우스 잠금을 풀었으므로 다시 잠그지 않고 클릭으로 시작하게 둠
		get_viewport().set_input_as_handled()

func set_open(open: bool, relock: bool) -> void:
	if open == is_open:
		return
	is_open = open
	Game.modal = "settings" if open else ""
	root.visible = open
	get_tree().paused = open
	if open:
		slider.value = Game.mouse_scale
		vol_slider.value = Game.volume * 100.0
		q_slider.value = Game.quality
	else:
		SaveScript.save_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # 마우스 잠금은 오른쪽 버튼 끌기 중에만 (main.gd)

func set_sensitivity(v: float) -> void:
	Game.mouse_scale = clampf(v, SENS_MIN, SENS_MAX)
	value_text.text = "×%.1f" % Game.mouse_scale

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Game.volume, 0.0001)))   # Master 버스. 음소거(M)와 따로 동작
	if vol_text != null:
		vol_text.text = "%d%%" % roundi(Game.volume * 100.0)

func apply_quality() -> void:
	var q: int = Game.quality
	get_viewport().scaling_3d_scale = QUALITY_SCALE[q]
	for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		(l as DirectionalLight3D).shadow_enabled = q > 0
	if q_text != null:
		q_text.text = QUALITY_NAMES[q]

func set_volume(v: float) -> void:
	Game.volume = clampf(v / 100.0, 0.0, 1.0)
	apply_volume()

func set_quality(q: int) -> void:
	Game.quality = clampi(q, 0, 2)
	apply_quality()

func _on_slider_changed(v: float) -> void:
	set_sensitivity(v)

func _on_drag_ended(_changed: bool) -> void:
	SaveScript.save_game()   # 놓는 순간 저장 (창을 안 닫고 페이지를 떠나도 남음)

# 슬라이더 손잡이용 동그라미 그림(이미지 파일 없이 만듦)
static func _dot(radius: int, color: Color) -> ImageTexture:
	var d := radius * 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - radius, y + 0.5 - radius).length()
			var a := clampf(radius - dist, 0.0, 1.0)   # 가장자리 부드럽게
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)

func _make_slider(panel: Control, lo: float, hi: float, step: float, val: float, y: float) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = val
	sl.mouse_filter = Control.MOUSE_FILTER_STOP
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.86, 0.78, 0.66)
	track.set_corner_radius_all(6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.8, 0.3)
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var dot := _dot(15, ThemeUI.CORAL)
	sl.add_theme_icon_override("grabber", dot)
	sl.add_theme_icon_override("grabber_highlight", dot)
	sl.add_theme_icon_override("grabber_disabled", dot)
	panel.add_child(sl)
	ThemeUI.at(sl, PANEL, 0, y, 480, 30)
	return sl

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)   # 화면 크기가 바뀌어도 가운데(앵커 기준 오프셋)
	panel.offset_left = -PANEL.x * 0.5
	panel.offset_right = PANEL.x * 0.5
	panel.offset_top = -PANEL.y * 0.5
	panel.offset_bottom = PANEL.y * 0.5

	var brown := Color(0.45, 0.30, 0.18)
	var title := ThemeUI.text("설정", 36, brown, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(title)
	ThemeUI.at(title, PANEL, -150, 185, 220, 50)

	var lab := ThemeUI.text("마우스 감도", 26, ThemeUI.INK, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(lab)
	ThemeUI.at(lab, PANEL, -150, 120, 220, 40)
	value_text = ThemeUI.text("×1.0", 28, ThemeUI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(value_text)
	ThemeUI.at(value_text, PANEL, 150, 120, 160, 40)

	slider = _make_slider(panel, SENS_MIN, SENS_MAX, 0.1, Game.mouse_scale, 75)
	slider.value_changed.connect(_on_slider_changed)
	slider.drag_ended.connect(_on_drag_ended)
	var vlab := ThemeUI.text("소리 크기", 26, ThemeUI.INK, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(vlab)
	ThemeUI.at(vlab, PANEL, -150, 20, 220, 40)
	vol_text = ThemeUI.text("100%", 28, ThemeUI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(vol_text)
	ThemeUI.at(vol_text, PANEL, 150, 20, 160, 40)
	vol_slider = _make_slider(panel, 0.0, 100.0, 10.0, Game.volume * 100.0, -20)
	vol_slider.value_changed.connect(set_volume)
	vol_slider.drag_ended.connect(_on_drag_ended)
	var qlab := ThemeUI.text("그림 품질", 26, ThemeUI.INK, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(qlab)
	ThemeUI.at(qlab, PANEL, -150, -75, 220, 40)
	q_text = ThemeUI.text("중", 28, ThemeUI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(q_text)
	ThemeUI.at(q_text, PANEL, 150, -75, 160, 40)
	q_slider = _make_slider(panel, 0.0, 2.0, 1.0, Game.quality, -115)
	q_slider.value_changed.connect(func(v: float) -> void: set_quality(int(v)))
	q_slider.drag_ended.connect(_on_drag_ended)
	apply_volume()
	apply_quality()
	set_sensitivity(Game.mouse_scale)

	var hint := ThemeUI.text("감도: 좌우 방향키로도 바꿔요      O / Esc: 닫기", 20, Color(0.4, 0.3, 0.22))
	panel.add_child(hint)
	ThemeUI.at(hint, PANEL, 0, -185, 520, 30)
