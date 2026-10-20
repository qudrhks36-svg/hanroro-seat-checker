extends Node3D
# 미니 농장 (포팅 11단계, GDD 3번 [확정]): 오두막 북쪽 풀밭의 밭 6칸. 빈 밭 E = 씨앗 창에서 씨앗을 사서 심기, 물주기 E(하루 한 번, 주면 즉시 한 단계), 다 자라면 E로 수확.
# 수확한 작물은 가방(Game.crops)에 쌓이고 바틀이·돌쇠에게 팔림(dialog.gd). 안 돌봐도 시들지 않음. 값·자리는 data/farm.json, 상태는 Game.plots(저장됨).
# 모양은 임시 도형(흙 두둑 + 단계별 식물). 좌표: 밭 자리는 유니티 (x, z) → 고닷 (x, -z).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const REACH := 2.6
const LOOK_DOT := 0.6
const TOAST_HOLD := 3.5
const SOIL := Color(0.45, 0.30, 0.18)
const SOIL_WET := Color(0.28, 0.18, 0.11)
const GREEN := Color(0.35, 0.65, 0.30)
const BROWN := Color(0.45, 0.30, 0.18)

var cam: Camera3D
var world: Node3D
var plots_nodes: Array = []    # {root, mound(mat), crop(Node3D)}
var shown_day := -999
var prompt: PanelContainer
var prompt_label: Label
var toast: PanelContainer
var toast_label: Label
var toast_t0 := -999.0
var current_plot := -1
var current_action := ""       # "plant" "water" "harvest" ""
var assume_captured := false   # 시험용
var debug := false

# 씨앗 창
var seed_layer: CanvasLayer
var seed_root: Control
var seed_panel: Panel
var seed_msg: Label
var seed_plot := -1
var seed_open := false

func setup(camera: Camera3D, world_node: Node3D) -> void:
	cam = camera
	world = world_node
	Game.ensure_loaded()
	_build_ui()
	_build_seed_window()
	_clear_decor()
	await get_tree().physics_frame   # 땅 높이는 물리 세계가 준비된 뒤에 잼
	await get_tree().physics_frame
	_build_plots()

# 밭 자리의 풀·꽃·덤불·바위를 치운다
func _clear_decor() -> void:
	var bx: Array = Game.clear_box["x"]
	var bz: Array = Game.clear_box["z"]
	var hidden := 0
	for it in world.items:
		if not String(it["parent"]).begins_with("Decor/"):
			continue
		var p: Array = it["pos"]
		var n = it.get("_node", null)
		if n != null and p[0] >= bx[0] and p[0] <= bx[1] and p[2] >= bz[0] and p[2] <= bz[1]:
			n.visible = false
			hidden += 1
	if debug:
		print("[FG] farm cleared decor: ", hidden)

func _ground_y(x: float, z: float) -> float:
	var from := Vector3(x, 20.0, z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0))
	if hit.is_empty() or (hit.collider as Node).name == "Sea":
		return 0.2
	return hit.position.y

func _build_plots() -> void:
	for i in Game.plot_pos.size():
		var pp: Array = Game.plot_pos[i]
		var root := Node3D.new()
		root.name = "Plot%d" % i
		root.position = Vector3(pp[0], _ground_y(pp[0], -pp[1]), -pp[1])
		add_child(root)
		var mound := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 0.16, 1.1)
		mound.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = SOIL
		mat.roughness = 1.0
		mound.material_override = mat
		mound.position = Vector3(0, 0.02, 0)
		mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mound)
		var border := StandardMaterial3D.new()
		border.albedo_color = Color(0.62, 0.45, 0.28)
		border.roughness = 1.0
		for side in [[Vector3(1.24, 0.12, 0.07), Vector3(0, 0.08, 0.585)], [Vector3(1.24, 0.12, 0.07), Vector3(0, 0.08, -0.585)], [Vector3(0.07, 0.12, 1.1), Vector3(0.585, 0.08, 0)], [Vector3(0.07, 0.12, 1.1), Vector3(-0.585, 0.08, 0)]]:
			var b := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = side[0]
			b.mesh = m
			b.material_override = border
			b.position = side[1]
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(b)
		plots_nodes.append({"root": root, "mound": mat, "crop": null})
	for i in plots_nodes.size():
		_refresh_plot(i)
	shown_day = Game.farm_day

# ---- 식물 모양 (임시 도형) ----
func _prim(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	return c

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s

func _leaf(parent: Node3D, pos: Vector3, rot_deg: Vector3, size: Vector3) -> void:
	var b := BoxMesh.new()
	b.size = size
	_prim(parent, b, GREEN, pos, rot_deg)

# 작물 번호 c, 물 준 횟수 g에 맞는 모습
func _crop_model(c: int, g: int) -> Node3D:
	var root := Node3D.new()
	var need: int = int(Game.crop_defs[c]["waterings"])
	var col: Color = Color(Game.crop_defs[c]["color"][0], Game.crop_defs[c]["color"][1], Game.crop_defs[c]["color"][2])
	if g <= 0:
		_prim(root, _cyl(0.0, 0.04, 0.12), GREEN, Vector3(0, 0.16, 0))   # 막 심은 새싹
	elif g < need:
		var f := float(g) / float(need)
		var h := 0.15 + 0.3 * f
		_prim(root, _cyl(0.025, 0.035, h), GREEN, Vector3(0, 0.1 + h * 0.5, 0))
		_leaf(root, Vector3(0.09, 0.1 + h * 0.8, 0), Vector3(0, 0, -35), Vector3(0.16, 0.02, 0.07))
		_leaf(root, Vector3(-0.09, 0.1 + h * 0.8, 0), Vector3(0, 0, 35), Vector3(0.16, 0.02, 0.07))
	else:   # 다 자람
		match c:
			0:   # 당근: 주황 뿌리가 땅 위로 + 잎
				_prim(root, _cyl(0.1, 0.0, 0.24), col, Vector3(0, 0.2, 0), Vector3(180, 0, 0))
				for a in [0.0, 120.0, 240.0]:
					_leaf(root, Vector3(0, 0.45, 0), Vector3(25, a, 0), Vector3(0.05, 0.34, 0.02))
			1:   # 옥수수: 키 큰 줄기 + 잎 + 노란 이삭
				_prim(root, _cyl(0.03, 0.045, 0.9), GREEN, Vector3(0, 0.55, 0))
				_leaf(root, Vector3(0.14, 0.7, 0), Vector3(0, 0, -50), Vector3(0.3, 0.02, 0.08))
				_leaf(root, Vector3(-0.14, 0.5, 0), Vector3(0, 0, 50), Vector3(0.3, 0.02, 0.08))
				var ear := CapsuleMesh.new()
				ear.radius = 0.06
				ear.height = 0.26
				_prim(root, ear, col, Vector3(0.07, 0.6, 0.02), Vector3(0, 0, -12))
			_:   # 딸기: 풀색 덤불 + 붉은 열매
				var bush := _prim(root, _sph(0.22), GREEN, Vector3(0, 0.28, 0))
				bush.scale = Vector3(1.0, 0.7, 1.0)
				for p in [Vector3(0.16, 0.2, 0.12), Vector3(-0.15, 0.22, 0.1), Vector3(0.02, 0.3, -0.17), Vector3(-0.08, 0.14, -0.14)]:
					_prim(root, _sph(0.055), col, p)
	return root

func _refresh_plot(i: int) -> void:
	var pn: Dictionary = plots_nodes[i]
	if pn["crop"] != null:
		(pn["crop"] as Node).queue_free()
		pn["crop"] = null
	var pl: Array = Game.plots[i]
	if int(pl[0]) >= 0:
		var model := _crop_model(int(pl[0]), int(pl[1]))
		model.position = Vector3(0, 0.1, 0)
		(pn["root"] as Node3D).add_child(model)
		pn["crop"] = model
	(pn["mound"] as StandardMaterial3D).albedo_color = SOIL_WET if (int(pl[0]) >= 0 and int(pl[2]) == Game.farm_day) else SOIL

# ---- 상태 판정 ----
func _need(i: int) -> int:
	return int(Game.crop_defs[int(Game.plots[i][0])]["waterings"])

func _action_of(i: int) -> String:
	var pl: Array = Game.plots[i]
	if int(pl[0]) < 0:
		return "plant"
	if int(pl[1]) >= _need(i):
		return "harvest"
	return "water" if int(pl[2]) != Game.farm_day else ""

func _prompt_text(i: int) -> String:
	var pl: Array = Game.plots[i]
	if int(pl[0]) < 0:
		return "E: 씨앗 심기"
	var nm: String = Game.crop_defs[int(pl[0])]["name"]
	var need := _need(i)
	match _action_of(i):
		"harvest": return "E: %s 수확하기" % nm
		"water": return "E: 물주기 (%s %d/%d)" % [nm, int(pl[1]), need]
		_: return "%s: 오늘은 물을 줬어요 (%d/%d)" % [nm, int(pl[1]), need]

func _process(_delta: float) -> void:
	if shown_day != Game.farm_day and not plots_nodes.is_empty():
		shown_day = Game.farm_day
		for i in plots_nodes.size():
			_refresh_plot(i)
	var t := Time.get_ticks_msec() / 1000.0
	var tt := t - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
	current_plot = -1
	current_action = ""
	var free := Game.modal == ""   # 마우스 잠금 없이도 E가 됨
	if free and not plots_nodes.is_empty():
		var best := LOOK_DOT
		for i in plots_nodes.size():
			var to: Vector3 = (plots_nodes[i]["root"] as Node3D).global_position + Vector3(0, 0.1, 0) - cam.global_position
			if to.length() > REACH:
				continue
			var d := (-cam.global_transform.basis.z).dot(to.normalized())
			if d > best:
				best = d
				current_plot = i
		if current_plot >= 0:
			current_action = _action_of(current_plot)
			prompt_label.text = _prompt_text(current_plot)
	prompt.visible = current_plot >= 0

func _unhandled_input(event: InputEvent) -> void:
	if seed_open:
		_seed_input(event)
		return
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and current_action != ""):
		return
	act(current_plot, current_action)
	get_viewport().set_input_as_handled()

func act(i: int, action: String) -> void:
	match action:
		"plant":
			_open_seeds(i)
		"water":
			var pl: Array = Game.plots[i]
			pl[1] = int(pl[1]) + 1
			pl[2] = Game.farm_day
			SfxScript.play("splash", 0.5)
			var nm: String = Game.crop_defs[int(pl[0])]["name"]
			_toast("물을 줬어요! (%s %d/%d)" % [nm, int(pl[1]), _need(i)] + ("  다 자랐어요!" if int(pl[1]) >= _need(i) else ""))
			SaveScript.save_game()
			_refresh_plot(i)
		"harvest":
			var pl: Array = Game.plots[i]
			var c := int(pl[0])
			Game.crops[c] = int(Game.crops[c]) + 1
			Game.plots[i] = [-1, 0, -1]
			SfxScript.play("catch")
			_toast("%s을(를) 수확했어요! (가방 %d)" % [Game.crop_defs[c]["name"], int(Game.crops[c])])
			SaveScript.save_game()
			_refresh_plot(i)
	if debug:
		print("[FG] farm ", action, " plot=", i, " state=", Game.plots[i], " crops=", Game.crops, " day=", Game.farm_day, " money=", Game.money)

func _toast(text: String) -> void:
	toast_label.text = text
	toast_t0 = Time.get_ticks_msec() / 1000.0

# ---- 씨앗 창: 숫자 1~3 또는 클릭으로 사서 바로 심기 ----
func _open_seeds(i: int) -> void:
	seed_plot = i
	seed_open = true
	Game.modal = "seeds"
	get_tree().paused = true   # 마우스는 잠근 채로 둠(숫자 키로 심기)
	seed_msg.text = "돈 %d원 · 숫자 키로 심어요" % Game.money
	seed_root.visible = true
	_place_seed_panel()

func close_seeds(relock: bool) -> void:
	if not seed_open:
		return
	seed_open = false
	Game.modal = ""
	get_tree().paused = false
	seed_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if relock else Input.MOUSE_MODE_VISIBLE

func _seed_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ESCAPE:
		close_seeds(false)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		close_seeds(true)
		get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode < KEY_1 + Game.seed_count:
		plant(seed_plot, event.keycode - KEY_1)
		get_viewport().set_input_as_handled()

# 씨앗을 사서 심는다. 돈이 모자라면 안내만. 심으면 창이 닫힘
func plant(i: int, c: int) -> void:
	var price := int(Game.crop_defs[c]["seed_price"])
	if Game.money < price:
		seed_msg.text = "돈이 모자라요. %d원이 필요해요." % price
		return
	Game.money -= price
	Game.plots[i] = [c, 0, -1]
	SfxScript.play("sell")
	SaveScript.save_game()
	_refresh_plot(i)
	close_seeds(true)
	_toast("%s 씨앗을 심었어요! 매일 물을 주세요" % Game.crop_defs[c]["name"])
	if debug:
		print("[FG] farm plant plot=", i, " crop=", c, " money=", Game.money)

func _place_seed_panel() -> void:
	seed_panel.position = (get_viewport().get_visible_rect().size - seed_panel.size) * 0.5

func _build_seed_window() -> void:
	seed_layer = CanvasLayer.new()
	seed_layer.layer = 9
	seed_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(seed_layer)
	seed_root = Control.new()
	seed_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	seed_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_layer.add_child(seed_root)
	var size := Vector2(640, 380)
	seed_panel = ThemeUI.box(Color(0.99, 0.95, 0.86, 0.98), 22, Color(0.45, 0.30, 0.18, 0.9), 3)
	seed_panel.size = size
	seed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	seed_root.add_child(seed_panel)
	var title := ThemeUI.text("씨앗 고르기", 34, BROWN, HORIZONTAL_ALIGNMENT_LEFT)
	seed_panel.add_child(title)
	ThemeUI.at(title, size, -200, 150, 220, 50)
	for i in Game.seed_count:
		var d: Dictionary = Game.crop_defs[i]
		var row := ThemeUI.box(Color(1, 1, 1, 0.55), 14)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		seed_panel.add_child(row)
		ThemeUI.at(row, size, 0, 72 - i * 68, 580, 58)
		var rs := Vector2(580, 58)
		var key := ThemeUI.box(BROWN, 14)
		row.add_child(key)
		ThemeUI.at(key, rs, -255, 0, 40, 40)
		var kt := ThemeUI.text(str(i + 1), 24, Color.WHITE)
		key.add_child(kt)
		ThemeUI.at(kt, Vector2(40, 40), 0, 0, 40, 40)
		var sw := ThemeUI.box(Color(d["color"][0], d["color"][1], d["color"][2]), 10, Color(0.45, 0.30, 0.18, 0.6), 2)
		row.add_child(sw)
		ThemeUI.at(sw, rs, -200, 0, 34, 34)
		var nm := ThemeUI.text("%s 씨앗" % d["name"], 28, Color(0.22, 0.15, 0.10), HORIZONTAL_ALIGNMENT_LEFT)
		row.add_child(nm)
		ThemeUI.at(nm, rs, -60, 0, 240, 50)
		var info := ThemeUI.text("물 %d번 · 팔면 %d원" % [int(d["waterings"]), int(d["sell_price"])], 20, Color(0.4, 0.3, 0.22), HORIZONTAL_ALIGNMENT_LEFT)
		row.add_child(info)
		ThemeUI.at(info, rs, 70, 0, 210, 50)
		var pr := ThemeUI.text("%d원" % int(d["seed_price"]), 26, Color(0.22, 0.15, 0.10), HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(pr)
		ThemeUI.at(pr, rs, 235, 0, 110, 50)
		row.gui_input.connect(_on_seed_row_input.bind(i))
	seed_msg = ThemeUI.text("", 22, BROWN)
	seed_panel.add_child(seed_msg)
	ThemeUI.at(seed_msg, size, 0, -150, 580, 34)
	var hint := ThemeUI.text("E / Esc: 닫기", 20, Color(0.4, 0.3, 0.22))
	seed_panel.add_child(hint)
	ThemeUI.at(hint, size, 0, -178, 400, 28)
	seed_root.visible = false

func _on_seed_row_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		plant(seed_plot, i)

# ---- 화면 ----
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
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 80)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0
