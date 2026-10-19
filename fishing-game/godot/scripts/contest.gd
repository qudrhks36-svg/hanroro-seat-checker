extends CanvasLayer
# 낚시 대회 (포팅 8단계, GDD 9번 [확정], 유니티 Contest): 바틀이에게서 C로 시작하는 3분 기록 도전. 점수 = 대회 중 잡은 가장 큰 물고기의 크기(cm).
# 시간은 delta로 세므로 대화창·도감이 열려 있으면(일시정지) 멈춘다. 상금/기록 저장은 data/economy.json contest 규칙 그대로.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const FarSeaScript := preload("res://scripts/far_sea.gd")

const DURATION := 180.0
const CARD_SECONDS := 7.0
const INK := Color(0.22, 0.15, 0.10)

var fishing
var time_left := 0.0
var card_until := 0.0
var pill: Panel
var pill_text: Label
var card: Panel
var card_title: Label
var card_fish: Label
var card_prize: Label

func setup(fishing_node) -> void:
	fishing = fishing_node
	process_mode = Node.PROCESS_MODE_ALWAYS   # 카드 사라짐은 실제 시간으로, 대회 시간은 멈춤 중에는 세지 않음
	layer = 6
	Game.ensure_loaded()
	_build()
	pill.visible = false
	card.visible = false

# 낚싯대를 거두고 있고 이미 진행 중이 아닐 때만 시작할 수 있다.
func can_start() -> bool:
	return not Game.contest_active and fishing != null and fishing.is_idle() and not FarSeaScript.busy

func begin() -> void:
	if not can_start():
		return
	Game.contest_active = true
	Game.contest_cm = 0
	Game.contest_fish = -1
	time_left = DURATION
	card.visible = false
	card_until = 0.0
	SfxScript.play("upgrade")

func _process(delta: float) -> void:
	if Game.contest_active:
		if not get_tree().paused:
			time_left = maxf(0.0, time_left - delta)
		# 시간이 다 됐을 때 입질·릴 감기 중이면 그 한 마리까지만 끝내고 마감
		if time_left <= 0.0 and not fishing.is_hooked():
			finish()
		else:
			_refresh_pill()
	pill.visible = Game.contest_active
	if card_until > 0.0 and Time.get_ticks_msec() / 1000.0 > card_until:
		card.visible = false
		card_until = 0.0

func _refresh_pill() -> void:
	var s := ceili(time_left)
	var best := "최고 %s %dcm" % [Game.fish[Game.contest_fish]["name"], Game.contest_cm] if Game.contest_fish >= 0 else "아직 한 마리도 없어요"
	pill_text.text = "낚시 대회 %d:%02d · %s" % [s / 60, s % 60, best]

func finish() -> void:
	Game.contest_active = false
	var prize: int
	var record := false
	var got := Game.contest_fish >= 0
	if not got:
		prize = 10   # 참가상
	else:
		prize = 100 if Game.contest_cm >= 100 else (50 if Game.contest_cm >= 50 else 20)
		if Game.contest_cm > Game.contest_best:
			Game.contest_best = Game.contest_cm
			prize += 30
			record = true
	Game.money += prize
	SaveScript.save_game()
	SfxScript.play("new_fish" if record else "goal_done")
	card_title.text = "대회 신기록!" if record else "대회 끝!"
	card_title.add_theme_color_override("font_color", ThemeUI.CORAL if record else INK)
	card_fish.text = "가장 큰 물고기: %s %dcm" % [Game.fish[Game.contest_fish]["name"], Game.contest_cm] if got else "이번엔 한 마리도 못 잡았어요"
	card_prize.text = "%s +%d원%s" % ["상금" if got else "참가상", prize, " (신기록 보너스 포함)" if record else ""]
	card.visible = true
	card_until = Time.get_ticks_msec() / 1000.0 + CARD_SECONDS
	pill.visible = false
	print("[FG] contest finish got=", got, " cm=", Game.contest_cm, " prize=", prize, " record=", record, " best=", Game.contest_best, " money=", Game.money)

func _build() -> void:
	pill = ThemeUI.box(ThemeUI.CREAM, 16, ThemeUI.EDGE, 2)
	pill.custom_minimum_size = Vector2(430, 52)
	add_child(pill)
	pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	pill_text = ThemeUI.text("", 26, ThemeUI.INK)
	pill_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill_text.clip_text = true
	pill.add_child(pill_text)
	pill_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var csize := Vector2(620, 230)
	card = ThemeUI.box(ThemeUI.CREAM, 16, ThemeUI.EDGE, 2)
	card.custom_minimum_size = csize
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	card.position.y -= 40
	card_title = ThemeUI.text("", 40, INK)
	card.add_child(card_title)
	ThemeUI.at(card_title, csize, 0, 72, 600, 56)
	card_fish = ThemeUI.text("", 30, INK)
	card.add_child(card_fish)
	ThemeUI.at(card_fish, csize, 0, 8, 600, 44)
	card_prize = ThemeUI.text("", 30, ThemeUI.INK_SOFT)
	card.add_child(card_prize)
	ThemeUI.at(card_prize, csize, 0, -56, 600, 44)
