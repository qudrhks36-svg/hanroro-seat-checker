extends CanvasLayer
# 옷장 창 (포팅 10단계, GDD 3번 [확정]): 집 안 옷장에서 E → 왼쪽에 옷 6벌 목록, 오른쪽에 천천히 도는 캐릭터 미리보기. 숫자 1~6 또는 클릭으로 입기, Esc/E로 닫기.
# 열려 있는 동안 시간이 멈추고 마우스가 보임(도감과 같은 방식). 입은 옷은 저장(Game.outfit), 1인칭 소매 색이 바뀜(outfit_view.gd).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const CharacterScript := preload("res://scripts/character.gd")

const PANEL := Vector2(860, 520)
const BROWN := Color(0.45, 0.30, 0.18)
const INK := Color(0.22, 0.15, 0.10)

var root: Control
var panel: Panel
var rows: Array = []        # {button, swatch, label, mark}
var preview_root: Node3D
var preview_char: Node3D
var is_open := false
var debug := false

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.ensure_loaded()
	_build()
	root.visible = false

func open() -> void:
	if is_open:
		return
	is_open = true
	Game.modal = "wardrobe"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root.visible = true
	panel.position = (get_viewport().get_visible_rect().size - PANEL) * 0.5
	_refresh()

func close(relock: bool) -> void:
	if not is_open:
		return
	is_open = false
	Game.modal = ""
	get_tree().paused = false
	root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if relock else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		close(false)   # Esc는 브라우저가 이미 마우스 잠금을 풀었으므로 다시 잠그지 않음
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		close(true)
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode < KEY_1 + Game.outfits.size():
		wear(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func wear(i: int) -> void:
	if i < 0 or i >= Game.outfits.size():
		return
	Game.outfit = i
	SaveScript.save_game()
	SfxScript.play("sell")
	_refresh()
	if debug:
		print("[FG] wardrobe wear ", i, " ", Game.outfits[i]["name"])

func _on_row_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		wear(i)

func _refresh() -> void:
	for i in rows.size():
		var worn := i == Game.outfit
		var r: Dictionary = rows[i]
		ThemeUI.set_box_color(r["bg"], Color(1.0, 0.93, 0.7) if worn else Color(1, 1, 1, 0.55))
		(r["mark"] as Label).text = "입는 중" if worn else ""
	if preview_char != null:
		preview_char.queue_free()
	preview_char = CharacterScript.build(Game.outfits[Game.outfit])
	preview_root.add_child(preview_char)

func _process(delta: float) -> void:
	if is_open:
		panel.position = (get_viewport().get_visible_rect().size - PANEL) * 0.5   # 화면 가운데(창 크기가 바뀌어도)
		if preview_char != null:
			preview_char.rotation.y += delta * 0.9

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	panel.size = PANEL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var title := ThemeUI.text("옷장", 34, BROWN, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(title)
	ThemeUI.at(title, PANEL, -310, 218, 200, 50)
	for i in Game.outfits.size():
		var o: Dictionary = Game.outfits[i]
		var bg := ThemeUI.box(Color(1, 1, 1, 0.55), 14)
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_child(bg)
		ThemeUI.at(bg, PANEL, -150, 150 - i * 64, 470, 56)
		var rs := Vector2(470, 56)
		var key := ThemeUI.box(BROWN, 14)
		bg.add_child(key)
		ThemeUI.at(key, rs, -208, 0, 40, 40)
		var kt := ThemeUI.text(str(i + 1), 24, Color.WHITE)
		key.add_child(kt)
		ThemeUI.at(kt, Vector2(40, 40), 0, 0, 40, 40)
		var sw := ThemeUI.box(CharacterScript.color_of(o["top"]), 10, Color(0.45, 0.30, 0.18, 0.6), 2)
		bg.add_child(sw)
		ThemeUI.at(sw, rs, -150, 0, 34, 34)
		var nm := ThemeUI.text(String(o["name"]), 28, INK, HORIZONTAL_ALIGNMENT_LEFT)
		bg.add_child(nm)
		ThemeUI.at(nm, rs, -20, 0, 220, 50)
		var mk := ThemeUI.text("", 22, Color(0.25, 0.55, 0.30), HORIZONTAL_ALIGNMENT_RIGHT)
		bg.add_child(mk)
		ThemeUI.at(mk, rs, 160, 0, 120, 50)
		bg.gui_input.connect(_on_row_input.bind(i))
		rows.append({"bg": bg, "mark": mk})

	# 오른쪽: 캐릭터 미리보기 (따로 만든 작은 3D 세계)
	var frame := ThemeUI.box(Color(0.80, 0.90, 0.95, 0.9), 18, Color(0.45, 0.30, 0.18, 0.5), 2)
	panel.add_child(frame)
	ThemeUI.at(frame, PANEL, 290, 20, 280, 400)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(svc)
	svc.position = Vector2(4, 4)
	svc.size = Vector2(272, 392)
	var sv := SubViewport.new()
	sv.size = Vector2i(272, 392)
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.process_mode = Node.PROCESS_MODE_ALWAYS
	svc.add_child(sv)
	preview_root = Node3D.new()
	sv.add_child(preview_root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.6)
	cam.fov = 38.0
	sv.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.9
	cam.environment = env
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_energy = 0.8
	sv.add_child(sun)

	var hint := ThemeUI.text("숫자 키 또는 클릭: 입기      Esc / E: 닫기", 22, Color(0.4, 0.3, 0.22))
	panel.add_child(hint)
	ThemeUI.at(hint, PANEL, 0, -240, 800, 34)
