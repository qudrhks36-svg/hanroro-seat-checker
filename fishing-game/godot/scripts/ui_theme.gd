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
