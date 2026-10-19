extends Node3D
# 섬 놓기 (포팅 2-1): data/scene.json(유니티 장면에서 뽑은 물체 목록)을 읽어서 FBX 모델을 같은 자리에 놓는다.
# 좌표: 유니티는 왼손(앞 +Z), 고닷은 오른손(앞 -Z). 위치는 z 부호 반전, 회전은 쿼터니언 (x,y,z,w) → (-x,-y,z,w).
# FBX 모델 안의 모양은 유니티·고닷 가져오기 방식이 달라 거울상이 될 수 있어서, 모델에만 MODEL_FIX를 곱해 맞춘다(사진으로 확인).

const MODEL_FIX := Basis(Vector3.UP, PI)   # 모델에 곱하는 보정 (Y축 180도). 사진 비교 결과로 정함
const SCENE_JSON := "res://data/scene.json"
const MATERIALS_JSON := "res://data/materials.json"
const CUSTOM_SHADER_MATS := ["Mat_Sea", "Mat_SkyGradient"]   # 따로 셰이더로 만드는 것(2-3)

var items: Array = []
var by_path: Dictionary = {}
var spawned := 0
var mat_defs: Dictionary = {}
var mat_cache: Dictionary = {}
var unmatched: Dictionary = {}
var skipped_child := 0

static func to_godot_pos(p: Array) -> Vector3:
	return Vector3(p[0], p[1], -p[2])

static func to_godot_basis(q: Array) -> Basis:
	return Basis(Quaternion(-q[0], -q[1], q[2], q[3]))

static func model_path(source: String) -> String:
	# 유니티 Assets/Models/X.fbx → assets/models/X.fbx, Assets/Resources/Models/Y.fbx → assets/models/extra/Y.fbx
	if source.begins_with("Assets/Resources/Models/"):
		return "res://assets/models/extra/" + source.trim_prefix("Assets/Resources/Models/")
	return "res://assets/models/" + source.trim_prefix("Assets/Models/")

# 유니티 재질(.mat)의 색을 같은 이름의 고닷 재질로 만든다 (FBX 안의 색은 유니티에서 쓰이지 않음)
func get_material(mat_name: String) -> StandardMaterial3D:
	if mat_cache.has(mat_name):
		return mat_cache[mat_name]
	var d: Dictionary = mat_defs[mat_name]
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	var c: Array = d["base_color"]
	m.albedo_color = Color(c[0], c[1], c[2], 1.0)
	m.roughness = 1.0 - float(d.get("smoothness", 0.1))
	m.metallic = float(d.get("metallic", 0.0))
	m.metallic_specular = float(_arg_spec())   # 하늘 반사로 허옇게 뜨는 것을 줄임(유니티 재질은 반짝임 0.1)
	if d.get("emission") != null:
		var e: Array = d["emission"]
		m.emission_enabled = true
		m.emission = Color(e[0], e[1], e[2])
		m.emission_energy_multiplier = 1.0
	m.cull_mode = BaseMaterial3D.CULL_BACK if int(d.get("cull", 2)) == 2 else BaseMaterial3D.CULL_DISABLED
	mat_cache[mat_name] = m
	return m

func _arg_spec() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--spec="):
			return float(a.trim_prefix("--spec="))
	return 0.25

func apply_materials(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var orig: Material = mi.mesh.surface_get_material(i)
			var nm: String = orig.resource_name if orig != null else ""
			if mat_defs.has(nm) and not CUSTOM_SHADER_MATS.has(nm):
				mi.set_surface_override_material(i, get_material(nm))
			elif not mat_defs.has(nm):
				unmatched[nm] = true

# 유니티 충돌 모양(scene.json의 colliders)을 같은 모양으로 만든다. 메시 충돌은 모델 모양 그대로, 캡슐·상자·구는 중심/크기 문자열을 읽음.
func add_colliders(node: Node3D, it: Dictionary) -> void:
	if not it.has("colliders"):
		return
	for c in it["colliders"]:
		var cs: String = c
		if cs == "MeshCollider":
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).create_trimesh_collision()
			continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var center := _vec(cs, "center")
		if cs.begins_with("Capsule"):
			var cap := CapsuleShape3D.new()
			cap.radius = _num(cs, "radius")
			cap.height = _num(cs, "height")
			shape.shape = cap
		elif cs.begins_with("Sphere"):
			var sp := SphereShape3D.new()
			sp.radius = _num(cs, "radius")
			shape.shape = sp
		elif cs.begins_with("Box"):
			var bx := BoxShape3D.new()
			bx.size = _vec(cs, "size")
			shape.shape = bx
		else:
			continue
		body.position = Vector3(-center.x, center.y, -center.z)   # 모델 안쪽 좌표(위치 z 반전 + 모델 Y180 보정)
		body.add_child(shape)
		node.add_child(body)

static func _vec(s: String, key: String) -> Vector3:
	var re := RegEx.create_from_string(key + r"=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)")
	var m := re.search(s)
	if m == null:
		return Vector3.ZERO
	return Vector3(float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3)))

static func _num(s: String, key: String) -> float:
	var re := RegEx.create_from_string(key + r"=([-\d.]+)")
	var m := re.search(s)
	return float(m.get_string(1)) if m != null else 0.0

# 바다 충돌판: 이름이 "Sea"인 큰 판(낚싯줄 찌가 바다인지 땅인지 가를 때 이름으로 찾음). 유니티 바다 판은 300x300, 높이 -0.1
func add_sea_body() -> void:
	var body := StaticBody3D.new()
	body.name = "Sea"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	shape.shape = box
	body.position = Vector3(0, -0.1 - 0.5, 0)
	body.add_child(shape)
	add_child(body)
	var mesh_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	mesh_node.mesh = plane
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = load("res://shaders/sea.gdshader")
	mesh_node.material_override = sea_mat
	mesh_node.position = Vector3(0, -0.1, 0)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_node)

func build() -> void:
	var mf := FileAccess.open(MATERIALS_JSON, FileAccess.READ)
	mat_defs = JSON.parse_string(mf.get_as_text())
	var f := FileAccess.open(SCENE_JSON, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	items = data["items"]
	for it in items:
		by_path[it["path"]] = it
	for it in items:
		if not it["active"] or not it.has("source") or it["source"] == "":
			continue
		var parent_item = by_path.get(it["parent"], null)
		if parent_item != null and parent_item.get("source", "") == it["source"]:
			skipped_child += 1   # FBX 안의 조각이 또 목록에 있는 경우: 맨 위 것만 놓음
			continue
		var path := model_path(it["source"])
		if not ResourceLoader.exists(path):
			push_warning("모델 없음: " + path)
			continue
		var ps: PackedScene = load(path)
		var node: Node3D = ps.instantiate()
		node.name = it["name"]
		var s: Array = it["scale"]
		var basis := to_godot_basis(it["quat"]) * MODEL_FIX
		node.transform = Transform3D(basis.scaled(Vector3(s[0], s[1], s[2])), to_godot_pos(it["pos"]))
		add_child(node)
		apply_materials(node)
		add_colliders(node, it)
		spawned += 1
	add_sea_body()
	print("[FG] world built: ", spawned, " models (skipped child pieces: ", skipped_child, "), unmatched materials: ", unmatched.keys())
