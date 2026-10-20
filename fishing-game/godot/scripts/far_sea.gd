extends Node3D
# 먼 바다 낚시터 (포팅 7-1, GDD 9번 [확정], 유니티 FarSea): 부두 옆에 매어 둔 배에서 E → 화면이 어두워졌다 밝아지며 먼 바다의 작은 배 위로 순간 이동. 배에서 E → 부두로 돌아옴.
# 먼 바다(active)에서는 먼 바다 전용 물고기만 낚인다(Game.pick). 낚싯줄이 나가 있으면(대기 상태가 아니면) 못 탄다. 저장하지 않음(늘 섬에서 시작).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const WorldScript := preload("res://scripts/world.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")

const DOCK_BOAT := Vector3(24, -0.1, -2.7)      # 부두 남쪽에 매어 둔 배(뱃머리 +x), 유니티 좌표
const DOCK_STAND := Vector3(24, 0, -0.6)         # 돌아왔을 때 서는 부두 위 자리
const FAR_BOAT := Vector3(95, -0.1, -40)         # 섬에서 약 100m
const BOARD_DISTANCE := 2.6
const FADE_TIME := 0.5
const TOAST_HOLD := 4.0
const STAND_HEIGHT := 1.02                       # 땅에서 플레이어 몸 중심까지
const FADE_COLOR := Color(0.03, 0.05, 0.1)

static var active := false     # 먼 바다에 있나
static var busy := false       # 이동(페이드) 중 — 낚시 입력을 막음

var cam: Camera3D
var player: CharacterBody3D
var fishing
var dock_boat: Node3D
var far_boat: Node3D
var dock_lamp: OmniLight3D
var far_lamp: OmniLight3D
var prompt: PanelContainer
var prompt_label: Label
var toast: PanelContainer
var toast_label: Label
var fade: ColorRect
var toast_t0 := -999.0
var assume_captured := false    # 시험용
var last_near := false
var debug := false              # 시험용: 이동 결과를 로그로 찍고, 도착하면 바다 쪽(섬 반대)을 보게 돌림

static func reset() -> void:
	active = false
	busy = false

func setup(camera: Camera3D, player_node: CharacterBody3D, fishing_node) -> void:
	reset()
	cam = camera
	player = player_node
	fishing = fishing_node
	dock_boat = _make_boat("DockBoat", DOCK_BOAT, 0.0)
	far_boat = _make_boat("FarBoat", FAR_BOAT, rad_to_deg(atan2(-FAR_BOAT.x, -FAR_BOAT.z)) - 90.0)   # 뱃머리가 섬 쪽
	dock_lamp = dock_boat.get_node("Lamp")
	far_lamp = far_boat.get_node("Lamp")
	_build_ui()

# ---- 배 ----
func _make_boat(boat_name: String, pos_u: Vector3, yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = boat_name
	add_child(root)
	root.set_meta("base", Vector3(pos_u.x, pos_u.y, -pos_u.z))
	root.set_meta("yaw", yaw_deg)
	var q := Quaternion(Vector3.UP, deg_to_rad(yaw_deg))   # 유니티 Quaternion.Euler(0, yaw, 0) → 고닷 (z 반전 변환)
	root.basis = Basis(Quaternion(-q.x, -q.y, q.z, q.w))
	root.position = root.get_meta("base")
	var model: Node3D = (load("res://assets/models/extra/Sea_Rowboat.fbx") as PackedScene).instantiate()
	model.basis = WorldScript.MODEL_FIX
	root.add_child(model)
	WorldScript.tint_c_materials(model)
	var lamp := OmniLight3D.new()   # 뱃머리 등불: 밤에만 켜짐
	lamp.name = "Lamp"
	lamp.position = Vector3(1.35, 1.3, 0.0)
	lamp.light_color = Color(1.0, 0.8, 0.45)
	lamp.omni_range = 8.0
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	root.add_child(lamp)
	return root

# 물결에 살짝 흔들림: 위아래 0.04m, 기울기 1.5도·2도
func _bob(boat: Node3D, phase: float, t: float) -> void:
	var yaw_deg: float = boat.get_meta("yaw")
	var q := Quaternion(Vector3.UP, deg_to_rad(yaw_deg))
	var base := Basis(Quaternion(-q.x, -q.y, q.z, q.w))
	boat.position = (boat.get_meta("base") as Vector3) + Vector3.UP * (0.04 * sin(t * 1.3 + phase))
	boat.basis = base * Basis.from_euler(Vector3(deg_to_rad(sin(t * 0.9 + phase) * 1.5), 0.0, deg_to_rad(sin(t * 1.1 + phase) * 2.0)))

# ---- 매 프레임 ----
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_bob(dock_boat, 0.0, t)
	_bob(far_boat, 1.7, t)
	var night := smoothstep(0.0, 1.0, TimeScript.night)
	dock_lamp.light_energy = night * 1.0   # 밤엔 뱃머리 등불이 켜짐
	far_lamp.light_energy = night * 1.0

	var free := not busy and Game.modal == ""   # 마우스 잠금 없이도 E가 됨
	var near := free and _near(FAR_BOAT if active else DOCK_BOAT)
	prompt.visible = near
	if debug and near != last_near:
		last_near = near
		print("[FG] boat prompt=", near, " active=", active)
	if near:
		var idle: bool = fishing.state == fishing.S.IDLE
		prompt_label.text = "낚싯줄을 먼저 거둬 주세요" if not idle else ("E: 부두로 돌아가기" if active else "E: 배 타고 먼 바다로 가기")
	var tt := t - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and prompt.visible and fishing.state == fishing.S.IDLE:
		travel(not active)
		get_viewport().set_input_as_handled()

# 배 가까이(수평 거리)에 있고, (부두 쪽에서는) 배를 바라보고 있나
func _near(boat_u: Vector3) -> bool:
	var boat := Vector3(boat_u.x, boat_u.y, -boat_u.z)
	var to := boat - cam.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > BOARD_DISTANCE:
		return false
	return active or (-cam.global_transform.basis.z).dot(to.normalized()) > 0.3

# 화면이 어두워졌다 밝아지며 이동 (0.5초씩, 실제 시간)
func travel(to_far: bool) -> void:
	if busy:
		return
	busy = true
	await _fade(0.0, 1.0)
	var dest := FAR_BOAT if to_far else DOCK_STAND
	var yaw_u := rad_to_deg(atan2(-FAR_BOAT.x, -FAR_BOAT.z)) if to_far else 180.0   # 먼 바다: 섬 쪽을 봄 / 부두: 배(바다) 쪽을 봄
	var y := _ground_y(dest.x, -dest.z) + STAND_HEIGHT
	player.global_position = Vector3(dest.x, y, -dest.z)
	player.velocity = Vector3.ZERO
	player.look(-yaw_u, 0.0)   # 유니티 yaw → 고닷 yaw는 부호 반대(z 반전)
	player.reset_physics_interpolation()
	active = to_far
	toast_label.text = "먼 바다에 도착했어요! 여기서만 잡히는 물고기가 있어요" if to_far else "부두로 돌아왔어요"
	toast_t0 = Time.get_ticks_msec() / 1000.0
	if debug:
		if to_far:
			player.look(player.rotation_degrees.y + 180.0, 0.0)
		print("[FG] travel done active=", active, " pos=", player.global_position, " toast=", toast_label.text)
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

# 위에서 아래로 쏴서 가장 높은 곳(부두·바다 포함)의 높이
func _ground_y(x: float, z_godot: float) -> float:
	var from := Vector3(x, 20.0, z_godot)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 0xFFFFFFFF, [player.get_rid()]))
	return hit.position.y if not hit.is_empty() else -0.1

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
