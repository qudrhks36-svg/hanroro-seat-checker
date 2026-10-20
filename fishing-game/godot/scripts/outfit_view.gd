extends Node3D
# 1인칭 소매와 손 (포팅 10단계, GDD 3번 [확정]): 낚싯대를 든 두 손과 팔(소매)을 카메라 아래에 보여준다. 소매 색 = 입은 옷의 윗옷 색.
# 낚싯대의 손잡이 끝(handle)과 낚싯대 끝(tip)의 카메라 기준 자리에서 손 자리를 계산해, 낚싯대 단계(길이)가 바뀌어도 따라간다.

const Game := preload("res://scripts/game_state.gd")
const CharacterScript := preload("res://scripts/character.gd")

var fishing
var sleeve_mat: StandardMaterial3D
var hand_mat: StandardMaterial3D
var arms: Array = []      # {mesh, grip(막대 위 비율), from(화면 밖 시작점)}
var hands: Array = []
var shown_outfit := -1

func setup(fishing_node) -> void:
	fishing = fishing_node
	sleeve_mat = StandardMaterial3D.new()
	sleeve_mat.roughness = 1.0
	hand_mat = StandardMaterial3D.new()
	hand_mat.roughness = 1.0
	hand_mat.albedo_color = CharacterScript.SKIN
	# 오른손은 손잡이 가까이, 왼손은 낚싯대 가운데쯤. 팔은 어깨(눈 기준 아래 0.3, 좌우 0.26)에서 시작(3인칭)
	for spec in [[0.22, Vector3(0.26, -0.30, 0.0)], [0.5, Vector3(-0.26, -0.30, 0.0)]]:
		var arm := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.055
		cm.height = 1.0
		cm.radial_segments = 10
		arm.mesh = cm
		arm.material_override = sleeve_mat
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arm)
		var hand := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		sm.radial_segments = 12
		sm.rings = 6
		hand.mesh = sm
		hand.material_override = hand_mat
		hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hand)
		arms.append({"mesh": arm, "grip": spec[0], "from": spec[1]})
		hands.append(hand)

func _process(_delta: float) -> void:
	if fishing == null or fishing.rod_model == null:
		return
	if shown_outfit != Game.outfit:
		shown_outfit = Game.outfit
		sleeve_mat.albedo_color = CharacterScript.color_of(Game.outfits[Game.outfit]["top"])
	var handle: Vector3 = fishing.rod_model.position
	var tip: Vector3 = fishing.tip.position
	for k in arms.size():
		var a: Dictionary = arms[k]
		var grip: Vector3 = handle.lerp(tip, float(a["grip"]))
		var from: Vector3 = a["from"]
		var d: Vector3 = grip - from
		var len := d.length()
		var up := d / len
		var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x := up.cross(ref).normalized()
		var z := x.cross(up)
		(a["mesh"] as Node3D).transform = Transform3D(Basis(x, up * len, z), (from + grip) * 0.5)
		(hands[k] as Node3D).position = grip
