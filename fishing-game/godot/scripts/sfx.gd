extends RefCounted
# 효과음 재생 (유니티 Sfx의 고닷 버전): 소리 파일은 assets/audio/sfx/*.wav (유니티가 코드로 만들던 소리를 파일로 뽑은 것).
# host 노드 아래에 한 번 쓰고 사라지는 플레이어를 만들어 재생한다(겹쳐 울려도 됨). 일시정지 중에도 재생.
# 음소거(M)는 sound.gd가 Master 버스를 꺼서 처리한다.

const MASTER := 0.5   # 유니티 Sfx.Volume. 낚시·판매 같은 기본 효과음은 이 값을 곱하고, NPC 목소리처럼 값을 직접 정한 소리는 그대로

static var host: Node
static var cache: Dictionary = {}

static func play(sound_name: String, volume: float = -1.0) -> void:
	if host == null:
		return
	if not cache.has(sound_name):
		cache[sound_name] = load("res://assets/audio/sfx/%s.wav" % sound_name)
	var p := AudioStreamPlayer.new()
	p.stream = cache[sound_name]
	p.volume_db = linear_to_db(maxf(MASTER if volume < 0.0 else volume, 0.0001))
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
