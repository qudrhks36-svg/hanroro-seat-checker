extends CanvasLayer
# 꾸미기 창 (포팅 7-3, GDD 9번 [확정], 유니티 DecorShop): 바틀이 대화창에서 F를 누르면 열린다. 숫자 키 1~5 = 장식 사기, 6 = 오두막 키우기, F/Esc = 닫기.
# 바틀이 대화창이 이미 시간을 멈추고 마우스를 풀어 둔 상태라 그대로 두고, 이 창은 입력만 가로챈다(대화창은 Game.decor_open일 때 입력을 무시).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const PANEL := Vector2(820, 540)
const BROWN := Color(0.45, 0.30, 0.18)
const INK := Color(0.22, 0.15, 0.10)
const GREEN := Color(0.25, 0.55, 0.30)
const POOR := Color(0.6, 0.35, 0.3)
const ROWS := 6

var root: Control
var money_label: Label
var msg_label: Label
var names: Array = []
var infos: Array = []
var states: Array = []
var debug := false

func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.ensure_loaded()
	_build()
	root.visible = false

func open() -> void:
	if Game.decor_open:
		return
	Game.decor_open = true
	root.visible = true
	msg_label.text = "숫자 키로 사요. 산 물건은 바로 섬에 놓여요."
	_refresh()

func close() -> void:
	Game.decor_open = false
	root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not Game.decor_open or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_F:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
		buy(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func buy(i: int) -> void:
	if i < 5:
		if Game.owns(i):
			msg_label.text = "이미 있는 물건이에요."
		elif Game.buy_item(i):
			_done("와… %s이(가) 생겼어요!" % Game.home_items[i]["name"])
		else:
			msg_label.text = "돈이 모자라요. %d원이 필요해요." % int(Game.home_items[i]["price"])
	else:
		if Game.cabin_max():
			msg_label.text = "오두막은 더 키울 수 없어요."
		elif Game.buy_cabin():
			_done("오두막이 %s(으)로 바뀌었어요!" % Game.cabins[Game.cabin_level]["name"])
		else:
			msg_label.text = "돈이 모자라요. %d원이 필요해요." % int(Game.cabins[Game.cabin_level + 1]["price"])
	_refresh()

func _done(message: String) -> void:
	msg_label.text = message
	SaveScript.save_game()
	SfxScript.play("upgrade")

func _refresh() -> void:
	money_label.text = "소지금 %d원" % Game.money
	for i in 5:
		var it: Dictionary = Game.home_items[i]
		names[i].text = it["name"]
		infos[i].text = it["info"]
		var own := Game.owns(i)
		states[i].text = "보유 중" if own else "%d원" % int(it["price"])
		states[i].add_theme_color_override("font_color", GREEN if own else (INK if Game.money >= int(it["price"]) else POOR))
	names[5].text = "오두막 키우기"
	if Game.cabin_max():
		infos[5].text = "지금: %s" % Game.cabins[Game.cabin_level]["name"]
		states[5].text = "다 키웠어요"
		states[5].add_theme_color_override("font_color", GREEN)
	else:
		var nx := Game.cabin_level + 1
		infos[5].text = "%s%s" % [Game.cabins[nx]["name"], " (새 지붕, 굴뚝)" if nx == 1 else " (깃발, 등불, 창문 불빛)"]
		states[5].text = "%d원" % int(Game.cabins[nx]["price"])
		states[5].add_theme_color_override("font_color", INK if Game.money >= int(Game.cabins[nx]["price"]) else POOR)
	if debug:
		print("[FG] decor shop msg=", msg_label.text, " | money=", Game.money, " mask=", Game.decor_mask, " cabin=", Game.cabin_level, " | ", states.map(func(s): return s.text))

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

	var title := ThemeUI.text("집 꾸미기", 34, BROWN, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(title)
	ThemeUI.at(title, PANEL, -30, 232, 520, 50)
	money_label = ThemeUI.text("", 26, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(money_label)
	ThemeUI.at(money_label, PANEL, 250, 232, 300, 50)

	for i in ROWS:
		var y := 160.0 - i * 62.0
		var row := ThemeUI.box(Color(1.0, 0.93, 0.7) if i == ROWS - 1 else Color(1, 1, 1, 0.55), 14)
		panel.add_child(row)
		ThemeUI.at(row, PANEL, 0, y, 780, 56)
		var rs := Vector2(780, 56)
		var key := ThemeUI.box(BROWN, 14)
		row.add_child(key)
		ThemeUI.at(key, rs, -355, 0, 40, 40)
		var kt := ThemeUI.text(str(i + 1), 24, Color.WHITE)
		key.add_child(kt)
		ThemeUI.at(kt, Vector2(40, 40), 0, 0, 40, 40)
		var n := ThemeUI.text("", 28, INK, HORIZONTAL_ALIGNMENT_LEFT)
		row.add_child(n)
		ThemeUI.at(n, rs, -185, 0, 200, 50)
		var inf := ThemeUI.text("", 19, Color(0.4, 0.3, 0.22), HORIZONTAL_ALIGNMENT_LEFT)
		row.add_child(inf)
		ThemeUI.at(inf, rs, 85, 0, 330, 50)
		var st := ThemeUI.text("", 26, INK, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(st)
		ThemeUI.at(st, rs, 310, 0, 140, 50)
		names.append(n)
		infos.append(inf)
		states.append(st)
	msg_label = ThemeUI.text("", 24, BROWN)
	panel.add_child(msg_label)
	ThemeUI.at(msg_label, PANEL, 0, -218, 780, 40)
	var foot := ThemeUI.text("숫자 키: 사기      F / Esc: 닫기", 22, Color(0.4, 0.3, 0.22))
	panel.add_child(foot)
	ThemeUI.at(foot, PANEL, 0, -250, 780, 36)
