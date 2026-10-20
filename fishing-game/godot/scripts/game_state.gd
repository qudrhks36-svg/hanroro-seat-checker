extends RefCounted
# 게임 상태와 물고기 규칙 (유니티 FishTable + Collection + Inventory의 고닷 버전, GDD 7번). 숫자는 data/fish.json, data/fishing.json.
# 정적 함수만 쓴다(싱글톤 대신). 저장·불러오기는 5단계에서 붙임.

const FISH_JSON := "res://data/fish.json"
const FISHING_JSON := "res://data/fishing.json"
const ECONOMY_JSON := "res://data/economy.json"
const OUTFITS_JSON := "res://data/outfits.json"
const FARM_JSON := "res://data/farm.json"
const RARITY_INDEX := {"common": 0, "uncommon": 1, "rare": 2}
const PERIOD_NAMES := ["day", "sunset", "night"]   # TimeOfDay.Period 순서와 같음

static var fish: Array = []          # fish.json의 fish 목록 (순서 = 저장 칸 순서)
static var baits: Array = []
static var rods: Array = []
static var counts: Array = []        # 종류별 잡은 마릿수(도감)
static var best_cm: Array = []       # 종류별 최고 크기(0 = 아직 없음)
static var inventory: Array = []     # 종류별 보유(판매 대기) 마릿수
static var money := 0
static var rod_level := 0
static var modal := ""               # 지금 열려 있는 창("catalog", "settings", "dialog"), 없으면 ""  — 한 번에 하나만 열림
static var notes_found := 0         # 읽은 병 속 쪽지(비트 마스크, 저장됨)
static var decor_mask := 0           # 산 장식(비트 i = items[i]를 샀음, 저장됨)
static var cabin_level := 0          # 오두막 단계 0~2 (저장됨)
static var decor_open := false       # 꾸미기 창이 열려 있나 (바틀이 대화창 위에 열림)
static var home_items: Array = []    # economy.json home.items (이름·값·설명)
static var cabins: Array = []        # economy.json home.cabins
static var mouse_scale := 1.0        # 마우스 감도 배율 (설정 창, 기본 1.0 = 0.1도/픽셀)
static var goal_progress := 0        # 오늘의 목표: 지금까지 낚은 마릿수 (저장됨)
static var goal_target := 3
static var goal_reward := 50
static var contest_best := 0         # 낚시 대회 최고 기록(cm, 저장됨)
static var contest_active := false   # 대회 진행 중
static var contest_cm := 0           # 이번 대회에서 가장 큰 물고기 크기
static var contest_fish := -1        # 그 물고기 번호
static var friend: Array = [0, 0, 0, 0, 0]   # NPC 친밀도 점수(바틀이·끼룩이·모카·돌쇠·뽀로 순, 0~15, 저장됨)
static var animal_love: Array = [0, 0, 0, 0]   # 풀섬 동물 친밀도(뭉치·보리·치즈·솔이 순, 0~15, 저장됨)
const FRIEND_LEVELS := [3, 8, 15]         # ♥1·♥2·♥3이 되는 점수
static var quests: Array = [[], [], [], [], []]   # NPC별 부탁 [물고기 번호, 마릿수] (비어 있으면 새로 만듦, 저장됨)
static var outfits: Array = []             # 옷장 옷 목록 (data/outfits.json)
static var outfit := 0                      # 입은 옷 번호 (저장됨)
static var crop_defs: Array = []            # 작물 종류 (data/farm.json)
static var plot_pos: Array = []             # 밭 6칸 자리 (유니티 x,z)
static var clear_box: Dictionary = {}       # 밭 자리에서 치울 소품 범위
static var crops: Array = [0, 0, 0]         # 수확한 작물 가방(종류별, 저장됨)
static var plots: Array = []                # 밭 칸마다 [작물 번호(-1 비어 있음), 물 준 횟수, 마지막으로 물 준 날]
static var spots: Array = []               # 호수·연못 같은 낚시 자리 [Vector3 가운데(고닷 좌표), 반지름]. meadow.gd·snow_island.gd가 넣음. 낚싯줄이 그 안에 떨어지게 조준할 때 씀
static var story_stage := 0                 # 읽은 이야기 편지 수(0~12, 저장됨) — 글은 data/story.json
static var story_replies: Array = [-1, -1, -1]   # 챕터 1~3 끝에서 고른 답(0~2, -1 = 아직, 저장됨)
static var story_wait_day := -1            # 이 날(farm_day)부터 다음 이야기 병이 옴(저장됨)
static var seed_count := 0                  # 씨앗으로 심는 작물 수(열매 제외, farm.json 앞쪽)
static var fruit_day: Array = []           # 과일나무마다 열매를 딴 날(-1000 = 아직 안 땀, 저장됨)
static var fruit_regrow_days := 1          # 딴 뒤 다시 열리기까지 날 수(farm.json)
static var farm_day := 0                    # 날짜(하루 시계가 한 바퀴 돌 때마다 +1, 저장됨)
static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	fish = JSON.parse_string(FileAccess.get_file_as_string(FISH_JSON))["fish"]
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FISHING_JSON))
	baits = f["baits"]
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_JSON))["home"]
	home_items = e["items"]
	cabins = e["cabins"]
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_JSON))["goal"]
	goal_target = int(g["target_catches"])
	goal_reward = int(g["reward"])
	rods = f["rods"]
	outfits = JSON.parse_string(FileAccess.get_file_as_string(OUTFITS_JSON))["outfits"]
	var fm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FARM_JSON))
	crop_defs = fm["crops"]
	plot_pos = fm["plots"]
	clear_box = fm["clear_box"]
	for c in crop_defs:
		if not c.get("fruit", false):
			seed_count += 1
	fruit_regrow_days = int(fm.get("fruit_regrow_days", 1))
	fruit_day.resize(int(fm.get("fruit_trees", 6)))
	fruit_day.fill(-1000)
	crops.resize(crop_defs.size())
	crops.fill(0)
	plots.clear()
	for k in plot_pos.size():
		plots.append([-1, 0, -1])
	counts.resize(fish.size())
	best_cm.resize(fish.size())
	inventory.resize(fish.size())
	counts.fill(0)
	best_cm.fill(0)
	inventory.fill(0)

static func rarity_index(i: int) -> int:
	return RARITY_INDEX[fish[i]["rarity"]]

static func price(i: int) -> int:
	return int(fish[i]["price"])

static func zone_width() -> float:
	return float(rods[rod_level]["zone_width"])

# 시간대·미끼에 맞는 물고기 하나 뽑기. 등급 확률은 미끼마다 다르고, 같은 등급 안에서는 균등.
# 그 시간대에 보통/희귀 물고기가 없으면 그 확률은 흔함으로 합침 (GDD 7번). 섬 근처와 먼 바다는 서로 다른 물고기.
static func pick(period: int, bait: int, far_sea: bool, pond: bool = false, ice: bool = false) -> int:
	ensure_loaded()
	var wd: Dictionary = baits[bait]["tier_weights_percent"]
	var w := [float(wd["common"]), float(wd["uncommon"]), float(wd["rare"])]
	var pool := [[], [], []]
	for i in fish.size():
		var f: Dictionary = fish[i]
		if bool(f["far_sea"]) == far_sea and bool(f.get("pond", false)) == pond and bool(f.get("ice", false)) == ice and f["periods"].has(PERIOD_NAMES[period]):
			pool[rarity_index(i)].append(i)
	for t in [1, 2]:
		if pool[t].is_empty():
			w[0] += w[t]
			w[t] = 0.0
	var roll: float = randf() * (w[0] + w[1] + w[2])
	var tier: int = 0 if roll < w[0] else (1 if roll < w[0] + w[1] else 2)
	return pool[tier][randi() % pool[tier].size()]

# 크기 뽑기: 범위 가운데가 잘 나오고 양끝은 드물게
static func roll_size(i: int) -> int:
	var s: Dictionary = fish[i]["size_cm"]
	var t := (randf() + randf()) * 0.5
	return roundi(lerpf(float(s["min"]), float(s["max"]), t))

# 도감에 등록하고, 이미 잡아 본 물고기의 최고 크기를 넘었으면 true (처음 잡은 건 기록 갱신이 아니라 NEW)
static func register(i: int, cm: int) -> bool:
	var record: bool = counts[i] > 0 and cm > best_cm[i]
	counts[i] += 1
	if cm > best_cm[i]:
		best_cm[i] = cm
	inventory[i] += 1
	return record

# ---- 농장 (GDD 3번 [확정]) ----
static func crop_value() -> int:
	var v := 0
	for i in crops.size():
		v += int(crops[i]) * int(crop_defs[i]["sell_price"])
	return v

static func crop_count() -> int:
	var n := 0
	for c in crops:
		n += int(c)
	return n

# 친밀도 ♥ 단계 0~3
static func friend_level(i: int) -> int:
	var lv := 0
	for need in FRIEND_LEVELS:
		if friend[i] >= need:
			lv += 1
	return lv

# ---- 부탁 (GDD 3번 [확정]): NPC마다 "물고기 N마리 가져다 주기". 보상 = 판매 값 × 마릿수 × 2 + 친밀도 +2 ----
static func quest_reward(q: Array) -> int:
	return roundi(2.0 * price(int(q[0])) * int(q[1]))

# 이 NPC의 새 부탁을 건다. 잡아 본 물고기나 섬 근처 흔한 물고기 중에서, 다른 NPC가 건 것·직전 부탁과 겹치지 않게
static func new_quest(who: int) -> void:
	ensure_loaded()
	var taken: Array = []
	for k in quests.size():
		if k != who and not quests[k].is_empty():
			taken.append(int(quests[k][0]))
	var last: int = int(quests[who][0]) if not quests[who].is_empty() else -1
	var pool: Array = []
	var any_ok: Array = []   # 겹침을 허용하는 후보(처음엔 흔한 물고기가 3종뿐이라 NPC 4명이 다 다르기 어려움)
	for i in fish.size():
		var ok: bool = counts[i] > 0 or (rarity_index(i) == 0 and not bool(fish[i]["far_sea"]) and not bool(fish[i].get("pond", false)) and not bool(fish[i].get("ice", false)))
		if ok and i != last:
			any_ok.append(i)
			if not taken.has(i):
				pool.append(i)
	if pool.is_empty():
		pool = any_ok
	if pool.is_empty():
		pool = range(fish.size())
	var i: int = pool[randi() % pool.size()]
	var n: int = [randi_range(1, 3), randi_range(1, 2), 1][rarity_index(i)]
	quests[who] = [i, n]

static func ensure_quests() -> void:
	for who in quests.size():
		if quests[who].size() != 2:
			new_quest(who)

# 오늘의 목표 (GDD 9번 [확정]): 한 마리 낚을 때마다 부른다. 목표를 채우면 상금을 주고 true, 바로 다음 목표가 시작.
static func goal_on_catch() -> bool:
	goal_progress += 1
	if goal_progress < goal_target:
		return false
	goal_progress = 0
	money += goal_reward
	return true

# 낚시 대회 (GDD 9번 [확정]): 대회 중 낚은 물고기 중 가장 큰 것만 기억
static func contest_on_catch(i: int, cm: int) -> void:
	if contest_active and (contest_fish < 0 or cm > contest_cm):
		contest_fish = i
		contest_cm = cm

# ---- 집 꾸미기 (GDD 9번 [확정]: 장식 5종 + 오두막 3단계) ----
static func owns(i: int) -> bool:
	return (decor_mask >> i) & 1 != 0

static func cabin_max() -> bool:
	return cabin_level >= cabins.size() - 1

# 성공하면 true (이미 샀거나 돈이 모자라면 false)
static func buy_item(i: int) -> bool:
	var price := int(home_items[i]["price"])
	if owns(i) or money < price:
		return false
	money -= price
	decor_mask |= 1 << i
	return true

static func buy_cabin() -> bool:
	if cabin_max() or money < int(cabins[cabin_level + 1]["price"]):
		return false
	money -= int(cabins[cabin_level + 1]["price"])
	cabin_level += 1
	return true
