extends CanvasLayer
# 성능 점검 표시 (사용자 요청 2026-10-22: 렉이 심함 → 어디서 느린지 숫자로 보기). F3로 켜고 끈다. 창이 열려 시간이 멈춰도 계속 갱신.
# FPS는 최근 1초 평균/가장 느렸던 프레임, 그림 호출(draw call)·물체·삼각형은 그 프레임에 그린 양. 자리는 유니티 좌표(x,z).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")

var player: Node3D
var label: Label
var frames: Array = []     # [시각, 프레임 시간(초)] 최근 1초
var acc := 0.0

func setup(player_node: Node3D) -> void:
	player = player_node
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	label = ThemeUI.label("", 18, Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(12, 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		label.visible = not label.visible

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	frames.append([now, delta])
	while frames.size() > 0 and now - float(frames[0][0]) > 1.0:
		frames.pop_front()
	acc += delta
	if not label.visible or acc < 0.25:
		return
	acc = 0.0
	var worst := 0.0
	var sum := 0.0
	for f in frames:
		worst = maxf(worst, float(f[1]))
		sum += float(f[1])
	var avg_fps := frames.size() / maxf(sum, 0.0001)
	var p := player.global_position if player != null else Vector3.ZERO
	label.text = "FPS %d (최저 %d)  프레임 %.1fms\n그림 호출 %d · 물체 %d · 삼각형 %dK\n노드 %d\n자리 x=%.0f z=%.0f" % [
		roundi(avg_fps), roundi(1.0 / maxf(worst, 0.0001)), worst * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) / 1000,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		p.x, -p.z]
