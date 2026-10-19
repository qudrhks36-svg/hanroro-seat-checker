extends Node3D
# 시작 장면 (포팅 2단계): 섬을 놓고, 플레이어·빛·글자를 만든다.
# 사진·동작 시험용 명령줄(`godot ... -- --cam=a --walk=0,1`): --cam=키(유니티 사진 시험과 같은 자리), --walk=좌우,앞뒤(키 대신 걷기), --tm= --energy= --amb=

const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const WeatherScript := preload("res://scripts/weather.gd")
const FishingScript := preload("res://scripts/fishing_rod.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const HudScript := preload("res://scripts/hud.gd")
const CatalogScript := preload("res://scripts/catalog.gd")
const ResultCardScript := preload("res://scripts/result_card.gd")

# 유니티 사진 시험(ScreenShot.cs)과 같은 카메라: 눈 위치(유니티 좌표)와 오일러 각도(x=아래로 숙임, y=좌우)
const DEBUG_CAMS := {
	"a": [Vector3(0, 1.7, 0), Vector3(8, 0, 0)],
	"b": [Vector3(0, 1.7, 0), Vector3(8, 90, 0)],
	"c": [Vector3(0, 1.7, 0), Vector3(8, 270, 0)],
	"d": [Vector3(0, 1.7, 0), Vector3(8, 180, 0)],
	"e": [Vector3(0, 38, -34), Vector3(52, 0, 0)],
	"f": [Vector3(-6, 1.7, -10), Vector3(6, 20, 0)],
	"g": [Vector3(-6, 2, 3), Vector3(4, 270, 0)],
	"j": [Vector3(-14, 2, -6), Vector3(4, 227, 0)],
}

var fishing: Node3D
var world: Node3D
var player: CharacterBody3D
var frames := 0
var weather: Node
var tod: Node

func _arg(key: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.trim_prefix("--" + key + "=")
	return default

func _ready() -> void:
	var env := Environment.new()
	AtmosphereScript.ensure_globals()   # 셰이더가 읽는 전역 값은 셰이더를 불러오기 전에 먼저 만든다
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if _arg("refl", "0") == "0" else Environment.REFLECTION_SOURCE_SKY
	# 유니티 후처리(SampleSceneProfile)에 맞춤: 중립 톤매핑 ≈ AgX, 노출 +0.1. 대비·채도·빛 세기는 같은 자리 사진의 색과 비교해 정한 값(채도는 하늘·바다가 너무 진해지지 않는 선)
	env.tonemap_mode = int(_arg("tm", "4"))
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.07
	env.adjustment_contrast = float(_arg("con", "1.1"))
	env.adjustment_saturation = float(_arg("sat", "1.15"))
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	world = Node3D.new()
	world.set_script(WorldScript)
	world.name = "World"
	add_child(world)
	world.build()

	# 해·하늘·바다·안개: 시간대 모습(look)을 한 번에 넣는다 (3단계에서 시간에 따라 섞음). 시험용 --look=day|sunset|night
	var sun := DirectionalLight3D.new()
	add_child(sun)
	var atmo := Node.new()
	atmo.set_script(AtmosphereScript)
	atmo.name = "Atmosphere"
	add_child(atmo)
	atmo.load_looks()
	atmo.sun_energy_per_intensity = float(_arg("energy", "0.08"))
	atmo.ambient_energy = float(_arg("amb", "1.0"))
	atmo.fog_density_objects = float(_arg("fd", "0.001"))
	AtmosphereScript.color_power = float(_arg("cp", "1.3"))
	atmo.setup(env, sun)
	if _arg("fog", "1") == "0":
		env.fog_enabled = false
	atmo.apply_look(atmo.looks[_arg("look", "day")])   # 시간·날씨 노드가 매 프레임 덮어씀

	weather = Node.new()
	weather.set_script(WeatherScript)
	weather.name = "Weather"
	add_child(weather)
	tod = Node.new()
	tod.set_script(TimeScript)
	tod.name = "TimeOfDay"
	tod.atmo = atmo
	add_child(tod)

	# 플레이어: 유니티 시작 자리 (0, 1.1, 0), 앞은 -Z
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.position = Vector3(0, 1.1, 0)
	add_child(player)
	weather.follow = player.cam
	_apply_test_args()

	# 저장 불러오기(도감·보유·기록·소지금), 낚시: 낚싯대·찌·줄·안내 판·릴 화면 (4단계)
	if _arg("nosave", "") == "":
		SaveScript.load_game()
	SfxScript.host = self
	fishing = Node3D.new()
	fishing.set_script(FishingScript)
	fishing.name = "Fishing"
	add_child(fishing)
	fishing.setup(player.cam, world)
	# 상태창·결과 카드·도감 (5단계)
	var hud := CanvasLayer.new()
	hud.set_script(HudScript)
	hud.name = "Hud"
	hud.fishing = fishing
	add_child(hud)
	var result_card := CanvasLayer.new()
	result_card.set_script(ResultCardScript)
	result_card.name = "ResultCard"
	add_child(result_card)
	fishing.result_card = result_card
	var catalog := CanvasLayer.new()
	catalog.set_script(CatalogScript)
	catalog.name = "Catalog"
	add_child(catalog)
	if _arg("catalog", "") != "":   # 시험용: 도감을 열고 이 번호 칸을 고른다
		catalog.debug = true
		catalog.selected = int(_arg("catalog", "0"))
		catalog.set_open(true, false)
	fishing.auto = _arg("auto", "") != ""
	if _arg("rodcheck", "") != "":
		fishing.debug_rod()
	if _arg("bait", "") != "":
		fishing.selected_bait = int(_arg("bait", "0"))
	if _arg("timescale", "") != "":
		Engine.time_scale = float(_arg("timescale", "1"))

func _apply_test_args() -> void:
	var key := _arg("cam", "")
	if DEBUG_CAMS.has(key):
		var p: Vector3 = DEBUG_CAMS[key][0]
		var e: Vector3 = DEBUG_CAMS[key][1]
		player.position = Vector3(p.x, p.y - player.EYE_HEIGHT, -p.z)
		player.look(-e.y, -e.x)   # 유니티 오일러(x 숙임, y 좌우)를 고닷으로: 숙임은 -x, 좌우는 z 반전이라 부호 반대
	var yaw := _arg("yaw", "")            # 시험용: 바라보는 방향(도, 0=유니티 +Z, 90=왼쪽(유니티 -X))
	if yaw != "":
		player.look(float(yaw), 0.0)
	var pos := _arg("pos", "")   # 시험용 시작 자리(유니티 좌표 x,z)
	if pos != "":
		var q := pos.split(",")
		player.position = Vector3(float(q[0]), 1.1, -float(q[1]))
	var clock := _arg("clock", "")        # 시험용: 시각(초, 0=낮 300=노을 450=밤)
	if clock != "":
		tod.clock = float(clock)
		tod.apply(tod.clock)
	tod.frozen = _arg("freeze", "") != ""
	var wk := _arg("weather", "")        # 시험용: clear / cloudy / rain
	if wk != "":
		weather.force({"clear": WeatherScript.Kind.CLEAR, "cloudy": WeatherScript.Kind.CLOUDY, "rain": WeatherScript.Kind.RAIN}[wk])
	var walk := _arg("walk", "")
	if walk != "":
		var w := walk.split(",")
		player.test_walk = Vector2(float(w[0]), float(w[1]))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 첫 클릭은 시작(마우스 잠금)만 하고, 낚시가 던지기로 받지 않게 먹는다
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

var probed := false
func _physics_process(_delta: float) -> void:
	var probe := _arg("probe", "")   # 시험용: x1,x2,z1,z2 (유니티 좌표) 안을 0.25 간격으로 위에서 아래로 쏴 높이와 이름을 찍음
	if probe != "" and not probed:
		probed = true
		var q := probe.split(",")
		var z := float(q[2])
		while z <= float(q[3]) + 0.01:
			var x := float(q[0])
			var row := ""
			while x <= float(q[1]) + 0.01:
				var from := Vector3(x, 10, -z)
				var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20))
				row += ("%5.2f " % hit.position.y) if hit else " none "
				x += 0.25
			print("[FG] probe z=", z, " | ", row)
			z += 0.25

func _process(_delta: float) -> void:
	frames += 1
	if _arg("log", "") != "" and frames % 10 == 0:
		print("[FG] frame ", frames, " player=", player.position, " floor=", player.is_on_floor(), " hit=", player.dbg)
