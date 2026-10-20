extends Node3D
# 풀섬 동물 (GDD 8번 [확정] 풀섬 2단계): 토끼 둘·고양이·사슴이 풀밭을 어슬렁거린다. 바라보고 E = 쓰다듬기(하트·울음소리), 친밀도 3·8·15에서 돈 선물.
# 모양은 임시 도형(공·캡슐). 값은 data/animals.json, 친밀도는 Game.animal_love(저장됨). 좌표는 풀섬(Meadow) 안쪽 (x, z).

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SaveScript := preload("res://scripts/save_data.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const REACH := 2.8
const LOOK_DOT := 0.8
const TOAST_HOLD := 3.5
const WALK_RADIUS := 9.3
const GROUND_Y := 0.12
const PET_TIME := 2.5
const DATA_JSON := "res://data/animals.json"

var cam: Camera3D
var cfg: Dictionary
var blocked: Array = []            # [Vector2 자리, 반지름] — 연못·나무·바위
var list: Array = []               # {node, body, def, state, t, target, last_pet}
var rng := RandomNumberGenerator.new()
var current := -1
var assume_captured := false       # 시험용
var debug := false
var prompt: PanelContainer
var prompt_label: Label
var toast: PanelContainer
var toast_label: Label
var toast_t0 := -999.0

func setup(camera: Camera3D, blocked_spots: Array) -> void:
	cam = camera
	blocked = blocked_spots
	Game.ensure_loaded()
	rng.seed = 77
	cfg = JSON.parse_string(FileAccess.get_file_as_string(DATA_JSON))
	for i in cfg["animals"].size():
		_spawn(i, cfg["animals"][i])
	_build_ui()

# ---- 모양 (임시 도형) ----
func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	return c

func _eyes(body: Node3D, z: float, y: float, dx: float, r: float) -> void:
	for sx in [-1.0, 1.0]:
		_part(body, _sph(r), Color(0.1, 0.08, 0.08), Vector3(sx * dx, y, z))

# 앞은 +Z. body는 걸을 때 위아래로 통통 튀는 부분.
func _make_model(kind: String, col: Color) -> Node3D:
	var body := Node3D.new()
	var dark := col.darkened(0.25)
	match kind:
		"rabbit":
			_part(body, _sph(0.27), col, Vector3(0, 0.30, 0), Vector3.ZERO, Vector3(1, 0.9, 1.3))
			_part(body, _sph(0.19), col, Vector3(0, 0.48, 0.28))
			for sx in [-1.0, 1.0]:
				_part(body, _cap(0.06, 0.38), col, Vector3(sx * 0.08, 0.76, 0.24), Vector3(-8, 0, sx * 10))
			_part(body, _sph(0.09), Color(1, 1, 1), Vector3(0, 0.33, -0.36))
			_part(body, _sph(0.035), Color(1.0, 0.6, 0.65), Vector3(0, 0.46, 0.46))
			_eyes(body, 0.40, 0.53, 0.09, 0.03)
		"cat":
			_part(body, _cap(0.16, 0.62), col, Vector3(0, 0.30, 0), Vector3(90, 0, 0))
			_part(body, _sph(0.2), col, Vector3(0, 0.44, 0.34))
			for sx in [-1.0, 1.0]:
				_part(body, _cone(0.07, 0.15), dark, Vector3(sx * 0.11, 0.65, 0.34))
			_part(body, _cap(0.045, 0.55), col, Vector3(0, 0.50, -0.42), Vector3(-45, 0, 0))
			for sz in [0.18, -0.2]:
				for sx in [-1.0, 1.0]:
					_part(body, _sph(0.075), col, Vector3(sx * 0.11, 0.08, sz), Vector3.ZERO, Vector3(1, 0.8, 1.3))
			_part(body, _cap(0.03, 0.3), dark, Vector3(0, 0.36, 0), Vector3(90, 0, 0))
			_eyes(body, 0.52, 0.48, 0.08, 0.03)
		"deer":
			_part(body, _cap(0.26, 0.95), col, Vector3(0, 0.82, 0), Vector3(90, 0, 0))
			_part(body, _cap(0.09, 0.5), col, Vector3(0, 1.2, 0.5), Vector3(35, 0, 0))
			_part(body, _sph(0.16), col, Vector3(0, 1.5, 0.66), Vector3.ZERO, Vector3(1, 1, 1.2))
			_part(body, _sph(0.07), Color(0.25, 0.17, 0.12), Vector3(0, 1.45, 0.82))
			for sx in [-1.0, 1.0]:
				_part(body, _cone(0.05, 0.2), dark, Vector3(sx * 0.2, 1.62, 0.6), Vector3(0, 0, -sx * 35))
				_part(body, _cap(0.02, 0.3), Color(0.55, 0.4, 0.28), Vector3(sx * 0.08, 1.8, 0.58), Vector3(0, 0, -sx * 20))
				for sz in [0.35, -0.35]:
					_part(body, _cap(0.045, 0.62), dark, Vector3(sx * 0.14, 0.3, sz))
			for sp in [Vector3(0.15, 0.98, 0.12), Vector3(-0.17, 1.0, -0.15), Vector3(0.1, 1.04, -0.3), Vector3(-0.12, 1.02, 0.28)]:
				_part(body, _sph(0.045), Color(1, 0.97, 0.9), sp, Vector3.ZERO, Vector3(1, 0.5, 1))
			_part(body, _sph(0.06), Color(1, 1, 1), Vector3(0, 0.95, -0.52))
			_eyes(body, 0.76, 1.54, 0.1, 0.025)
	return body

func _spawn(i: int, def: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Animal_" + String(def["kind"]) + str(i)
	add_child(root)
	var c: Array = def["color"]
	var body := _make_model(def["kind"], Color(c[0], c[1], c[2]))
	root.add_child(body)
	root.scale = Vector3.ONE * float(def.get("scale", 1.0))
	var st: Array = def["start"]
	root.position = Vector3(st[0], GROUND_Y, st[1])
	list.append({"node": root, "body": body, "def": def, "state": "idle", "t": rng.randf_range(0.5, 3.0), "target": Vector3.ZERO, "last_pet": -999.0})

func _is_blocked(p: Vector2, margin: float = 0.45) -> bool:
	if p.length() > WALK_RADIUS:
		return true
	for b in blocked:
		if p.distance_to(b[0]) < float(b[1]) + margin:
			return true
	return false

# 지금 자리에서 다음 목표로 가는 길이 막히지 않았는지(8곳 확인)
func _clear_path(a: Vector2, b: Vector2) -> bool:
	for k in range(1, 9):
		if _is_blocked(a.lerp(b, k / 8.0)):
			return false
	return true

func _pick_target(a: Dictionary) -> bool:
	var n: Node3D = a["node"]
	var from := Vector2(n.position.x, n.position.z)
	for _t in 24:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(1.5, 5.0)
		var to := from + Vector2(cos(ang), sin(ang)) * d
		if not _is_blocked(to) and _clear_path(from, to):
			a["target"] = Vector3(to.x, GROUND_Y, to.y)
			return true
	return false

func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for a in list:
		var n: Node3D = a["node"]
		var body: Node3D = a["body"]
		var def: Dictionary = a["def"]
		a["t"] = float(a["t"]) - delta
		match String(a["state"]):
			"idle":
				body.position.y = lerpf(body.position.y, 0.0, 0.2)
				if float(a["t"]) <= 0.0:
					if _pick_target(a):
						a["state"] = "walk"
					else:
						a["t"] = 1.0
			"walk":
				var to: Vector3 = a["target"] - n.position
				to.y = 0.0
				if to.length() < 0.15:
					a["state"] = "idle"
					a["t"] = rng.randf_range(2.0, 6.0)
				else:
					var spd := float(def["speed"])
					n.position += to.normalized() * spd * delta
					n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), minf(delta * 6.0, 1.0))
					var rabbit: bool = def["kind"] == "rabbit"
					body.position.y = absf(sin(now * (7.0 if rabbit else 4.0) * spd)) * (0.12 if rabbit else 0.03)
			"pet":
				body.position.y = lerpf(body.position.y, 0.0, 0.2)
				if float(a["t"]) <= 0.0:
					a["state"] = "idle"
					a["t"] = rng.randf_range(1.0, 3.0)

# ---- 쓰다듬기 ----
func _hearts(a: Dictionary) -> void:
	for k in 3:
		var h := _part(a["node"], _sph(0.06), Color(1.0, 0.45, 0.6), Vector3((k - 1) * 0.18, 1.0 + k * 0.05, 0.0))
		(h.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var tw := h.create_tween()
		tw.set_parallel(true)
		tw.tween_property(h, "position:y", h.position.y + 0.9, 1.1).set_delay(k * 0.15)
		tw.tween_property(h, "scale", Vector3.ZERO, 0.4).set_delay(0.8 + k * 0.15)
		tw.chain().tween_callback(h.queue_free)

func _level(love: int) -> int:
	var lv := 0
	for need in Game.FRIEND_LEVELS:
		if love >= int(need):
			lv += 1
	return lv

func pet(i: int, force: bool = false) -> String:
	var a: Dictionary = list[i]
	var def: Dictionary = a["def"]
	var now := Time.get_ticks_msec() / 1000.0
	a["state"] = "pet"
	a["t"] = PET_TIME
	var n: Node3D = a["node"]
	var to := cam.global_position - n.global_position
	n.rotation.y = atan2(to.x, to.z)
	_hearts(a)
	SfxScript.play(def["sound"], 0.5, float(def["pitch"]))
	var msg := "%s: 기분 좋아 보여요" % def["name"]
	var love := int(Game.animal_love[i])
	if (force or now - float(a["last_pet"]) >= float(cfg["pet_cooldown_sec"])) and love < int(Game.FRIEND_LEVELS[2]):
		a["last_pet"] = now
		var before := _level(love)
		love += 1
		Game.animal_love[i] = love
		var after := _level(love)
		msg = "%s가 좋아해요! (친밀도 %d)" % [def["name"], love]
		if after > before:
			var gift: int = int(cfg["gift_money"][after - 1])
			Game.money += gift
			SfxScript.play("sell")
			msg = "%s가 선물을 줬어요! +%d원" % [def["name"], gift]
		SaveScript.save_game()
	_toast(msg)
	if debug:
		print("[FG] pet ", def["name"], " love=", Game.animal_love[i], " money=", Game.money)
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
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 80)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.modulate.a = 0.0

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var tt := t - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 4.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
	current = -1
	var free := Game.modal == ""   # 마우스 잠금 없이도 E가 됨
	if free:
		var best := LOOK_DOT
		for i in list.size():
			var to: Vector3 = (list[i]["node"] as Node3D).global_position + Vector3(0, 0.5, 0) - cam.global_position
			if to.length() > REACH:
				continue
			var d := (-cam.global_transform.basis.z).dot(to.normalized())
			if d > best:
				best = d
				current = i
		if current >= 0:
			prompt_label.text = "E: %s 쓰다듬기 (친밀도 %d)" % [list[current]["def"]["name"], int(Game.animal_love[current])]
	prompt.visible = current >= 0

func _unhandled_input(event: InputEvent) -> void:
	if current >= 0 and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pet(current)
		get_viewport().set_input_as_handled()
