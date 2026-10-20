extends RefCounted
# 저장 (GDD 8번): 도감·가진 물고기·최고 기록·소지금·낚싯대 단계를 user://save.json 하나에 저장/불러오기(웹은 브라우저 저장소).
# 칸 이름은 유니티 SaveData와 같음(collection, inventory, best, money, rod, goal, notes, decor, cabin, contestBest).
# 고닷이 모르는 칸은 읽은 그대로 보존해서 다시 쓴다(옛 저장이 안전).
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
	d["mouseSens"] = Game.mouse_scale
	d["notes"] = Game.notes_found
	d["decor"] = Game.decor_mask
	d["cabin"] = Game.cabin_level
	d["friend"] = Game.friend
	d["animals"] = Game.animal_love
	d["fruit"] = Game.fruit_day
	d["outfit"] = Game.outfit
	d["crops"] = Game.crops
	d["farm"] = {"day": Game.farm_day, "plots": Game.plots}
	d["quests"] = Game.quests
	d["goal"] = Game.goal_progress
	d["contestBest"] = Game.contest_best
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
	Game.notes_found = int(d.get("notes", 0)) & ((1 << 10) - 1)   # 쪽지 10종 칸만
	Game.decor_mask = int(d.get("decor", 0)) & ((1 << Game.home_items.size()) - 1)
	Game.cabin_level = clampi(int(d.get("cabin", 0)), 0, Game.cabins.size() - 1)
	Game.mouse_scale = clampf(float(d.get("mouseSens", 1.0)), 0.3, 3.0)   # 옛 저장에는 없음 → 1.0
	var fr = d.get("friend")
	if fr is Array:
		for i in mini(4, fr.size()):
			Game.friend[i] = clampi(int(fr[i]), 0, Game.FRIEND_LEVELS[2])
	var fd = d.get("fruit")
	if fd is Array:
		for i in mini(Game.fruit_day.size(), fd.size()):
			Game.fruit_day[i] = int(fd[i])
	var an = d.get("animals")
	if an is Array:
		for i in mini(Game.animal_love.size(), an.size()):
			Game.animal_love[i] = clampi(int(an[i]), 0, Game.FRIEND_LEVELS[2])
	Game.outfit = clampi(int(d.get("outfit", 0)), 0, Game.outfits.size() - 1)
	_copy_counts(d.get("crops"), Game.crops)
	var fm = d.get("farm")
	if fm is Dictionary:
		Game.farm_day = maxi(0, int(fm.get("day", 0)))
		var ps = fm.get("plots")
		if ps is Array:
			for i in mini(Game.plots.size(), ps.size()):
				var pl = ps[i]
				if pl is Array and pl.size() == 3 and int(pl[0]) >= -1 and int(pl[0]) < Game.crop_defs.size():
					Game.plots[i] = [int(pl[0]), maxi(0, int(pl[1])), int(pl[2])]
	var qs = d.get("quests")
	if qs is Array:
		for i in mini(4, qs.size()):
			var q = qs[i]
			if q is Array and q.size() == 2 and int(q[0]) >= 0 and int(q[0]) < Game.fish.size() and int(q[1]) >= 1:
				Game.quests[i] = [int(q[0]), int(q[1])]
	Game.goal_progress = clampi(int(d.get("goal", 0)), 0, Game.goal_target - 1)
	Game.contest_best = maxi(0, int(d.get("contestBest", 0)))
	extra = d.duplicate()
	for k in ["collection", "inventory", "best", "money", "rod", "mouseSens", "notes", "decor", "cabin", "goal", "contestBest", "friend", "animals", "fruit", "quests", "outfit", "crops", "farm"]:
		extra.erase(k)

# 물고기 종류 수가 바뀐 저장 파일도 읽을 수 있게 짧은 쪽에 맞춰 복사, 음수는 0으로
static func _copy_counts(src, dst: Array) -> void:
	if not (src is Array):
		return
	for i in mini(dst.size(), src.size()):
		dst[i] = maxi(0, int(src[i]))
