extends Node3D
# 풀섬 과일나무 (GDD 8번 [확정] 풀섬 3단계): 풀섬 나무 앞에서 E = 열매 3개 따기. 딴 열매는 하루(Game.farm_day) 지나면 다시 열림.
# 열매는 작물 가방(Game.crops, farm.json의 "fruit":true 항목)에 쌓여 바틀이·돌쇠에게 팔리고 주민 선물로도 쓰임(dialog.gd). 딴 날은 Game.fruit_day(저장됨).
# 나무 모양은 meadow.gd가 만든 둥근 나무에 열매 공 3개를 붙인 것(임시 도형).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const REACH := 3.2
const LOOK_DOT := 0.75
const TOAST_HOLD := 3.5
const FRUIT_R := 0.17
const PER_TREE := 3

var cam: Camera3D
var fruit_defs: Array = []        # Game.crop_defs 중 "fruit":true 의 번호 (사과·귤·복숭아 순)
var trees: Array = []             # {node, kind(fruit_defs 안 순번), fruits(Array of MeshInstance3D)}
var shown_day := -999
var current := -1
var assume_captured := false      # 시험용
var debug := false
var prompt: PanelContainer
var prompt_label: Label
var toast: PanelContainer
var toast_label: Label
var toast_t0 := -999.0

func setup(camera: Camera3D, tree_nodes: Array, canopy: Array) -> void:
	cam = camera
	Game.ensure_loaded()
	for i in Game.crop_defs.size():
		if Game.crop_defs[i].get("fruit", false):
			fruit_defs.append(i)
	for t in mini(Game.fruit_day.size(), tree_nodes.size()):
		var kind := t % fruit_defs.size()
		var d: Dictionary = Game.crop_defs[fruit_defs[kind]]
		var col := Color(d["color"][0], d["color"][1], d["color"][2])
		var fruits: Array = []
		for k in PER_TREE:
			var m := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = FRUIT_R
			sm.height = FRUIT_R * 2.0
			m.mesh = sm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col
			mat.roughness = 0.5
			m.material_override = mat
			m.position = _surface_point(canopy, t * 0.9 + k * TAU / PER_TREE)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(tree_nodes[t] as Node3D).add_child(m)
			fruits.append(m)
		trees.append({"node": tree_nodes[t], "kind": kind, "fruits": fruits})
	_build_ui()
	_refresh()

# 캔버스(공 3개) 겉면 중 이 방향(각도)에서 바깥으로 나온 자리: 줄기 축에서 밖으로 나가며 어느 공에도 안 들어가는 첫 점
func _surface_point(canopy: Array, ang: float) -> Vector3:
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	var r := 0.6
	while r < 3.0:
		var p := dir * r + Vector3(0, 1.8, 0)
		var inside := false
		for c in canopy:
			if p.distance_to(c[0]) < float(c[1]) + FRUIT_R * 0.5:
				inside = true
		if not inside:
			return p + Vector3(0, 0.0, 0)
		r += 0.05
	return Vector3(0, 1.8, 0)

func ready_for(i: int) -> bool:
	return Game.farm_day - int(Game.fruit_day[i]) >= int(Game.fruit_regrow_days)

func _refresh() -> void:
	shown_day = Game.farm_day
	for i in trees.size():
		var on := ready_for(i)
		for f in trees[i]["fruits"]:
			(f as Node3D).visible = on

func pick(i: int) -> String:
	var t: Dictionary = trees[i]
	var idx: int = fruit_defs[int(t["kind"])]
	Game.crops[idx] = int(Game.crops[idx]) + PER_TREE
	Game.fruit_day[i] = Game.farm_day
	var nm: String = Game.crop_defs[idx]["name"]
	SfxScript.play("chime")
	_refresh()
	SaveScript.save_game()
	var msg := "%s %d개를 땄어요! (가방 %d)" % [nm, PER_TREE, int(Game.crops[idx])]
	_toast(msg)
	if debug:
		print("[FG] fruit pick tree=", i, " ", nm, " crops=", Game.crops, " day=", Game.farm_day)
	return msg

func _toast(text: String) -> void:
	toast_label.text = text
	toast_t0 = Time.get_ticks_msec() / 1000.0

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 6
	add_child(ui)
	prompt = ThemeUI.panel(Vector2(0, 0))
	prompt_label = ThemeUI.label("", 28)
	prompt.add_child(prompt_label)
	ui.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position.y += 80
	prompt.visible = false
	toast = ThemeUI.panel(Vector2(560, 54))
	toast_label = ThemeUI.label("", 28)
	toast.add_child(toast_label)
	ui.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 130)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0

func _process(_delta: float) -> void:
	if shown_day != Game.farm_day:
		_refresh()
	var tt := Time.get_ticks_msec() / 1000.0 - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
	current = -1
	var free := Game.modal == ""   # 마우스 잠금 없이도 E가 됨
	if free:
		var best := LOOK_DOT
		for i in trees.size():
			if not ready_for(i):
				continue
			var to: Vector3 = (trees[i]["node"] as Node3D).global_position + Vector3(0, 1.6, 0) - cam.global_position
			if to.length() > REACH + 1.0 or Vector2(to.x, to.z).length() > REACH:
				continue
			var d := (-cam.global_transform.basis.z).dot(to.normalized())
			if d > best:
				best = d
				current = i
		if current >= 0:
			prompt_label.text = "E: %s 따기" % Game.crop_defs[fruit_defs[int(trees[current]["kind"])]]["name"]
	prompt.visible = current >= 0

func _unhandled_input(event: InputEvent) -> void:
	if current >= 0 and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pick(current)
		get_viewport().set_input_as_handled()
