extends Node3D
# 아기자기한 이벤트 (포팅 7-2, GDD 9번 [확정], 유니티 SeaEvents): ① 가끔 하늘을 가로지르는 갈매기 ② 몇 분에 한 번 해변에 떠밀려 오는 병(E로 줍기 → 쪽지 + 돈).
# 시간은 delta로 세므로 도감·대화 중(일시정지)에는 멈춘다. 쪽지 카드는 시간을 멈추지 않는 실제 시간 카드. 읽은 쪽지는 저장(notes 비트 마스크).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const WorldScript := preload("res://scripts/world.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const WeatherScript := preload("res://scripts/weather.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const EVENTS_JSON := "res://data/events.json"

const NOTE_COUNT := 10
const BOTTLE_MIN_DELAY := 120.0
const BOTTLE_MAX_DELAY := 240.0
const NEXT_MIN := 180.0
const NEXT_MAX := 300.0
const GULL_MIN_DELAY := 40.0
const GULL_MAX_DELAY := 90.0
const GULL_SPEED := 8.0
const PICK_DISTANCE := 2.6
const NOTE_HOLD := 7.0
const TOAST_HOLD := 6.0

var cam: Camera3D
var player: CharacterBody3D
var notes: Array = []
var bottle: Node3D
var gem: Node3D
var bottle_bob := 0.0
var bottle_timer := 0.0
var gull: Node3D
var gull_wing_l: Node3D
var gull_wing_r: Node3D
var gull_audio: AudioStreamPlayer3D
var gull_from := Vector3.ZERO
var gull_to := Vector3.ZERO
var gull_t := 0.0
var gull_len := 1.0
var gull_cry := 0.0
var gull_timer := 0.0
var assume_captured := false     # 시험용
var debug := false

# 화면
var note_card: Panel
var note_title: Label
var note_text: Label
var note_reward: Label
var toast: PanelContainer
var toast_label: Label
var prompt: PanelContainer
var note_t0 := -999.0
var toast_t0 := -999.0

func setup(camera: Camera3D, player_node: CharacterBody3D) -> void:
	cam = camera
	player = player_node
	Game.ensure_loaded()
	notes = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_JSON))["notes"]
	bottle_timer = randf_range(BOTTLE_MIN_DELAY, BOTTLE_MAX_DELAY)
	gull_timer = randf_range(GULL_MIN_DELAY, GULL_MAX_DELAY)
	_build_ui()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func found_count() -> int:
	var n := 0
	for i in NOTE_COUNT:
		if (Game.notes_found >> i) & 1:
			n += 1
	return n

# ---------------- 병 ----------------
func _process(delta: float) -> void:
	_update_bottle(delta)
	_update_gull(delta)
	_update_ui()

func _update_bottle(delta: float) -> void:
	if bottle == null:
		bottle_timer -= delta
		if bottle_timer <= 0.0 and spawn_bottle():
			toast_t0 = _now()
			toast_label.text = "해변에 병이 떠밀려 왔어요!"
		prompt.visible = false
		return
	bottle_bob += delta
	if gem != null:
		gem.position.y = 0.55 + 0.08 * sin(bottle_bob * 3.0)
		gem.global_rotate(Vector3.UP, deg_to_rad(90.0) * delta)   # 월드 Y축으로 돎
	var near := Game.modal == "" and _reachable()   # 마우스 잠금 없이도 E가 됨
	prompt.visible = near

func _reachable() -> bool:
	var to := bottle.global_position - cam.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	return flat.length() < PICK_DISTANCE and (-cam.global_transform.basis.z).dot(to.normalized()) > 0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and bottle != null and prompt.visible:
		pick_up()
		get_viewport().set_input_as_handled()

func pick_up() -> void:
	var idx := _pick_note_index()
	var fresh := ((Game.notes_found >> idx) & 1) == 0
	Game.notes_found |= 1 << idx
	var reward := (randi() % 6 + 3) * 10   # 30~80원 (10원 단위)
	Game.money += reward
	SaveScript.save_game()
	SfxScript.play("new_fish")   # 도감 등록 "띠링"을 재사용
	bottle.queue_free()
	bottle = null
	gem = null
	bottle_timer = randf_range(NEXT_MIN, NEXT_MAX)
	show_note(idx, reward, fresh)

# 아직 못 읽은 쪽지가 있으면 그 중에서, 다 읽었으면 아무거나
func _pick_note_index() -> int:
	var left: Array = []
	for i in NOTE_COUNT:
		if ((Game.notes_found >> i) & 1) == 0:
			left.append(i)
	return left[randi() % left.size()] if not left.is_empty() else randi() % NOTE_COUNT

func show_note(idx: int, reward: int, fresh: bool) -> void:
	note_title.text = "병 속 쪽지   %d/%d%s" % [found_count(), NOTE_COUNT, "" if fresh else "  (읽은 쪽지)"]
	note_text.text = notes[idx]
	note_reward.text = "+%d원" % reward
	note_t0 = _now()
	if debug:
		print("[FG] note idx=", idx, " fresh=", fresh, " reward=", reward, " found=", found_count(), " money=", Game.money, " text=", notes[idx])

# 해변(반지름 15.3~16.3, 모래밭)의 비어 있는 자리를 찾아 병을 놓는다
func spawn_bottle() -> bool:
	for tries in 30:
		var a := randf() * TAU
		var r := randf_range(15.3, 16.3)
		var p = _try_ground(Vector3(cos(a) * r, 0.0, sin(a) * r))
		if p != null:
			_place_bottle(p)
			return true
	bottle_timer = 30.0   # 자리를 못 찾으면 잠시 뒤 다시
	return false

# 위에서 아래로 쏴서 가장 높은 곳이 바다가 아니고, 기울기가 완만하고, 다른 물건과 안 겹치면 그 점. 아니면 null.
func _try_ground(xz_unity: Vector3):
	var space := get_world_3d().direct_space_state
	var from := Vector3(xz_unity.x, 20.0, -xz_unity.z)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 0xFFFFFFFF, [player.get_rid()]))
	if hit.is_empty() or (hit.collider as Node).name == "Sea":
		return null
	if hit.normal.y < 0.8 or hit.position.y < 0.02 or hit.position.y > 0.5:   # 모래밭만(야자수 잎 위처럼 높은 곳은 안 됨)
		return null
	var q := PhysicsShapeQueryParameters3D.new()   # 다른 물건(야자수·바위·울타리)과 겹치지 않게
	var sph := SphereShape3D.new()
	sph.radius = 0.32
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, hit.position + Vector3.UP * 0.4)
	q.exclude = [player.get_rid()]
	if not space.intersect_shape(q, 1).is_empty():
		return null
	return hit.position

func _place_bottle(ground: Vector3) -> void:
	bottle = Node3D.new()
	bottle.name = "Bottle"
	add_child(bottle)
	bottle.position = ground
	bottle.rotation.y = randf() * TAU
	bottle.scale = Vector3.ONE * 1.4   # 멀리서도 눈에 띄게
	var model: Node3D = (load("res://assets/models/extra/Sea_Bottle.fbx") as PackedScene).instantiate()
	model.basis = WorldScript.MODEL_FIX
	bottle.add_child(model)
	WorldScript.tint_c_materials(model)
	gem = model.find_child("Gem", true, false)   # 모델의 "Gem"이 위에서 떠서 도는 반짝이
	bottle_bob = 0.0
	if debug:
		print("[FG] bottle at ", ground, " r=", Vector2(ground.x, ground.z).length(), " gem=", gem != null)

# ---------------- 갈매기 ----------------
func _update_gull(delta: float) -> void:
	if gull == null:
		gull_timer -= delta
		if gull_timer <= 0.0:
			if WeatherScript.rain_amount < 0.3 and TimeScript.night < 0.5:   # 비 오는 날·밤에는 날지 않음
				spawn_gull()
			gull_timer = randf_range(GULL_MIN_DELAY, GULL_MAX_DELAY)
		return
	gull_t += delta * GULL_SPEED / gull_len
	if gull_t >= 1.0:
		gull.queue_free()
		gull = null
		return
	var p := gull_from.lerp(gull_to, gull_t)
	p.y += sin(gull_t * 9.0) * 0.7
	gull.global_position = p
	var flap := sin(_now() * 9.0) * 35.0
	if gull_wing_l != null and gull_wing_r != null:
		gull_wing_l.rotation_degrees.x = flap
		gull_wing_r.rotation_degrees.x = -flap
	gull_cry -= delta
	if gull_cry <= 0.0 and p.distance_to(cam.global_position) < 70.0:
		gull_audio.play()
		gull_cry = randf_range(5.0, 9.0)

func spawn_gull() -> void:
	var a := randf() * TAU
	var h := randf_range(12.0, 20.0)
	var dir := Vector3(cos(a), 0.0, sin(a))   # 유니티 좌표
	var side := Vector3(-dir.z, 0.0, dir.x)
	start_gull(dir * 90.0 + Vector3.UP * h + side * randf_range(-25.0, 25.0), -dir * 90.0 + Vector3.UP * h + side * randf_range(-25.0, 25.0))

# from/to는 유니티 좌표(z가 앞)로 받아 고닷 좌표로 바꾼다
func start_gull(from_u: Vector3, to_u: Vector3) -> void:
	if gull != null:
		gull.queue_free()
	gull_from = Vector3(from_u.x, from_u.y, -from_u.z)
	gull_to = Vector3(to_u.x, to_u.y, -to_u.z)
	gull_t = 0.0
	gull_len = gull_from.distance_to(gull_to)
	gull_cry = 1.0
	gull = Node3D.new()
	gull.name = "Seagull"
	add_child(gull)
	gull.global_position = gull_from
	# 유니티: Quaternion.LookRotation(dir) * Euler(0, -90, 0) → 몸의 앞(+x)이 날아가는 쪽. 고닷 좌표로 바꿔서 모델 보정과 함께 적용
	var d := (to_u - from_u).normalized()
	var fwd := d
	var right := Vector3.UP.cross(fwd).normalized()
	var up := fwd.cross(right)
	var look := Basis(right, up, fwd).get_rotation_quaternion()
	var q := look * Quaternion(Vector3.UP, deg_to_rad(-90.0))
	gull.basis = WorldScript.to_godot_basis([q.x, q.y, q.z, q.w]) * Basis.IDENTITY
	gull.scale = Vector3.ONE * 1.8
	var model: Node3D = (load("res://assets/models/extra/Sea_Gull.fbx") as PackedScene).instantiate()
	model.basis = WorldScript.MODEL_FIX
	gull.add_child(model)
	WorldScript.tint_c_materials(model)
	gull_wing_l = model.find_child("WingL", true, false)   # 모델의 "WingL"·"WingR"(원점 = 어깨)만 퍼덕임
	gull_wing_r = model.find_child("WingR", true, false)
	gull_audio = AudioStreamPlayer3D.new()
	gull_audio.stream = load("res://assets/audio/sfx/voice_seagull.wav")
	gull_audio.volume_db = linear_to_db(0.4)
	gull_audio.unit_size = 8.0
	gull_audio.max_distance = 80.0
	gull.add_child(gull_audio)
	if debug:
		print("[FG] gull from=", gull_from, " to=", gull_to, " wings=", gull_wing_l != null, "/", gull_wing_r != null)

# ---------------- 화면 ----------------
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	# 쪽지 카드 (화면 가운데 위쪽)
	var size := Vector2(760, 230)
	note_card = ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 20, Color(0.45, 0.30, 0.18, 0.9), 3)
	note_card.custom_minimum_size = size
	ui.add_child(note_card)
	note_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	note_card.position.y -= 130
	note_card.pivot_offset = size * 0.5
	note_card.modulate.a = 0.0
	note_title = ThemeUI.text("", 24, Color(0.45, 0.30, 0.18), HORIZONTAL_ALIGNMENT_LEFT)
	note_card.add_child(note_title)
	ThemeUI.at(note_title, size, 0, 90, 700, 36)
	note_text = ThemeUI.text("", 30, Color(0.22, 0.15, 0.10))
	note_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_card.add_child(note_text)
	ThemeUI.at(note_text, size, 0, 10, 690, 110)
	var chip := ThemeUI.box(Color(1.0, 0.82, 0.28), 16)
	note_card.add_child(chip)
	ThemeUI.at(chip, size, 0, -82, 150, 42)
	note_reward = ThemeUI.text("", 26, Color(0.22, 0.15, 0.10))
	chip.add_child(note_reward)
	ThemeUI.at(note_reward, Vector2(150, 42), 0, 0, 150, 42)
	# 알림(위쪽 가운데)
	toast = ThemeUI.panel(Vector2(520, 54))
	toast_label = ThemeUI.label("", 28)
	toast.add_child(toast_label)
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0
	# 줍기 안내 (대화 안내와 같은 자리)
	prompt = ThemeUI.panel(Vector2(260, 0))
	prompt.add_child(ThemeUI.label("E: 병 줍기", 28))
	ui.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position.y += 80
	prompt.visible = false

func _update_ui() -> void:
	var t := _now() - note_t0
	if t > NOTE_HOLD + 0.5:
		note_card.modulate.a = 0.0
	else:
		var pt := clampf(t / 0.3, 0.0, 1.0)
		note_card.scale = Vector2.ONE * lerpf(0.85, 1.0, pt)
		note_card.modulate.a = clampf(pt * 3.0, 0.0, 1.0) * (1.0 - clampf((t - NOTE_HOLD) / 0.5, 0.0, 1.0))
	var tt := _now() - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
