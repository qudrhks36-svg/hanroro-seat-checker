extends Node3D
# 3인칭 캐릭터 몸 (GDD 8번 [확정] 3인칭 1단계): 옷장에서 고른 옷의 둥근 도형 사람(character.gd)을 플레이어 아래에 세운다. 0.8배 크기, 그림자 있음, 걸을 때 통통.
# 걷는 방향으로 몸을 돌린다(동물의 숲처럼): 움직일 때는 가는 쪽을 보고, 멈추거나 낚시 중이면 카메라가 보는 쪽(조준)으로 돌아온다.
# 몸이 카메라 앞쪽에서 35도 넘게 돌아가 있으면 낚싯대·팔을 숨긴다(player.aligned). 팔은 outfit_view.gd가 어깨에서 낚싯대까지 따로 그리므로 몸 모델은 팔 없이 만든다. 옷이 바뀌면 다시 만든다.

const Game := preload("res://scripts/game_state.gd")
const CharacterScript := preload("res://scripts/character.gd")

const BODY_SCALE := 0.8
const FOOT := 1.02          # 플레이어(캡슐) 중심에서 발까지

var player: CharacterBody3D
var fishing                  # 낚시 중에는 조준 방향을 봄 (main.gd가 정함)
var face := 0.0              # 몸이 보는 방향(세계 기준 각도)
const TURN_SPEED := 12.0     # 몸 돌리는 빠르기
const ALIGN_DEG := 35.0      # 이 안이면 낚싯대를 들고 있는 것으로 봄
var model: Node3D
var shown_outfit := -1
var t := 0.0

func setup(p: CharacterBody3D) -> void:
	player = p
	position = Vector3(0, -FOOT, 0)
	scale = Vector3.ONE * BODY_SCALE

func _rebuild() -> void:
	if model != null:
		model.queue_free()
	model = CharacterScript.build(Game.outfits[Game.outfit], false)
	for n in model.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(model)
	shown_outfit = Game.outfit

func _process(delta: float) -> void:
	Game.ensure_loaded()
	if shown_outfit != Game.outfit or model == null:
		_rebuild()
	var v := Vector2(player.velocity.x, player.velocity.z)
	var speed := v.length()
	var cam_yaw: float = player.rotation.y
	var target := cam_yaw
	var casting: bool = fishing != null and not fishing.is_idle()
	if speed > 0.5 and not casting:
		target = atan2(-v.x, -v.y)   # 앞(-z)을 y만큼 돌린 방향 = (-sin, -cos)
	face = lerp_angle(face, target, minf(delta * TURN_SPEED, 1.0))
	rotation.y = face - cam_yaw
	player.aligned = absf(angle_difference(face, cam_yaw)) < deg_to_rad(ALIGN_DEG)
	t += delta * speed * 2.4
	model.position.y = absf(sin(t)) * 0.06 * clampf(speed / 4.0, 0.0, 1.0)
