extends CharacterBody3D
# 플레이어 (포팅 2-2): WASD 이동, 마우스 시점, 중력. 유니티 PlayerController와 같은 값(속도 4, 감도 0.1도/픽셀, 중력 -20).
# 몸(캡슐) 중심이 땅에서 약 1.02 위, 눈은 몸 중심에서 0.7 위(유니티: 몸 y 1.1, 눈 y 1.8).

const SPEED := 4.0
const GRAVITY := 20.0
const MOUSE_SENS := 0.1          # 도/픽셀
const EYE_HEIGHT := 0.7
const STEP_HEIGHT := 0.4        # 유니티 CharacterController: 계단 0.3 + 몸 표면 여유 0.08 → 모래 끝(-0.06)에서 부두 바닥(0.3)까지 오를 수 있음

var cam: Camera3D
var pitch := 0.0                 # 위아래 각도(도)
var test_walk := Vector2.ZERO    # 시험용: 키 대신 이 방향으로 걷게 함(x=오른쪽, y=앞)

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35   # 유니티 CharacterController: 반지름 0.35, 높이 1.8, 계단 0.3
	cap.height = 1.8
	shape.shape = cap
	add_child(shape)
	cam = Camera3D.new()
	cam.position = Vector3(0, EYE_HEIGHT, 0)
	cam.current = true
	cam.fov = 60.0                  # 유니티 카메라 시야각(세로 60도). 고닷 기본은 75도
	add_child(cam)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENS))
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -80.0, 80.0)
		cam.rotation_degrees.x = pitch

func look(yaw_deg: float, pitch_deg: float) -> void:
	rotation_degrees.y = yaw_deg
	pitch = pitch_deg
	cam.rotation_degrees.x = pitch

func _physics_process(delta: float) -> void:
	var dir := test_walk
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		dir.x += (1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0)
		dir.y += (1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0)
	dir = dir.limit_length(1.0)
	var move := (global_transform.basis.x * dir.x + -global_transform.basis.z * dir.y) * SPEED
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y -= GRAVITY * delta
	# 올라서기: 땅 위에서 앞이 막혔는데, STEP_HEIGHT만큼 올려 보면 앞이 비어 있으면 그만큼 올라선다
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if is_on_floor() and motion.length() > 0.0001 and test_move(global_transform, motion):
		var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
		if not test_move(raised, motion):
			global_position.y += STEP_HEIGHT
	move_and_slide()
