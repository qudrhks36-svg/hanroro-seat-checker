extends CanvasLayer
# 상태창 (GDD 9번 [확정]): 시간대·날씨·미끼·소지금·도감을 왼쪽 아래 크림색 둥근 판 하나에 `아이콘 + 글자` 줄로 모아 보여준다.
# 오늘의 목표 줄은 목표 기능(8단계)과 함께 붙는다.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const IconScript := preload("res://scripts/icons.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const WeatherScript := preload("res://scripts/weather.gd")

const ROWS := 4
const ROW_H := 46
const PAD := 12
const PANEL_W := 300
const BAIT_ICONS := ["worm", "shrimp", "bread"]
const TIME_ICONS := ["sun", "sunset", "moon"]
const TIME_NAMES := ["낮", "노을", "밤"]

var fishing
var time_icon
var time_text: Label
var weather_icon
var bait_icon
var bait_text: Label
var money_text: Label
var dex_text: Label
var shown_period := -1
var shown_weather := -1
var shown_bait := -1
var shown_money := -1
var shown_dex := -1

func _ready() -> void:
	layer = 4
	var panel := ThemeUI.box(ThemeUI.CREAM, 16, ThemeUI.EDGE, 2)
	panel.custom_minimum_size = Vector2(PANEL_W, PAD * 2 + ROW_H * ROWS)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)

	time_icon = _icon(panel, 0)
	time_text = _text(panel, 0, 190)
	weather_icon = _icon(panel, 0)
	weather_icon.position.x = PANEL_W - 14 - 36
	weather_icon.visible = false
	bait_icon = _icon(panel, 1)
	bait_text = _text(panel, 1, 130)
	var hint := _text(panel, 1, 70, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.position.x = PANEL_W - 14 - 70
	hint.text = "1·2·3"
	hint.add_theme_color_override("font_color", ThemeUI.INK_SOFT)
	var coin = _icon(panel, 2)
	coin.set_kind("coin")
	money_text = _text(panel, 2, 200)
	var book = _icon(panel, 3)
	book.set_kind("book")
	dex_text = _text(panel, 3, 200)

func _icon(parent: Control, row: int):
	var ic = IconScript.new()
	ic.position = Vector2(14, PAD + ROW_H * row + (ROW_H - 36) * 0.5)
	parent.add_child(ic)
	return ic

func _text(parent: Control, row: int, width: float, size: int = 26, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := ThemeUI.text("", size, ThemeUI.INK, align)
	l.size = Vector2(width, 40)
	l.position = Vector2(62, PAD + ROW_H * row + (ROW_H - 40) * 0.5)
	parent.add_child(l)
	return l

func _process(_delta: float) -> void:
	var period: int = TimeScript.period
	var weather: int = WeatherScript.current
	if period != shown_period or weather != shown_weather:
		shown_period = period
		shown_weather = weather
		time_icon.set_kind(TIME_ICONS[period])
		time_text.text = TIME_NAMES[period] if weather == WeatherScript.Kind.CLEAR else "%s · %s" % [TIME_NAMES[period], WeatherScript.kind_name(weather)]
		weather_icon.visible = weather != WeatherScript.Kind.CLEAR   # 맑음은 아이콘 없음
		weather_icon.set_kind("rain" if weather == WeatherScript.Kind.RAIN else "cloud")
	if fishing != null and fishing.selected_bait != shown_bait:
		shown_bait = fishing.selected_bait
		bait_icon.set_kind(BAIT_ICONS[shown_bait])
		bait_text.text = Game.baits[shown_bait]["name"]
	if Game.money != shown_money:
		shown_money = Game.money
		money_text.text = "%d원" % shown_money
	var found := 0
	for c in Game.counts:
		if c > 0:
			found += 1
	if found != shown_dex:
		shown_dex = found
		var done := found >= Game.fish.size()
		dex_text.text = "도감 완성!" if done else "도감 %d/%d" % [found, Game.fish.size()]
		dex_text.add_theme_color_override("font_color", Color(0.88, 0.52, 0.1) if done else ThemeUI.INK)
