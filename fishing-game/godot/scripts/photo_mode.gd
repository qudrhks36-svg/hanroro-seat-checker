extends CanvasLayer
# 사진 찍기 (포팅 8단계, GDD 9번 [확정], 유니티 PhotoMode): P키 → 화면 글자(상태창·안내)를 한 프레임 빼고 풍경(낚싯대 포함)만 찍어 저장한다.
# 찰칵 소리 + 하얀 번쩍임(0.4초) + "사진을 저장했어요!"(3초). 웹: 브라우저 다운로드. PC: 내 사진 폴더 아래 BottleIsland. 창이 열려 있거나 마우스가 풀려 있으면 안 찍힘.

const Game := preload("res://scripts/game_state.gd")
const ThemeUI := preload("res://scripts/ui_theme.gd")
const SfxScript := preload("res://scripts/sfx.gd")

const FLASH_TIME := 0.4
const TOAST_HOLD := 3.0
const COOLDOWN := 1.2

static var save_dir_override := ""   # 시험용: PC 저장 폴더를 바꿈

var busy := false
var cooldown_until := 0.0
var flash: ColorRect
var toast: Panel
var toast_label: Label
var flash_t0 := -999.0
var toast_t0 := -999.0
var assume_captured := false         # 시험용: 마우스 잠금 없이도 잠긴 것으로 침

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast = ThemeUI.box(ThemeUI.CREAM, 16, ThemeUI.EDGE, 2)
	toast.custom_minimum_size = Vector2(420, 54)
	toast.modulate.a = 0.0
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	toast_label = ThemeUI.text("", 28, ThemeUI.INK)
	toast.add_child(toast_label)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _can_shoot() -> bool:
	var locked := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or assume_captured
	return not busy and _now() >= cooldown_until and locked and Game.modal == ""

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P and _can_shoot():
		shoot()
		get_viewport().set_input_as_handled()

# 화면 글자(CanvasLayer)만 한 프레임 꺼서 풍경만 찍는다
func shoot() -> void:
	busy = true
	var hidden: Array = []
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c != self and c.visible:
			c.visible = false
			hidden.append(c)
	await get_tree().process_frame   # 꺼진 모습이 그려진 프레임을 기다림(frame_post_draw는 화면 없는 실행에서 오지 않아 멈출 수 있어 쓰지 않음)
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	for c in hidden:
		if is_instance_valid(c):
			c.visible = true
	var ok := img != null and not img.is_empty() and _save(img)
	SfxScript.play("shutter")
	flash_t0 = _now()
	toast_label.text = "사진을 저장했어요!" if ok else "사진을 저장하지 못했어요"
	toast_t0 = _now()
	cooldown_until = _now() + COOLDOWN
	busy = false
	print("[FG] photo ok=", ok)

static func file_name() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "BottleIsland_%04d%02d%02d_%02d%02d%02d.png" % [t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]]

# 웹은 브라우저 다운로드, PC는 사진 폴더에 저장. 성공하면 true
static func _save(img: Image) -> bool:
	var fname := file_name()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), fname, "image/png")
		return true
	var dir := save_dir_override if save_dir_override != "" else OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("BottleIsland")
	DirAccess.make_dir_recursive_absolute(dir)
	var err := img.save_png(dir.path_join(fname))
	if err != OK:
		push_warning("사진 저장 실패: %s" % error_string(err))
	return err == OK

func _process(_delta: float) -> void:
	var f := (_now() - flash_t0) / FLASH_TIME
	flash.color = Color(1, 1, 1, 0.0 if f >= 1.0 else 0.85 * (1.0 - f) * (1.0 - f))
	var tt := _now() - toast_t0
	toast.modulate.a = 0.0 if tt > TOAST_HOLD + 0.5 else clampf(tt * 5.0, 0.0, 1.0) * (1.0 - clampf((tt - TOAST_HOLD) / 0.5, 0.0, 1.0))
