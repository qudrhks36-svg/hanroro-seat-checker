extends CanvasLayer
# 낚은 물고기 결과 카드 (GDD 9번 [확정] ①③, 유니티 ResultCard): 물고기가 찌 자리에서 포물선으로 튀어올라 카드 그림 자리로 들어가고,
# 카드가 팝업으로 나타났다가 서서히 사라진다. 새로 잡았거나 기록을 깼으면 "NEW! 도감 등록"/"기록 갱신!" 배지, 새로 잡았거나 희귀하면 반짝이는 조각이 퍼진다.
# 시간은 실제 시간(Time.get_ticks_msec)으로 진행해서 일시정지·배속과 상관없이 같은 속도로 보인다.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")

const CARD := Vector2(560, 184)
const JUMP_TIME := 0.8
const POP_START := 0.6
const POP_TIME := 0.35
const HOLD_TIME := 3.5
const FADE_TIME := 0.5
const CARD_Y := 110.0          # 화면 가운데에서 위로 (유니티 좌표)
const ICON_X := -190.0

var card: Panel
var icon_bg: Panel
var icon: TextureRect
var name_text: Label
var size_text: Label
var chip: Panel
var chip_text: Label
var price_text: Label
var new_badge: Panel
var new_text: Label
var goal_badge: Panel
var jumper: TextureRect
var sparks: Array = []
var textures: Array = []
var t0 := -999.0
var jump_from := Vector2.ZERO
var show_sparks := false

func _ready() -> void:
	layer = 7
	Game.ensure_loaded()
	for f in Game.fish:
		textures.append(load("res://assets/fish/" + f["image_file"]))
	_build()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# 낚았을 때 FishingRod가 부른다. bobber_screen = 찌의 화면 위치(튀어오르는 시작 자리).
func show_result(fish_index: int, is_new: bool, cm: int, is_record: bool, bobber_screen: Vector2, goal_done: bool = false) -> void:
	var f: Dictionary = Game.fish[fish_index]
	var rc := ThemeUI.rarity_color(Game.rarity_index(fish_index))
	ThemeUI.set_box_color(icon_bg, rc)
	icon.texture = textures[fish_index]
	jumper.texture = textures[fish_index]
	name_text.text = f["name"]
	ThemeUI.set_box_color(chip, rc.lerp(Color.WHITE, 0.25))
	chip_text.text = ThemeUI.rarity_name(Game.rarity_index(fish_index))
	price_text.text = "판매 값 %d원" % Game.price(fish_index)
	size_text.text = "%dcm" % cm if cm > 0 else ""
	new_text.text = "NEW! 도감 등록" if is_new else "기록 갱신!"
	new_badge.visible = is_new or is_record
	goal_badge.visible = goal_done
	show_sparks = is_new or is_record or goal_done or Game.rarity_index(fish_index) == 2
	jump_from = bobber_screen
	for s in sparks:
		s.visible = false
	t0 = _now()
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * 0.6

func _process(_delta: float) -> void:
	var t := _now() - t0
	var total := POP_START + POP_TIME + HOLD_TIME + FADE_TIME
	if t > total:
		card.modulate.a = 0.0
		jumper.visible = false
		return
	var vp := get_viewport().get_visible_rect().size
	# 물고기가 찌 자리에서 포물선으로 튀어올라 카드 그림 자리로 들어감
	var target := Vector2(vp.x * 0.5 + ICON_X, vp.y * 0.5 - CARD_Y)
	if t < JUMP_TIME:
		var k := t / JUMP_TIME
		jumper.visible = true
		var p := jump_from.lerp(target, smoothstep(0.0, 1.0, k)) + Vector2.UP * sin(k * PI) * 200.0
		jumper.position = p - jumper.size * 0.5
		jumper.rotation = -TAU * k
		jumper.scale = Vector2.ONE * (1.0 + 0.5 * sin(k * PI))
	else:
		jumper.visible = false

	# 카드 팝업(살짝 튀어나왔다 자리잡음) → 유지 → 사라짐
	var pt := clampf((t - POP_START) / POP_TIME, 0.0, 1.0)
	var back := 1.0 + 2.2 * pow(pt - 1.0, 3.0) + 1.2 * pow(pt - 1.0, 2.0)   # easeOutBack
	card.scale = Vector2.ONE * lerpf(0.6, 1.0, back)
	var fade := 1.0 - clampf((t - (POP_START + POP_TIME + HOLD_TIME)) / FADE_TIME, 0.0, 1.0)
	card.modulate.a = 0.0 if t < POP_START else clampf(pt * 3.0, 0.0, 1.0) * fade
	card.position = Vector2((vp.x - CARD.x) * 0.5, vp.y * 0.5 - CARD_Y - CARD.y * 0.5)

	# 반짝이는 조각: 새로 잡았거나 희귀하면 카드 그림 둘레로 퍼짐
	if show_sparks:
		var st := (t - POP_START) / 1.0
		for i in sparks.size():
			var on := st > 0.0 and st < 1.0
			sparks[i].visible = on
			if not on:
				continue
			var a := i / 12.0 * TAU
			var r := 80.0 + 70.0 * sqrt(st) + (i % 2) * 14.0
			var center := Vector2(CARD.x * 0.5 + ICON_X, CARD.y * 0.5)
			sparks[i].position = center + Vector2(cos(a), -sin(a)) * r - sparks[i].size * 0.5
			sparks[i].scale = Vector2.ONE * ((1.0 - st) * (0.7 + 0.5 * (i % 3) / 2.0))
			sparks[i].modulate = Color(1, 1, 1, 1.0 - st)

# ---- 화면 만들기 (카드 안 좌표는 카드 가운데 기준, 위쪽이 +y) ----
func _build() -> void:
	card = ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 20, Color(0.45, 0.30, 0.18, 0.9), 3)
	card.size = CARD
	card.pivot_offset = CARD * 0.5
	card.modulate.a = 0.0
	add_child(card)

	icon_bg = ThemeUI.box(Color.WHITE, 16)
	card.add_child(icon_bg)
	ThemeUI.at(icon_bg, CARD, ICON_X, 0, 150, 150)
	icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.add_child(icon)
	ThemeUI.at(icon, Vector2(150, 150), 0, 0, 132, 110)

	var title := ThemeUI.text("낚았다!", 24, Color(0.45, 0.30, 0.18), HORIZONTAL_ALIGNMENT_LEFT)
	card.add_child(title)
	ThemeUI.at(title, CARD, 70, 62, 330, 32)
	name_text = ThemeUI.text("", 46, Color(0.22, 0.15, 0.10), HORIZONTAL_ALIGNMENT_LEFT)
	card.add_child(name_text)
	ThemeUI.at(name_text, CARD, 70, 14, 330, 60)
	size_text = ThemeUI.text("", 34, Color(0.62, 0.38, 0.12), HORIZONTAL_ALIGNMENT_RIGHT)   # 이름 줄 오른쪽 끝에 크기(cm)
	card.add_child(size_text)
	ThemeUI.at(size_text, CARD, 70, 14, 330, 60)
	chip = ThemeUI.box(Color.WHITE, 14)
	card.add_child(chip)
	ThemeUI.at(chip, CARD, -30, -42, 96, 36)
	chip_text = ThemeUI.text("", 22, Color(0.22, 0.15, 0.10))
	chip.add_child(chip_text)
	ThemeUI.at(chip_text, Vector2(96, 36), 0, 0, 96, 36)
	price_text = ThemeUI.text("", 24, Color(0.22, 0.15, 0.10), HORIZONTAL_ALIGNMENT_LEFT)
	card.add_child(price_text)
	ThemeUI.at(price_text, CARD, 135, -42, 200, 36)

	new_badge = ThemeUI.box(Color(0.95, 0.45, 0.25), 14, Color(0.55, 0.2, 0.08), 2)
	card.add_child(new_badge)
	ThemeUI.at(new_badge, CARD, 185, 90, 190, 42)
	new_badge.rotation_degrees = -6.0
	new_text = ThemeUI.text("NEW! 도감 등록", 24, Color.WHITE)
	new_badge.add_child(new_text)
	ThemeUI.at(new_text, Vector2(190, 42), 0, 0, 190, 42)

	goal_badge = ThemeUI.box(Color(1.0, 0.82, 0.28), 14, Color(0.55, 0.38, 0.08), 2)   # 목표를 채웠을 때만 카드 아래에 붙는 금색 띠
	card.add_child(goal_badge)
	ThemeUI.at(goal_badge, CARD, 0, -CARD.y * 0.5 - 30.0, 360, 44)
	var goal_text := ThemeUI.text("오늘의 목표 달성!  +%d원" % Game.goal_reward, 26, Color(0.22, 0.15, 0.10))
	goal_badge.add_child(goal_text)
	ThemeUI.at(goal_text, Vector2(360, 44), 0, 0, 360, 44)
	goal_badge.visible = false

	for i in 12:   # 반짝이는 조각(마름모)
		var s := ThemeUI.box(Color(1.0, 0.92, 0.5), 2)
		s.size = Vector2(18, 18)
		s.pivot_offset = Vector2(9, 9)
		s.rotation_degrees = 45.0
		s.visible = false
		card.add_child(s)
		sparks.append(s)

	jumper = TextureRect.new()
	jumper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jumper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	jumper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jumper.size = Vector2(120, 90)
	jumper.pivot_offset = jumper.size * 0.5
	jumper.visible = false
	add_child(jumper)
