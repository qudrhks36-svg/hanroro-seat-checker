extends RefCounted
# 저장 (GDD 8번): 도감·가진 물고기·최고 기록·소지금·낚싯대 단계를 user://save.json 하나에 저장/불러오기(웹은 브라우저 저장소).
# 칸 이름은 유니티 SaveData와 같음(collection, inventory, best, money, rod, goal, notes, decor, cabin, contestBest).
# 아직 고닷에 없는 칸(goal·notes·decor·cabin·contestBest)은 읽은 그대로 보존해서 다시 쓴다(나중 단계가 붙어도 옛 저장이 안전).
# 시간대·날씨·미끼·위치는 저장하지 않음. 저장은 낚을 때·사고팔 때 부른다.

const Game := preload("res://scripts/game_state.gd")
const PATH := "user://save.json"

static var extra: Dictionary = {}

static func save_game() -> void:
	Game.ensure_loaded()
	var d := extra.duplicate()
	d["collection"] = Game.counts
	d["inventory"] = Game.inventory
	d["best"] = Game.best_cm
	d["money"] = Game.money
	d["rod"] = Game.rod_level
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("저장하지 못했어요: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(d))

static func load_game() -> void:
	Game.ensure_loaded()
	if not FileAccess.file_exists(PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_warning("save.json을 읽지 못해 새로 시작해요")
		return
	var d: Dictionary = parsed
	_copy_counts(d.get("collection"), Game.counts)
	_copy_counts(d.get("inventory"), Game.inventory)
	_copy_counts(d.get("best"), Game.best_cm)
	Game.money = maxi(0, int(d.get("money", 0)))
	Game.rod_level = clampi(int(d.get("rod", 0)), 0, Game.rods.size() - 1)
	extra = d.duplicate()
	for k in ["collection", "inventory", "best", "money", "rod"]:
		extra.erase(k)

# 물고기 종류 수가 바뀐 저장 파일도 읽을 수 있게 짧은 쪽에 맞춰 복사, 음수는 0으로
static func _copy_counts(src, dst: Array) -> void:
	if not (src is Array):
		return
	for i in mini(dst.size(), src.size()):
		dst[i] = maxi(0, int(src[i]))
