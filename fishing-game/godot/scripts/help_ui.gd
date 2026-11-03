extends CanvasLayer
# 조작 안내 카드 (사용자 선택 2026-11-03, UI 개선 3·4번): 처음 시작할 때 한 번 저절로 열리고(저장), 그 뒤로는 H로 열고 닫는다.
# 열려 있는 동안 시간이 멈춘다(도감·설정과 같은 방식). 시험 인자가 있으면 저절로 열리지 않는다(시험이 멈추지 않게).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")

const PANEL := Vector2(660, 460)
const LINES := [
	["WASD / Space", "걷기 / 점프"],
	["오른쪽 버튼 누른 채 끌기", "시점 돌리기"],
	["R, 왼쪽 클릭", "낚싯대 꺼내서 던지기"],
	["느낌표(!)가 뜨면", "다시 클릭, 릴은 꾹 누르기"],
	["E", "말 걸기 · 줍기 · 배 타기"],
	["Tab / O / H", "도감 / 설정 / 이 안내"],
]

static var is_open := false

var root: Control
var opened_at := 0.0

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	root.visible = false

func auto_open_first_time() -> void:
	if not Game.intro_seen and OS.get_cmdline_user_args().is_empty():
		await get_tree().create_timer(1.0).timeout
		set_open(true)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Game.modal != "" and Game.modal != "help":
		return
	if event.keycode == KEY_H:
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_E, KEY_SPACE]:
		set_open(false)
		get_viewport().set_input_as_handled()

func _on_click(event: InputEvent) -> void:
	if is_open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_open(false)

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	Game.modal = "help" if open else ""
	root.visible = open
	get_tree().paused = open
	if not open and not Game.intro_seen:
		Game.intro_seen = true
		SaveScript.save_game()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_click)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var panel := ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)   # 화면 크기가 바뀌어도 가운데에 고정(앵커 기준 오프셋)
	panel.offset_left = -PANEL.x * 0.5
	panel.offset_right = PANEL.x * 0.5
	panel.offset_top = -PANEL.y * 0.5
	panel.offset_bottom = PANEL.y * 0.5
	var brown := Color(0.45, 0.30, 0.18)
	var title := ThemeUI.text("조작 안내", 36, brown)
	panel.add_child(title)
	ThemeUI.at(title, PANEL, 0, 190, 400, 50)
	for i in LINES.size():
		var y := 118.0 - i * 52.0
		var key := ThemeUI.text(LINES[i][0], 24, ThemeUI.CORAL, HORIZONTAL_ALIGNMENT_RIGHT)
		panel.add_child(key)
		ThemeUI.at(key, PANEL, -170, y, 300, 44)
		var what := ThemeUI.text(LINES[i][1], 22, ThemeUI.INK, HORIZONTAL_ALIGNMENT_LEFT)
		panel.add_child(what)
		ThemeUI.at(what, PANEL, 165, y, 320, 44)
	var hint := ThemeUI.text("H / E / Esc / 클릭: 닫기", 20, Color(0.4, 0.3, 0.22))
	panel.add_child(hint)
	ThemeUI.at(hint, PANEL, 0, -200, 500, 30)
