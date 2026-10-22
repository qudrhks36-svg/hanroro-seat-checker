extends CharacterBody3D
# 플레이어 (포팅 2-2): WASD 이동, 마우스 시점, 중력. 유니티 PlayerController와 같은 값(속도 4, 감도 0.1도/픽셀, 중력 -20).
# 몸(캡슐) 중심이 땅에서 약 1.02 위. 3인칭(GDD 8번 [확정]): cam은 머리 높이(몸 중심 위 0.42)의 보이지 않는 "눈"으로 조준·말 걸기·낚시 판정이 그대로 쓰고,
# 화면에 보이는 카메라 view는 어깨 뒤에서 따라오며 눈이 보는 방향의 15m 앞 한 점을 바라본다(십자 = 실제 조준).

const Game := preload("res://scripts/game_state.gd")

const SPEED := 4.0
const GRAVITY := 20.0
const JUMP_SPEED := 4.6          # 점프(Space): 높이 약 0.8~1m (부두·배 갑판 위로 올라서기)
const MOUSE_SENS := 0.1          # 도/픽셀
const ARROW_TURN := 100.0         # 방향키 시점 도는 빠르기(도/초)
const EYE_HEIGHT := 0.22
const VIEW_BACK := 3.2           # 3인칭 카메라: 눈에서 뒤로
const VIEW_SIDE := 0.55          # 오른쪽으로
const VIEW_UP := 0.35            # 위로
const VIEW_AIM := 15.0           # 카메라가 바라볼 눈 앞 거리
const VIEW_MIN := 0.9            # 이보다 가까우면 몸을 숨김
const STEP_HEIGHT := 0.4        # 유니티 CharacterController: 계단 0.3 + 몸 표면 여유 0.08 → 모래 끝(-0.06)에서 부두 바닥(0.3)까지 오를 수 있음

var cam: Camera3D                # 눈(보이지 않음, 판정용)
var view: Camera3D               # 화면 카메라(3인칭)
var body: Node3D                 # 3인칭 몸(main.gd가 정함)
var view_back := VIEW_BACK       # 지금 카메라 거리(집 안은 좁아서 cabin.gd가 줄임)
var rod_out := false             # 낚싯대를 꺼내 들고 있나(R 키, fishing_rod.gd가 바꿈). 넣어 두면 낚싯대·오른팔이 안 보이고 몸이 걷는 방향으로 돎
var orbit := 0.0                 # 시험용 --orbit=도: 카메라를 캐릭터 둘레로 돌려 앞·옆모습을 본다(0 = 뒤)
var fpv := false                 # 시험용 --fpv=1: 옛 1인칭 화면
var pitch := 0.0                 # 위아래 각도(도)
var dbg := ""                    # 시험용: 지금 닿은 것들
var test_jump := false           # 시험용: Space 대신 계속 점프
var peak_y := -1e9               # 시험용: 가장 높이 오른 높이
var test_walk := Vector2.ZERO    # 시험용: 키 대신 이 방향으로 걷게 함(x=오른쪽, y=앞)

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35   # 유니티 CharacterController: 반지름 0.35, 높이 1.8, 계단 0.3
	cap.height = 1.8
	shape.shape = cap
	add_child(shape)
	floor_snap_length = STEP_HEIGHT + 0.1   # 계단·부두 끝에서 내려올 때 바닥에 붙어서 떨어지지 않게
	cam = Camera3D.new()
	cam.position = Vector3(0, EYE_HEIGHT, 0)
	cam.current = false
	cam.fov = 60.0                  # 유니티 카메라 시야각(세로 60도). 고닷 기본은 75도
	add_child(cam)
	view = Camera3D.new()
	view.top_level = true
	view.current = true
	view.fov = 60.0
	add_child(view)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		turn(event.relative)

# 마우스가 움직인 픽셀(relative)만큼 몸(좌우)과 카메라(위아래)를 돌린다. 감도 = 0.1도/픽셀 × 설정 창의 배율.
func turn(relative: Vector2) -> void:
	var k := MOUSE_SENS * Game.mouse_scale
	rotate_y(deg_to_rad(-relative.x * k))
	pitch = clampf(pitch - relative.y * k, -80.0, 80.0)
	cam.rotation_degrees.x = pitch

func look(yaw_deg: float, pitch_deg: float) -> void:
	rotation_degrees.y = yaw_deg
	pitch = pitch_deg
	cam.rotation_degrees.x = pitch

func _physics_process(delta: float) -> void:
	var dir := test_walk
	# 걷기(WASD)와 방향키 시점은 마우스 잠금이 없어도 바로 된다(브라우저는 마우스 잠금에 클릭이 한 번 필요하므로 그 전에도 움직일 수 있게). 창이 열리면 시간이 멈춰 이 함수가 안 돌아감.
	dir.x += (1.0 if Input.is_physical_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_A) else 0.0)
	dir.y += (1.0 if Input.is_physical_key_pressed(KEY_W) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0)
	var turn_x := (1.0 if Input.is_physical_key_pressed(KEY_LEFT) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_RIGHT) else 0.0)
	var turn_y := (1.0 if Input.is_physical_key_pressed(KEY_UP) else 0.0) - (1.0 if Input.is_physical_key_pressed(KEY_DOWN) else 0.0)
	if turn_x != 0.0 or turn_y != 0.0:
		rotate_y(deg_to_rad(turn_x * ARROW_TURN * delta))
		pitch = clampf(pitch + turn_y * ARROW_TURN * 0.6 * delta, -80.0, 80.0)
		cam.rotation_degrees.x = pitch
	dir = dir.limit_length(1.0)
	var move := (global_transform.basis.x * dir.x + -global_transform.basis.z * dir.y) * SPEED
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = -2.0
		if Input.is_physical_key_pressed(KEY_SPACE) or test_jump:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	# 올라서기: 땅 위에서 앞이 막혔는데, STEP_HEIGHT만큼 올려 보면 앞이 비어 있으면 그만큼 올라선다
	# 막힌 곳이 "벽"(옆면이 거의 수직)일 때만 올라선다. 바닥의 작은 요철에 부딪힌 걸 벽으로 착각하면 위아래로 덜컹거림.
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if is_on_floor() and motion.length() > 0.0001:
		var hit := KinematicCollision3D.new()
		if test_move(global_transform, motion, hit) and absf(hit.get_normal().y) < 0.3:
			var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
			if not test_move(raised, motion):
				global_position.y += STEP_HEIGHT
	move_and_slide()
	peak_y = maxf(peak_y, global_position.y)
	dbg = ""
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		dbg += "%s n=%s | " % [(c.get_collider() as Node).name if c.get_collider() else "?", c.get_normal()]

func set_fpv(on: bool) -> void:
	fpv = on
	cam.current = on
	view.current = not on

func _process(_delta: float) -> void:
	var head := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var desired := head + Basis(Vector3.UP, deg_to_rad(orbit)) * (cam.global_transform.basis * Vector3(VIEW_SIDE if orbit == 0.0 else 0.0, VIEW_UP, view_back))
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(head, desired, 0xFFFFFFFF, [get_rid()]))
	var pos := desired
	if not hit.is_empty():   # 벽·나무에 닿으면 그 앞으로 당김
		pos = hit.position + (head - desired).normalized() * 0.25
	var target := head + fwd * VIEW_AIM if orbit == 0.0 else head
	if (target - pos).length() > 0.01 and absf((target - pos).normalized().dot(Vector3.UP)) < 0.999:
		view.look_at_from_position(pos, target, Vector3.UP)
	else:
		view.global_position = pos
	var far_enough := pos.distance_to(head) > VIEW_MIN
	if body != null:
		body.visible = not fpv and far_enough
	cam.visible = fpv or (far_enough and rod_out)   # 낚싯대·팔도 카메라가 너무 가까우면 숨김
