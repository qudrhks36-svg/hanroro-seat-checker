extends Node3D
# 포팅 1단계 시험 장면 (docs/GODOT_PORT.md): 섬 모델 하나 + 하늘 + 주아 글꼴 한글 + 첫 클릭 마우스 잠금 표시.
# 이 파일은 1단계가 끝나면 진짜 시작 장면으로 바뀐다.

var label: Label
var started := false

func _ready() -> void:
	# 하늘·빛 (유니티 낮 값, world.json)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.58, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.50, 0.60)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 150, 0)
	sun.light_color = Color(1, 0.97, 0.92)
	add_child(sun)

	# 섬 (FBX를 그대로 불러옴)
	var island: PackedScene = load("res://assets/models/Island.fbx")
	add_child(island.instantiate())

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.8, 0)
	cam.current = true
	add_child(cam)

	# 화면 글자 (주아)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.add_theme_font_override("font", load("res://assets/fonts/Jua-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.33, 0.23, 0.16))
	label.position = Vector2(24, 24)
	layer.add_child(label)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # 첫 클릭은 시작(마우스 잠금)만
		started = true
		print("[FG] first click -> mouse captured")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	var mode := "잠김" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "풀림"
	label.text = "화면을 한 번 클릭하면 시작해요\n마우스: %s · 시작함: %s · %d fps" % [mode, "예" if started else "아니오", Engine.get_frames_per_second()]
