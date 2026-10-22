extends RefCounted
# 캐릭터 임시 모양 (포팅 10단계, GDD 3번 [확정] 옷장 + 3인칭): 둥근 도형으로 만든 동글동글한 사람(머리가 크고 몸이 작은 "동물의 숲" 비율).
# 머리(+머리카락·얼굴), 몸통, 치마 또는 다리+신발, 모자. 옷장 창 미리보기와 3인칭 플레이어 몸(player_body.gd)이 씀. 색은 data/outfits.json.
# 앞이 -z, 발이 y=0, 키 약 1.8m(모자 빼고). 3인칭 플레이어는 팔을 outfit_view.gd가 낚싯대 쥔 모양으로 따로 그려서 arms=false.

const SKIN := Color(1.0, 0.85, 0.70)
const HAIR := Color(0.33, 0.21, 0.13)
const SHOE := Color(0.30, 0.20, 0.14)
const SHOULDER_Y := 1.12
const SHOULDER_X := 0.24
const PLAYER_SCALE := 0.85      # 3인칭 플레이어 몸 크기(player_body.gd). 팔 어깨 자리 계산에도 씀(outfit_view.gd)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

static func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 6
	return m

static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m

static func color_of(a: Array) -> Color:
	return Color(a[0], a[1], a[2])

# 다리: 엉덩이 자리(hip_y)에 축 노드를 두고 다리·신발은 그 아래에 매달아, 축을 x로 돌리면 걷는 다리 흔들림이 됨(player_body.gd). meta "leg" = 좌우(-1/1)
static func _leg(root: Node3D, c: Color, x: float, hip_y: float, r: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, hip_y, 0)
	pivot.set_meta("leg", signf(x))
	root.add_child(pivot)
	var h := hip_y - 0.1
	_part(pivot, _capsule(r, h), c, Vector3(0, -h * 0.5, 0))
	_part(pivot, _sphere(0.1), SHOE, Vector3(0, -hip_y + 0.06, -0.035), Vector3(0.95, 0.62, 1.5))   # 신발

# 팔: 어깨에 축 노드를 두고 팔·손은 그 아래에 매달아, 축을 x로 돌리면 팔 흔들림이 됨(player_body.gd). meta "arm" = 좌우(-1/1)
static func _arm(root: Node3D, c: Color, x: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, SHOULDER_Y, 0)
	pivot.rotation.z = -signf(x) * 0.08   # 살짝 벌어짐
	pivot.set_meta("arm", signf(x))
	root.add_child(pivot)
	_part(pivot, _capsule(0.07, 0.5), c, Vector3(0, -0.25, 0))
	_part(pivot, _sphere(0.075), SKIN, Vector3(0, -0.53, 0))

static func build(o: Dictionary, arms: bool = true) -> Node3D:
	var root := Node3D.new()
	var top := color_of(o["top"])
	var bottom := color_of(o["bottom"])
	var hair: Color = color_of(o["hair"]) if o.has("hair") else HAIR
	# 몸통
	_part(root, _capsule(0.235, 0.68), top, Vector3(0, 0.93, 0))
	_part(root, _sphere(0.13), top, Vector3(0, 1.2, 0), Vector3(1.4, 0.7, 1.0))   # 어깨선
	if bool(o["dress"]):   # 치마
		var sk := CylinderMesh.new()
		sk.top_radius = 0.2
		sk.bottom_radius = 0.37
		sk.height = 0.42
		sk.radial_segments = 20
		_part(root, sk, bottom, Vector3(0, 0.66, 0))
		for x in [-0.09, 0.09]:
			_leg(root, SKIN, x, 0.47, 0.055)
	else:
		for x in [-0.11, 0.11]:
			_leg(root, bottom, x, 0.64, 0.095)
	if arms:   # 팔: 소매 + 손 (3인칭 플레이어는 낚싯대 쥔 오른팔을 outfit_view.gd가 따로 그림)
		for x in [-SHOULDER_X * 1.06, SHOULDER_X * 1.06]:
			_arm(root, top, x)
	# 머리: 크고 동그랗게
	_part(root, _sphere(0.36), SKIN, Vector3(0, 1.45, 0))
	_part(root, _sphere(0.385), hair, Vector3(0, 1.53, 0.07), Vector3(1.0, 0.95, 1.0))        # 머리카락(뒤·위)
	_part(root, _sphere(0.2), hair, Vector3(0, 1.69, -0.2), Vector3(1.55, 0.5, 0.75))         # 앞머리
	for x in [-0.13, 0.13]:
		_part(root, _sphere(0.05), Color(0.1, 0.08, 0.08), Vector3(x, 1.47, -0.325), Vector3(0.85, 1.25, 0.55))   # 눈
		_part(root, _sphere(0.016), Color.WHITE, Vector3(x + 0.014, 1.495, -0.347))                                # 눈빛
		_part(root, _sphere(0.065), Color(1.0, 0.65, 0.65), Vector3(x * 1.6, 1.385, -0.285), Vector3(1.0, 0.65, 0.4))   # 볼
	_part(root, _sphere(0.04), Color(0.85, 0.45, 0.45), Vector3(0, 1.34, -0.345), Vector3(1.3, 0.45, 0.5))   # 입
	if o["hat"] != null:
		var hc := color_of(o["hat"]["color"])
		var beanie: bool = o["hat"]["shape"] == "beanie"
		var dome := SphereMesh.new()
		dome.is_hemisphere = true
		dome.radius = 0.43 if beanie else 0.41
		dome.height = dome.radius
		dome.radial_segments = 20
		dome.rings = 8
		_part(root, dome, hc, Vector3(0, 1.69 if beanie else 1.72, 0.02))
		if beanie:   # 방울
			_part(root, _sphere(0.09), hc.lightened(0.25), Vector3(0, 2.14, 0.02))
		else:   # 챙
			var brim := CylinderMesh.new()
			brim.top_radius = 0.24
			brim.bottom_radius = 0.24
			brim.height = 0.035
			_part(root, brim, hc, Vector3(0, 1.74, -0.35))
	return root
