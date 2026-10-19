extends Control
# 상태창 아이콘 (유니티는 코드로 그린 작은 그림): 이미지 파일 없이 36x36 칸에 도형으로 그린다.
# 종류: sun sunset moon / worm shrimp bread / coin book flag heart heart_off / cloud rain

var kind := ""

func _init() -> void:
	custom_minimum_size = Vector2(36, 36)
	size = Vector2(36, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	var c := Vector2(18, 18)
	match kind:
		"sun":
			draw_circle(c, 8.5, Color(1.0, 0.82, 0.2))
			for i in 8:
				var a := i * PI / 4.0
				draw_line(c + Vector2(cos(a), sin(a)) * 12.0, c + Vector2(cos(a), sin(a)) * 16.5, Color(1.0, 0.7, 0.1), 2.6)
		"sunset":
			var pts := PackedVector2Array()
			for i in 25:
				var a := PI + PI * i / 24.0
				pts.append(Vector2(18 + 10.0 * cos(a), 25 + 10.0 * sin(a)))
			draw_colored_polygon(pts, Color(1.0, 0.58, 0.25))
			draw_line(Vector2(3, 25), Vector2(33, 25), Color(0.85, 0.45, 0.25), 2.6)
			draw_line(Vector2(9, 30), Vector2(27, 30), Color(0.95, 0.65, 0.45), 2.0)
		"moon":
			draw_circle(c, 11.5, Color(1.0, 0.93, 0.55))
			draw_circle(c + Vector2(6, -4), 9.5, Color(1.0, 0.97, 0.9))   # 크림 판 색으로 파내 초승달 모양
		"worm":
			var pts2 := PackedVector2Array()
			for i in 15:
				var x := 4.0 + i * 1.9
				pts2.append(Vector2(x, 18.0 + 5.5 * sin(x * 0.55)))
			draw_polyline(pts2, Color(0.93, 0.55, 0.62), 6.0, true)
			draw_circle(pts2[14], 3.4, Color(0.88, 0.42, 0.52))
		"shrimp":
			draw_arc(Vector2(17, 17), 10.5, -0.6, 3.4, 24, Color(1.0, 0.55, 0.35), 6.5, true)
			draw_circle(Vector2(26, 9), 2.2, Color(0.25, 0.1, 0.05))
			draw_line(Vector2(8, 24), Vector2(4, 30), Color(1.0, 0.55, 0.35), 3.0)
		"bread":
			draw_rect(Rect2(6, 14, 24, 13), Color(0.87, 0.62, 0.32))
			draw_circle(Vector2(12, 14), 6.5, Color(0.87, 0.62, 0.32))
			draw_circle(Vector2(24, 14), 6.5, Color(0.87, 0.62, 0.32))
			draw_line(Vector2(9, 20), Vector2(27, 20), Color(0.7, 0.45, 0.2), 1.8)
		"coin":
			draw_circle(c, 14.0, Color(1.0, 0.8, 0.2))
			draw_arc(c, 10.5, 0.0, TAU, 28, Color(0.8, 0.58, 0.1), 2.2, true)
			draw_line(Vector2(18, 10), Vector2(18, 26), Color(0.8, 0.58, 0.1), 3.2)
		"book":
			draw_rect(Rect2(7, 4, 23, 28), Color(0.74, 0.3, 0.28))
			draw_rect(Rect2(10, 8, 17, 20), Color(1.0, 0.96, 0.88))
			draw_line(Vector2(13, 13), Vector2(24, 13), Color(0.74, 0.3, 0.28), 2.0)
			draw_line(Vector2(13, 18), Vector2(24, 18), Color(0.74, 0.3, 0.28), 2.0)
		"heart", "heart_off":
			var hc := Color(0.93, 0.35, 0.42) if kind == "heart" else Color(0.82, 0.74, 0.68)
			draw_circle(Vector2(12, 14), 7.5, hc)
			draw_circle(Vector2(24, 14), 7.5, hc)
			draw_colored_polygon(PackedVector2Array([Vector2(5.2, 16.5), Vector2(30.8, 16.5), Vector2(18, 31)]), hc)
		"flag":
			draw_rect(Rect2(9, 4, 3, 28), Color(0.72, 0.55, 0.35))
			draw_rect(Rect2(12, 4, 19, 13), Color(0.95, 0.4, 0.3))
		"cloud", "rain":
			var col := Color(0.78, 0.83, 0.88) if kind == "cloud" else Color(0.6, 0.66, 0.74)
			draw_circle(Vector2(12, 17), 7.0, col)
			draw_circle(Vector2(20, 13), 8.5, col)
			draw_circle(Vector2(27, 18), 6.0, col)
			draw_rect(Rect2(12, 17, 15, 7), col)
			if kind == "rain":
				for x in [11.0, 18.0, 25.0]:
					draw_line(Vector2(x, 27), Vector2(x - 2, 33), Color(0.4, 0.6, 0.92), 2.4)
