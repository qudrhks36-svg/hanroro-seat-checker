extends Node3D
# 시작 장면 (포팅 2단계): 섬을 놓고, 플레이어·빛·글자를 만든다.
# 사진·동작 시험용 명령줄(`godot ... -- --cam=a --walk=0,1`): --cam=키(유니티 사진 시험과 같은 자리), --walk=좌우,앞뒤(키 대신 걷기), --tm= --energy= --amb=

const WorldScript := preload("res://scripts/world.gd")
const PlayerScript := preload("res://scripts/player.gd")
const AtmosphereScript := preload("res://scripts/atmosphere.gd")

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

var label: Label
var world: Node3D
var player: CharacterBody3D
var frames := 0

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
	env.adjustment_saturation = float(_arg("sat", "1.25"))
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
	atmo.sun_energy_per_intensity = float(_arg("energy", "0.36"))
	atmo.ambient_energy = float(_arg("amb", "0.1"))
	atmo.fog_density_objects = float(_arg("fd", "0.001"))
	atmo.setup(env, sun)
	if _arg("fog", "1") == "0":
		env.fog_enabled = false
	atmo.apply_look(atmo.looks[_arg("look", "day")])

	# 플레이어: 유니티 시작 자리 (0, 1.1, 0), 앞은 -Z
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.position = Vector3(0, 1.1, 0)
	add_child(player)
	_apply_test_args()

	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	var jua: FontFile = load("res://assets/fonts/Jua-Regular.ttf")
	jua.fallbacks = [ThemeDB.fallback_font]   # 주아에 없는 기호(· … —)는 고닷 기본 글꼴로 (웹에는 시스템 대체 글꼴이 없음)
	label.add_theme_font_override("font", jua)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.33, 0.23, 0.16))
	label.position = Vector2(24, 24)
	layer.add_child(label)

func _apply_test_args() -> void:
	var key := _arg("cam", "")
	if DEBUG_CAMS.has(key):
		var p: Vector3 = DEBUG_CAMS[key][0]
		var e: Vector3 = DEBUG_CAMS[key][1]
		player.position = Vector3(p.x, p.y - player.EYE_HEIGHT, -p.z)
		player.look(-e.y, -e.x)   # 유니티 오일러(x 숙임, y 좌우)를 고닷으로: 숙임은 -x, 좌우는 z 반전이라 부호 반대
	var pos := _arg("pos", "")   # 시험용 시작 자리(유니티 좌표 x,z)
	if pos != "":
		var q := pos.split(",")
		player.position = Vector3(float(q[0]), 1.1, -float(q[1]))
	var walk := _arg("walk", "")
	if walk != "":
		var w := walk.split(",")
		player.test_walk = Vector2(float(w[0]), float(w[1]))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 첫 클릭은 시작(마우스 잠금)만
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
	var mode := "잠김" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "풀림"
	label.text = "화면을 한 번 클릭하면 시작해요\n마우스: %s · %d fps" % [mode, Engine.get_frames_per_second()]
