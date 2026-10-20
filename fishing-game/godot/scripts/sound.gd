extends CanvasLayer
# 배경음악과 음소거 (포팅 8단계, GDD 2번 [확정], 유니티 BgmPlayer + MuteToggle).
# BGM: 원곡 앞의 잔잔한 15초 조각을 틈 없이 계속 반복(tools/make_bgm_loop.py가 끝 1.5초를 처음과 크로스페이드해서 만든 파일, 스트림 loop=true). 볼륨 0.2.
# M키: 소리 전체(BGM·효과음·NPC 소리·빗소리)를 끄고 켠다. 꺼진 동안만 "소리 꺼짐 (M)" 표시. 저장하지 않음. 시간이 멈춰도(대화·도감) 동작.

const ThemeUI := preload("res://scripts/ui_theme.gd")

const BGM_PATH := "res://assets/audio/bgm_loop.ogg"
const BGM_VOLUME := 0.2

static var muted := false

var player: AudioStreamPlayer
var label: Panel

func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(false)   # 항상 소리가 켜진 채로 시작
	player = AudioStreamPlayer.new()
	var bgm: AudioStreamOggVorbis = load(BGM_PATH)
	bgm.loop = true   # 끝에서 처음으로 틈 없이 이어짐
	player.stream = bgm
	player.volume_db = linear_to_db(BGM_VOLUME)
	add_child(player)
	player.play()
	label = ThemeUI.box(ThemeUI.CREAM, 16, ThemeUI.EDGE, 2)
	label.custom_minimum_size = Vector2(210, 46)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 30)
	var t := ThemeUI.text("소리 꺼짐 (M)", 24, ThemeUI.INK)
	label.add_child(t)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_apply(not muted)

static func _apply(on: bool) -> void:
	muted = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func _process(_delta: float) -> void:
	label.visible = muted
	if not player.playing:
		player.play()   # 혹시 멈췄으면 다시 시작
