extends CanvasLayer
# 병 속 이야기 편지 (GDD 8번 [확정] 병 쪽지 이야기): 일반 병 쪽지를 3장 읽으면 리본 달린 이야기 병이 섞여 떠밀려 오고, 주우면 편지가 한 통씩 이어진다(12통 = 4챕터 × 3통).
# 챕터 1~3의 세 번째 편지를 읽으면 답장 문장 3개 중 1개를 골라 띄우고(숫자 1~3), 하루(Game.farm_day) 뒤에 다음 챕터 병이 온다. 고른 답에 따라 다음 챕터 첫 편지 앞에 한 줄이 붙는다.
# 글은 data/story.json(스포일러라 플레이 전엔 열지 않기). 진행(편지 수·답·기다리는 날)은 Game.story_*(저장됨). 병 놓기·줍기는 sea_events.gd가 이 노드에 물어봄.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const DATA_JSON := "res://data/story.json"
const LETTERS := 12
const CHAPTER := 3
const INK := Color(0.22, 0.15, 0.10)
const BROWN := Color(0.45, 0.30, 0.18)
const CLOSE_GUARD := 0.7       # 열린 직후 이 시간(실제 초) 동안은 닫히지 않음(줍는 E가 바로 닫지 않게)
const TOAST_HOLD := 4.0

var data: Dictionary
var mode := ""                 # "" / "letter" / "reply"
var opened_at := -999.0
var debug := false
var root: Control
var letter_panel: Panel
var letter_title: Label
var letter_body: Label
var letter_reward: Label
var reply_panel: Panel
var reply_title: Label
var reply_rows: Array = []     # {box, text}
var toast: PanelContainer
var toast_label: Label
var toast_t0 := -999.0

func setup() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.ensure_loaded()
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_JSON))
	_build()
	if reply_due():   # 답장을 고르기 전에 게임을 껐으면 다시 열어 준다
		await get_tree().create_timer(1.5).timeout
		open_reply()

static func notes_read() -> int:
	var n := 0
	for i in 10:
		if (Game.notes_found >> i) & 1:
			n += 1
	return n

# ---- 진행 판정 ----
func reply_due() -> bool:
	var s := Game.story_stage
	return s % CHAPTER == 0 and s > 0 and s < LETTERS and int(Game.story_replies[s / CHAPTER - 1]) < 0

# 지금 이야기 병이 떠밀려 올 차례인가
func wants_bottle() -> bool:
	return Game.story_stage < LETTERS and notes_read() >= int(data["unlock_notes"]) and not reply_due() and Game.farm_day >= Game.story_wait_day

func letter_text(idx: int) -> String:
	var t: String = data["letters"][idx]
	var key := str(idx)
	if data["leads"].has(key):   # 챕터 첫 편지: 지난 답에 맞는 첫 줄
		var choice := int(Game.story_replies[idx / CHAPTER - 1])
		if choice >= 0:
			t = String(data["leads"][key][choice]) + "\n\n" + t
	return t

# ---- 편지 창 ----
func open_letter() -> void:
	var idx := Game.story_stage
	if idx >= LETTERS or mode != "":
		return
	Game.story_stage = idx + 1
	var reward := int(data["reward"])
	Game.money += reward
	SaveScript.save_game()
	letter_title.text = "%s  %d/%d" % [data["title"], idx + 1, LETTERS]
	letter_body.text = letter_text(idx)
	letter_reward.text = "+%d원" % reward
	_show("letter")
	if debug:
		print("[FG] story letter ", idx + 1, "/", LETTERS, " stage=", Game.story_stage, " replies=", Game.story_replies, " money=", Game.money, " due=", reply_due())

func close_letter() -> void:
	if mode != "letter":
		return
	_hide()
	if reply_due():
		open_reply()
	elif Game.story_stage >= LETTERS:
		_toast("마지막 편지를 읽었어요.")
		if debug:
			print("[FG] story done")

# ---- 답장 창 ----
func open_reply() -> void:
	if mode != "" or not reply_due():
		return
	var ch: int = Game.story_stage / CHAPTER - 1
	var r: Dictionary = data["replies"][ch]
	reply_title.text = r["prompt"]
	for i in 3:
		(reply_rows[i]["text"] as Label).text = r["choices"][i]
	_show("reply")
	if debug:
		print("[FG] story reply open chapter=", ch + 1, " prompt=", r["prompt"])

func choose(i: int) -> void:
	if mode != "reply":
		return
	var ch: int = Game.story_stage / CHAPTER - 1
	Game.story_replies[ch] = i
	Game.story_wait_day = Game.farm_day + int(data["wait_days"])
	SaveScript.save_game()
	SfxScript.play("splash")
	_hide()
	_toast("답장 병을 바다에 띄웠어요. 곧 소식이 올 거예요.")
	if debug:
		print("[FG] story reply chapter=", ch + 1, " choice=", i, " wait_day=", Game.story_wait_day, " day=", Game.farm_day)

func _show(m: String) -> void:
	mode = m
	opened_at = Time.get_ticks_msec() / 1000.0
	Game.modal = "story"
	get_tree().paused = true
	root.visible = true
	letter_panel.visible = m == "letter"
	reply_panel.visible = m == "reply"
	_place()

func _hide() -> void:
	mode = ""
	Game.modal = ""
	get_tree().paused = false
	root.visible = false

func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	for p in [letter_panel, reply_panel]:
		(p as Panel).position = (vp - (p as Panel).size) * 0.5

func _toast(text: String) -> void:
	toast_label.text = text
	toast_t0 = Time.get_ticks_msec() / 1000.0

func _unhandled_input(event: InputEvent) -> void:
	if mode == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if event is InputEventKey and event.pressed and not event.echo:
		if mode == "letter" and now - opened_at > CLOSE_GUARD and event.keycode in [KEY_E, KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			close_letter()
		elif mode == "reply" and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			choose(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and mode == "letter" and now - opened_at > CLOSE_GUARD:
		close_letter()
		get_viewport().set_input_as_handled()

# ---- 화면 ----
func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	var size := Vector2(840, 500)
	letter_panel = ThemeUI.box(Color(0.99, 0.95, 0.84, 0.99), 24, Color(0.78, 0.55, 0.62, 0.95), 4)
	letter_panel.size = size
	root.add_child(letter_panel)
	letter_title = ThemeUI.text("", 30, Color(0.70, 0.35, 0.45))
	letter_panel.add_child(letter_title)
	ThemeUI.at(letter_title, size, 0, 200, 760, 44)
	letter_body = ThemeUI.text("", 30, INK, HORIZONTAL_ALIGNMENT_LEFT)
	letter_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	letter_panel.add_child(letter_body)
	ThemeUI.at(letter_body, size, 0, 28, 740, 316)
	var chip := ThemeUI.box(Color(1.0, 0.82, 0.28), 16)
	letter_panel.add_child(chip)
	ThemeUI.at(chip, size, -300, -208, 130, 40)
	letter_reward = ThemeUI.text("", 24, INK)
	chip.add_child(letter_reward)
	ThemeUI.at(letter_reward, Vector2(130, 40), 0, 0, 130, 40)
	var hint := ThemeUI.text("E: 닫기", 22, Color(0.4, 0.3, 0.22))
	letter_panel.add_child(hint)
	ThemeUI.at(hint, size, 300, -208, 140, 34)
	# 답장 창
	var rs := Vector2(760, 440)
	reply_panel = ThemeUI.box(Color(0.99, 0.95, 0.84, 0.99), 24, Color(0.78, 0.55, 0.62, 0.95), 4)
	reply_panel.size = rs
	root.add_child(reply_panel)
	reply_title = ThemeUI.text("", 32, Color(0.70, 0.35, 0.45))
	reply_panel.add_child(reply_title)
	ThemeUI.at(reply_title, rs, 0, 170, 700, 48)
	for i in 3:
		var row := ThemeUI.box(Color(1, 1, 1, 0.65), 16)
		reply_panel.add_child(row)
		ThemeUI.at(row, rs, 0, 70 - i * 92, 680, 78)
		var key := ThemeUI.box(BROWN, 14)
		row.add_child(key)
		ThemeUI.at(key, Vector2(680, 78), -300, 0, 46, 46)
		var kt := ThemeUI.text(str(i + 1), 28, Color.WHITE)
		key.add_child(kt)
		ThemeUI.at(kt, Vector2(46, 46), 0, 0, 46, 46)
		var tx := ThemeUI.text("", 28, INK, HORIZONTAL_ALIGNMENT_LEFT)
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(tx)
		ThemeUI.at(tx, Vector2(680, 78), 30, 0, 560, 70)
		reply_rows.append({"box": row, "text": tx})
	var rh := ThemeUI.text("숫자 키 1~3으로 골라 주세요", 22, Color(0.4, 0.3, 0.22))
	reply_panel.add_child(rh)
	ThemeUI.at(rh, rs, 0, -192, 500, 32)
	toast = ThemeUI.panel(Vector2(640, 54))
	toast_label = ThemeUI.label("", 28)
	toast.add_child(toast_label)
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 180)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0

func _process(_delta: float) -> void:
	var tt := Time.get_ticks_msec() / 1000.0 - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
