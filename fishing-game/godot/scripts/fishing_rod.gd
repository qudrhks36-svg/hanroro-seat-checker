extends Node3D
# 낚시 (포팅 4단계, 유니티 FishingRod): 왼쪽 클릭 = 던지기 / 입질 타이밍에 낚기 / 회수. 낚기 성공 뒤엔 릴 감기(왼쪽 버튼 누르고 있기).
# 값은 data/fishing.json (던지기 12m·0.8초·높이 3, 입질 후 1.6초 안에 클릭, 릴 감기 수치). 첫 클릭은 시작(마우스 잠금)이라 main.gd가 먹음.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const WorldScript := preload("res://scripts/world.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const FarSeaScript := preload("res://scripts/far_sea.gd")

enum S { IDLE, FLYING, FLOATING, BITING, REELING }

const CAST_DISTANCE := 12.0
const CAST_TIME := 0.8
const ARC_HEIGHT := 3.0
const WATER_Y := -0.1
const BITE_WINDOW := 1.6              # 입질 후 클릭 가능 시간(초)
const REEL_ZONE_SPEED := 0.7
const REEL_START := 0.4
const REEL_GAIN := 0.4
const REEL_LOSS := 0.2
const FISH_SPEED := [0.3, 0.5, 0.75]   # 흔함/보통/희귀
const BAR_W := 600.0
const ROD_LENGTH := [1.0, 1.15, 1.3]   # 낚싯대 단계별 길이 배율 (모델 길이도 1.4 / 1.61 / 1.82)

var cam: Camera3D
var world: Node3D
var state := S.IDLE
var selected_bait := 0
var cast_bait := 0
var click_pending := false
var auto := false                      # 시험용: 스스로 던지고 낚음

var tip: Node3D                        # 낚싯대 끝 (카메라 아래)
var rod_model: Node3D
var bobber: MeshInstance3D
var line: MeshInstance3D
var start_pos := Vector3.ZERO
var end_pos := Vector3.ZERO
var t := 0.0
var bite_timer := 0.0
var hooked := -1
var zone_pos := 0.5
var fish_pos := 0.5
var fish_target := 0.5
var retarget_timer := 0.0
var gauge := 0.0
var toast_until := 0.0
var catches := 0
var shown_rod := -1                    # 지금 보이는 낚싯대 단계

# 화면
var ui: CanvasLayer
var guide: PanelContainer
var guide1: Label
var guide2: Label
var toast: PanelContainer
var toast_label: Label
var result_card                        # 결과 카드 (main이 넣어 줌)
var fx                                 # 물보라·물결 (main이 넣어 줌)
var bang: Label
var reel_root: Control
var zone_rect: ColorRect
var fish_rect: ColorRect
var gauge_rect: ColorRect

func setup(camera: Camera3D, world_node: Node3D) -> void:
	cam = camera
	world = world_node
	Game.ensure_loaded()
	_build_rod(Game.rod_level)
	shown_rod = Game.rod_level
	_build_bobber_and_line()
	_build_ui()
	_set_casting(false)

# ---- 낚싯대 모델 (카메라 아래, 유니티 RodLook과 같은 자리) ----
func _build_rod(level: int) -> void:
	if rod_model != null:
		rod_model.queue_free()
	if tip == null:
		tip = Node3D.new()
		cam.add_child(tip)
	var it: Dictionary
	for x in world.items:
		if x["path"] == "Player/PlayerCamera/Rod":
			it = x
	var p: Array = it["pos"]
	var q: Array = it["quat"]
	var rod_u := Vector3(p[0], p[1] - 1.8, p[2])           # 유니티 카메라 기준 자리
	var qu := Quaternion(q[0], q[1], q[2], q[3])
	var half: float = 0.7 * float(ROD_LENGTH[level])                      # 대 길이 1.4의 절반
	var tip_u := rod_u + qu * Vector3(0, 0, half)
	var handle_u := rod_u - qu * Vector3(0, 0, half)
	tip.position = Vector3(tip_u.x, tip_u.y, -tip_u.z)
	var scene: PackedScene = load("res://assets/models/extra/Rod_%d.fbx" % level)
	rod_model = scene.instantiate()
	rod_model.position = Vector3(handle_u.x, handle_u.y, -handle_u.z)
	rod_model.basis = WorldScript.to_godot_basis(q) * WorldScript.MODEL_FIX
	cam.add_child(rod_model)
	_tint_c_materials(rod_model)

# 시험용: 낚싯대 모델의 양끝(카메라 기준)과 낚싯줄 시작점(tip)을 찍는다
func debug_rod() -> void:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for n in rod_model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var xf: Transform3D = cam.global_transform.affine_inverse() * mi.global_transform
		var bb := mi.get_aabb()
		for c in 8:
			var corner := bb.position + bb.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)
			var p := xf * corner
			lo = lo.min(p)
			hi = hi.max(p)
	print("[FG] rod aabb(cam local) lo=", lo, " hi=", hi, " tip=", tip.position)

# 재질 이름 "C_RRGGBB" → 그 색 (유니티 RodLook.ColorMaterial). 그림자는 끔.
func _tint_c_materials(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.mesh.get_surface_count():
			var orig: Material = mi.mesh.surface_get_material(i)
			var nm: String = orig.resource_name if orig != null else ""
			var k := nm.find("C_")
			if k >= 0 and nm.length() >= k + 8:
				var m := StandardMaterial3D.new()
				m.albedo_color = Color.html("#" + nm.substr(k + 2, 6))
				m.roughness = 0.9
				mi.set_surface_override_material(i, m)

func _build_bobber_and_line() -> void:
	bobber = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.125
	sph.height = 0.25
	bobber.mesh = sph
	bobber.material_override = world.get_material("Mat_Bobber")
	bobber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bobber)
	line = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 1.0
	cyl.radial_segments = 4
	line.mesh = cyl
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.9)
	line.material_override = lm
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)

# ---- 화면 ----
func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 3
	add_child(ui)
	guide = ThemeUI.panel(Vector2(560, 0))
	var v := VBoxContainer.new()
	guide1 = ThemeUI.label("", 28)
	guide2 = ThemeUI.label("", 19, ThemeUI.INK_SOFT)
	v.add_child(guide1)
	v.add_child(guide2)
	guide.add_child(v)
	ui.add_child(guide)
	guide.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	guide.grow_horizontal = Control.GROW_DIRECTION_BOTH   # 글자가 길어져도 가운데 기준으로 커짐

	toast = ThemeUI.panel()
	toast_label = ThemeUI.label("", 30)
	toast.add_child(toast_label)
	toast.visible = false
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 130)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH

	bang = ThemeUI.label("!", 96, Color(1.0, 0.9, 0.3))
	bang.add_theme_color_override("font_outline_color", Color(0.3, 0.15, 0.05))
	bang.add_theme_constant_override("outline_size", 10)
	bang.visible = false
	ui.add_child(bang)

	# 릴 감기 화면: 가로 막대(주황 물고기 칸 + 초록 내 칸)와 그 아래 노란 게이지 (화면 가운데 기준)
	reel_root = Control.new()
	reel_root.set_anchors_preset(Control.PRESET_CENTER)
	reel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel_root.add_child(ThemeUI.rect(Color(1, 0.97, 0.9, 0.82), Vector2(BAR_W, 36), Vector2(-BAR_W / 2, 140 - 18)))
	zone_rect = ThemeUI.rect(Color(0.5, 0.82, 0.6, 0.9), Vector2(Game.zone_width() * BAR_W, 36), Vector2.ZERO)
	fish_rect = ThemeUI.rect(Color(1, 0.55, 0.35), Vector2(18, 36), Vector2.ZERO)
	reel_root.add_child(zone_rect)
	reel_root.add_child(fish_rect)
	reel_root.add_child(ThemeUI.rect(Color(1, 0.97, 0.9, 0.82), Vector2(BAR_W, 14), Vector2(-BAR_W / 2, 185 - 7)))
	gauge_rect = ThemeUI.rect(Color(1, 0.9, 0.4), Vector2(0, 14), Vector2(-BAR_W / 2, 185 - 7))
	reel_root.add_child(gauge_rect)
	reel_root.visible = false
	ui.add_child(reel_root)

# ---- 입력 ----
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		click_pending = true
	elif event is InputEventKey and event.pressed and not event.echo and state == S.IDLE:
		match event.keycode:
			KEY_1: _select_bait(0)
			KEY_2: _select_bait(1)
			KEY_3: _select_bait(2)

func _select_bait(i: int) -> void:
	selected_bait = i

func is_idle() -> bool:
	return state == S.IDLE

func is_hooked() -> bool:   # 입질 중이거나 릴 감는 중 (낚시 대회는 이 한 마리까지만 끝내고 마감)
	return state == S.BITING or state == S.REELING

# ---- 매 프레임 ----
func _process(delta: float) -> void:
	if FarSeaScript.busy:
		return   # 배로 이동하는 동안(화면이 어두워지는 사이)엔 던지기 등 입력을 막음
	if shown_rod != Game.rod_level:
		shown_rod = Game.rod_level
		_build_rod(shown_rod)   # 업그레이드하거나 저장을 불러오면 낚싯대 모양을 바꿈
	var click := click_pending
	click_pending = false
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var held := captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if auto:   # 시험용 스스로 낚기
		click = state == S.IDLE or state == S.BITING
		held = fish_pos > zone_pos
	match state:
		S.IDLE:
			if click:
				_cast()
		S.FLYING:
			t += delta / CAST_TIME
			var k := clampf(t, 0.0, 1.0)
			bobber.global_position = start_pos.lerp(end_pos, k) + Vector3.UP * sin(k * PI) * ARC_HEIGHT
			if k >= 1.0:
				_land()
		S.FLOATING:
			bobber.global_position = end_pos + Vector3.UP * sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.03
			bite_timer -= delta
			if click:
				_set_casting(false)   # 입질 전에 감으면 그냥 회수
			elif bite_timer <= 0.0:
				_start_bite()
		S.BITING:
			bobber.global_position = end_pos + Vector3.DOWN * 0.15   # 찌가 가라앉음
			bite_timer -= delta
			if click:
				_hook()
			elif bite_timer <= 0.0:
				_show_toast("놓쳤어요...")
				SfxScript.play("miss")
				_set_casting(false)
		S.REELING:
			bobber.global_position = end_pos + Vector3.DOWN * 0.15
			_reel(held, delta)
	if state != S.IDLE:
		_update_line()
	if toast.visible and Time.get_ticks_msec() / 1000.0 > toast_until:
		toast.visible = false
	_update_guide()
	if state == S.BITING:
		bang.visible = true
		var sp := cam.unproject_position(bobber.global_position + Vector3.UP * 0.8)
		bang.position = sp - bang.size * 0.5

func _cast() -> void:
	var dir := -cam.global_transform.basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	cast_bait = selected_bait
	start_pos = tip.global_position
	end_pos = Vector3(start_pos.x, WATER_Y, start_pos.z) + dir * CAST_DISTANCE
	t = 0.0
	state = S.FLYING
	_set_casting(true)
	bobber.global_position = start_pos
	SfxScript.play("cast")

func _land() -> void:
	# 위에서 아래로 쏴서 바다가 먼저 맞으면 물 위, 섬·부두·배가 맞으면 육지.
	var from := Vector3(end_pos.x, 20.0, end_pos.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0))
	var water: bool = not hit.is_empty() and (hit.collider as Node).name == "Sea"
	if water:
		state = S.FLOATING
		var w: Array = Game.baits[cast_bait]["wait_sec"]
		bite_timer = randf_range(float(w[0]), float(w[1]))   # 미끼마다 다름 (GDD 6번)
		SfxScript.play("splash")
		if fx != null:
			fx.splash(end_pos, false)   # 찌가 물에 닿는 물보라 (GDD 9번 낚시 연출)
	else:
		_set_casting(false)   # 육지: 회수

func _start_bite() -> void:
	state = S.BITING
	bite_timer = BITE_WINDOW
	SfxScript.play("bite")
	if fx != null:
		fx.ring(end_pos, 1.1)   # 입질 물결

# 입질 타이밍 성공 → 물고기를 정하고 릴 감기 시작
func _hook() -> void:
	hooked = Game.pick(TimeScript.period, cast_bait, FarSeaScript.active)   # 먼 바다에서는 먼 바다 전용 물고기만
	bang.visible = false
	zone_pos = 0.5
	fish_pos = 0.5
	fish_target = 0.5
	retarget_timer = 0.0
	gauge = REEL_START
	zone_rect.size = Vector2(Game.zone_width() * BAR_W, 36)
	reel_root.visible = true
	state = S.REELING

func _reel(held: bool, delta: float) -> void:
	zone_pos = clampf(zone_pos + (1.0 if held else -1.0) * REEL_ZONE_SPEED * delta, 0.0, 1.0)
	retarget_timer -= delta
	if retarget_timer <= 0.0:
		fish_target = randf()
		retarget_timer = randf_range(0.6, 1.2)
	fish_pos = move_toward(fish_pos, fish_target, FISH_SPEED[Game.rarity_index(hooked)] * delta)
	var inside := absf(fish_pos - zone_pos) <= Game.zone_width() * 0.5
	gauge = clampf(gauge + (REEL_GAIN if inside else -REEL_LOSS) * delta, 0.0, 1.0)
	zone_rect.color = Color(0.35, 1.0, 0.5, 0.9) if inside else Color(0.95, 0.45, 0.35, 0.8)   # 물고기를 잡고 있으면 밝은 초록, 놓치면 붉은 주황
	zone_rect.position.x = (zone_pos - 0.5) * BAR_W - zone_rect.size.x * 0.5
	zone_rect.position.y = 140 - 18
	fish_rect.position.x = (fish_pos - 0.5) * BAR_W - fish_rect.size.x * 0.5
	fish_rect.position.y = 140 - 18
	gauge_rect.size.x = gauge * BAR_W
	if gauge >= 1.0:
		_catch()
	elif gauge <= 0.0:
		_show_toast("물고기가 도망갔어요...")
		SfxScript.play("miss")
		_end_reel()

func _catch() -> void:
	var cm := Game.roll_size(hooked)
	var was_new: bool = Game.counts[hooked] == 0   # 처음 잡은 물고기인지 (NEW)
	var record := Game.register(hooked, cm)
	var goal_done := Game.goal_on_catch()   # 오늘의 목표 (GDD 9번)
	Game.contest_on_catch(hooked, cm)       # 진행 중인 낚시 대회의 최고 크기
	catches += 1
	SfxScript.play("catch")
	if was_new:
		SfxScript.play("new_fish")
	if goal_done:
		SfxScript.play("goal_done")
	if fx != null:
		fx.splash(end_pos, true)
	var f: Dictionary = Game.fish[hooked]
	SaveScript.save_game()
	if result_card != null:
		result_card.show_result(hooked, was_new, cm, record, cam.unproject_position(bobber.global_position), goal_done)
	print("[FG] catch #", catches, " ", f["name"], " ", cm, "cm ", f["rarity"], " period=", TimeScript.period, " bait=", cast_bait)
	_end_reel()

func _end_reel() -> void:
	reel_root.visible = false
	_set_casting(false)

func _set_casting(on: bool) -> void:
	if not on:
		state = S.IDLE
	bang.visible = false
	bobber.visible = on
	line.visible = on

func _update_line() -> void:
	var a := tip.global_position
	var b := bobber.global_position
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var up := d / len
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := up.cross(ref).normalized()
	var z := x.cross(up)
	line.global_transform = Transform3D(Basis(x, up * len, z), (a + b) * 0.5)

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast.visible = true
	toast_until = Time.get_ticks_msec() / 1000.0 + 3.0

# ---- 안내 판 (유니티 GuideHint): 지금 할 일을 단계마다 보여준다 ----
func _update_guide() -> void:
	var a := ""
	var b := ""
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		a = "화면을 한 번 클릭하면 시작해요"
	else:
		match state:
			S.IDLE:
				a = "왼쪽 클릭: 바다 쪽으로 낚싯대 던지기"
				b = "E: 배 가까이에서 부두로 돌아가기 · 1·2·3 미끼 · Tab 도감 · P 사진 · M 소리 · O 설정" if FarSeaScript.active else "WASD 이동 · 마우스 시점 · 1·2·3 미끼 · Tab 도감 · E 말 걸기 · P 사진 · M 소리 · O 설정"
			S.FLOATING:
				a = "찌를 지켜보세요… 느낌표(!)가 뜨면 바로 왼쪽 클릭!"
				b = "기다리다 마음이 바뀌면 왼쪽 클릭: 낚싯대 거두기"
			S.BITING:
				a = "지금! 왼쪽 클릭!"
			S.REELING:
				a = "왼쪽 버튼을 꾹 누르면 초록 칸이 오른쪽으로, 떼면 왼쪽으로 가요"
				b = "주황 물고기 위에 초록 칸을 맞추세요. 노란 게이지가 가득 차면 성공!"
	guide.visible = a != ""
	if guide1.text != a:
		guide1.text = a
	if guide2.text != b:
		guide2.text = b
	guide2.visible = b != ""
	guide1.add_theme_color_override("font_color", ThemeUI.CORAL if state == S.BITING else ThemeUI.INK)
