extends Node3D
# 3인칭 캐릭터 몸 (GDD 8번 [확정] 3인칭 1단계): 옷장에서 고른 옷의 둥근 도형 사람(character.gd)을 플레이어 아래에 세운다. 0.8배 크기, 그림자 있음, 걸을 때 통통.
# 낚싯대를 넣어 둔 동안(player.rod_out == false)은 걷는 방향으로 몸이 돌고 두 팔을 다리 반대로 흔들며 걷는다(동물의 숲처럼).
# 낚싯대를 꺼낸 동안(R 키)은 몸이 늘 카메라가 보는 쪽(조준)을 보고, 왼팔은 옆에 내린 채 고정, 오른팔은 outfit_view.gd가 낚싯대를 쥔 모양으로 따로 그린다(그 동안 몸의 오른팔은 숨김). 옷이 바뀌면 다시 만든다.

const Game := preload("res://scripts/game_state.gd")
const CharacterScript := preload("res://scripts/character.gd")

const BODY_SCALE := CharacterScript.PLAYER_SCALE
const FOOT := 1.02          # 플레이어(캡슐) 중심에서 발까지

var player: CharacterBody3D
var fishing                  # 낚시 중에는 조준 방향을 봄 (main.gd가 정함)
var face := 0.0              # 몸이 보는 방향(세계 기준 각도)
const TURN_SPEED := 12.0     # 몸 돌리는 빠르기
const ARM_SWING := 0.55      # 팔 흔들림 최대 각도(라디안)
const LEG_SWING := 0.7       # 다리 흔들림 최대 각도(라디안)
var model: Node3D
var shown_outfit := -1
var t := 0.0
var legs: Array = []        # 다리 축 노드 (character.gd의 meta "leg" = 좌우). 걸을 때 번갈아 흔듦
var arms: Array = []        # 팔 축 노드 (meta "arm" = 좌우, +1이 오른팔)

func setup(p: CharacterBody3D) -> void:
	player = p
	position = Vector3(0, -FOOT, 0)
	scale = Vector3.ONE * BODY_SCALE

func _rebuild() -> void:
	if model != null:
		model.queue_free()
	model = CharacterScript.build(Game.outfits[Game.outfit], true)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(model)
	legs = model.get_children().filter(func(n): return n.has_meta("leg"))
	arms = model.get_children().filter(func(n): return n.has_meta("arm"))
	shown_outfit = Game.outfit

func _process(delta: float) -> void:
	Game.ensure_loaded()
	if shown_outfit != Game.outfit or model == null:
		_rebuild()
	var v := Vector2(player.velocity.x, player.velocity.z)
	var speed := v.length()
	var cam_yaw: float = player.rotation.y
	var target := cam_yaw
	var casting: bool = player.rod_out or (fishing != null and not fishing.is_idle())   # 낚싯대를 꺼냈거나 낚시 중이면 조준 방향을 봄
	if speed > 0.5 and not casting:
		target = atan2(-v.x, -v.y)   # 앞(-z)을 y만큼 돌린 방향 = (-sin, -cos)
	face = lerp_angle(face, target, minf(delta * TURN_SPEED, 1.0))
	rotation.y = face - cam_yaw
	t += delta * speed * 2.4
	var k := clampf(speed / 4.0, 0.0, 1.0)
	for l in legs:
		(l as Node3D).rotation.x = lerpf((l as Node3D).rotation.x, sin(t) * LEG_SWING * k * float(l.get_meta("leg")), minf(delta * 20.0, 1.0))
	for a in arms:
		var side := float(a.get_meta("arm"))
		(a as Node3D).visible = not (player.rod_out and side > 0.0)   # 꺼낸 동안 오른팔은 낚싯대 쥔 팔(outfit_view.gd)이 대신함
		var want := 0.0 if player.rod_out else -sin(t) * ARM_SWING * k * side   # 낚싯대를 꺼낸 동안 왼팔은 고정, 넣어 두면 다리 반대로 흔듦
		(a as Node3D).rotation.x = lerpf((a as Node3D).rotation.x, want, minf(delta * 20.0, 1.0))
	model.position.y = absf(sin(t)) * 0.06 * clampf(speed / 4.0, 0.0, 1.0)
