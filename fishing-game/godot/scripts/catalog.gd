extends CanvasLayer
# Tab으로 여는 도감 (GDD 9번 [확정] 도감 고도화, 유니티 CatalogUI): 크림색 둥근 판, 위쪽 진행 막대, 왼쪽 상세 카드(그림·이름·칩·기록),
# 오른쪽 4x4 둥근 칸(등급 색 테두리, 못 잡은 건 실루엣). 열려 있는 동안 게임 시간이 멈추고 마우스 커서가 나타난다.
# 좌표는 유니티와 같은 "판 가운데 기준, 위쪽이 +y" 값을 그대로 쓴다(ThemeUI.at).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")

const PANEL := Vector2(900, 540)
const BAR_W := 440.0
const BROWN := Color(0.45, 0.30, 0.18)
const INK := Color(0.22, 0.15, 0.10)
const UNKNOWN_BORDER := Color(0.78, 0.72, 0.62)
const UNKNOWN_TEXT := Color(0.55, 0.47, 0.38)
const SILHOUETTE := Color(0.15, 0.12, 0.10, 0.8)

static var is_open := false

var root: Control
var panel: Panel
var count_text: Label
var progress_fill: Panel
var name_text: Label
var hint_text: Label
var caught_value: Label
var best_value: Label
var price_value: Label
var big_bg: Panel
var big_picture: TextureRect
var rarity_chip: Panel
var rarity_chip_text: Label
var far_chip: Panel
var cells: Array = []          # 칸(Panel)
var cell_icons: Array = []
var cell_texts: Array = []
var textures: Array = []
var selected := 0
var debug := false   # 시험용: 도감 상태를 로그로 찍음

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # 시간이 멈춰도(일시정지) 입력을 받음
	Game.ensure_loaded()
	for f in Game.fish:
		textures.append(load("res://assets/fish/" + f["image_file"]))
	_build()
	root.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if Game.modal != "" and Game.modal != "catalog":
			return   # 다른 창(설정·대화)이 열려 있으면 무시
		if event.keycode == KEY_TAB:
			set_open(not is_open, true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open:
			set_open(false, false)   # Esc는 브라우저가 이미 마우스 잠금을 풀었으므로 다시 잠그지 않고 클릭으로 시작하게 둠
			get_viewport().set_input_as_handled()

func set_open(open: bool, relock: bool) -> void:
	is_open = open
	Game.modal = "catalog" if open else ""
	root.visible = open
	get_tree().paused = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if relock else Input.MOUSE_MODE_VISIBLE

func _refresh() -> void:
	var found := 0
	for c in Game.counts:
		if c > 0:
			found += 1
	var total := Game.fish.size()
	count_text.text = "%d / %d" % [found, total]
	progress_fill.size.x = maxf(24.0, BAR_W * found / total)   # 최소 폭 = 둥근 모서리가 찌그러지지 않게
	progress_fill.visible = found > 0
	for i in total:
		var got: bool = Game.counts[i] > 0
		ThemeUI.set_box_color(cells[i], ThemeUI.rarity_color(Game.rarity_index(i)) if got else UNKNOWN_BORDER)
		cell_icons[i].modulate = Color.WHITE if got else SILHOUETTE   # 못 잡은 물고기는 어두운 실루엣
		cell_texts[i].text = Game.fish[i]["name"] if got else "???"
		cell_texts[i].add_theme_color_override("font_color", INK if got else UNKNOWN_TEXT)
		var sel := i == selected
		cells[i].scale = Vector2.ONE * (1.07 if sel else 1.0)
		ThemeUI.set_box_border(cells[i], Color(0.35, 0.22, 0.12) if sel else Color(0, 0, 0, 0), 3 if sel else 0)
	var f: Dictionary = Game.fish[selected]
	var seen: bool = Game.counts[selected] > 0
	var rc := ThemeUI.rarity_color(Game.rarity_index(selected))
	ThemeUI.set_box_color(big_bg, rc if seen else UNKNOWN_BORDER)
	big_picture.texture = textures[selected]
	big_picture.modulate = Color.WHITE if seen else SILHOUETTE
	name_text.text = f["name"] if seen else "???"
	rarity_chip.visible = seen
	far_chip.visible = seen and bool(f["far_sea"])
	if seen:
		ThemeUI.set_box_color(rarity_chip, rc.lerp(Color.WHITE, 0.1))
		rarity_chip_text.text = ThemeUI.rarity_name(Game.rarity_index(selected))
		ThemeUI.at(rarity_chip, Vector2(360, 410), -62.0 if bool(f["far_sea"]) else 0.0, -68.0, 96, 32)   # 먼 바다 칩이 없으면 등급 칩이 가운데
	caught_value.text = "%d마리" % Game.counts[selected] if seen else "—"
	best_value.text = "%dcm" % Game.best_cm[selected] if seen else "—"
	price_value.text = "%d원" % Game.price(selected) if seen else "—"
	if debug:
		print("[FG] catalog selected=", selected, " name=", name_text.text, " found=", count_text.text, " caught=", caught_value.text, " best=", best_value.text, " price=", price_value.text)
	hint_text.text = "칸을 클릭하면 물고기를 볼 수 있어요      Tab / Esc: 닫기" if seen else "아직 못 잡았어요. 낚아서 도감을 채워 보세요      Tab / Esc: 닫기"

func _on_cell_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = i
		_refresh()

# ---- 화면 만들기 ----
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	panel.custom_minimum_size = PANEL
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title := ThemeUI.text("도감", 36, BROWN, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(title)
	ThemeUI.at(title, PANEL, -290, 238, 220, 50)
	var bar_bg := ThemeUI.box(Color(0.86, 0.78, 0.66), 13)
	panel.add_child(bar_bg)
	ThemeUI.at(bar_bg, PANEL, 150, 238, BAR_W, 26)
	progress_fill = ThemeUI.box(Color(1.0, 0.8, 0.3), 13)
	panel.add_child(progress_fill)
	ThemeUI.at(progress_fill, PANEL, 150 - BAR_W / 2.0 + BAR_W / 2.0, 238, BAR_W, 26)
	progress_fill.position.x = PANEL.x * 0.5 + 150 - BAR_W * 0.5   # 왼쪽 끝 고정, 폭만 변함
	count_text = ThemeUI.text("", 22, INK)
	panel.add_child(count_text)
	ThemeUI.at(count_text, PANEL, 150, 238, 200, 30)

	# 왼쪽 상세 카드 (360x410, 판 가운데 기준 (-255,-18))
	var card_size := Vector2(360, 410)
	var card := ThemeUI.box(Color(1, 1, 1, 0.55), 16)
	panel.add_child(card)
	ThemeUI.at(card, PANEL, -255, -18, card_size.x, card_size.y)
	big_bg = ThemeUI.box(Color.WHITE, 14)
	card.add_child(big_bg)
	ThemeUI.at(big_bg, card_size, 0, 95, 320, 190)
	big_picture = TextureRect.new()
	big_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big_bg.add_child(big_picture)
	ThemeUI.at(big_picture, Vector2(320, 190), 0, 0, 290, 170)
	name_text = ThemeUI.text("", 38, INK)
	card.add_child(name_text)
	ThemeUI.at(name_text, card_size, 0, -22, 330, 44)
	rarity_chip = ThemeUI.box(Color.WHITE, 14)
	card.add_child(rarity_chip)
	ThemeUI.at(rarity_chip, card_size, -30, -68, 96, 32)
	rarity_chip_text = ThemeUI.text("", 22, INK)
	rarity_chip.add_child(rarity_chip_text)
	ThemeUI.at(rarity_chip_text, Vector2(96, 32), 0, 0, 96, 34)
	far_chip = ThemeUI.box(Color(0.35, 0.5, 0.72), 14)
	card.add_child(far_chip)
	ThemeUI.at(far_chip, card_size, 80, -68, 110, 32)
	var far_text := ThemeUI.text("먼 바다", 20, Color.WHITE)
	far_chip.add_child(far_text)
	ThemeUI.at(far_text, Vector2(110, 32), 0, 0, 110, 34)
	var labels := ["잡은 수", "최고 기록", "판매 값"]
	for i in 3:
		var y := -113.0 - i * 36.0
		var line := ThemeUI.box(Color(0.45, 0.3, 0.18, 0.18), 1)
		card.add_child(line)
		ThemeUI.at(line, card_size, 0, y + 19, 320, 2)
		var lab := ThemeUI.text(labels[i], 22, BROWN, HORIZONTAL_ALIGNMENT_LEFT)
		card.add_child(lab)
		ThemeUI.at(lab, card_size, -70, y, 170, 34)
		var val := ThemeUI.text("", 24, INK, HORIZONTAL_ALIGNMENT_RIGHT)
		card.add_child(val)
		ThemeUI.at(val, card_size, 80, y, 160, 34)
		match i:
			0: caught_value = val
			1: best_value = val
			_: price_value = val

	# 오른쪽 칸(4열 4줄)
	for i in Game.fish.size():
		var cx := 12.5 + (i % 4) * 117.0
		var cy := 138.0 - (i / 4) * 102.0
		var cell := ThemeUI.box(UNKNOWN_BORDER, 16)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_cell_input.bind(i))
		panel.add_child(cell)
		ThemeUI.at(cell, PANEL, cx, cy, 105, 92)
		var inner := ThemeUI.box(Color(1, 0.98, 0.93), 14)
		cell.add_child(inner)
		ThemeUI.at(inner, Vector2(105, 92), 0, 0, 97, 84)
		var icon := TextureRect.new()
		icon.texture = textures[i]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		ThemeUI.at(icon, Vector2(97, 84), 0, 12, 82, 50)
		var lt := ThemeUI.text("", 18, INK)
		inner.add_child(lt)
		ThemeUI.at(lt, Vector2(97, 84), 0, -29, 97, 24)
		cells.append(cell)
		cell_icons.append(icon)
		cell_texts.append(lt)
	hint_text = ThemeUI.text("", 20, Color(0.4, 0.3, 0.22))
	panel.add_child(hint_text)
	ThemeUI.at(hint_text, PANEL, 0, -250, 840, 30)
