extends Node3D
# 낚시 물보라·물결 (포팅 8단계, GDD 9번 [확정] 낚시 연출 ③, 유니티 SplashFx): 찌가 물에 닿을 때·입질이 올 때·낚았을 때 쓰는 효과.
# 물결 고리 = 물 위에 눕힌 납작한 판에 고리 무늬를 입혀 커지며 사라지게 함, 물방울 = 한 번 터지는 CPU 입자(웹에서 안전). 그림 파일 없이 코드로 무늬를 만든다.

static var _dot_tex: ImageTexture
static var _ring_tex: ImageTexture

var rings: Array = []   # {mesh, mat, t, life, size}
var plane: PlaneMesh

func _ready() -> void:
	plane = PlaneMesh.new()
	plane.size = Vector2.ONE

# 가운데는 밝고 가장자리로 부드럽게 사라지는 빛 점 (유니티 SoftDot 셰이더와 같은 식). 반딧불·물방울이 같이 씀
static func soft_dot() -> ImageTexture:
	if _dot_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2((x + 0.5) / n - 0.5, (y + 0.5) / n - 0.5).length() * 2.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				a *= a
				var core := clampf(1.0 - d * 2.5, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 1.6 + core, 0.0, 1.0)))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex

# 가운데가 비고 가장자리가 부드러운 고리 (유니티 Ring 셰이더와 같은 식)
static func ring_texture() -> ImageTexture:
	if _ring_tex == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2((x + 0.5) / n - 0.5, (y + 0.5) / n - 0.5).length() * 2.0
				var r := smoothstep(0.62, 0.86, d) * (1.0 - smoothstep(0.88, 1.0, d))
				img.set_pixel(x, y, Color(1, 1, 1, r))
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex

# 빛 점을 더해서(Additive) 그리는 재질. 입자 색은 정점 색으로 들어옴
static func glow_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	return m

# 가운데에서 퍼지는 물결 고리 한 개 (size = 다 퍼졌을 때 지름 m)
func ring(pos: Vector3, size: float, life: float = 1.2) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = ring_texture()
	m.albedo_color = Color(0.85, 0.97, 1.0, 0.0)
	mi.material_override = m
	mi.position = pos + Vector3.UP * 0.04
	mi.scale = Vector3.ONE * size * 0.12
	add_child(mi)
	rings.append({"mesh": mi, "mat": m, "t": 0.0, "life": life, "size": size})

# 물보라: 물결 고리 두 개 + 물방울 (big이면 더 크게)
func splash(pos: Vector3, big: bool) -> void:
	ring(pos, 2.4 if big else 1.5, 1.1)
	ring(pos, 4.0 if big else 2.4, 1.7)
	_drops(pos, 16 if big else 9, 1.4 if big else 1.0)

func _drops(pos: Vector3, n: int, power: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.85
	p.lifetime_randomness = 0.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = 2.5 * power
	p.initial_velocity_max = 4.8 * power
	p.gravity = Vector3(0, -9.8 * 1.7, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.24
	p.color = Color(0.8, 0.95, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.6, Color(1, 1, 1, 0.9))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = glow_material(soft_dot())
	p.mesh = q
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos + Vector3.UP * 0.05
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

func _process(delta: float) -> void:
	var i := rings.size() - 1
	while i >= 0:
		var r: Dictionary = rings[i]
		r["t"] += delta
		var k: float = r["t"] / r["life"]
		if k >= 1.0:
			(r["mesh"] as Node).queue_free()
			rings.remove_at(i)
		else:
			# 크기: 0.12 → 0.62(35%) → 1.0, 투명도: 0 → 0.9(10%) → 0 (유니티와 같은 곡선)
			var s: float = lerpf(0.12, 0.62, k / 0.35) if k < 0.35 else lerpf(0.62, 1.0, (k - 0.35) / 0.65)
			var a: float = lerpf(0.0, 0.9, k / 0.1) if k < 0.1 else lerpf(0.9, 0.0, (k - 0.1) / 0.9)
			(r["mesh"] as Node3D).scale = Vector3.ONE * float(r["size"]) * s
			(r["mat"] as StandardMaterial3D).albedo_color = Color(0.85, 0.97, 1.0, a)
		i -= 1
