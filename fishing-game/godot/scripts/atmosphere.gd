extends Node
# 하늘·바다·안개·해 (유니티 TimeOfDay.Apply의 고닷 버전): 한 시점의 "모습(look)"을 받아 셰이더 전역 값과 환경·해에 넣는다.
# look 은 data/world.json 의 looks.day / sunset / night 모양(색은 sRGB 배열). 낮·노을·밤 섞기는 3단계(시간대)에서 이 함수에 섞은 look을 넣으면 된다.

const WORLD_JSON := "res://data/world.json"
const SUN_YAW := 330.0                 # 유니티: 해 방향은 y 330도 고정, 높이(pitch)만 변함
var sun_energy_per_intensity := 0.08   # 유니티 해 세기 2.0 ≈ 고닷 0.16 (주변광을 유니티처럼 크게 쓰므로 해는 작게. 낮·노을·밤 같은 자리 사진 색 비교로 맞춤)
var ambient_energy := 1.0              # 유니티 평평한 주변광과 같게(선형 값 그대로)
var fog_density_objects := 0.001       # 모델·땅에 쓰는 고닷 지수 안개 (사진 색 비교로 맞춤, 시험용으로 main에서 바꿀 수 있음)
const FOG_DENSITY_SEA := 0.010         # 바다 셰이더가 직접 계산하는 지수 제곱 안개 (유니티와 같은 값)

var env: Environment
var sun: DirectionalLight3D
var looks: Dictionary = {}

# 유니티 셰이더 색 → 고닷 전역 색. 유니티 사진(낮·노을·밤 바다·하늘)에 맞추면 "값의 약 1.3제곱"(선형)으로 보임.
# 고닷은 전역 색 변수를 받을 때 sRGB→선형 변환을 한 번 해 버리므로, 미리 반대로 바꿔서 넣는다.
static var color_power := 1.3

static func _lin(a: Array) -> Color:
	var c := Color(pow(a[0], color_power), pow(a[1], color_power), pow(a[2], color_power))
	return c.linear_to_srgb()

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

# 색의 밝기만 남기고 회색 쪽으로 amount만큼 섞은 뒤 dim을 곱함 (유니티 TimeOfDay.Grey)
static func _grey(c: Color, amount: float, dim: float) -> Color:
	var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	var g := c.lerp(Color(l, l, l), amount)
	return Color(g.r * dim, g.g * dim, g.b * dim, c.a)

# overcast: 0=맑음 … 1=비. 흐림·비일 때 하늘·안개·바다를 회색빛으로, 해·해무리·반짝임은 약하게 (GDD 9번 날씨, 유니티 TimeOfDay.Apply와 같은 식)
func apply_look(look: Dictionary, overcast: float = 0.0) -> void:
	var o := overcast
	var fog := _grey(_lin(look["fog"]), o * 0.9, 1.0 - 0.15 * o)
	RenderingServer.global_shader_parameter_set("sky_top", _grey(_lin(look["sky_top"]), o * 0.95, 1.0 - 0.15 * o))
	RenderingServer.global_shader_parameter_set("sky_glow_color", _lin(look["sky_glow_color"]))
	RenderingServer.global_shader_parameter_set("fog_color", fog)
	RenderingServer.global_shader_parameter_set("sea_shallow", _grey(_lin(look["sea_shallow"]), o * 0.6, 1.0 - 0.22 * o))
	RenderingServer.global_shader_parameter_set("sea_deep", _grey(_lin(look["sea_deep"]), o * 0.6, 1.0 - 0.22 * o))
	RenderingServer.global_shader_parameter_set("sea_foam", _lin(look["sea_foam"]))
	RenderingServer.global_shader_parameter_set("sky_glow", float(look["sky_glow"]) * (1.0 - 0.8 * o))
	RenderingServer.global_shader_parameter_set("stars", float(look["stars"]))
	RenderingServer.global_shader_parameter_set("sea_glint", float(look["sea_glint"]) * (1.0 - 0.7 * o))

	# 해: 유니티 Quaternion.Euler(pitch, 330, 0) → 고닷 (z 반전 변환). 해 쪽 방향 = 빛이 비추는 방향의 반대 = 몸의 +Z
	var q := Quaternion(Vector3.UP, deg_to_rad(SUN_YAW)) * Quaternion(Vector3.RIGHT, deg_to_rad(float(look["sun_pitch"])))
	sun.basis = Basis(Quaternion(-q.x, -q.y, q.z, q.w))
	sun.light_color = Color(look["sun_color"][0], look["sun_color"][1], look["sun_color"][2])
	sun.light_energy = float(look["sun_intensity"]) * sun_energy_per_intensity * (1.0 - 0.5 * o)
	RenderingServer.global_shader_parameter_set("sun_dir", sun.basis.z.normalized())

	# 유니티 주변광도 색 값을 변환 없이 쓴 것처럼 보임(밤 사진 비교) → 고닷은 sRGB로 받으므로 선형 값을 sRGB로 바꿔서 넣음
	env.ambient_light_color = Color(look["ambient"][0], look["ambient"][1], look["ambient"][2]).linear_to_srgb()
	env.fog_light_color = fog
