extends RefCounted
# 게임 상태와 물고기 규칙 (유니티 FishTable + Collection + Inventory의 고닷 버전, GDD 7번). 숫자는 data/fish.json, data/fishing.json.
# 정적 함수만 쓴다(싱글톤 대신). 저장·불러오기는 5단계에서 붙임.

const FISH_JSON := "res://data/fish.json"
const FISHING_JSON := "res://data/fishing.json"
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
static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	fish = JSON.parse_string(FileAccess.get_file_as_string(FISH_JSON))["fish"]
	var f: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FISHING_JSON))
	baits = f["baits"]
	rods = f["rods"]
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
static func pick(period: int, bait: int, far_sea: bool) -> int:
	ensure_loaded()
	var wd: Dictionary = baits[bait]["tier_weights_percent"]
	var w := [float(wd["common"]), float(wd["uncommon"]), float(wd["rare"])]
	var pool := [[], [], []]
	for i in fish.size():
		var f: Dictionary = fish[i]
		if bool(f["far_sea"]) == far_sea and f["periods"].has(PERIOD_NAMES[period]):
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
