extends Node3D
# 살아 있는 섬 (포팅 8단계, GDD 8번 [확정], 유니티 WindSway + Fireflies + CloudDrift + FishShadows):
#  ① 바람에 야자수·풀·꽃이 흔들리고 섬 둘레 배가 물결 따라 출렁인다 ② 밤에만 풀밭 위를 반딧불이 떠다닌다
#  ③ 하늘의 몽실몽실한 구름이 천천히 흘러간다 ④ 섬 둘레 바다를 어두운 반투명 물고기 그림자 6마리가 헤엄친다(장식일 뿐 낚시와 무관).
# 시간은 delta로 세어서 일시정지(대화·도감)에는 같이 멈춘다. 반딧불·구름·그림자는 코드로 만든다(웹에서 안전한 CPU 입자·기본 도형).

const TimeScript := preload("res://scripts/time_of_day.gd")
const SplashScript := preload("res://scripts/splash_fx.gd")

const SWAY_PARENTS := {"Decor/Grass": [4.0, 1.6], "Decor/Flowers": [5.0, 1.4], "Landmarks/Palms": [1.2, 0.8]}   # 부모 → [기울기(도), 속도]
const SWAY_PATHS := ["Island/PalmTree_01", "Island/PalmTree_02", "Island/PalmTree_03", "Island/PalmTree_04"]
const BOAT_PATHS := ["Landmarks/SeaDecor/Boat", "Island/BoatSpot"]
const CLOUD_COUNT := 12
const CLOUD_SPEED := 1.5
const CLOUD_RANGE := 170.0
const FIREFLY_AMOUNT := 50          # 수명 약 7초 → 밤에 약 50개
const SHADOW_Y := -0.07             # 바다(-0.1) 바로 위

var world: Node3D
var time := 0.0
var sways: Array = []               # {node, q(기본 회전), sc(기본 크기), amp, speed, phase}
var boats: Array = []               # {node, pos, q, sc, phase}
var clouds: Array = []
var fireflies: CPUParticles3D
var fish: Array = []                # {node, radius, speed, phase, wobble}

func setup(world_node: Node3D) -> void:
	world = world_node
	_collect_sways()
	_build_fireflies()
	_build_clouds()
	_build_fish_shadows()

func _collect_sways() -> void:
	for it in world.items:
		var n = it.get("_node", null)
		if n == null:
			continue
		var parent: String = it["parent"]
		var path: String = it["path"]
		if SWAY_PARENTS.has(parent):
			_add_sway(n, SWAY_PARENTS[parent][0], SWAY_PARENTS[parent][1])
		elif SWAY_PATHS.has(path):
			_add_sway(n, 1.2, 0.8)
		elif BOAT_PATHS.has(path):
			boats.append({"node": n, "pos": n.position, "q": n.basis.get_rotation_quaternion(), "sc": n.basis.get_scale(), "phase": n.position.x * 0.2 + n.position.z * 0.3})

func _add_sway(n: Node3D, amp: float, speed: float) -> void:
	var ph := fposmod(n.position.x * 0.37 + n.position.z * 0.53, TAU)   # 자리마다 다른 박자
	sways.append({"node": n, "q": n.basis.get_rotation_quaternion(), "sc": n.basis.get_scale(), "amp": amp, "speed": speed, "phase": ph})

# ---- 반딧불 ----
func _build_fireflies() -> void:
	var p := CPUParticles3D.new()
	p.amount = FIREFLY_AMOUNT
	p.lifetime = 7.0
	p.lifetime_randomness = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 1.2, 13)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	var init := Gradient.new()   # 노란 초록 두 색 사이에서 무작위
	init.set_color(0, Color(0.85, 1.0, 0.45))
	init.set_color(1, Color(1.0, 0.92, 0.5))
	p.color_initial_ramp = init
	var fade := Gradient.new()   # 서서히 나타났다가 사라짐
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = SplashScript.glow_material(SplashScript.soft_dot())
	p.mesh = q
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 1.3, 0)
	p.emitting = false
	add_child(p)
	fireflies = p

# ---- 구름: 동글동글 공 몇 개를 뭉친 덩이 ----
func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # 늘 같은 하늘
	var mat: Material = world.get_material("Mat_Cloud")
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 16
	sph.rings = 8
	for i in CLOUD_COUNT:
		var c := Node3D.new()
		c.name = "Cloud%d" % i
		var ang := rng.randf() * TAU
		var dist := 55.0 + rng.randf() * 110.0
		c.position = Vector3(cos(ang) * dist, 38.0 + rng.randf() * 30.0, sin(ang) * dist)
		var s := 1.0 + rng.randf() * 0.9
		var puffs := 4 + rng.randi() % 3
		for p in puffs:
			var u := 0.0 if puffs <= 1 else (p / (puffs - 1.0) - 0.5)
			var h := 1.0 - absf(u) * 1.2   # 가운데 공이 크고 높게
			var mi := MeshInstance3D.new()
			mi.mesh = sph
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(u * 16.0 * s, h * 2.5 * s, (rng.randf() - 0.5) * 3.0)
			mi.scale = Vector3(9.0, 6.0, 7.0) * (0.55 + 0.45 * h) * s
			c.add_child(mi)
		add_child(c)
		clouds.append(c)

# ---- 물고기 그림자 ----
func _build_fish_shadows() -> void:
	var mesh := _fish_mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	var radius := [23.0, 27.0, 31.0, 25.0, 36.0, 29.0]
	var speed := [0.05, -0.04, 0.035, -0.06, 0.03, 0.045]
	var size := [1.0, 1.3, 2.4, 0.9, 1.6, 1.1]   # 셋째는 큰 그림자
	for i in 6:
		var mi := MeshInstance3D.new()
		mi.name = "FishShadow%d" % i
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * float(size[i])
		add_child(mi)
		fish.append({"node": mi, "size": size[i], "radius": radius[i], "speed": speed[i], "phase": i * 1.7, "wobble": 0.6 + 0.2 * i})

# +Z가 머리 방향. 길이 약 1.6, 폭 약 0.55. 가장자리는 투명(정점 색의 알파)이라 부드럽다. 물색(0.02,0.10,0.18) × 알파 0.28
func _fish_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var body := Color(0.02, 0.10, 0.18, 0.28)
	var edge := Color(0.02, 0.10, 0.18, 0.0)
	v.append(Vector3(0, 0, 0.1))
	c.append(body)
	var n := 14
	for i in n:
		var a := float(i) / n * TAU
		v.append(Vector3(sin(a) * 0.28, 0, 0.1 + cos(a) * 0.62))
		c.append(edge)
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	var tail := v.size()   # 꼬리: 몸통 뒤쪽 끝에서 갈라지는 삼각형
	v.append(Vector3(0, 0, -0.5))
	c.append(Color(0.02, 0.10, 0.18, 0.25))
	v.append(Vector3(-0.25, 0, -0.95))
	c.append(edge)
	v.append(Vector3(0.25, 0, -0.95))
	c.append(edge)
	idx.append_array([tail, tail + 2, tail + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func _process(delta: float) -> void:
	time += delta
	var gust := 0.8 + 0.2 * sin(time * 0.25)   # 바람 세기가 천천히 오르내림
	for s in sways:
		var a: float = float(s["amp"]) * gust
		var w: float = time * float(s["speed"]) + float(s["phase"])
		(s["node"] as Node3D).basis = Basis((s["q"] as Quaternion) * Quaternion.from_euler(Vector3(deg_to_rad(a * sin(w)), 0.0, deg_to_rad(a * 0.8 * sin(w * 0.87 + 1.3))))).scaled_local(s["sc"])
	for b in boats:
		var w: float = time * 0.9 + float(b["phase"])
		var n: Node3D = b["node"]
		n.position = (b["pos"] as Vector3) + Vector3.UP * 0.06 * sin(w)
		n.basis = Basis((b["q"] as Quaternion) * Quaternion.from_euler(Vector3(deg_to_rad(1.5 * sin(w * 0.8 + 0.7)), 0.0, deg_to_rad(2.0 * sin(w + 1.9))))).scaled_local(b["sc"])
	for c in clouds:
		var n: Node3D = c
		n.position.x += CLOUD_SPEED * delta
		if n.position.x > CLOUD_RANGE:
			n.position.x = -CLOUD_RANGE
	var night: float = TimeScript.night
	fireflies.emitting = night > 0.02
	fireflies.color = Color(1, 1, 1, night)   # 밤 정도만큼 진하게(낮엔 사라짐)
	for f in fish:
		var a: float = float(f["phase"]) + time * float(f["speed"])
		var r: float = float(f["radius"]) + sin(time * 0.15 + float(f["phase"])) * 1.5
		var n: Node3D = f["node"]
		n.position = Vector3(cos(a) * r, SHADOW_Y, -sin(a) * r)   # 유니티 z를 뒤집은 자리
		var dir: float = signf(float(f["speed"]))
		var tangent := Vector3(-sin(a) * dir, 0.0, -cos(a) * dir)
		var yaw_wobble := deg_to_rad(sin(time * float(f["wobble"]) + float(f["phase"])) * 12.0)   # 헤엄치며 살짝 꼬리질
		var bs := Basis.looking_at(-tangent, Vector3.UP) * Basis(Vector3.UP, yaw_wobble)
		n.basis = bs.scaled(Vector3.ONE * float(f["size"]))
