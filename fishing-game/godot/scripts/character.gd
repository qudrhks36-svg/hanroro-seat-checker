extends RefCounted
# 캐릭터 임시 모양 (포팅 10단계, GDD 3번 [확정] 옷장): 둥근 도형(몸통·머리·팔·다리·모자)으로 만든 작은 사람. 옷장 창 미리보기가 씀.
# 1인칭에서는 몸이 안 보이므로 소매·손은 outfit_view.gd가 따로 만든다. 색은 data/outfits.json.

const SKIN := Color(1.0, 0.85, 0.70)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

static func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
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

# 다리: 엉덩이 자리(hip_y)에 축 노드를 두고 모양은 그 아래에 매달아, 축을 x로 돌리면 걷는 다리 흔들림이 됨(player_body.gd). meta "leg" = 좌우(-1/1)
static func _leg(root: Node3D, mesh: Mesh, c: Color, x: float, hip_y: float, center_y: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, hip_y, 0)
	pivot.set_meta("leg", signf(x))
	root.add_child(pivot)
	_part(pivot, mesh, c, Vector3(0, center_y - hip_y, 0))

# 발이 y=0에 닿는 키 약 1.8m 캐릭터 (앞이 -z)
static func build(o: Dictionary, arms: bool = true) -> Node3D:
	var root := Node3D.new()
	var top := color_of(o["top"])
	var bottom := color_of(o["bottom"])
	_part(root, _capsule(0.26, 0.95), top, Vector3(0, 1.1, 0))   # 몸통
	if bool(o["dress"]):   # 치마
		var sk := CylinderMesh.new()
		sk.top_radius = 0.24
		sk.bottom_radius = 0.42
		sk.height = 0.55
		_part(root, sk, bottom, Vector3(0, 0.62, 0))
		for x in [-0.1, 0.1]:
			_leg(root, _capsule(0.06, 0.4), SKIN, x, 0.4, 0.2)
	else:
		for x in [-0.12, 0.12]:
			_leg(root, _capsule(0.1, 0.75), bottom, x, 0.78, 0.4)
	if arms:   # 팔: 소매 + 손 (3인칭 플레이어는 팔을 outfit_view.gd가 따로 그려서 끔)
		for x in [-0.34, 0.34]:
			_part(root, _capsule(0.08, 0.62), top, Vector3(x, 1.1, 0))
			_part(root, _sphere(0.075), SKIN, Vector3(x, 0.76, 0))
	_part(root, _sphere(0.24), SKIN, Vector3(0, 1.78, 0))   # 머리
	for x in [-0.09, 0.09]:
		_part(root, _sphere(0.03), Color(0.15, 0.1, 0.1), Vector3(x, 1.8, -0.21))
	if o["hat"] != null:
		var hc := color_of(o["hat"]["color"])
		var dome := SphereMesh.new()
		dome.is_hemisphere = true
		dome.radius = 0.27 if o["hat"]["shape"] == "beanie" else 0.25
		dome.height = dome.radius
		dome.radial_segments = 16
		dome.rings = 6
		_part(root, dome, hc, Vector3(0, 1.88 if o["hat"]["shape"] == "cap" else 1.9, 0))
		if o["hat"]["shape"] == "cap":   # 챙
			var brim := CylinderMesh.new()
			brim.top_radius = 0.2
			brim.bottom_radius = 0.2
			brim.height = 0.03
			_part(root, brim, hc, Vector3(0, 1.9, -0.16))
	return root
