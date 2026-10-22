extends Node3D
# 섬 여행 (GDD 8번 [확정] 섬 여행 1단계, 먼 바다 이동 far_sea.gd와 같은 방식): 부두 북쪽에 매어 둔 "눈 섬행" 배에서 E → 화면이 어두워졌다 밝아지며 눈 섬으로 이동, 눈 섬의 배에서 E → 부두로 돌아옴.
# 튼튼한 낚싯대(낚싯대 1단계 이상)가 있어야 탈 수 있다. 낚싯줄이 나가 있으면 못 탄다. 저장하지 않음(늘 부두에서 시작). 좌표는 고닷 기준.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const WorldScript := preload("res://scripts/world.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const SnowScript := preload("res://scripts/snow_island.gd")

const DOCK_BOAT := Vector3(21.5, -0.1, -3.3)      # 부두 북쪽에 매어 둔 배(뱃머리 +x)
const DOCK_STAND := Vector3(21.5, 0.0, -0.9)      # 돌아왔을 때 서는 부두 위 자리
const NEED_ROD := 1                               # 필요한 낚싯대 단계
const BOARD_DISTANCE := 2.6
const FADE_TIME := 0.5
const TOAST_HOLD := 4.0
const STAND_HEIGHT := 1.02
const FADE_COLOR := Color(0.03, 0.05, 0.1)

static var active := false     # 눈 섬에 있나
static var busy := false       # 이동(페이드) 중 — 낚시 입력을 막음

var cam: Camera3D
var player: CharacterBody3D
var fishing
var dock_boat: Node3D
var snow_boat: Node3D
var snow_boat_pos: Vector3
var prompt: PanelContainer
var prompt_label: Label
var toast: PanelContainer
var toast_label: Label
var fade: ColorRect
var toast_t0 := -999.0
var assume_captured := false    # 시험용
var debug := false

static func reset() -> void:
	active = false
	busy = false

func setup(camera: Camera3D, player_node: CharacterBody3D, fishing_node) -> void:
	reset()
	cam = camera
	player = player_node
	fishing = fishing_node
	snow_boat_pos = SnowScript.CENTER + SnowScript.BOAT_LOCAL
	dock_boat = _make_boat("TripDockBoat", DOCK_BOAT, 0.0)
	snow_boat = _make_boat("TripSnowBoat", snow_boat_pos, 90.0)
	_build_ui()

func _make_boat(boat_name: String, pos: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = boat_name
	add_child(root)
	root.set_meta("base", pos)
	root.set_meta("yaw", yaw_deg)
	root.position = pos
	root.rotation_degrees.y = yaw_deg
	var model: Node3D = (load("res://assets/models/extra/Sea_Rowboat.fbx") as PackedScene).instantiate()
	model.basis = WorldScript.MODEL_FIX
	root.add_child(model)
	WorldScript.tint_c_materials(model)
	WorldScript.add_boat_deck(root)
	return root

func _bob(boat: Node3D, phase: float, t: float) -> void:
	var base := Basis(Vector3.UP, deg_to_rad(float(boat.get_meta("yaw"))))
	boat.position = (boat.get_meta("base") as Vector3) + Vector3.UP * (0.04 * sin(t * 1.3 + phase))
	boat.basis = base * Basis.from_euler(Vector3(deg_to_rad(sin(t * 0.9 + phase) * 1.5), 0.0, deg_to_rad(sin(t * 1.1 + phase) * 2.0)))

func unlocked() -> bool:
	return Game.rod_level >= NEED_ROD

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_bob(dock_boat, 0.4, t)
	_bob(snow_boat, 2.1, t)
	var free := not busy and Game.modal == ""
	var near := free and _near(snow_boat_pos if active else DOCK_BOAT)
	prompt.visible = near
	if near:
		var idle: bool = fishing.state == fishing.S.IDLE
		if not idle:
			prompt_label.text = "낚싯줄을 먼저 거둬 주세요"
		elif active:
			prompt_label.text = "E: 부두로 돌아가기"
		elif unlocked():
			prompt_label.text = "E: 배 타고 눈 섬으로 가기"
		else:
			prompt_label.text = "눈 섬에 가려면 튼튼한 낚싯대가 필요해요"
	var tt := t - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and prompt.visible and fishing.state == fishing.S.IDLE and (active or unlocked()):
		travel(not active)
		get_viewport().set_input_as_handled()

func _near(boat: Vector3) -> bool:
	var to := boat - cam.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > BOARD_DISTANCE:
		return false
	return active or (-cam.global_transform.basis.z).dot(to.normalized()) > 0.3

func travel(to_snow: bool) -> void:
	if busy:
		return
	busy = true
	await _fade(0.0, 1.0)
	var dest := SnowScript.CENTER + SnowScript.LAND_LOCAL if to_snow else DOCK_STAND
	var y := _ground_y(dest.x, dest.z) + STAND_HEIGHT
	player.global_position = Vector3(dest.x, y, dest.z)
	player.velocity = Vector3.ZERO
	player.look(0.0 if to_snow else 90.0, 0.0)   # 눈 섬: 섬 안쪽(북)을 봄 / 부두: 바다 쪽(+x)을 봄
	player.reset_physics_interpolation()
	active = to_snow
	toast_label.text = "눈 섬에 도착했어요! 얼음 호수에서 낚시해 보세요" if to_snow else "부두로 돌아왔어요"
	toast_t0 = Time.get_ticks_msec() / 1000.0
	if debug:
		print("[FG] trip done active=", active, " pos=", player.global_position, " toast=", toast_label.text)
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

func _ground_y(x: float, z: float) -> float:
	var from := Vector3(x, 20.0, z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 0xFFFFFFFF, [player.get_rid()]))
	return hit.position.y if not hit.is_empty() else -0.1

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
	toast = ThemeUI.panel(Vector2(760, 54))
	toast_label = ThemeUI.label("", 28)
	toast.add_child(toast_label)
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 21
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(FADE_COLOR.r, FADE_COLOR.g, FADE_COLOR.b, 0.0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade)
