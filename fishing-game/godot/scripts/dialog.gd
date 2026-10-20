extends CanvasLayer
# NPC 대화·상점 (포팅 6단계, 유니티 ShopNPC + TalkNPC + DialogView, GDD 3·9번): 바틀이(상점: 팔기·낚싯대), 끼룩이·모카(짧은 대사), 돌쇠(노을에만, 1.2배로 삼).
# 3m 안에서 바라보고 E → 대화창. 열려 있는 동안 시간이 멈추고 마우스가 보임. 왼쪽 클릭 = 물고기 모두 팔기, 오른쪽 클릭 = 낚싯대 업그레이드(바틀이), E/Esc = 닫기.
# 집 꾸미기(F, 7단계)·낚시 대회(C, 8단계) 키는 바틀이에게서만. 대사·값은 data/dialog.json, data/fishing.json(낚싯대 값).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const TimeScript := preload("res://scripts/time_of_day.gd")
const IconScript := preload("res://scripts/icons.gd")
const WeatherScript := preload("res://scripts/weather.gd")
const DIALOG_JSON := "res://data/dialog.json"

const TALK_DISTANCE := 3.0
const LOOK_DOT := 0.8
const W := 1080.0
const NPC_PATHS := {"바틀이": "Island/Bartle", "끼룩이": "Island/Seagull", "모카": "Island/Cat", "돌쇠": "Island/Merchant"}
const VOICES := {"끼룩이": "voice_seagull", "모카": "voice_cat", "돌쇠": "voice_merchant", "뽀로": "voice_seagull"}
const INK := Color(0.22, 0.15, 0.10)

static var is_open := false
var debug := false                   # 시험용: 상태를 로그로 찍음
var decor_shop                       # 꾸미기 창 (main이 넣어 줌)
var contest                          # 낚시 대회 (main이 넣어 줌)

var cam: Camera3D
var world: Node3D
var npcs: Array = []                 # {name, color, data, pos, up, model}
var current := -1                    # 지금 대화 중인 NPC
var near := -1                       # 지금 바라보는 NPC(안내가 뜬 것)
var message := ""
var sold := false
var assume_captured := false         # 시험용: 마우스 잠금 없이도 잠긴 것으로 침
var last_near := -2
var test_near := -1                   # 시험용: 마우스 잠금 없이도 이 NPC를 바라보는 것으로 침

# 화면
var prompt: PanelContainer
var prompt_label: Label
var box: Panel
var tag: Panel
var tag_label: Label
var message_label: Label
var info_box: Panel
var info_label: Label
var chips: HBoxContainer
var hearts: Array = []               # 친밀도 ♥ 3개 (대화창 오른쪽 위)

func setup(camera: Camera3D, world_node: Node3D) -> void:
	cam = camera
	world = world_node
	process_mode = Node.PROCESS_MODE_ALWAYS   # 시간이 멈춰도(일시정지) 입력을 받음
	layer = 5
	Game.ensure_loaded()
	Game.ensure_quests()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIALOG_JSON))
	var snow := get_parent().get_node_or_null("SnowIsland")   # 눈 섬 주민(뽀로)은 장면 목록에 없고 눈 섬이 직접 세움
	for n in d["npcs"]:
		var pos: Vector3
		var model = null
		if NPC_PATHS.has(n["name"]):
			var item: Dictionary
			for it in world.items:
				if it["path"] == NPC_PATHS[n["name"]]:
					item = it
			var p: Array = item["pos"]
			pos = Vector3(p[0], p[1], -p[2])
			model = world.models_by_parent.get(NPC_PATHS[n["name"]], null)
		elif snow != null:
			pos = snow.penguin_pos
			model = snow.penguin
		else:
			continue
		var is_shop: bool = n["name"] == "바틀이"
		var c: Array = n["color"]
		npcs.append({
			"name": n["name"], "color": Color(c[0], c[1], c[2]), "data": n, "shop": is_shop,
			"pos": pos, "up": 0.6 if is_shop else 0.43,   # 바라보는 높이 (NPC 크기 0.85배)
			"model": model,
		})
	_add_shop_collider(0)
	_build()
	box.visible = false
	prompt.visible = false

# 바틀이는 부딪혀서 못 지나감(유니티: 캡슐 충돌 반지름 0.4, 높이 1.3, 중심 y 0.65 → 0.85배 크기로 반지름 0.34, 높이 1.1, 중심 y 0.55)
func _add_shop_collider(i: int) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34   # 크기 0.85배
	cap.height = 1.1
	shape.shape = cap
	body.add_child(shape)
	body.position = npcs[i]["pos"] + Vector3(0, 0.55, 0)
	world.add_child(body)

# ---- 매 프레임: 바라보는 NPC 찾기 / 돌쇠는 노을에만 보임 ----
func _is_present(i: int) -> bool:
	return npcs[i]["name"] != "돌쇠" or TimeScript.period == TimeScript.Period.SUNSET

func _process(_delta: float) -> void:
	for i in npcs.size():
		var m = npcs[i]["model"]
		if m != null and npcs[i]["name"] == "돌쇠":
			m.visible = _is_present(i)
	near = -1
	var free := Game.modal == ""   # 마우스 잠금 없이도 E가 됨
	if free:
		if test_near >= 0:
			near = test_near
		else:
			for i in npcs.size():
				if _is_present(i) and _looking_at(i):
					near = i
					break
	prompt.visible = near >= 0
	if debug and near != last_near:
		last_near = near
		print("[FG] near=", npcs[near]["name"] if near >= 0 else "없음")
	if near >= 0:
		var nm: String = npcs[near]["name"]
		var t := "E: 바틀이와 이야기하기" if npcs[near]["shop"] else "E: %s에게 말 걸기" % nm
		if prompt_label.text != t:
			prompt_label.text = t

func _looking_at(i: int) -> bool:
	var to: Vector3 = npcs[i]["pos"] + Vector3.UP * float(npcs[i]["up"]) - cam.global_position
	if to.length() > TALK_DISTANCE:
		return false
	return (-cam.global_transform.basis.z).dot(to.normalized()) > LOOK_DOT

# ---- 입력 ----
func _unhandled_input(event: InputEvent) -> void:
	if Game.decor_open:
		return   # 꾸미기 창이 열려 있으면 그 창이 입력을 처리
	if event is InputEventKey and event.pressed and not event.echo:
		if is_open:
			if event.keycode == KEY_F and npcs[current]["shop"] and decor_shop != null:
				decor_shop.open()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_C and npcs[current]["shop"] and contest != null and contest.can_start():
				close(true)
				contest.begin()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_G:
				give_gift()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_Q:
				complete_quest()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_E:
				close(true)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				close(false)   # Esc는 브라우저가 이미 마우스 잠금을 풀었으므로 다시 잠그지 않음
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and near >= 0:
			open(near)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and is_open:
		if event.button_index == MOUSE_BUTTON_LEFT:
			sell_all()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			buy_rod()

func open(i: int) -> void:
	current = i
	is_open = true
	Game.modal = "dialog"
	get_tree().paused = true   # 마우스는 잠근 채로 둔다(클릭으로 팔기·업그레이드는 잠금 중에도 됨 → 닫은 뒤 다시 클릭할 필요 없음)
	prompt.visible = false
	sold = false
	var n: Dictionary = npcs[i]["data"]
	if npcs[i]["shop"]:
		message = "저, 저기… 물고기 잡으셨네요." if _inventory_count() > 0 else pick_line(n["tips"], n["name"])
	elif n.has("lines"):
		message = pick_line(n["lines"], n["name"])
	else:   # 돌쇠
		message = n["has_fish"] if _inventory_count() > 0 else pick_line(n["no_fish"], n["name"])
	if VOICES.has(n["name"]):
		SfxScript.play(VOICES[n["name"]], 0.5)
	box.visible = true
	_refresh()

# ---- 상황별 대사 (8단계 후속, GDD 3번): 줄은 문자열(조건 없음) 또는 {t, when} ----
var last_line: Dictionary = {}   # NPC → 바로 앞에 한 말(되도록 반복 안 함)

func _context(who_name: String = "") -> Dictionary:
	var found := 0
	for c in Game.counts:
		if c > 0:
			found += 1
	return {
		"period": ["day", "sunset", "night"][TimeScript.period],
		"weather": ["clear", "cloudy", "rain"][WeatherScript.current],
		"friend": Game.friend_level(_index_of(who_name)), "dex": found, "rod": Game.rod_level, "money": Game.money, "best": Game.contest_best,
	}

func _matches(when: Dictionary, ctx: Dictionary) -> bool:
	for k in when:
		var v = when[k]
		var ok := false
		match k:
			"period": ok = ctx["period"] == v
			"weather": ok = ctx["weather"] == v
			"friend_min": ok = ctx["friend"] >= int(v)
			"dex_min": ok = ctx["dex"] >= int(v)
			"dex_full": ok = (ctx["dex"] >= Game.fish.size()) == bool(v)
			"rod_max": ok = (ctx["rod"] >= Game.rods.size() - 1) == bool(v)
			"money_min": ok = ctx["money"] >= int(v)
			"contest_done": ok = (ctx["best"] > 0) == bool(v)
		if not ok:
			return false
	return true

# 맞는 조건 대사가 있으면 70%로 그 중에서, 아니면 조건 없는 대사에서 고른다. 바로 앞에 한 말은 다른 후보가 있으면 뺀다.
func pick_line(lines: Array, who: String) -> String:
	var ctx := _context(who)
	var plain: Array = []
	var cond: Array = []
	for l in lines:
		if l is String:
			plain.append(l)
		elif _matches(l.get("when", {}), ctx):
			cond.append(l["t"])
	var last: String = last_line.get(who, "")
	var cond2: Array = cond.filter(func(x): return x != last)    # 바로 앞에 한 말은 다른 후보가 있으면 뺀다
	var plain2: Array = plain.filter(func(x): return x != last)
	var pool: Array
	if not cond2.is_empty() and (plain2.is_empty() or randf() < 0.7):
		pool = cond2
	elif not plain2.is_empty():
		pool = plain2
	else:
		pool = cond if not cond.is_empty() else plain
	var text: String = pool[randi() % pool.size()]
	last_line[who] = text
	return text.replace("{best}", str(ctx["best"]))

# ---- 선물과 친밀도 (GDD 3번 [확정]): G = 물고기 1마리 선물. 좋아하는 물고기 +3, 아니면 가장 싼 물고기 +1. ♥ 3·8·15점에서 오르며 작은 선물 ----
func _index_of(who_name: String) -> int:
	for i in npcs.size():
		if npcs[i]["name"] == who_name:
			return i
	return 0

func _favorite_index(who: int) -> int:
	var fav: String = npcs[who]["data"].get("favorite", "")
	for i in Game.fish.size():
		if Game.fish[i]["name"] == fav:
			return i
	return -1

func _gift_fish(who: int) -> int:
	var fav := _favorite_index(who)
	if fav >= 0 and Game.inventory[fav] > 0:
		return fav
	var best := -1
	for i in Game.inventory.size():
		if Game.inventory[i] > 0 and (best < 0 or Game.price(i) < Game.price(best)):
			best = i
	return best

# 선물로 줄 열매(가장 싼 것). 없으면 -1
func _gift_fruit() -> int:
	var best := -1
	for i in Game.crops.size():
		if Game.crop_defs[i].get("fruit", false) and Game.crops[i] > 0 and (best < 0 or int(Game.crop_defs[i]["sell_price"]) < int(Game.crop_defs[best]["sell_price"])):
			best = i
	return best

func give_gift() -> void:
	if current < 0:
		return
	var who := current
	var n: Dictionary = npcs[who]["data"]
	var g: Dictionary = n["gift"]
	var lvl := Game.friend_level(who)
	if lvl >= 3:
		message = g["max"]   # 이미 가장 친함: 물고기는 안 받고 마음만
		sold = true
		_refresh()
		return
	var idx := _gift_fish(who)
	var fruit := -1
	if idx < 0 or idx != _favorite_index(who):   # 가장 좋아하는 물고기가 아니면 열매를 먼저 줌
		fruit = _gift_fruit()
	if idx < 0 and fruit < 0:
		return
	var love := fruit < 0 and idx == _favorite_index(who)
	var gname := ""
	if fruit >= 0:
		Game.crops[fruit] -= 1
		gname = Game.crop_defs[fruit]["name"]
	else:
		Game.inventory[idx] -= 1
		gname = Game.fish[idx]["name"]
	var up := _add_friend(who, 3 if love else 1)
	var lines: Array = g["love"] if love else g["like"]
	message = String(lines[randi() % lines.size()]).replace("{fish}", gname)
	var now := Game.friend_level(who)
	if up != "":
		message = up
		SfxScript.play("upgrade")
	else:
		SfxScript.play("sell")
	SaveScript.save_game()
	sold = true
	_refresh()
	if debug:
		print("[FG] gift ", n["name"], " item=", gname, " love=", love, " points=", Game.friend[who], " level=", now)

# 친밀도 점수를 더한다. ♥ 단계가 오르면 그 단계 대사 + 작은 선물 문장을, 아니면 ""를 돌려줌
func _add_friend(who: int, points: int) -> String:
	var lvl := Game.friend_level(who)
	Game.friend[who] = mini(Game.friend[who] + points, Game.FRIEND_LEVELS[2])
	var now := Game.friend_level(who)
	var text := ""
	for l in range(lvl + 1, now + 1):
		text = String(npcs[who]["data"]["gift"]["levelup"][l - 1]) + _level_reward(who, l)
	return text

# ---- 부탁 (GDD 3번 [확정]) ----
func _quest_have(who: int) -> int:
	return int(Game.inventory[int(Game.quests[who][0])])

func _quest_ready(who: int) -> bool:
	return _quest_have(who) >= int(Game.quests[who][1])

func _quest_line(who: int) -> String:
	var q: Array = Game.quests[who]
	return "부탁: %s %d마리 · 보상 %d원, 친밀도 +2 (가진 것 %d/%d)" % [Game.fish[int(q[0])]["name"], int(q[1]), Game.quest_reward(q), mini(_quest_have(who), int(q[1])), int(q[1])]

func complete_quest() -> void:
	if current < 0 or not _quest_ready(current):
		return
	var who := current
	var q: Array = Game.quests[who]
	Game.inventory[int(q[0])] -= int(q[1])
	var reward := Game.quest_reward(q)
	Game.money += reward
	var up := _add_friend(who, 2)
	var done: Array = npcs[who]["data"]["quest_done"]
	var fish_name: String = Game.fish[int(q[0])]["name"]
	if up != "":
		message = up + "\n부탁 보상 +%d원" % reward
		SfxScript.play("upgrade")
	else:
		message = String(done[randi() % done.size()]).replace("{fish}", fish_name) + " (+%d원)" % reward
		SfxScript.play("goal_done")
	Game.new_quest(who)
	SaveScript.save_game()
	sold = true
	_refresh()
	if debug:
		print("[FG] quest done ", npcs[who]["name"], " fish=", fish_name, " reward=", reward, " points=", Game.friend[who], " next=", Game.quests[who], " money=", Game.money)

# ♥ 단계가 오를 때 받는 작은 선물: ♥1 돈 30원, ♥2 도감 힌트(다 잡았으면 50원), ♥3 돈 100원
func _level_reward(who: int, level: int) -> String:
	if level == 1:
		Game.money += 30
		return " (+30원)"
	if level == 3:
		Game.money += 100
		return " (+100원)"
	var left: Array = []
	for i in Game.fish.size():
		if Game.counts[i] == 0:
			left.append(i)
	if left.is_empty():
		Game.money += 50
		return " (+50원)"
	var f: Dictionary = Game.fish[left[randi() % left.size()]]
	var names := {"day": "낮", "sunset": "노을", "night": "밤"}
	var times: Array = []
	for p in f["periods"]:
		times.append(names[p])
	var when := "하루 종일" if times.size() == 3 else "·".join(times)
	var where := "먼 바다에서" if bool(f["far_sea"]) else ("풀섬 연못에서" if bool(f.get("pond", false)) else ("눈 섬 얼음 호수에서" if bool(f.get("ice", false)) else "섬 근처에서"))
	var nm: String = f["name"]
	var eun := "은" if (nm.unicode_at(nm.length() - 1) - 0xAC00) % 28 != 0 else "는"
	return "\n" + String(npcs[who]["data"]["hint_prefix"]) + "%s%s %s %s 나온대." % [nm, eun, when, where]

func close(relock: bool) -> void:
	is_open = false
	Game.modal = ""
	current = -1
	box.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if relock else Input.MOUSE_MODE_VISIBLE

# ---- 팔기·업그레이드 ----
func _inventory_count() -> int:
	var n := 0
	for c in Game.inventory:
		n += int(c)
	return n

func _inventory_value() -> int:
	var v := 0
	for i in Game.inventory.size():
		v += int(Game.inventory[i]) * Game.price(i)
	return v

func _buy_multiplier() -> float:
	return float(npcs[current]["data"].get("buy_multiplier", 1.0))

func _can_buy_fish() -> bool:
	return current >= 0 and (npcs[current]["shop"] or npcs[current]["data"].has("buy_multiplier"))

# 보유 물고기를 모두 판다 (바틀이 ×1.0, 돌쇠 ×1.2 반올림)
func sell_all() -> void:
	if current < 0 or not _can_buy_fish() or _inventory_count() + Game.crop_count() == 0:
		return
	var earned := roundi((_inventory_value() + Game.crop_value()) * _buy_multiplier())   # 물고기와 수확한 작물을 함께 판다
	Game.inventory.fill(0)
	Game.crops.fill(0)
	Game.money += earned
	SaveScript.save_game()
	SfxScript.play("sell")
	var n: Dictionary = npcs[current]["data"]
	message = String(n["sold"]).replace("{n}", str(earned))
	sold = true
	_refresh()

func buy_rod() -> void:
	if current < 0 or not npcs[current]["shop"]:
		return
	var n: Dictionary = npcs[current]["data"]
	if Game.rod_level >= Game.rods.size() - 1:
		message = n["rod_max"]
	else:
		var next: Dictionary = Game.rods[Game.rod_level + 1]
		var cost := int(next["cost"])
		if Game.money >= cost:
			Game.money -= cost
			Game.rod_level += 1
			SaveScript.save_game()
			SfxScript.play("upgrade")
			message = String(n["rod_bought"]).replace("{rod}", next["name"])
		else:
			message = String(n["rod_short"]).replace("{cost}", str(cost))
	sold = true
	_refresh()

# ---- 화면 갱신 ----
func _refresh() -> void:
	var n: Dictionary = npcs[current]["data"]
	var shop: bool = npcs[current]["shop"]
	var has_info: bool = shop or n.has("buy_multiplier")
	message_label.text = message
	info_box.visible = true
	tag_label.text = n["name"]
	tag.size = Vector2(maxf(170.0, 40.0 + String(n["name"]).length() * 34.0), 54)
	tag.position = Vector2(28, -27)
	tag_label.size = tag.size
	ThemeUI.set_box_color(tag, npcs[current]["color"])
	ThemeUI.set_box_border(tag, (npcs[current]["color"] as Color) * 0.5, 2)

	var info := ""
	var hints: Array = []
	if has_info:
		if _inventory_count() + Game.crop_count() > 0:
			for i in Game.inventory.size():
				if Game.inventory[i] > 0:
					info += "%s x%d   " % [Game.fish[i]["name"], Game.inventory[i]]
			for i in Game.crops.size():
				if Game.crops[i] > 0:
					info += "%s x%d   " % [Game.crop_defs[i]["name"], Game.crops[i]]
			var total := roundi((_inventory_value() + Game.crop_value()) * (_buy_multiplier() if not shop else 1.0))
			info += "\n합계 %d원" % total
			hints.append(["왼쪽 클릭", "팔기" if shop else "모두 팔기"])
		elif not sold:
			info = "(팔 물고기가 없어요)"
		if shop:
			info += "\n낚싯대: %s" % Game.rods[Game.rod_level]["name"]
			if Game.rod_level < Game.rods.size() - 1:
				var nx: Dictionary = Game.rods[Game.rod_level + 1]
				info += "   —   다음: %s %d원" % [nx["name"], int(nx["cost"])]
				hints.append(["오른쪽 클릭", "낚싯대 %d원" % int(nx["cost"])])
		if shop:
			if contest != null and contest.can_start():
				hints.append(["C", "대회 3분"])
			hints.append(["F", "꾸미기"])
	if _quest_ready(current):
		hints.append(["Q", "부탁"])
	if (_inventory_count() > 0 or _gift_fruit() >= 0) and Game.friend_level(current) < 3:
		hints.append(["G", "선물"])
	hints.append(["E / Esc", "닫기"])
	var lv := Game.friend_level(current)
	for k in 3:
		hearts[k].set_kind("heart" if k < lv else "heart_off")
	info = info.strip_edges(true, false) + ("\n" if info.strip_edges() != "" else "") + _quest_line(current)   # 맨 아래 줄은 항상 이 NPC의 부탁
	var lines := info.count("\n") + 1
	var info_h := 28 + 30 * lines
	info_box.size = Vector2(W - 60, info_h)
	info_label.size = Vector2(W - 92, info_h - 18)
	box.custom_minimum_size = Vector2(W, 246 + info_h)
	box.size = box.custom_minimum_size
	_place_box()
	info_label.text = info
	_set_chips(hints)
	if debug:
		print("[FG] dialog npc=", n["name"], " msg=", message, " | info=", info.replace("\n", " / "), " | chips=", hints.map(func(h): return h[0] + ":" + h[1]), " | money=", Game.money, " inv=", _inventory_count(), " rod=", Game.rod_level)

func _place_box() -> void:
	var vp := get_viewport().get_visible_rect().size
	box.position = Vector2((vp.x - W) * 0.5, vp.y - box.size.y - 150.0)
	# 화면이 대화창보다 좁으면 줄여서 안 잘리게
	box.pivot_offset = Vector2(W * 0.5, box.size.y)
	box.scale = Vector2.ONE * minf(1.0, vp.x / (W + 40.0))
	box.position.y = vp.y - box.size.y - 150.0

func _set_chips(hints: Array) -> void:
	for c in chips.get_children():
		c.queue_free()
	for h in hints:
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.38, 0.26, 0.17, 0.92)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 6
		sb.content_margin_right = 14
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var badge := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.99, 0.95, 0.86)
		bsb.set_corner_radius_all(12)
		bsb.content_margin_left = 11
		bsb.content_margin_right = 11
		bsb.content_margin_top = 2
		bsb.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bsb)
		badge.add_child(ThemeUI.text(h[0], 20, INK))
		row.add_child(badge)
		row.add_child(ThemeUI.text(h[1], 22, Color(0.99, 0.95, 0.86), HORIZONTAL_ALIGNMENT_LEFT))
		chip.add_child(row)
		chips.add_child(chip)

# ---- 화면 만들기 ----
func _build() -> void:
	# 위쪽 안내 알약 "E: …" (화면 가운데 아래쪽)
	prompt = ThemeUI.panel()
	prompt_label = ThemeUI.label("", 28)
	prompt.add_child(prompt_label)
	add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	prompt.position.y += 80   # 화면 가운데에서 아래로 80
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH   # 글자가 길어져도 가운데 기준으로 커짐

	# 대화창: 크림 판 + 색깔 이름표 + 대사 + (상점·돌쇠) 정보 칸 + 키 안내 알약 줄
	box = ThemeUI.box(Color(0.99, 0.95, 0.86, 0.97), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	tag = ThemeUI.box(Color(0.95, 0.62, 0.25), 18, Color(0.5, 0.3, 0.1), 2)
	box.add_child(tag)
	tag_label = ThemeUI.text("", 30, Color.WHITE)
	tag_label.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.06, 0.8))
	tag_label.add_theme_constant_override("outline_size", 4)
	tag.add_child(tag_label)
	for k in 3:   # 친밀도 ♥ (대화창 오른쪽 위)
		var h = IconScript.new()
		h.position = Vector2(W - 30 - (3 - k) * 40, 8)
		box.add_child(h)
		hearts.append(h)
	message_label = ThemeUI.text("", 28, INK, HORIZONTAL_ALIGNMENT_LEFT)
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.position = Vector2(36, 40)
	message_label.size = Vector2(W - 72, 112)
	box.add_child(message_label)
	info_box = ThemeUI.box(Color(0.96, 0.87, 0.70), 14)
	info_box.position = Vector2(30, 156)
	info_box.size = Vector2(W - 60, 118)
	box.add_child(info_box)
	info_label = ThemeUI.text("", 24, INK, HORIZONTAL_ALIGNMENT_LEFT)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.position = Vector2(16, 10)
	info_label.size = Vector2(W - 92, 100)
	info_box.add_child(info_label)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chips)
	chips.anchor_left = 0.0   # 아래쪽 왼쪽 모서리 기준, 글자 길이에 맞춰 오른쪽으로 늘어남
	chips.anchor_right = 0.0
	chips.anchor_top = 1.0
	chips.anchor_bottom = 1.0
	chips.offset_left = 30
	chips.offset_right = 30
	chips.offset_top = -60
	chips.offset_bottom = -20
