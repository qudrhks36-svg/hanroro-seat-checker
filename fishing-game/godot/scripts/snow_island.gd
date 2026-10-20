extends Node3D
# 눈 섬 (GDD 8번 [확정] 섬 여행 1단계): 섬 서쪽 바다 멀리의 눈 덮인 작은 섬. 눈 덮인 땅·얼음 호수(낚시, "Ice" 충돌)·소나무·눈사람·이글루·눈 바위, 섬에서만 내리는 눈.
# 모양은 임시 도형(코드로 만든 둥근 모양). 좌표는 고닷 기준, 섬 안쪽 좌표는 중심에서 잰 (x, z).

const Game := preload("res://scripts/game_state.gd")
const SmoothScript := preload("res://scripts/mesh_smooth.gd")

const CENTER := Vector3(-105, 0, 85)
const GROUND_Y := 0.12
const LAKE := Vector3(2.8, 0, -1.2)      # 섬 안쪽 좌표
const LAKE_R := 4.0
const SNOW := Color(0.97, 0.98, 1.0)
const ICE_SHORE := Color(0.82, 0.92, 0.98)
const BOAT_LOCAL := Vector3(0, -0.1, 14.2)    # 돌아가는 배 자리(섬 안쪽 좌표, 남쪽 바다)
const LAND_LOCAL := Vector3(0, 0, 10.6)       # 도착해서 서는 자리
const MODELS := "res://assets/models/Props/"

var world: Node3D
var player: CharacterBody3D
var rng := RandomNumberGenerator.new()
var snow: CPUParticles3D
var spots: Array = []
var trees := 0
var penguin: Node3D            # 눈 섬 주민 뽀로 (dialog.gd가 가져다 씀)
var penguin_pos := Vector3.ZERO   # 뽀로 서 있는 자리(세계 좌표, 발 기준)

func setup(world_node: Node3D, player_node: CharacterBody3D) -> void:
	world = world_node
	player = player_node
	rng.seed = 20261021
	position = CENTER
	_build_island()
	_build_lake()
	_build_penguin()   # 먼저 세워서 나무가 그 자리를 피함
	_scatter()
	_build_snow()
	Game.spots.append([CENTER + LAKE, LAKE_R])   # 낚싯줄이 호수 안에 떨어지게 조준할 때 씀(fishing_rod.gd)
	print("[FG] snow island built: trees=", trees)

static func _mat(c: Color, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _lathe(profile: PackedVector2Array, c: Color) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = profile
	p.mode = CSGPolygon3D.MODE_SPIN
	p.spin_degrees = 360.0
	p.spin_sides = 40
	p.material = _mat(c)
	return p

func _build_island() -> void:
	var root := CSGCombiner3D.new()
	root.name = "Ground"
	root.use_collision = true
	add_child(root)
	root.add_child(_lathe(PackedVector2Array([Vector2(0, -1.2), Vector2(15.5, -1.2), Vector2(14.6, -0.5), Vector2(12.8, -0.12), Vector2(11.6, 0.0), Vector2(0, 0.0)]), ICE_SHORE))
	root.add_child(_lathe(PackedVector2Array([Vector2(0, -0.1), Vector2(10.4, -0.1), Vector2(10.4, 0.05), Vector2(9.8, GROUND_Y), Vector2(0, GROUND_Y)]), SNOW))
	var hole := CSGCylinder3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.radius = LAKE_R
	hole.height = 1.2
	hole.sides = 32
	hole.position = LAKE + Vector3(0, -0.3, 0)
	hole.material = _mat(Color(0.55, 0.75, 0.9))
	root.add_child(hole)

func _build_lake() -> void:
	var ice := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = LAKE_R + 0.05
	cyl.bottom_radius = LAKE_R + 0.05
	cyl.height = 0.02
	cyl.radial_segments = 32
	ice.mesh = cyl
	var m := _mat(Color(0.72, 0.9, 0.98, 0.92), 0.1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.material_override = m
	ice.position = LAKE + Vector3(0, -0.04, 0)
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ice)
	for k in 3:   # 낚시 구멍 (그림만)
		var a := TAU * k / 3.0 + 0.5
		var h := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.38
		hm.bottom_radius = 0.38
		hm.height = 0.02
		hm.radial_segments = 16
		h.mesh = hm
		h.material_override = _mat(Color(0.12, 0.3, 0.5))
		h.position = LAKE + Vector3(cos(a) * 1.6, -0.03, sin(a) * 1.6)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(h)
	var body := StaticBody3D.new()   # 얼음 위를 걷고, 던진 찌가 "Ice"에 닿으면 호수 낚시
	body.name = "Ice"
	var sh := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = LAKE_R
	cs.height = 0.3
	sh.shape = cs
	body.add_child(sh)
	body.position = LAKE + Vector3(0, -0.19, 0)
	add_child(body)
	spots.append([Vector2(LAKE.x, LAKE.z), LAKE_R + 0.8])

func _free(p: Vector2, r: float) -> bool:
	if p.length() > 8.6:
		return false
	if p.distance_to(Vector2(LAKE.x, LAKE.z)) < LAKE_R + 0.9 + r:
		return false
	if absf(p.x) < 2.0 and p.y > 4.0:   # 배에서 올라오는 길
		return false
	for s in spots:
		if p.distance_to(s[0]) < r + float(s[1]):
			return false
	return true

func _pick(r: float, rmin: float, rmax: float) -> Variant:
	for _t in 40:
		var a := rng.randf() * TAU
		var d := rng.randf_range(rmin, rmax)
		var p := Vector2(cos(a), sin(a)) * d
		if _free(p, r):
			spots.append([p, r])
			return p
	return null

func _scatter() -> void:
	for i in 10:
		var p: Variant = _pick(1.1, 4.5, 8.4)
		if p != null:
			_pine(Vector3(p.x, GROUND_Y, p.y), rng.randf_range(0.85, 1.25))
	for i in 2:
		var p: Variant = _pick(0.9, 3.0, 7.5)
		if p != null:
			_snowman(Vector3(p.x, GROUND_Y, p.y), rng.randf_range(0.9, 1.1))
	var ip: Variant = _pick(2.2, 4.0, 7.0)
	if ip != null:
		_igloo(Vector3(ip.x, GROUND_Y, ip.y))
	for i in 4:
		var p: Variant = _pick(0.8, 3.0, 8.5)
		if p != null:
			_rock("RockA" if i % 2 == 0 else "RockB", Vector3(p.x, GROUND_Y, p.y), rng.randf_range(0.7, 1.0))

func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c

func _static_body(parent: Node3D, shape: Shape3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var sh := CollisionShape3D.new()
	sh.shape = shape
	body.add_child(sh)
	body.position = pos
	parent.add_child(body)

# 눈 덮인 소나무: 갈색 줄기 + 초록 원뿔 3단 + 단마다 흰 눈 원뿔
func _pine(pos: Vector3, s: float) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * s
	add_child(t)
	var tr := CylinderMesh.new()
	tr.top_radius = 0.14
	tr.bottom_radius = 0.2
	tr.height = 0.9
	_part(t, tr, Color(0.45, 0.32, 0.22), Vector3(0, 0.45, 0))
	for k in 3:
		var r := 1.0 - k * 0.22
		var y := 1.05 + k * 0.7
		_part(t, _cone(r, 1.3), Color(0.2, 0.46, 0.34), Vector3(0, y, 0))
		_part(t, _cone(r * 0.82, 0.8), SNOW, Vector3(0, y + 0.32, 0))
	var cap := CylinderShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	_static_body(t, cap, Vector3(0, 0.8, 0))
	trees += 1

func _snowman(pos: Vector3, s: float) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * s
	t.rotation.y = rng.randf() * TAU
	add_child(t)
	_part(t, _sph(0.5), SNOW, Vector3(0, 0.45, 0))
	_part(t, _sph(0.36), SNOW, Vector3(0, 1.08, 0))
	_part(t, _sph(0.26), SNOW, Vector3(0, 1.55, 0))
	for x in [-0.09, 0.09]:
		_part(t, _sph(0.03), Color(0.1, 0.1, 0.12), Vector3(x, 1.6, -0.22))
	_part(t, _cone(0.04, 0.22), Color(1.0, 0.55, 0.15), Vector3(0, 1.54, -0.3)).rotation_degrees = Vector3(-90, 0, 0)
	var hat := CylinderMesh.new()
	hat.top_radius = 0.14
	hat.bottom_radius = 0.17
	hat.height = 0.24
	_part(t, hat, Color(0.25, 0.25, 0.35), Vector3(0, 1.82, 0))
	var cap := CylinderShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	_static_body(t, cap, Vector3(0, 0.9, 0))

func _igloo(pos: Vector3) -> void:
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = rng.randf() * TAU
	add_child(t)
	var dome := SphereMesh.new()
	dome.is_hemisphere = true
	dome.radius = 1.7
	dome.height = 1.7
	dome.radial_segments = 24
	dome.rings = 10
	_part(t, dome, Color(0.94, 0.97, 1.0), Vector3.ZERO)
	var tunnel := CylinderMesh.new()
	tunnel.top_radius = 0.55
	tunnel.bottom_radius = 0.55
	tunnel.height = 1.0
	tunnel.radial_segments = 16
	var tn := _part(t, tunnel, Color(0.94, 0.97, 1.0), Vector3(0, 0.3, -1.5), Vector3(1, 1, 1))
	tn.rotation_degrees = Vector3(90, 0, 0)
	var door := _sph(0.4)
	_part(t, door, Color(0.1, 0.12, 0.18), Vector3(0, 0.3, -2.0), Vector3(1, 0.9, 0.3))
	var cap := CylinderShape3D.new()
	cap.radius = 1.75
	cap.height = 1.6
	_static_body(t, cap, Vector3(0, 0.8, 0))

func _rock(file: String, pos: Vector3, s: float) -> void:
	var ps: PackedScene = load(MODELS + file + ".fbx")
	if ps == null:
		return
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * s
	add_child(n)
	SmoothScript.smooth_node(n, world.smooth_angle)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _mat(Color(0.86, 0.9, 0.96))

# 펭귄 상인 뽀로(키 약 1.0, 임시 도형). 배에서 올라오는 길 옆에 서서 남쪽(배 쪽)을 봄. 대화는 dialog.gd
func _build_penguin() -> void:
	var local := Vector3(-2.0, GROUND_Y, 7.2)
	penguin = Node3D.new()
	penguin.name = "Penguin"
	penguin.position = local
	penguin.rotation.y = PI   # 앞(-z)이 남쪽(+z, 배 쪽)을 보게
	add_child(penguin)
	penguin_pos = CENTER + local
	var dark := Color(0.16, 0.19, 0.3)
	_part(penguin, _sph(0.42), dark, Vector3(0, 0.5, 0), Vector3(1.0, 1.15, 0.95))
	_part(penguin, _sph(0.3), Color(0.97, 0.98, 1.0), Vector3(0, 0.48, -0.17), Vector3(1.0, 1.15, 0.6))   # 하얀 배
	_part(penguin, _sph(0.3), dark, Vector3(0, 1.0, 0), Vector3(1.0, 0.95, 0.95))   # 머리
	for x in [-0.12, 0.12]:
		_part(penguin, _sph(0.045), Color.WHITE, Vector3(x, 1.04, -0.25), Vector3(1, 1.2, 0.6))
		_part(penguin, _sph(0.022), Color(0.05, 0.05, 0.08), Vector3(x, 1.04, -0.285))
	_part(penguin, _cone(0.07, 0.22), Color(1.0, 0.6, 0.15), Vector3(0, 0.97, -0.34)).rotation_degrees = Vector3(-90, 0, 0)   # 부리
	for x in [-0.46, 0.46]:   # 날개
		_part(penguin, _sph(0.14), dark, Vector3(x, 0.55, 0), Vector3(0.35, 1.3, 0.8))
	for x in [-0.16, 0.16]:   # 발
		_part(penguin, _sph(0.1), Color(1.0, 0.6, 0.15), Vector3(x, 0.05, -0.1), Vector3(1.0, 0.4, 1.4))
	_part(penguin, _sph(0.2), Color(0.9, 0.25, 0.3), Vector3(0, 0.78, -0.02), Vector3(1.9, 0.3, 1.9))   # 빨간 목도리
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.1
	_static_body(penguin, cap, Vector3(0, 0.55, 0))
	spots.append([Vector2(local.x, local.z), 1.0])

# 섬 위(플레이어가 섬 가까이 있을 때만) 눈이 내림
func _build_snow() -> void:
	snow = CPUParticles3D.new()
	snow.amount = 260
	snow.lifetime = 5.0
	snow.local_coords = false
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(14, 0.5, 14)
	snow.direction = Vector3(0.15, -1, 0.05)
	snow.spread = 12.0
	snow.gravity = Vector3(0, -0.4, 0)
	snow.initial_velocity_min = 1.2
	snow.initial_velocity_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	snow.mesh = q
	snow.emitting = false
	snow.top_level = true
	add_child(snow)

func _process(_delta: float) -> void:
	var near: bool = player.global_position.distance_to(CENTER) < 30.0
	snow.emitting = near
	if near:
		snow.global_position = player.global_position + Vector3(0, 6.5, 0)
