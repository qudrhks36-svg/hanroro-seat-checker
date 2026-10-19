extends Node3D
# 집 꾸미기 모습 (포팅 7-3, GDD 9번 [확정], 유니티 HomeDecor): 산 장식 5종(화분·해변 파라솔·풍경·모닥불·해먹)과 오두막 단계(1: 새 지붕+굴뚝 연기, 2: 깃발+등불+창문 불빛)를 섬에 보여준다.
# 게임 상태(Game.decor_mask, Game.cabin_level)가 바뀌면 바로 반영. 장식을 사면 그 둘레의 풀·꽃·덤불·바위(섬 소품 Decor, 해변 제외)를 치운다.
# 좌표는 유니티 값 그대로 적고 고닷 좌표(z 반전)로 바꿔서 쓴다.

const Game := preload("res://scripts/game_state.gd")
const WorldScript := preload("res://scripts/world.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")

const ITEM_POS := [[-9.8, 2.4], [-4.6, 1.0], [-6.0, 2.85], [-7.5, -1.2], [-11.4, -3.5]]   # 화분·파라솔·풍경·모닥불·해먹 (유니티 x, z)
const CHIME_Y := 3.45                      # 풍경은 처마 끝에 걸림
const CLEAR_ZONES := [[-9.8, 2.4, 0.6, 0.6], [-4.6, 1.0, 1.5, 1.5], null, [-7.5, -1.2, 1.0, 1.0], [-11.4, -3.5, 1.0, 2.0]]   # {x, z, 반폭 x, 반폭 z}
const MODELS := ["Home_Pot", "Home_Parasol", "Home_Chime", "Home_Fire", "Home_Hammock"]
const ROOF_NEW := Color(0.28, 0.58, 0.66)
const WINDOW_GLOW := Color(1.0, 0.82, 0.4)
const LIGHT_COLOR := Color(1.0, 0.8, 0.45)

var world: Node3D
var items: Array = []                      # 장식 5개의 뿌리 노드
var cleared := [false, false, false, false, false]
var grounded := [false, false, false, false, false]
var chime: Node3D
var chime_audio: AudioStreamPlayer3D
var chime_timer := 0.0
var hammock: Node3D
var fire_light: OmniLight3D
var chimney: Node3D
var roof_cover: MeshInstance3D
var smoke: CPUParticles3D
var flag_group: Node3D
var flag: Node3D
var lantern_group: Node3D
var lantern_light: OmniLight3D
var window_light_l: OmniLight3D
var window_light_r: OmniLight3D
var roof_mat: StandardMaterial3D
var window_mat: StandardMaterial3D
var roof_base := Color.WHITE
var window_base := Color.WHITE
var shown_cabin := -1
var dot_texture: Texture2D

static func _g(p: Vector3) -> Vector3:   # 유니티 좌표 → 고닷 좌표
	return Vector3(p.x, p.y, -p.z)

func setup(world_node: Node3D) -> void:
	world = world_node
	Game.ensure_loaded()
	dot_texture = _soft_dot()
	roof_mat = world.get_material("Mat_Roof")
	window_mat = world.get_material("Mat_Window")
	roof_base = roof_mat.albedo_color
	window_base = window_mat.albedo_color
	items.resize(5)
	for i in 5:
		_build_item(i)
	_build_pot_etc()
	_build_cabin_extras()
	chime_timer = randf_range(8.0, 16.0)

# 장식 뿌리 노드: 땅 높이에 놓고 처음엔 숨김. 모델은 유니티 로컬 회전 없음(원점에 그대로).
func _build_item(i: int) -> void:
	var pos: Array = ITEM_POS[i]
	var root := Node3D.new()
	root.name = "Decor_" + Game.home_items[i]["name"]
	add_child(root)
	root.position = _g(Vector3(pos[0], CHIME_Y if i == 2 else 0.0, pos[1]))   # 땅 높이는 처음 나타날 때 잼(물리 세계가 준비된 뒤)
	root.visible = false
	items[i] = root
	var model := _spawn(MODELS[i], root)
	match i:
		2:
			chime = model   # 모델의 원점 = 처마에 거는 점이라 통째로 흔들면 됨
			chime_audio = AudioStreamPlayer3D.new()
			chime_audio.stream = load("res://assets/audio/sfx/chime.wav")
			chime_audio.volume_db = linear_to_db(0.5)
			chime_audio.unit_size = 3.0
			chime_audio.max_distance = 30.0
			root.add_child(chime_audio)
		4:
			hammock = model.find_child("Hammock", true, false)   # 모델의 "Hammock" 부분(원점 = 흔들리는 축)만 흔듦

func _build_pot_etc() -> void:
	# 모닥불: 불꽃 입자 + 흔들리는 불빛
	var g: Node3D = items[3]
	g.add_child(_flames())
	fire_light = _light(g, Vector3(0, 0.7, 0), Color(1.0, 0.6, 0.25), 9.0)

func _flames() -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.position = Vector3(0, 0.2, 0)
	ps.amount = 24
	ps.lifetime = 0.8
	ps.local_coords = false
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.14
	ps.direction = Vector3.UP
	ps.spread = 9.0
	ps.initial_velocity_min = 1.1
	ps.initial_velocity_max = 1.1
	ps.gravity = Vector3.ZERO
	ps.scale_amount_min = 0.28
	ps.scale_amount_max = 0.45
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.8))
	curve.add_point(Vector2(1, 0.0))
	ps.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.9, 0.4, 0.9), Color(1, 0.4, 0.1, 0.7), Color(0.6, 0.15, 0.05, 0.0)])
	ps.color_ramp = grad
	ps.mesh = _particle_quad(true)
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ps

func _particle_quad(additive: bool) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot_texture
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	return quad

# 부드러운 동그라미(가운데가 밝고 가장자리가 투명) — 이미지 파일 없이 만듦
static func _soft_dot() -> Texture2D:
	var t := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _light(parent: Node3D, local: Vector3, color: Color, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = local
	l.light_color = color
	l.omni_range = range_m
	l.light_energy = 0.0
	l.shadow_enabled = false
	parent.add_child(l)
	return l

# ---- 오두막 단계 ----
func _build_cabin_extras() -> void:
	# 1단계: 새 지붕 색. 오두막 모델의 지붕 윗면이 벽과 같은 재질이라 색만 바꿀 수 없어, 지붕 위에 살짝 덮는 판을 얹는다.
	roof_cover = MeshInstance3D.new()
	roof_cover.mesh = _gable_mesh(-11.58, -4.42, -8.0, 2.94, 9.06, 3.46, 5.56)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = ROOF_NEW
	rm.roughness = 0.9
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof_cover.material_override = rm
	roof_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roof_cover)
	# 1단계: 굴뚝(+ 연기)
	chimney = Node3D.new()
	chimney.name = "Chimney"
	chimney.position = _g(Vector3(-9.6, 4.75, 7.4))
	add_child(chimney)
	var cm := _spawn("Home_Chimney", chimney)
	cm.position = Vector3(0, -0.4, 0)
	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0, 1.0, 0)
	smoke.amount = 20
	smoke.lifetime = 3.2
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.12
	smoke.direction = Vector3.UP
	smoke.spread = 6.0
	smoke.initial_velocity_min = 0.7
	smoke.initial_velocity_max = 0.7
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 0.4
	smoke.scale_amount_max = 0.7
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.2))
	smoke.scale_amount_curve = curve
	smoke.color = Color(0.85, 0.88, 0.95, 0.22)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	smoke.color_ramp = grad
	smoke.mesh = _particle_quad(false)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.emitting = false
	chimney.add_child(smoke)
	# 2단계: 지붕 깃발 + 문 옆 등불 + 창문 불빛
	flag_group = Node3D.new()
	flag_group.name = "Flag"
	flag_group.position = _g(Vector3(-8.0, 5.5, 6.0))
	add_child(flag_group)
	var fm := _spawn("Home_Flag", flag_group)
	flag = fm.find_child("FlagCloth", true, false)   # 천(원점 = 깃대)만 살랑
	lantern_group = Node3D.new()
	lantern_group.name = "Lantern"
	lantern_group.position = _g(Vector3(-6.7, 2.3, 2.8))
	add_child(lantern_group)
	_spawn("Home_Lantern", lantern_group)
	lantern_light = _light(lantern_group, Vector3.ZERO, LIGHT_COLOR, 7.0)
	# 창문 앞 불빛: 유니티는 등불 기준 로컬 좌표 (-11.9+6.7, -0.7, 6-2.8)·(-3.9+6.7, -0.7, 6-2.8)
	window_light_l = _light(lantern_group, _g(Vector3(-11.9 + 6.7, -0.7, 6.0 - 2.8)), LIGHT_COLOR, 5.0)   # 서쪽 창 앞
	window_light_r = _light(lantern_group, _g(Vector3(-3.9 + 6.7, -0.7, 6.0 - 2.8)), LIGHT_COLOR, 5.0)    # 동쪽 창 앞

# 박공지붕(앞뒤가 삼각형 벽, 지붕면은 서쪽·동쪽 두 장)에 덮는 얇은 판 두 장. 어느 쪽에서 봐도 보이게 앞뒤 면을 모두 넣는다. (유니티 좌표로 받아 고닷 좌표로 바꿈)
func _gable_mesh(x0: float, x1: float, xm: float, z0: float, z1: float, y_eave: float, y_ridge: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads := [
		[Vector3(x0, y_eave, z0), Vector3(xm, y_ridge, z0), Vector3(xm, y_ridge, z1), Vector3(x0, y_eave, z1)],   # 서쪽 지붕면
		[Vector3(x1, y_eave, z1), Vector3(xm, y_ridge, z1), Vector3(xm, y_ridge, z0), Vector3(x1, y_eave, z0)],   # 동쪽 지붕면
	]
	for q in quads:
		var a := _g(q[0])
		var b := _g(q[1])
		var c := _g(q[2])
		var d := _g(q[3])
		for tri in [[a, b, c], [a, c, d], [a, c, b], [a, d, c]]:   # 앞면 두 장 + 뒷면 두 장
			for v in tri:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()

# ---- 매 프레임 ----
func _process(delta: float) -> void:
	for i in 5:
		var own := Game.owns(i)
		if own and not grounded[i]:
			grounded[i] = true
			if i != 2:
				items[i].position.y = _ground_y(ITEM_POS[i][0], ITEM_POS[i][1])
		if items[i].visible != own:
			items[i].visible = own
		if own and not cleared[i]:
			cleared[i] = true
			_clear_near(i)
	if Game.cabin_level != shown_cabin:
		_apply_cabin(Game.cabin_level)

	var t := Time.get_ticks_msec() / 1000.0
	var night := clampf(TimeScript.night, 0.0, 1.0)
	var wind := sin(t * 1.7) * 0.6 + sin(t * 0.7 + 1.0) * 0.4
	if items[2].visible:
		# 유니티 Euler(wind*9, 0, sin*7)를 고닷으로: x축 회전 부호만 반대(z 반전)
		var q := Quaternion(Vector3.RIGHT, -deg_to_rad(wind * 9.0)) * Quaternion(Vector3.BACK, deg_to_rad(sin(t * 1.3) * 7.0))
		chime.basis = Basis(q) * WorldScript.MODEL_FIX
		chime_timer -= delta
		if chime_timer <= 0.0:
			chime_timer = randf_range(10.0, 22.0)
			chime_audio.play()
	if items[4].visible and hammock != null:
		hammock.rotation.z = deg_to_rad(sin(t * 0.9) * 3.0)
	if items[3].visible:
		fire_light.light_energy = 0.5 * (0.8 + night * 2.2) * (0.85 + 0.15 * sin(t * 17.0) + 0.08 * sin(t * 29.0))
	if Game.cabin_level >= 1:
		smoke.emitting = true
	if Game.cabin_level >= 2:
		if flag != null:
			flag.rotation.y = deg_to_rad(sin(t * 3.0) * 14.0)
		var glow := smoothstep(0.0, 1.0, night)
		lantern_light.light_energy = glow * 1.1
		window_light_l.light_energy = glow * 0.7
		window_light_r.light_energy = glow * 0.7
		window_mat.albedo_color = window_base.lerp(WINDOW_GLOW, glow)

func _apply_cabin(level: int) -> void:
	shown_cabin = level
	roof_mat.albedo_color = ROOF_NEW if level >= 1 else roof_base
	chimney.visible = level >= 1
	roof_cover.visible = level >= 1
	flag_group.visible = level >= 2
	lantern_group.visible = level >= 2
	smoke.emitting = level >= 1
	if level < 2:
		window_mat.albedo_color = window_base
		lantern_light.light_energy = 0.0
		window_light_l.light_energy = 0.0
		window_light_r.light_energy = 0.0

# 장식을 사면 그 둘레의 풀·꽃·덤불·바위(섬 소품 Decor, 해변 제외)를 치운다
func _clear_near(i: int) -> void:
	var box = CLEAR_ZONES[i]
	if box == null:
		return
	var hidden := 0
	for it in world.items:
		var parent: String = it["parent"]
		if not parent.begins_with("Decor/") or parent == "Decor/Beach":
			continue
		var p: Array = it["pos"]
		if absf(p[0] - box[0]) < box[2] and absf(p[2] - box[1]) < box[3]:
			var n = it.get("_node", null)
			if n != null:
				n.visible = false
				hidden += 1
	print("[FG] decor cleared near ", Game.home_items[i]["name"], ": ", hidden)

# ---- 공통 ----
# 장식 모델 (assets/models/extra/<이름>.fbx)을 부모 아래에 놓는다: 유니티 로컬 회전 없음 → 모델 보정만. 재질 이름 "C_RRGGBB"를 색으로.
func _spawn(res: String, parent: Node3D) -> Node3D:
	var model: Node3D = (load("res://assets/models/extra/%s.fbx" % res) as PackedScene).instantiate()
	model.basis = WorldScript.MODEL_FIX
	parent.add_child(model)
	WorldScript.tint_c_materials(model)
	return model

# 위에서 아래로 쏴서 바다가 아닌 가장 높은 곳(섬 땅)의 높이. 못 찾으면 0.
func _ground_y(x_u: float, z_u: float) -> float:
	var from := Vector3(x_u, 20.0, -z_u)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0))
	if hit.is_empty() or (hit.collider as Node).name == "Sea":
		return 0.0
	return maxf(0.0, hit.position.y)

# 시험용: 지금 보이는 것 요약
func debug_state() -> String:
	var parts: Array = []
	for i in 5:
		parts.append("%s=%s" % [Game.home_items[i]["name"], "보임" if items[i].visible else "숨김"])
	return "장식[%s] 오두막=%d 굴뚝=%s 지붕덮개=%s 깃발=%s 등불=%s 지붕색=%s | 흔들 부분 찾음: 풍경=%s 해먹=%s 깃발천=%s" % [", ".join(parts), Game.cabin_level, chimney.visible, roof_cover.visible, flag_group.visible, lantern_group.visible, roof_mat.albedo_color, chime != null, hammock != null, flag != null]
