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
const SettingsScript := preload("res://scripts/settings_ui.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const FarSeaScript := preload("res://scripts/far_sea.gd")
const SeaEventsScript := preload("res://scripts/sea_events.gd")
const HomeDecorScript := preload("res://scripts/home_decor.gd")
const DecorShopScript := preload("res://scripts/decor_shop.gd")
const ContestScript := preload("res://scripts/contest.gd")
const PhotoScript := preload("res://scripts/photo_mode.gd")
const SoundScript := preload("res://scripts/sound.gd")
const SplashScript := preload("res://scripts/splash_fx.gd")
const LifeScript := preload("res://scripts/life.gd")
const Game := preload("res://scripts/game_state.gd")
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
	var splash := Node3D.new()   # 물보라·물결 (8단계)
	splash.set_script(SplashScript)
	splash.name = "SplashFx"
	add_child(splash)
	fishing.fx = splash
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
	var contest := CanvasLayer.new()   # 낚시 대회: 바틀이에게서 C (8단계)
	contest.set_script(ContestScript)
	contest.name = "Contest"
	add_child(contest)
	contest.setup(fishing)
	var far_sea := Node3D.new()   # 먼 바다 낚시터: 배 2척, E로 이동 (7-1)
	far_sea.set_script(FarSeaScript)
	far_sea.name = "FarSea"
	add_child(far_sea)
	far_sea.setup(player.cam, player, fishing)
	if _arg("travel", "") != "":   # 시험용: 먼 바다로 이동(--travel=1) / 이동 후 부두로 돌아오기(--travel=2)
		far_sea.debug = true
		far_sea.travel(true)
		if _arg("travel", "") == "2":
			await get_tree().create_timer(1.6, true, false, true).timeout
			far_sea.debug = true
			far_sea.travel(false)
	var sea_events := Node3D.new()   # 병 쪽지와 갈매기 (7-2)
	sea_events.set_script(SeaEventsScript)
	sea_events.name = "SeaEvents"
	add_child(sea_events)
	sea_events.setup(player.cam, player)
	if _arg("bottle", "") != "":   # 시험용: 병을 N번 놓고 줍는다(쪽지 첫 읽기/반복, 돈)
		sea_events.debug = true
		for i in int(_arg("bottle", "1")):
			if sea_events.spawn_bottle():
				sea_events.pick_up()
	if _arg("bottlenear", "") != "":   # 시험용: 병 옆 1.5m에서 병을 바라보게 서서 줍기 안내가 뜨는지
		sea_events.debug = true
		sea_events.assume_captured = true
		if sea_events.spawn_bottle():
			var b: Vector3 = sea_events.bottle.global_position
			player.global_position = b + Vector3(1.5, 1.0, 0.0)
			player.look(rad_to_deg(atan2(1.5, 0.0)), 0.0)
			await get_tree().process_frame
			await get_tree().process_frame
			print("[FG] bottle prompt=", sea_events.prompt.visible, " reachable=", sea_events._reachable())
	if _arg("gull", "") != "":   # 시험용: 갈매기가 한쪽 끝에서 반대쪽 끝까지 나는 것(날개 퍼덕임)
		sea_events.debug = true
		sea_events.start_gull(Vector3(90, 15, 0), Vector3(-90, 15, 10))
		var max_flap := 0.0
		for i in 80:
			sea_events._update_gull(0.5)
			if sea_events.gull != null and sea_events.gull_wing_l != null:
				max_flap = maxf(max_flap, absf(sea_events.gull_wing_l.rotation_degrees.x))
		print("[FG] gull finished=", sea_events.gull == null, " max_flap=", max_flap)
	if _arg("friend", "") != "":   # 시험용: 친밀도 점수 미리 정하기 (--friend=NPC번호:점수,…)
		for kv in _arg("friend", "").split(",", false):
			var q := kv.split(":")
			Game.friend[int(q[0])] = int(q[1])
	if _arg("setquest", "") != "":   # 시험용: 부탁을 정함 (--setquest=NPC번호:물고기번호:마릿수,…)
		for kv in _arg("setquest", "").split(",", false):
			var sq := kv.split(":")
			Game.quests[int(sq[0])] = [int(sq[1]), int(sq[2])]
	var dialog := CanvasLayer.new()   # NPC 대화·상점 (6단계)
	dialog.set_script(DialogScript)
	dialog.name = "Dialog"
	add_child(dialog)
	dialog.setup(player.cam, world)
	dialog.contest = contest
	if _arg("nearcheck", "") != "":   # 시험용: 마우스 잠금 없이 "바라보면 E 안내" 판정만 확인
		dialog.debug = true
		dialog.assume_captured = true
		far_sea.debug = true
		far_sea.assume_captured = true
	if _arg("npc", "") != "":   # 시험용: 이 번호의 NPC와 대화(0 바틀이, 1 끼룩이, 2 모카, 3 돌쇠). --give=N 물고기 N마리씩 주기, --money=N, --act=sell,rod,...
		dialog.debug = true
		if _arg("give", "") != "":
			for i in mini(3, Game.inventory.size()):
				Game.inventory[i] += int(_arg("give", "0"))
		if _arg("money", "") != "":
			Game.money = int(_arg("money", "0"))
		if _arg("givefish", "") != "":   # 시험용: 이 번호 물고기를 N마리 (--givefish=번호:N)
			var gq := _arg("givefish", "0:1").split(":")
			Game.inventory[int(gq[0])] += int(gq[1])
		dialog.open(int(_arg("npc", "0")))
		for a in _arg("act", "").split(",", false):
			if a == "sell":
				dialog.sell_all()
			elif a == "rod":
				dialog.buy_rod()
			elif a == "gift":
				dialog.give_gift()
			elif a == "quest":
				dialog.complete_quest()
		print("[FG] after: money=", Game.money, " rod=", Game.rod_level, " zone=", Game.zone_width())
		if _arg("keepopen", "") == "":   # 시험용 --keepopen=1: 대화창을 열어 둔 채(웹에서 화면 사진용)
			dialog.close(false)
	var home := Node3D.new()   # 집 꾸미기 모습: 장식 5종·오두막 단계 (7-3)
	home.set_script(HomeDecorScript)
	home.name = "HomeDecor"
	add_child(home)
	home.setup(world)
	var decor_shop := CanvasLayer.new()   # 꾸미기 창(바틀이 대화창에서 F). 대화창보다 뒤에 만들어야 Esc·숫자 키를 먼저 받음
	decor_shop.set_script(DecorShopScript)
	decor_shop.name = "DecorShop"
	add_child(decor_shop)
	dialog.decor_shop = decor_shop
	if _arg("decorbuy", "") != "":   # 시험용: 이 번호들을 차례로 산다(0~4 장식, 5 오두막). --money=N
		decor_shop.debug = true
		if _arg("money", "") != "":
			Game.money = int(_arg("money", "0"))
		for s in _arg("decorbuy", "").split(",", false):
			decor_shop.buy(int(s))
		await get_tree().process_frame
		await get_tree().process_frame
		print("[FG] home ", home.debug_state())
	if _arg("fcheck", "") != "":   # 시험용: 바틀이 대화창 → F → 꾸미기 창 → 숫자 키 → F로 닫기 → E로 대화창 닫기
		Game.money = 1000
		dialog.open(0)
		var k := InputEventKey.new()
		k.pressed = true
		k.keycode = KEY_F
		dialog._unhandled_input(k)
		print("[FG] fcheck F in dialog -> decor_open=", Game.decor_open, " dialog_open=", dialog.is_open)
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = KEY_E
		dialog._unhandled_input(e)   # 꾸미기 창이 열려 있으면 대화창은 E를 무시해야 함
		print("[FG] fcheck E while decor open -> dialog_open=", dialog.is_open)
		var d1 := InputEventKey.new()
		d1.pressed = true
		d1.keycode = KEY_1
		decor_shop._unhandled_input(d1)
		print("[FG] fcheck key 1 -> owns pot=", Game.owns(0), " money=", Game.money)
		decor_shop._unhandled_input(k)   # F로 닫기
		print("[FG] fcheck F in shop -> decor_open=", Game.decor_open, " dialog_open=", dialog.is_open)
		dialog._unhandled_input(e)
		print("[FG] fcheck E in dialog -> dialog_open=", dialog.is_open, " modal=[", Game.modal, "]")
	var settings := CanvasLayer.new()
	settings.set_script(SettingsScript)
	settings.name = "Settings"
	add_child(settings)
	print("[FG] mouse_scale=", Game.mouse_scale)
	var life := Node3D.new()   # 살아 있는 섬: 바람 흔들림·반딧불·구름·물고기 그림자 (8단계)
	life.set_script(LifeScript)
	life.name = "Life"
	add_child(life)
	life.setup(world)
	var photo := CanvasLayer.new()   # 사진 찍기 P (8단계). 다른 화면을 꺼야 하므로 맨 마지막에 만든다
	photo.set_script(PhotoScript)
	photo.name = "PhotoMode"
	add_child(photo)
	var sound := CanvasLayer.new()   # 배경음악과 음소거 M (8단계)
	sound.set_script(SoundScript)
	sound.name = "Sound"
	add_child(sound)
	_run_step8_tests(contest, photo, sound, dialog)
	if _arg("lifecheck", "") != "":   # 시험용: 흔들림 대상 수와 반딧불·구름·그림자 (밤이면 --clock=450 --freeze=1)
		print("[FG] life sways=", life.sways.size(), " boats=", life.boats.size(), " clouds=", life.clouds.size(), " puffs=", life.clouds[0].get_child_count(), " fish=", life.fish.size())
		await get_tree().create_timer(2.0).timeout
		print("[FG] life night=", TimeScript.night, " fireflies emitting=", life.fireflies.emitting, " alpha=", life.fireflies.color.a, " cloud0.x=", life.clouds[0].position.x, " fish0=", life.fish[0]["node"].position)
	if _arg("splashcheck", "") != "":   # 시험용: 물보라와 물결 고리가 만들어졌다가 사라지는지
		splash.splash(Vector3(20, -0.1, 0), true)
		splash.ring(Vector3(20, -0.1, 3), 1.1)
		print("[FG] splash rings=", splash.rings.size(), " children=", splash.get_child_count())
		await get_tree().create_timer(3.0).timeout
		print("[FG] splash after 3s rings=", splash.rings.size(), " children=", splash.get_child_count())
	if _arg("sens", "") != "":   # 시험용: 설정 창을 열어 감도를 바꾸고 닫는다(저장됨)
		settings.set_open(true, false)
		settings.set_sensitivity(float(_arg("sens", "1.0")))
		settings.set_open(false, false)
		print("[FG] sens set -> ", Game.mouse_scale)
	if _arg("lookcheck", "") != "":   # 시험용: 마우스를 오른쪽으로 100픽셀 움직였을 때 몇 도 도는지 (감도 1.0, 2.0 비교)
		for sc in [1.0, 2.0, 0.5]:
			Game.mouse_scale = sc
			player.rotation_degrees.y = 0.0
			player.turn(Vector2(100, 0))
			print("[FG] lookcheck scale=", sc, " yaw=", player.rotation_degrees.y)
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
	if frames == 8 and OS.has_feature("web"):   # 몇 프레임 그린 뒤 웹 페이지의 "섬으로 가는 중" 화면을 걷음 (web/shell.html)
		JavaScriptBridge.eval("window.fgGameReady && window.fgGameReady()")
	if _arg("log", "") != "" and frames % 10 == 0:
		print("[FG] frame ", frames, " player=", player.position, " floor=", player.is_on_floor(), " hit=", player.dbg)

# 8단계 시험용 명령줄: --goalcheck=1 --contest=cm,cm,... (0 = 한 마리도 못 잡음; --contestbest=N 이전 기록) --photo=1 --photosave=폴더 --mute=1 --ckey=1
func _run_step8_tests(contest: Node, photo: Node, sound: Node, dialog: Node) -> void:
	if _arg("dex", "") != "":   # 시험용: 도감을 앞에서 N종 채운 것으로
		for i in mini(int(_arg("dex", "0")), Game.counts.size()):
			Game.counts[i] = 1
	if _arg("rodlevel", "") != "":
		Game.rod_level = int(_arg("rodlevel", "0"))
	if _arg("best", "") != "":
		Game.contest_best = int(_arg("best", "0"))
	if _arg("talktest", "") != "":   # 시험용: 이 번호 NPC(0~3)의 대사를 N번 뽑아 어떤 말이 몇 번 나오는지 (--clock --weather --dex --rodlevel --best --money 로 상황을 정함)
		if _arg("money", "") != "":
			Game.money = int(_arg("money", "0"))
		var who := int(_arg("talktest", "0"))
		var n: Dictionary = dialog.npcs[who]["data"]
		var key: String = "tips" if dialog.npcs[who]["shop"] else ("lines" if n.has("lines") else "no_fish")
		var counts: Dictionary = {}
		for i in 300:
			var line: String = dialog.pick_line(n[key], n["name"])
			counts[line] = counts.get(line, 0) + 1
		print("[FG] talktest ", n["name"], " ctx=", dialog._context(), " kinds=", counts.size())
		for line in counts:
			print("[FG]   ", counts[line], " | ", line)
	if _arg("goalcheck", "") != "":
		for i in 7:
			var before := Game.money
			var done := Game.goal_on_catch()
			print("[FG] goal #", i + 1, " done=", done, " progress=", Game.goal_progress, " money+=", Game.money - before)
	if _arg("contest", "") != "":
		Game.contest_best = int(_arg("contestbest", "0"))
		var before := Game.money
		contest.begin()
		print("[FG] contest started active=", Game.contest_active, " can_start_again=", contest.can_start())
		for s in _arg("contest", "").split(",", false):
			if int(s) > 0:
				Game.contest_on_catch(0, int(s))
		contest.time_left = 0.0
		contest.finish()
		print("[FG] contest after: money+=", Game.money - before, " best=", Game.contest_best, " active=", Game.contest_active)
	if _arg("ckey", "") != "":   # 바틀이 대화 중 C → 대화창 닫히고 대회 시작, 낚싯대가 거둬져 있지 않으면 안 됨
		dialog.debug = true
		dialog.open(0)
		var ck := InputEventKey.new()
		ck.pressed = true
		ck.keycode = KEY_C
		dialog._unhandled_input(ck)
		print("[FG] ckey -> contest_active=", Game.contest_active, " dialog_open=", dialog.is_open, " time_left=", contest.time_left)
	if _arg("photosave", "") != "":   # 합성 이미지를 PC 저장 경로에 저장
		PhotoScript.save_dir_override = _arg("photosave", "")
		var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.2, 0.6, 0.9))
		print("[FG] photosave ok=", PhotoScript._save(img))
	if _arg("photo", "") != "":
		photo.assume_captured = true
		await photo.shoot()
		print("[FG] photo layers restored=", $Hud.visible, " busy=", photo.busy)
	if _arg("mute", "") != "":
		var bus := AudioServer.get_bus_index("Master")
		print("[FG] mute start=", AudioServer.is_bus_mute(bus))
		sound.toggle()
		print("[FG] mute after M=", AudioServer.is_bus_mute(bus), " label=", sound.muted)
		sound.toggle()
		print("[FG] mute after M again=", AudioServer.is_bus_mute(bus))
