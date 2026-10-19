extends RefCounted
# 화면 글자·판의 공통 색과 만드는 법 (유니티 UiTheme, GDD 9번 [확정] 힐링 톤): 크림색 둥근 판 + 진한 갈색 글자 + 글꼴 주아.

const CREAM := Color(1.0, 0.97, 0.90, 0.92)
const INK := Color(0.33, 0.23, 0.16)
const INK_SOFT := Color(0.50, 0.40, 0.32)
const EDGE := Color(0.45, 0.30, 0.18, 0.5)
const CORAL := Color(0.92, 0.38, 0.27)

static var _font: FontFile

# 주아 글꼴. 주아에 없는 기호(· … —)는 고닷 기본 글꼴로 대신 나오게 함 (웹에는 시스템 대체 글꼴이 없음)
static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/Jua-Regular.ttf")
		_font.fallbacks = [ThemeDB.fallback_font]
	return _font

# 크림색 둥근 판. 안에 줄(Label)들을 넣어 쓴다.
static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CREAM
	sb.set_corner_radius_all(16)
	sb.border_color = EDGE
	sb.set_border_width_all(2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func rect(color: Color, size: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = pos
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# 유니티 UGUI처럼 "부모 가운데 기준 좌표(위쪽이 +y)"로 놓는다: 가운데 (cx, cy), 크기 (w, h)
static func at(c: Control, parent_size: Vector2, cx: float, cy: float, w: float, h: float) -> void:
	c.size = Vector2(w, h)
	c.position = Vector2(parent_size.x * 0.5 + cx - w * 0.5, parent_size.y * 0.5 - cy - h * 0.5)
	c.pivot_offset = c.size * 0.5

# 둥근 모서리 상자 (색, 모서리 반지름, 테두리색, 테두리 두께)
static func box(color: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func set_box_color(p: Panel, color: Color) -> void:
	(p.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color

static func set_box_border(p: Panel, color: Color, w: int) -> void:
	var sb := p.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color = color
	sb.set_border_width_all(w)

# 칸 안에서 세로 가운데로 맞춘 글자
static func text(t: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(t, size, color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

# 물고기 등급 색 (도감 칸 테두리·결과 카드)
static func rarity_color(rarity_index: int) -> Color:
	match rarity_index:
		0: return Color(0.70, 0.85, 0.95)
		1: return Color(0.75, 0.90, 0.60)
		_: return Color(1.0, 0.85, 0.45)

static func rarity_name(rarity_index: int) -> String:
	return ["흔함", "보통", "희귀"][rarity_index]
