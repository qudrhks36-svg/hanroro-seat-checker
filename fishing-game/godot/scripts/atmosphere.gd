extends Node
# 하늘·바다·안개·해 (유니티 TimeOfDay.Apply의 고닷 버전): 한 시점의 "모습(look)"을 받아 셰이더 전역 값과 환경·해에 넣는다.
# look 은 data/world.json 의 looks.day / sunset / night 모양(색은 sRGB 배열). 낮·노을·밤 섞기는 3단계(시간대)에서 이 함수에 섞은 look을 넣으면 된다.

const WORLD_JSON := "res://data/world.json"
const SUN_YAW := 330.0                 # 유니티: 해 방향은 y 330도 고정, 높이(pitch)만 변함
var sun_energy_per_intensity := 0.36   # 유니티 해 세기 2.0 ≈ 고닷 0.72 (고닷은 빛 세기에 내부적으로 π를 곱해 유니티보다 훨씬 밝게 나옴. 같은 자리 사진 색 비교로 맞춤)
var ambient_energy := 0.1              # 유니티 평평한 주변광 ≈ 고닷 0.1 (고닷 주변광이 유니티보다 훨씬 강하게 더해짐)
var fog_density_objects := 0.001       # 모델·땅에 쓰는 고닷 지수 안개 (사진 색 비교로 맞춤, 시험용으로 main에서 바꿀 수 있음)
const FOG_DENSITY_SEA := 0.010         # 바다 셰이더가 직접 계산하는 지수 제곱 안개 (유니티와 같은 값)

var env: Environment
var sun: DirectionalLight3D
var looks: Dictionary = {}

static func _lin(a: Array) -> Color:
	return Color(a[0], a[1], a[2])   # 유니티는 전역 색을 변환 없이 그대로 쓴 값처럼 보임(사진 비교) → 고닷도 변환하지 않음

static func ensure_globals() -> void:
	# 셰이더가 읽는 전역 변수. 셰이더를 불러오기 전에 먼저 만들어 둔다.
	var colors := ["sky_top", "sky_glow_color", "fog_color", "sea_shallow", "sea_deep", "sea_foam"]
	for n in colors:
		RenderingServer.global_shader_parameter_add(n, RenderingServer.GLOBAL_VAR_TYPE_COLOR, Color.BLACK)
	RenderingServer.global_shader_parameter_add("sun_dir", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.UP)
	for n in ["sky_glow", "stars", "sea_glint"]:
		RenderingServer.global_shader_parameter_add(n, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add("fog_density", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, FOG_DENSITY_SEA)

func load_looks() -> void:
	var f := FileAccess.open(WORLD_JSON, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	looks = data["looks"]

func setup(environment: Environment, light: DirectionalLight3D) -> void:
	env = environment
	sun = light
	env.fog_enabled = true
	env.fog_density = fog_density_objects
	env.fog_sky_affect = 0.0           # 유니티 하늘 셰이더는 안개를 안 받음
	env.ambient_light_energy = ambient_energy
	sun.shadow_enabled = true

func apply_look(look: Dictionary) -> void:
	var fog := _lin(look["fog"])
	RenderingServer.global_shader_parameter_set("sky_top", _lin(look["sky_top"]))
	RenderingServer.global_shader_parameter_set("sky_glow_color", _lin(look["sky_glow_color"]))
	RenderingServer.global_shader_parameter_set("fog_color", fog)
	RenderingServer.global_shader_parameter_set("sea_shallow", _lin(look["sea_shallow"]))
	RenderingServer.global_shader_parameter_set("sea_deep", _lin(look["sea_deep"]))
	RenderingServer.global_shader_parameter_set("sea_foam", _lin(look["sea_foam"]))
	RenderingServer.global_shader_parameter_set("sky_glow", float(look["sky_glow"]))
	RenderingServer.global_shader_parameter_set("stars", float(look["stars"]))
	RenderingServer.global_shader_parameter_set("sea_glint", float(look["sea_glint"]))

	# 해: 유니티 Quaternion.Euler(pitch, 330, 0) → 고닷 (z 반전 변환). 해 쪽 방향 = 빛이 비추는 방향의 반대 = 몸의 +Z
	var q := Quaternion(Vector3.UP, deg_to_rad(SUN_YAW)) * Quaternion(Vector3.RIGHT, deg_to_rad(float(look["sun_pitch"])))
	sun.basis = Basis(Quaternion(-q.x, -q.y, q.z, q.w))
	sun.light_color = Color(look["sun_color"][0], look["sun_color"][1], look["sun_color"][2])
	sun.light_energy = float(look["sun_intensity"]) * sun_energy_per_intensity
	RenderingServer.global_shader_parameter_set("sun_dir", sun.basis.z.normalized())

	env.ambient_light_color = Color(look["ambient"][0], look["ambient"][1], look["ambient"][2])
	env.fog_light_color = Color(look["fog"][0], look["fog"][1], look["fog"][2])
