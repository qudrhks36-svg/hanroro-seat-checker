extends CanvasLayer
# 배경음악과 음소거 (포팅 8단계, GDD 2번 [확정], 유니티 BgmPlayer + MuteToggle).
# BGM: 음원의 잔잔한 앞부분(0~16.5초)만 게임 내내 반복. 드럼 "딩"이 16.75초에 들어와서 그 전에 처음으로 돌아가고, 이음새는 0.5초 동안 소리를 줄였다 키움. 볼륨 0.2.
# M키: 소리 전체(BGM·효과음·NPC 소리·빗소리)를 끄고 켠다. 꺼진 동안만 "소리 꺼짐 (M)" 표시. 저장하지 않음. 시간이 멈춰도(대화·도감) 동작.

const ThemeUI := preload("res://scripts/ui_theme.gd")

const BGM_PATH := "res://assets/audio/bgm_loop.ogg"
const BGM_VOLUME := 0.2
const LOOP_END := 16.5
const FADE := 0.5

static var muted := false

var player: AudioStreamPlayer
var label: Panel

func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply(false)   # 항상 소리가 켜진 채로 시작
	player = AudioStreamPlayer.new()
	player.stream = load(BGM_PATH)
	player.volume_db = linear_to_db(0.0001)
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
	var t := player.get_playback_position()
	if t >= LOOP_END:
		player.seek(0.0)
		t = 0.0
	player.volume_db = linear_to_db(maxf(BGM_VOLUME * minf(1.0, minf(t / FADE, (LOOP_END - t) / FADE)), 0.0001))
	if not player.playing:
		player.play()
