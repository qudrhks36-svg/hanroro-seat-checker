extends Node3D
# 3인칭 캐릭터 몸 (GDD 8번 [확정] 3인칭 1단계): 옷장에서 고른 옷의 둥근 도형 사람(character.gd)을 플레이어 아래에 세운다. 0.8배 크기, 그림자 있음, 걸을 때 통통.
# 팔은 outfit_view.gd가 어깨에서 낚싯대까지 따로 그리므로 몸 모델은 팔 없이 만든다. 옷이 바뀌면 다시 만든다.

const Game := preload("res://scripts/game_state.gd")
const CharacterScript := preload("res://scripts/character.gd")

const BODY_SCALE := 0.8
const FOOT := 1.02          # 플레이어(캡슐) 중심에서 발까지

var player: CharacterBody3D
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
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	t += delta * speed * 2.4
	model.position.y = absf(sin(t)) * 0.06 * clampf(speed / 4.0, 0.0, 1.0)
