extends CanvasLayer
# 설정 창 (GDD 4번 [확정], 사용자 요청 2026-10-19): Esc 또는 O로 열고 닫음. 열려 있는 동안 시간이 멈추고 마우스가 보임(도감과 같은 방식).
# 지금은 마우스 감도 슬라이더 하나(×0.3~×3.0, 기본 ×1.0 = 0.1도/픽셀). 값은 저장에 포함(SaveData의 mouseSens).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")

const PANEL := Vector2(560, 300)
const SENS_MIN := 0.3
const SENS_MAX := 3.0

static var is_open := false

var root: Control
var slider: HSlider
var value_text: Label

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS   # 시간이 멈춰도(일시정지) 입력을 받음
	_build()
	root.visible = false

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
		slider.value = Game.mouse_scale   # 마우스는 잠근 채로 둠
	else:
		SaveScript.save_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # 마우스 잠금은 오른쪽 버튼 끌기 중에만 (main.gd)

func set_sensitivity(v: float) -> void:
	Game.mouse_scale = clampf(v, SENS_MIN, SENS_MAX)
	value_text.text = "×%.1f" % Game.mouse_scale

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

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	panel.custom_minimum_size = PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	var brown := Color(0.45, 0.30, 0.18)
	var title := ThemeUI.text("설정", 36, brown, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(title)
	ThemeUI.at(title, PANEL, -150, 105, 220, 50)

	var lab := ThemeUI.text("마우스 감도", 26, ThemeUI.INK, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(lab)
	ThemeUI.at(lab, PANEL, -150, 30, 220, 40)
	value_text = ThemeUI.text("×1.0", 28, ThemeUI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(value_text)
	ThemeUI.at(value_text, PANEL, 150, 30, 160, 40)

	slider = HSlider.new()
	slider.min_value = SENS_MIN
	slider.max_value = SENS_MAX
	slider.step = 0.1
	slider.value = Game.mouse_scale
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
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
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var dot := _dot(15, ThemeUI.CORAL)
	slider.add_theme_icon_override("grabber", dot)
	slider.add_theme_icon_override("grabber_highlight", dot)
	slider.add_theme_icon_override("grabber_disabled", dot)
	panel.add_child(slider)
	ThemeUI.at(slider, PANEL, 0, -30, 480, 30)
	slider.value_changed.connect(_on_slider_changed)
	slider.drag_ended.connect(_on_drag_ended)
	set_sensitivity(Game.mouse_scale)

	var hint := ThemeUI.text("작게 = 천천히, 크게 = 빠르게      ← → 로 바꾸기      O / Esc: 닫기", 20, Color(0.4, 0.3, 0.22))
	panel.add_child(hint)
	ThemeUI.at(hint, PANEL, 0, -115, 520, 30)
