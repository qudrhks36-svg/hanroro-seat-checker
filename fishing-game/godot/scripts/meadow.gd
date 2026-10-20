extends Node3D
# 옆 섬 "풀섬" (GDD 8번 [확정] 동물의 숲 느낌 맵 확장, 1단계): 지금 섬 남쪽 바다의 새 섬 + 걸어 건너는 나무다리 + 연못 + 둥근 나무·덤불·꽃·바위.
# 모양은 임시 도형(코드로 만든 둥근 모양). 동물·과일나무·연못 낚시는 다음 단계.
# 좌표는 고닷 기준(유니티 (x,z) → 고닷 (x,-z)). 섬 중심 CENTER, 섬 안쪽 좌표는 중심에서 잰 (x, z)이고 +z가 먼 바다 쪽(남쪽), 다리는 -z 쪽에서 들어옴.

const Game := preload("res://scripts/game_state.gd")
const SmoothScript := preload("res://scripts/mesh_smooth.gd")
const AnimalsScript := preload("res://scripts/animals.gd")
const FruitScript := preload("res://scripts/fruit_trees.gd")
const CANOPY := [[Vector3(0, 2.2, 0), 1.0], [Vector3(0.55, 1.9, 0.25), 0.88], [Vector3(-0.5, 2.0, -0.3), 0.76]]   # 나무 잎 공 3개(중심, 반지름)

const CENTER := Vector3(4, 0, 58)
const BRIDGE_X := 4.0
const BRIDGE_Z0 := 14.0          # 다리 시작(지금 섬 모래밭)
const BRIDGE_Z1 := 46.0          # 다리 끝(풀섬 모래밭)
const DECK_TOP := 0.2
const DECK_W := 2.4
const GROUND_Y := 0.12           # 풀밭 윗면
const POND := Vector3(-4.2, 0, 3.2)   # 섬 안쪽 좌표
const POND_R := 3.0
const SAND := Color(0.93, 0.84, 0.62)
const GRASS := Color(0.55, 0.78, 0.38)
const WOOD := Color(0.78, 0.60, 0.40)
const WOOD_DARK := Color(0.62, 0.45, 0.30)
const MODELS := "res://assets/models/Props/"

var world: Node3D
var rng := RandomNumberGenerator.new()
var spots: Array = []            # 이미 차지한 자리 [Vector2 (섬 안쪽 x,z), 반지름]
var trees := 0
var props := 0
var blocked: Array = []          # 동물이 피할 곳 [Vector2 (섬 안쪽 x,z), 반지름]: 연못·나무·바위
var animals: Node3D
var tree_nodes: Array = []
var fruit: Node3D

func setup(world_node: Node3D, camera: Camera3D) -> void:
	world = world_node
	rng.seed = 20261020
	position = CENTER
	_build_island()
	_build_pond()
	_build_bridge()
	_scatter()
	animals = Node3D.new()   # 풀섬 동물 (2단계)
	animals.set_script(AnimalsScript)
	animals.name = "Animals"
	add_child(animals)
	animals.setup(camera, blocked)
	fruit = Node3D.new()   # 과일나무 (3단계)
	fruit.set_script(FruitScript)
	fruit.name = "FruitTrees"
	add_child(fruit)
	fruit.setup(camera, tree_nodes, CANOPY)
	print("[FG] meadow built: trees=", trees, " props=", props, " bridge z ", BRIDGE_Z0, "..", BRIDGE_Z1)

static func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _lathe(profile: PackedVector2Array, c: Color) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = profile
	p.mode = CSGPolygon3D.MODE_SPIN
	p.spin_degrees = 360.0
	p.spin_sides = 48
	p.material = _mat(c)
	return p

func _build_island() -> void:
	var root := CSGCombiner3D.new()
	root.name = "Ground"
	root.use_collision = true
	add_child(root)
	# 모래: 바닥 -1.2, 물가에서 완만히 깊어짐(바다 높이 -0.1)
	root.add_child(_lathe(PackedVector2Array([Vector2(0, -1.2), Vector2(16.5, -1.2), Vector2(15.5, -0.5), Vector2(13.5, -0.12), Vector2(12.2, 0.0), Vector2(0, 0.0)]), SAND))
	# 풀밭: 둥글게 모서리가 말린 윗면
	root.add_child(_lathe(PackedVector2Array([Vector2(0, -0.1), Vector2(10.9, -0.1), Vector2(10.9, 0.04), Vector2(10.3, GROUND_Y), Vector2(0, GROUND_Y)]), GRASS))
	var hole := CSGCylinder3D.new()   # 연못 구덩이
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.radius = POND_R
	hole.height = 1.2
	hole.sides = 32
	hole.position = POND + Vector3(0, -0.3, 0)
	hole.material = _mat(Color(0.78, 0.70, 0.52))
	root.add_child(hole)

func _build_pond() -> void:
	var water := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = POND_R + 0.05
	cyl.bottom_radius = POND_R + 0.05
	cyl.height = 0.02
	cyl.radial_segments = 32
	water.mesh = cyl
	var m := _mat(Color(0.36, 0.74, 0.78, 0.8), 0.15)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = m
	water.position = POND + Vector3(0, -0.04, 0)   # 바다 판(-0.1)보다 살짝 위라 연못 색이 따로 보임
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	# 물 위를 걷게 하는 얇은 바닥(바다와 같은 방식): 구덩이에 빠져 못 나오는 일 방지
	var body := StaticBody3D.new()
	body.name = "Pond"   # 낚시: 이 이름의 바닥에 떨어지면 연못 물고기가 나옴(fishing_rod.gd)
	var sh := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = POND_R
	cs.height = 0.3
	sh.shape = cs
	body.add_child(sh)
	body.position = POND + Vector3(0, -0.19, 0)
	add_child(body)
	Game.spots.append([CENTER + POND, POND_R])
	spots.append([Vector2(POND.x, POND.z), POND_R + 0.9])
	blocked.append([Vector2(POND.x, POND.z), POND_R])

# ── 다리 ──
func _build_bridge() -> void:
	var br := Node3D.new()
	br.name = "Bridge"
	br.top_level = true   # 섬 위치와 상관없이 고닷 절대 좌표로 놓음
	add_child(br)
	var blen := BRIDGE_Z1 - BRIDGE_Z0
	var zc := (BRIDGE_Z0 + BRIDGE_Z1) * 0.5
	br.global_position = Vector3(BRIDGE_X, 0, zc)
	# 널빤지(MultiMesh) — 앞뒤 0.5m 간격
	var plank := BoxMesh.new()
	plank.size = Vector3(DECK_W, 0.14, 0.44)
	var n := int(blen / 0.5)
	var planks: Array = []
	for i in n:
		planks.append(Transform3D(Basis.IDENTITY, Vector3(0, DECK_TOP - 0.07, -blen * 0.5 + 0.25 + i * 0.5)))
	_multi(br, plank, _mat(WOOD), planks)
	# 난간 기둥 2m 간격 + 가로대
	var post := BoxMesh.new()
	post.size = Vector3(0.14, 1.0, 0.14)
	var posts: Array = []
	for side in [-1.0, 1.0]:
		for i in int(blen / 2.0) + 1:
			posts.append(Transform3D(Basis.IDENTITY, Vector3(side * (DECK_W * 0.5 - 0.05), DECK_TOP + 0.5, -blen * 0.5 + i * 2.0)))
	_multi(br, post, _mat(WOOD_DARK), posts)
	for side in [-1.0, 1.0]:
		_box(br, Vector3(0.1, 0.1, blen), Vector3(side * (DECK_W * 0.5 - 0.05), DECK_TOP + 0.95, 0), WOOD_DARK, false)
	# 물속 받침 말뚝
	var pile := CylinderMesh.new()
	pile.top_radius = 0.13
	pile.bottom_radius = 0.13
	pile.height = 1.4
	var piles: Array = []
	for side in [-1.0, 1.0]:
		for i in int(blen / 4.0) + 1:
			piles.append(Transform3D(Basis.IDENTITY, Vector3(side * 1.0, DECK_TOP - 0.8, -blen * 0.5 + i * 4.0)))
	_multi(br, pile, _mat(WOOD_DARK), piles)
	# 충돌: 바닥 하나 + 양쪽 난간 벽(떨어지지 않게)
	_box(br, Vector3(DECK_W, 0.2, blen), Vector3(0, DECK_TOP - 0.1, 0), WOOD, true, false)
	for side in [-1.0, 1.0]:
		_box(br, Vector3(0.15, 1.2, blen), Vector3(side * (DECK_W * 0.5), DECK_TOP + 0.6, 0), WOOD, true, false)

func _multi(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, collide: bool, visible_mesh: bool = true) -> void:
	if visible_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _mat(c)
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var sh := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		sh.shape = bs
		body.add_child(sh)
		body.position = pos
		parent.add_child(body)

# ── 나무·꽃·덤불·바위 ──
func _free(p: Vector2, r: float) -> bool:
	if p.length() > 9.6:
		return false
	if absf(p.x) < 3.0 and p.y < 2.0:   # 다리에서 들어오는 길
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
	for i in 13:
		var p: Variant = _pick(1.6, 4.0, 9.0)
		if p != null:
			_tree(Vector3(p.x, GROUND_Y, p.y), rng.randf_range(0.9, 1.25) * float(world.obj_scale["meadow_tree"]), i)
	for i in 9:
		var p: Variant = _pick(0.9, 3.0, 9.4)
		if p != null:
			_prop("Bush", Vector3(p.x, GROUND_Y, p.y), rng.randf_range(0.9, 1.3))
	for i in 3:   # 연못가 바위
		var a := PI * 0.2 + i * 1.7
		var q := Vector2(POND.x, POND.z) + Vector2(cos(a), sin(a)) * (POND_R + 0.35)
		if q.length() < 9.6:
			_prop("RockA" if i % 2 == 0 else "RockB", Vector3(q.x, GROUND_Y, q.y), rng.randf_range(0.7, 1.0))
			blocked.append([q, 0.7])
	var names := ["FlowerPink", "FlowerWhite", "FlowerYellow"]
	for i in 36:
		var p: Variant = _pick(0.35, 2.0, 9.6)
		if p != null:
			_prop(names[i % 3], Vector3(p.x, GROUND_Y, p.y), rng.randf_range(0.9, 1.4))

# 둥근 나무: 갈색 줄기 + 겹친 초록 공 세 개(임시 도형)
func _tree(pos: Vector3, s: float, i: int) -> void:
	var t := Node3D.new()
	t.name = "Tree%d" % i
	t.position = pos
	t.scale = Vector3.ONE * s
	add_child(t)
	var tr := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.26
	cm.height = 1.7
	tr.mesh = cm
	tr.material_override = _mat(Color(0.55, 0.38, 0.24))
	tr.position = Vector3(0, 0.85, 0)
	t.add_child(tr)
	var green := Color(0.40, 0.70, 0.34).lerp(Color(0.55, 0.78, 0.30), rng.randf())
	for k in 3:
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = CANOPY[k][1]
		sm.height = sm.radius * 1.8
		sp.mesh = sm
		sp.material_override = _mat(green.lightened(0.06 * k))
		sp.position = CANOPY[k][0]
		t.add_child(sp)
	var body := StaticBody3D.new()   # 줄기 충돌
	var sh := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	sh.shape = cap
	body.add_child(sh)
	body.position = Vector3(0, 0.9, 0)
	t.add_child(body)
	blocked.append([Vector2(pos.x, pos.z), 0.35 * s + 0.2])
	tree_nodes.append(t)
	trees += 1

func _prop(file: String, pos: Vector3, s: float) -> void:
	var ps: PackedScene = load(MODELS + file + ".fbx")
	if ps == null:
		return
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * s * float(world.obj_scale["meadow_prop"])
	add_child(n)
	SmoothScript.smooth_node(n, world.smooth_angle)
	world.apply_materials(n)
	props += 1
