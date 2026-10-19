extends Node
# 날씨 (GDD 9번 [확정]): 맑음 → 흐림 → 비로 이어지며 시간이 지나면 저절로 바뀐다. 낚시에는 영향 없고 분위기만 바꾼다(보기·아주 작은 빗소리).
# 하늘·안개·바다 색은 TimeOfDay가 overcast(0~1)를 읽어 회색빛으로 바꾼다. 비는 카메라 위에서 내리는 빗줄기 입자. 저장하지 않음(시작은 늘 맑음).

enum Kind { CLEAR, CLOUDY, RAIN }

const CHANGE_MIN := 70.0
const CHANGE_MAX := 130.0
const FADE_SECONDS := 10.0
const RAIN_SOUND_VOLUME := 0.06       # 아주 작은 빗소리. 별로면 0으로 (사용자: "나중에 별로면 뺄게")
const RAIN_SOUND_PATH := "res://assets/audio/sfx/rain_loop.wav"

static var current: Kind = Kind.CLEAR
static var overcast := 0.0            # 0=맑음 … 0.6=흐림 … 1=비 (천천히 따라감)
static var rain_amount := 0.0         # 0~1 비의 세기 (천천히 따라감)

var follow: Node3D                    # 비가 따라다닐 카메라
var timer := 0.0
var rain: CPUParticles3D
var sound: AudioStreamPlayer

static func kind_name(k: Kind) -> String:
	return "맑음" if k == Kind.CLEAR else ("흐림" if k == Kind.CLOUDY else "비")

static func reset() -> void:
	current = Kind.CLEAR
	overcast = 0.0
	rain_amount = 0.0

func _ready() -> void:
	reset()
	timer = randf_range(CHANGE_MIN, CHANGE_MAX)
	# 웹에서 안전하도록 CPU 입자. 폭 36m 상자에서 17m/s로 비스듬히 떨어지는 가는 줄.
	rain = CPUParticles3D.new()
	rain.amount = 900
	rain.lifetime = 0.8
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(18, 0.05, 18)
	rain.direction = Vector3(0.09, -1.0, 0.0).normalized()
	rain.spread = 0.0
	rain.initial_velocity_min = 17.0
	rain.initial_velocity_max = 17.0
	rain.gravity = Vector3.ZERO
	rain.local_coords = false
	rain.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.55, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.35)
	mesh.material = mat
	rain.mesh = mesh
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	add_child(rain)
	sound = AudioStreamPlayer.new()
	sound.stream = load(RAIN_SOUND_PATH)
	sound.volume_db = -80.0
	add_child(sound)

static func next(k: Kind) -> Kind:
	# 맑음→{맑음 .4, 흐림 .6}, 흐림→{맑음 .4, 흐림 .2, 비 .4}, 비→{흐림 .7, 비 .3}. 비는 흐림을 거쳐서만 온다.
	var v := randf()
	match k:
		Kind.CLEAR:
			return Kind.CLEAR if v < 0.4 else Kind.CLOUDY
		Kind.CLOUDY:
			return Kind.CLEAR if v < 0.4 else (Kind.CLOUDY if v < 0.6 else Kind.RAIN)
		_:
			return Kind.CLOUDY if v < 0.7 else Kind.RAIN

func force(k: Kind) -> void:
	# 시험용: 이 날씨로 바로 바꾸고(천천히 따라가지 않고) 오래 유지
	current = k
	overcast = 0.0 if k == Kind.CLEAR else (0.6 if k == Kind.CLOUDY else 1.0)
	rain_amount = 1.0 if k == Kind.RAIN else 0.0
	timer = 1.0e9

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		current = next(current)
		timer = randf_range(CHANGE_MIN, CHANGE_MAX)
	var target := 0.0 if current == Kind.CLEAR else (0.6 if current == Kind.CLOUDY else 1.0)
	var step := delta / FADE_SECONDS
	overcast = move_toward(overcast, target, step)
	rain_amount = move_toward(rain_amount, 1.0 if current == Kind.RAIN else 0.0, step)

	rain.emitting = rain_amount > 0.01
	rain.color = Color(1, 1, 1, rain_amount)
	if follow != null:
		var fwd := -follow.global_transform.basis.z
		fwd.y = 0.0
		rain.global_position = follow.global_position + Vector3.UP * 9.0 + fwd.normalized() * 6.0   # 늘 시야 위·앞에서 내림
	if rain_amount > 0.0:
		if not sound.playing:
			sound.play()
		sound.volume_db = linear_to_db(maxf(RAIN_SOUND_VOLUME * rain_amount, 0.0001))
	elif sound.playing:
		sound.stop()
