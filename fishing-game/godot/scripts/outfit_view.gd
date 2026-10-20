extends Node3D
# 낚싯대를 쥔 두 팔 (포팅 10단계, GDD 3번 [확정] + 3인칭): 눈(카메라) 아래에서 어깨 → 팔꿈치 → 손으로 이어지는 팔을 낚싯대 손잡이·가운데 자리에 맞춰 그린다.
# 팔꿈치는 두 마디 IK(윗팔·아랫팔 길이 고정, 팔꿈치는 바깥·아래로 꺾임). 낚싯대가 너무 멀면 팔이 쭉 펴짐. 소매 색 = 입은 옷의 윗옷 색.
# 낚싯대의 손잡이 끝(rod_model)과 끝(tip)은 눈 기준 자리라 낚싯대 단계(길이)가 바뀌어도 따라간다.

const Game := preload("res://scripts/game_state.gd")
const CharacterScript := preload("res://scripts/character.gd")
const PlayerScript := preload("res://scripts/player.gd")
const PlayerBodyScript := preload("res://scripts/player_body.gd")

const UPPER := 0.22          # 윗팔 길이
const FORE := 0.22           # 아랫팔 길이
const ARM_R := 0.05

var fishing
var sleeve_mat: StandardMaterial3D
var hand_mat: StandardMaterial3D
var arms: Array = []         # {upper, fore, shoulder, elbow, hand, grip(막대 위 비율), side, from}
var shown_outfit := -1

func setup(fishing_node) -> void:
	fishing = fishing_node
	sleeve_mat = StandardMaterial3D.new()
	sleeve_mat.roughness = 1.0
	hand_mat = StandardMaterial3D.new()
	hand_mat.roughness = 1.0
	hand_mat.albedo_color = CharacterScript.SKIN
	# 어깨 자리(눈 기준): 몸 모델의 어깨 높이에서 눈 높이를 뺀 값. 오른손은 손잡이 가까이, 왼손은 낚싯대 가운데쯤.
	var sy: float = CharacterScript.SHOULDER_Y * CharacterScript.PLAYER_SCALE - (PlayerBodyScript.FOOT + PlayerScript.EYE_HEIGHT)
	var sx: float = CharacterScript.SHOULDER_X * CharacterScript.PLAYER_SCALE
	for spec in [[0.22, 1.0], [0.5, -1.0]]:
		var side: float = spec[1]
		arms.append({
			"upper": _cyl(), "fore": _cyl(), "shoulder": _ball(ARM_R * 1.5, sleeve_mat), "elbow": _ball(ARM_R * 1.1, sleeve_mat),
			"hand": _ball(0.062, hand_mat), "grip": spec[0], "side": side, "from": Vector3(side * sx, sy, 0.0),
		})

func _cyl() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = ARM_R
	cm.bottom_radius = ARM_R
	cm.height = 1.0
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = sleeve_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _ball(r: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

# 점 a에서 b까지 막대(길이 1짜리 원기둥)를 뻗는다
func _seg(mi: Node3D, a: Vector3, b: Vector3, len_scale: float = 1.0) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.0001:
		return
	var up := d / len
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := up.cross(ref).normalized()
	var z := x.cross(up)
	mi.transform = Transform3D(Basis(x, up * len, z), (a + b) * 0.5)

func _process(_delta: float) -> void:
	if fishing == null or fishing.rod_model == null:
		return
	if shown_outfit != Game.outfit:
		shown_outfit = Game.outfit
		sleeve_mat.albedo_color = CharacterScript.color_of(Game.outfits[Game.outfit]["top"])
	var handle: Vector3 = fishing.rod_model.position
	var tip: Vector3 = fishing.tip.position
	for a in arms:
		var s: Vector3 = a["from"]
		var g: Vector3 = handle.lerp(tip, float(a["grip"]))
		var d := g - s
		var dist := d.length()
		var dir := d / maxf(dist, 0.0001)
		var reach := UPPER + FORE
		var elbow: Vector3
		if dist >= reach * 0.999:   # 너무 멀면 쭉 펴고, 손이 거기까지 가게 마디를 늘림
			elbow = s + dir * (dist * UPPER / reach)
		else:   # 두 마디 IK: 코사인 법칙으로 팔꿈치 자리, 바깥·아래·뒤쪽으로 꺾음
			var along := (dist * dist + UPPER * UPPER - FORE * FORE) / (2.0 * dist)
			var height := sqrt(maxf(UPPER * UPPER - along * along, 0.0))
			var pole := Vector3(float(a["side"]) * 0.6, -1.0, 0.35)
			pole = (pole - dir * pole.dot(dir)).normalized()
			elbow = s + dir * along + pole * height
		_seg(a["upper"], s, elbow)
		_seg(a["fore"], elbow, g)
		(a["shoulder"] as Node3D).position = s
		(a["elbow"] as Node3D).position = elbow
		(a["hand"] as Node3D).position = g
