extends Node3D
# 집 안 (포팅 10단계, GDD 3번 [확정]): 오두막 문에서 E → 화면이 어두워졌다 밝아지며 섬 밖에 만든 작은 방으로 이동. 방 안: 침대(E 잠자기 = 다음 시간대로 넘김),
# 옷장(E = 옷장 창), 문(E = 밖으로). 방은 임시 도형(상자 등)으로 만들고 나중에 블렌더 모델로 교체한다. 좌표는 모두 고닷 좌표(z 반전).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const DOOR_OUT := Vector3(-8.0, 0.88, -3.68)         # 오두막 문 가운데 (유니티 (-8, 1.1, 3.1)을 집 0.8배로 줄인 자리)
const STAND_OUT := Vector3(-8.0, 0.0, -2.0)         # 나왔을 때 서는 자리
const ROOM := Vector3(400, 0, 0)                     # 방 바닥 가운데 (섬 밖)
const ROOM_W := 6.0
const ROOM_D := 5.0
const ROOM_H := 2.8
const ENTER_DISTANCE := 2.8                          # 문 가운데까지의 거리
const FADE_TIME := 0.5
const TOAST_HOLD := 4.0
const STAND_HEIGHT := 1.05
const FADE_COLOR := Color(0.03, 0.05, 0.1)
const WAKE_CLOCKS := [300.0, 450.0, 20.0]            # 자고 나면: 낮→노을(300초) 노을→밤(450초) 밤→낮(20초)
const WAKE_NAMES := ["노을", "밤", "아침"]

static var inside := false     # 방 안에 있나
static var busy := false       # 이동·잠자기(페이드) 중

var cam: Camera3D
var player: CharacterBody3D
var fishing
var tod: Node
var weather: Node
var wardrobe
var prompt: PanelContainer
var prompt_label: Label
var toast: PanelContainer
var toast_label: Label
var fade: ColorRect
var toast_t0 := -999.0
var window_mat: StandardMaterial3D
var targets: Array = []       # 방 안에서 E로 하는 것들 {id, pos, text, range}
var current_target := ""
var assume_captured := false  # 시험용: 마우스 잠금 없이도 잠긴 것으로 침
var debug := false

static func reset() -> void:
	inside = false
	busy = false

func setup(camera: Camera3D, player_node: CharacterBody3D, fishing_node, tod_node: Node, weather_node: Node, wardrobe_node) -> void:
	reset()
	cam = camera
	player = player_node
	fishing = fishing_node
	tod = tod_node
	weather = weather_node
	wardrobe = wardrobe_node
	_build_room()
	_build_ui()

# ---- 방 (임시 도형) ----
func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, collide: bool = false, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	if emissive:
		m.emission_enabled = true
		m.emission = color
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi

func _build_room() -> void:
	var room := Node3D.new()
	room.name = "Room"
	room.position = ROOM
	add_child(room)
	var wood := Color(0.72, 0.52, 0.32)
	var wall := Color(0.96, 0.90, 0.78)
	_box(room, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0, -0.1, 0), wood, true)                      # 바닥
	_box(room, Vector3(ROOM_W + 0.4, 0.2, ROOM_D + 0.4), Vector3(0, ROOM_H + 0.1, 0), Color(0.99, 0.95, 0.88), true)   # 천장
	_box(room, Vector3(ROOM_W, ROOM_H, 0.2), Vector3(0, ROOM_H * 0.5, -ROOM_D * 0.5 - 0.1), wall, true)       # 안쪽(북) 벽
	_box(room, Vector3(ROOM_W, ROOM_H, 0.2), Vector3(0, ROOM_H * 0.5, ROOM_D * 0.5 + 0.1), wall, true)        # 문 쪽(남) 벽
	_box(room, Vector3(0.2, ROOM_H, ROOM_D), Vector3(-ROOM_W * 0.5 - 0.1, ROOM_H * 0.5, 0), wall, true)       # 왼쪽 벽
	_box(room, Vector3(0.2, ROOM_H, ROOM_D), Vector3(ROOM_W * 0.5 + 0.1, ROOM_H * 0.5, 0), wall, true)        # 오른쪽 벽
	_box(room, Vector3(1.0, 2.0, 0.08), Vector3(0, 1.0, ROOM_D * 0.5 - 0.04), Color(0.45, 0.30, 0.18))       # 문
	_box(room, Vector3(0.12, 0.12, 0.1), Vector3(0.35, 1.0, ROOM_D * 0.5 - 0.1), Color(0.95, 0.8, 0.3))     # 문고리
	# 창문(안쪽 벽): 틀 + 시간대에 따라 색이 바뀌는 유리
	_box(room, Vector3(1.9, 1.3, 0.06), Vector3(0, 1.6, -ROOM_D * 0.5 + 0.03), Color(0.55, 0.38, 0.24))
	var glass := _box(room, Vector3(1.7, 1.1, 0.07), Vector3(0, 1.6, -ROOM_D * 0.5 + 0.04), Color(0.75, 0.9, 1.0), false, true)
	window_mat = glass.material_override
	window_mat.emission_energy_multiplier = 1.6
	_box(room, Vector3(1.7, 0.06, 0.09), Vector3(0, 1.6, -ROOM_D * 0.5 + 0.045), Color(0.55, 0.38, 0.24))
	# 러그
	var rug := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 1.2
	cyl.height = 0.03
	rug.mesh = cyl
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.93, 0.55, 0.50)
	rm.roughness = 1.0
	rug.material_override = rm
	rug.position = Vector3(0.3, 0.015, 0.2)
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(rug)
	# 침대(왼쪽 안쪽): 틀 + 매트리스 + 이불 + 베개
	_box(room, Vector3(1.1, 0.35, 2.1), Vector3(-2.2, 0.175, -1.3), Color(0.55, 0.38, 0.24), true)
	_box(room, Vector3(1.0, 0.2, 2.0), Vector3(-2.2, 0.45, -1.3), Color(0.95, 0.92, 0.85))
	_box(room, Vector3(1.02, 0.22, 1.2), Vector3(-2.2, 0.47, -0.8), Color(0.45, 0.7, 0.85))
	_box(room, Vector3(0.6, 0.14, 0.38), Vector3(-2.2, 0.62, -2.05), Color(1.0, 0.98, 0.95))
	# 옷장(오른쪽 벽)
	_box(room, Vector3(0.7, 2.1, 1.4), Vector3(2.55, 1.05, -0.4), Color(0.58, 0.40, 0.26), true)
	_box(room, Vector3(0.04, 1.9, 0.03), Vector3(2.19, 1.05, -0.4), Color(0.35, 0.24, 0.15))
	for z in [-0.55, -0.25]:
		_box(room, Vector3(0.05, 0.12, 0.05), Vector3(2.18, 1.05, z), Color(0.95, 0.8, 0.3))
	# 천장 등불
	_box(room, Vector3(0.25, 0.25, 0.25), Vector3(0, ROOM_H - 0.2, 0), Color(1.0, 0.9, 0.6), false, true)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, ROOM_H - 0.5, 0)
	lamp.light_color = Color(1.0, 0.88, 0.62)
	lamp.light_energy = 1.4
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	room.add_child(lamp)
	targets = [
		{"id": "exit", "pos": ROOM + Vector3(0, 1.1, ROOM_D * 0.5 - 0.1), "text": "E: 밖으로 나가기", "range": 2.4},
		{"id": "bed", "pos": ROOM + Vector3(-2.2, 0.5, -1.3), "text": "E: 잠자기 (다음 시간대로)", "range": 2.6},
		{"id": "wardrobe", "pos": ROOM + Vector3(2.5, 1.1, -0.4), "text": "E: 옷장 열기", "range": 2.6},
	]

# ---- 매 프레임 ----
func _process(_delta: float) -> void:
	_update_window()
	var t := Time.get_ticks_msec() / 1000.0
	var tt := t - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
	var free := not busy and Game.modal == "" and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or assume_captured)
	current_target = ""
	var text := ""
	if free:
		if inside:
			var best_dot := 0.0
			for tg in targets:
				var to: Vector3 = (tg["pos"] as Vector3) - cam.global_position
				if to.length() > float(tg["range"]):
					continue
				var d := (-cam.global_transform.basis.z).dot(to.normalized())
				if d > 0.5 and d > best_dot:
					best_dot = d
					current_target = tg["id"]
					text = tg["text"]
		else:
			var to := (DOOR_OUT) - cam.global_position
			if to.length() <= ENTER_DISTANCE and (-cam.global_transform.basis.z).dot(to.normalized()) > 0.5:
				current_target = "enter"
				text = "E: 집에 들어가기" if fishing.is_idle() else "낚싯줄을 먼저 거둬 주세요"
	prompt.visible = current_target != ""
	if prompt.visible:
		prompt_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and prompt.visible):
		return
	match current_target:
		"enter":
			if fishing.is_idle():
				enter()
		"exit":
			leave()
		"bed":
			sleep()
		"wardrobe":
			wardrobe.open()
	get_viewport().set_input_as_handled()

# 시간대·시각에 맞춰 창문 유리 색
func _update_window() -> void:
	if window_mat == null:
		return
	var k := smoothstep(0.0, 1.0, TimeScript.night)
	var day := Color(0.75, 0.9, 1.0) if TimeScript.period != TimeScript.Period.SUNSET else Color(1.0, 0.7, 0.45)
	var c := day.lerp(Color(0.1, 0.13, 0.28), k)
	window_mat.albedo_color = c
	window_mat.emission = c

# ---- 이동 ----
func enter() -> void:
	if busy:
		return
	busy = true
	await _fade(0.0, 1.0)
	player.global_position = ROOM + Vector3(0, STAND_HEIGHT, ROOM_D * 0.5 - 1.9)   # 문에서 1.9m 안쪽 (3인칭 카메라가 뒤로 물러날 자리)
	player.view_back = 1.7
	player.velocity = Vector3.ZERO
	player.look(0.0, 0.0)   # 방 안쪽(북)을 봄
	player.reset_physics_interpolation()
	inside = true
	if weather != null:
		weather.rain.visible = false   # 지붕 아래라 빗줄기를 안 보이게
	if debug:
		print("[FG] cabin enter pos=", player.global_position)
	await _fade(1.0, 0.0)
	busy = false

func leave() -> void:
	if busy:
		return
	busy = true
	await _fade(0.0, 1.0)
	inside = false
	player.view_back = player.VIEW_BACK
	var y := _ground_y(STAND_OUT.x, STAND_OUT.z) + STAND_HEIGHT
	player.global_position = Vector3(STAND_OUT.x, y, STAND_OUT.z)
	player.velocity = Vector3.ZERO
	player.look(0.0, 0.0)   # 오두막(문)을 마주 봄 (오두막은 북쪽 -z)
	player.reset_physics_interpolation()
	if weather != null:
		weather.rain.visible = true
	if debug:
		print("[FG] cabin leave pos=", player.global_position)
	await _fade(1.0, 0.0)
	busy = false

# 침대에서 자면 다음 시간대로: 낮→노을→밤→낮, 날씨도 새로 정함
func sleep() -> void:
	if busy:
		return
	busy = true
	await _fade(0.0, 1.0)
	var idx: int = int(TimeScript.period)
	if idx == 2:
		Game.farm_day += 1   # 밤에 자고 아침이 되면 하루가 넘어감
	tod.clock = float(WAKE_CLOCKS[idx])
	tod.apply(tod.clock)
	if weather != null:
		weather.reroll()
	SfxScript.play("chime")
	await get_tree().create_timer(0.6, true, false, true).timeout   # 어두운 채로 잠깐
	toast_label.text = "푹 잤어요! 이제 %s이에요" % WAKE_NAMES[idx] if idx != 2 else "푹 잤어요! 아침이 밝았어요"
	toast_t0 = Time.get_ticks_msec() / 1000.0
	if debug:
		print("[FG] sleep slept from=", idx, " now period=", int(TimeScript.period), " clock=", tod.clock, " weather=", weather.current if weather != null else -1, " toast=", toast_label.text)
	await _fade(1.0, 0.0)
	busy = false

func _fade(from: float, to: float) -> void:
	fade.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, from)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(fade, "color:a", to, FADE_TIME)
	await tw.finished

func _ground_y(x: float, z_godot: float) -> float:
	var from := Vector3(x, 20.0, z_godot)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 0xFFFFFFFF, [player.get_rid()]))
	return hit.position.y if not hit.is_empty() else 0.0

# ---- 화면 ----
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	prompt = ThemeUI.panel(Vector2(0, 0))
	prompt_label = ThemeUI.label("", 28)
	prompt.add_child(prompt_label)
	ui.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position.y += 80
	prompt.visible = false
	toast = ThemeUI.panel(Vector2(560, 54))
	toast_label = ThemeUI.label("", 28)
	toast.add_child(toast_label)
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 22
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade)
