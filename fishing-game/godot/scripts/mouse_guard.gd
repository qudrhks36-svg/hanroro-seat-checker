extends Node
# 마우스 잠금 관리: 오른쪽 버튼을 누르는 동안만 잠가 시점을 돌린다. 창이 열려 시간이 멈춰도(process_mode ALWAYS) 떼는 신호를 놓치지 않고, 창이 열리면 바로 푼다.

const Game := preload("res://scripts/game_state.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed and Game.modal == "" else Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	if Game.modal != "" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
