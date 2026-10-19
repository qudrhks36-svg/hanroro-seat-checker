extends RefCounted
# 모델 면 부드럽게 보이기 (포팅 10단계 시험): 블렌더 모델이 면마다 따로 밝기를 받는 "각진(flat)" 상태로 나와서 레고처럼 보임.
# 모양(꼭짓점)은 그대로 두고, 같은 자리에서 만나는 면들 중 서로 각도가 작은(기본 55도 미만) 것끼리 법선(밝기 방향)을 평균 내서
# 둥근 면처럼 이어 보이게 한다. 상자 모서리·뾰족한 지붕처럼 각이 큰 곳은 그대로 각지게 남는다.
# 같은 모델(메시)은 한 번만 처리해서 나눠 쓴다. 뼈대(스킨)가 있는 메시는 건드리지 않는다.

static var cache: Dictionary = {}   # 원래 메시 → 부드럽게 만든 메시
static var stat_corners := 0
static var stat_changed := 0

static func smooth_node(root: Node, angle_deg: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null or angle_deg <= 0.0:
			continue
		var src: Mesh = mi.mesh
		if not cache.has(src):
			cache[src] = smooth_mesh(src, cos(deg_to_rad(angle_deg)))
		mi.mesh = cache[src]

static func smooth_mesh(src: Mesh, cos_t: float) -> Mesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var a: Array = src.surface_get_arrays(s)
		if src.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES or a[Mesh.ARRAY_BONES] != null:
			return src   # 삼각형이 아니거나 뼈대가 있으면 손대지 않음
	for s in src.get_surface_count():
		var a: Array = src.surface_get_arrays(s)
		var b := _smooth_surface(a, cos_t)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		out.surface_set_material(s, src.surface_get_material(s))
		out.surface_set_name(s, src.surface_get_name(s))
	return out

# 삼각형을 낱개로 펼친 뒤(꼭짓점 하나에 면 하나), 각 꼭짓점의 법선 = 같은 자리·비슷한 방향 면들의 넓이 가중 평균
static func _smooth_surface(a: Array, cos_t: float) -> Array:
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(v.size())
		for i in v.size():
			idx[i] = i
	var uv = a[Mesh.ARRAY_TEX_UV]
	var uv2 = a[Mesh.ARRAY_TEX_UV2]
	var col = a[Mesh.ARRAY_COLOR]
	var old_n = a[Mesh.ARRAY_NORMAL]
	var count := idx.size()
	var tris := count / 3
	var nv := PackedVector3Array()
	nv.resize(count)
	var nuv := PackedVector2Array()
	var nuv2 := PackedVector2Array()
	var ncol := PackedColorArray()
	var nold := PackedVector3Array()
	if uv != null:
		nuv.resize(count)
	if uv2 != null:
		nuv2.resize(count)
	if col != null:
		ncol.resize(count)
	nold.resize(count)
	for c in count:
		var k := idx[c]
		nv[c] = v[k]
		if uv != null:
			nuv[c] = uv[k]
		if uv2 != null:
			nuv2[c] = uv2[k]
		if col != null:
			ncol[c] = col[k]
		if old_n != null:
			nold[c] = old_n[k]
	# 면 법선(넓이 가중: 정규화 전 외적)
	var fn: Array = []
	fn.resize(tris)
	for t in tris:
		var p0 := nv[t * 3]
		var f: Vector3 = (nv[t * 3 + 2] - p0).cross(nv[t * 3 + 1] - p0)   # 고닷은 시계 방향이 앞면이라 외적 순서가 반대
		if old_n != null and f.dot(nold[t * 3] + nold[t * 3 + 1] + nold[t * 3 + 2]) < 0.0:
			f = -f   # 원래 법선과 반대로 나오면 뒤집음(모델 안쪽 방향 실수 방지)
		fn[t] = f
	# 같은 자리 꼭짓점끼리 묶기 (1mm 단위로 맞춤)
	var groups: Dictionary = {}
	for c in count:
		var p := nv[c]
		var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(c / 3)
	var nn := PackedVector3Array()
	nn.resize(count)
	for c in count:
		var p := nv[c]
		var key := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
		var f0: Vector3 = fn[c / 3]
		var f0n := f0.normalized()
		var sum := Vector3.ZERO
		for g in groups[key]:
			var fg: Vector3 = fn[g]
			if fg.length_squared() > 0.0 and f0n.dot(fg.normalized()) >= cos_t:
				sum += fg
		var res := sum.normalized() if sum.length_squared() > 0.0 else f0n
		nn[c] = res
		stat_corners += 1
		if res.dot(f0n) < 0.9999:
			stat_changed += 1
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_NORMAL] = nn
	if uv != null:
		out[Mesh.ARRAY_TEX_UV] = nuv
	if uv2 != null:
		out[Mesh.ARRAY_TEX_UV2] = nuv2
	if col != null:
		out[Mesh.ARRAY_COLOR] = ncol
	return out
