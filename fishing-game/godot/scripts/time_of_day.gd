extends Node
# 하루 10분: 낮 4분 → 노을 2분 → 밤 4분 (GDD 7번). 유니티 TimeOfDay의 고닷 버전.
# 키프레임 사이를 부드럽게(smoothstep) 섞은 look을 Atmosphere.apply_look()에 매 프레임 넣는다. 시간은 delta로 세므로 get_tree().paused 일 때 멈춘다.

enum Period { DAY, SUNSET, NIGHT }

const DAY_LENGTH := 600.0
const KEY_TIMES := [0.0, 210.0, 270.0, 330.0, 390.0, 570.0, 600.0]
const KEY_LOOKS := ["day", "day", "sunset", "sunset", "night", "night", "day"]

static var period: Period = Period.DAY   # 지금 시간대 (낚시가 읽음)
static var night := 0.0                   # 0=낮 … 1=한밤 (반딧불 같은 밤 장식이 읽음)

var atmo: Node
var clock := 0.0

static func period_at(t: float) -> Period:
	return Period.DAY if t < 240.0 else (Period.SUNSET if t < 360.0 else Period.NIGHT)

func _process(delta: float) -> void:
	clock = fmod(clock + delta, DAY_LENGTH)
	apply(clock)

# 두 look(색 배열·숫자)을 k(0~1)만큼 섞는다
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in a:
		var va = a[key]
		var vb = b[key]
		if va is Array:
			var arr := []
			for i in va.size():
				arr.append(lerpf(va[i], vb[i], k))
			out[key] = arr
		else:
			out[key] = lerpf(va, vb, k)
	return out

func apply(t: float) -> void:
	period = period_at(t)
	var i := 0
	while i < KEY_TIMES.size() - 2 and t >= KEY_TIMES[i + 1]:
		i += 1
	var k := smoothstep(0.0, 1.0, inverse_lerp(KEY_TIMES[i], KEY_TIMES[i + 1], t))
	var look := blend(atmo.looks[KEY_LOOKS[i]], atmo.looks[KEY_LOOKS[i + 1]], k)
	night = float(look["stars"])
	atmo.apply_look(look, preload("res://scripts/weather.gd").overcast)
