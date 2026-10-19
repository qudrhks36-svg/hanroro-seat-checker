# 고닷(Godot) 포팅 준비 노트 (2026-10-16)

BOTTLE ISLAND를 유니티에서 고닷으로 옮길 때 보는 문서예요. **오늘은 밑작업만 했어요(코드 이식은 안 함).** 이유(사용자): 웹 로딩이 무겁고, 유니티 사용·용량·라이선스가 걱정돼서.
옮기는 동안에도 유니티 버전이 공개 주소(https://fishing-game-web.vercel.app)에서 계속 돌아가요. 고닷 버전이 같은 수준이 되기 전에는 바꾸지 않아요.

## 1. 밑작업으로 만들어 둔 것
| 무엇 | 어디 | 비고 |
|---|---|---|
| 게임 숫자·글 (JSON) | `godot/data/` : `fish.json`(16종 표·크기·값) `fishing.json`(미끼·던지기·릴·낚싯대) `world.json`(하루·조명 색·날씨) `economy.json`(목표·판매·집 꾸미기·대회) `events.json`(갈매기·병·쪽지 10종·먼 바다·사진) `dialog.json`(NPC 대사) `save.json.example`(저장 칸) | `python tools/extract_godot_data.py`로 다시 만들 수 있음. 물고기 표·크기는 C# 코드를 읽어서 옮겨 적은 실수가 없음 |
| 섬 배치 (JSON) | `godot/data/scene.json` (물체 333개: 이름·부모·위치·회전·크기·FBX 출처·재질 이름·충돌 모양·조명) | 유니티에서 `-executeMethod GodotExport.Dump` (`fish game/Assets/Editor/GodotExport.cs`) |
| 효과음 15개 (WAV) | `godot/assets/audio/sfx/` : cast bite catch miss sell splash new_fish goal_done upgrade shutter chime voice_seagull voice_cat voice_merchant rain_loop | 코드가 숫자로 만들던 소리를 파일로 뽑음 (`GodotExport.DumpSfx`). 44100Hz 모노 14개 + 빗소리(22050Hz 4초, 이음새 없이 반복) 1개. **빗소리는 22050Hz라 고닷에서 두 배 빠르게 재생되지 않는지 확인할 것** |
| 에셋 모으는 스크립트 | `tools/export_assets_for_godot.py` (`--dry-run`으로 목록만 보기) | 아직 **실행 안 함**. 모델 36개·물고기 그림 16장·글꼴·BGM(16.5초만 잘라 ogg, 약 0.2MB)을 `godot/assets/`로 복사 |
| 이 문서 | `docs/GODOT_PORT.md` | |

기획의 기준은 계속 `docs/GDD.md`예요. 고닷으로 옮겨도 규칙은 안 바뀌고, 숫자는 위 JSON이 코드와 같아요.

## 2. 시작 전에 정할 것
**정함(2026-10-19)**: 언어 = **GDScript**(사용자 선택). 고닷 = **4.7.2 정식판**(바탕 화면 `Godot_v4.7.2-stable_win64.exe` 폴더, 명령줄용은 같은 폴더의 `…_console.exe`). 렌더러 = **GL Compatibility**(`godot/project.godot`에 설정). 프로젝트 폴더 = `godot/` (고닷에서 "가져오기"로 열기).

아래는 처음에 적어 둔 판단 근거예요(남은 확인 거리는 3·4번).
1. **언어**: GDScript(고닷 전용, 웹 내보내기 가능)와 C#. 제가 아는 범위로는 고닷 4의 C# 프로젝트는 웹으로 내보낼 수 없어서 **웹이 목표면 GDScript를 권해요.** 시작할 때 최신 고닷 문서로 꼭 다시 확인(제 지식은 최신이 아닐 수 있음).
2. **고닷 버전**: 시작하는 날의 최신 안정판 4.x. 설치 후 `godot --version` 기록.
3. **렌더러**: 웹은 호환성(Compatibility) 렌더러만 쓸 수 있다고 알고 있어요(확인 필요). 그림자·안개·후처리가 유니티 URP보다 약할 수 있어서, 첫 단계에서 섬 한 장면을 웹에서 띄워 보고 분위기가 유지되는지 사용자와 확인.
4. **하늘·바다**: 유니티는 직접 짠 셰이더(SkyGradient, Sea)예요. 고닷 셰이더 언어로 다시 써야 해요(색 값은 `world.json`에 다 있음).

## 2-1. 1단계 결과 (2026-10-19)
빈 장면(섬 모델 + 주아 글꼴 + 마우스 잠금 표시)을 웹으로 내보내 앱 안 브라우저에서 열어 확인했어요.

| 항목 | 고닷 4.7.2 (1단계 시험 장면) | 유니티 (현재 게임) |
|---|---|---|
| 엔진 코드(wasm) 압축 후 | 약 6.9MB (원본 39.5MB) | 약 12.0MB |
| 전체 압축 후 | 약 10.2MB (데이터 3.2MB 포함: 모델·그림·글꼴·BGM 전부) | 약 21.9MB (BGM 4.2MB·글꼴 2.1MB 포함) |
| **Vercel에서 실제 전송(측정)** | **약 12.9MB** (wasm 9.55MB + 데이터 3.32MB + js 0.07MB, 모두 brotli) | 약 21.9MB (이미 압축된 파일 그대로) |
| 로딩 | 몇 초 안에 뜸 | 20초 안팎 |

위 두 줄은 `brotli -q 11`로 잰 값이고, 굵게 쓴 줄이 Vercel에 올려서 `Accept-Encoding: br`로 받아 본 실제 전송 크기예요(고닷 시험 주소 `https://fishing-game-godot.vercel.app`). Vercel은 압축을 덜 세게 해서 wasm이 6.9MB가 아니라 9.55MB로 전송돼요. 게임이 커지면 데이터 쪽이 늘어나요.

- **웹 내보내기**: 내보내기 템플릿은 4.7.2 정식판의 웹용 8개만 `%APPDATA%\Godot\export_templates\4.7.2.stable\`에 설치했어요(공식 파일 체크섬 확인). 프리셋은 `godot/export_presets.cfg`(Web, 스레드 끔 → 특별한 서버 설정 없이 Vercel에서 돌아감). 내보내기 명령: `godot --headless --path godot --export-release "Web"` → `C:\Users\qudrh\fishing-game-build\godot-web\`(저장소 밖).
- **글꼴 함정(중요)**: 주아에는 `· … — × →` 같은 기호가 없어요. 웹에는 시스템 대체 글꼴이 없어서 네모(□)로 나왔어요. 해결: `jua.fallbacks = [ThemeDB.fallback_font]`(고닷 기본 글꼴을 대체로) → `· … —`은 나와요. 유니티 UI 문자열이 쓰는 비한글 기호는 `—` `·` `…` 세 가지뿐이라 충분해요. `→ ♪ ✓ ▶ ₩`는 여전히 안 나오니 새로 쓰지 말 것(★은 주아에 있음). **모든 글꼴 설정(테마)에 이 대체 글꼴을 붙일 것.**
- **마우스 잠금**: 첫 클릭 이벤트는 받고 `Input.mouse_mode = CAPTURED`를 요청해요. 브라우저가 잠금을 거절해도(앱 안 브라우저) 게임은 멈추지 않고 오류만 로그에 남아요 → 유니티처럼 따로 막을 필요가 없어요. 단, 잠금이 실제로 되는지는 진짜 크롬에서 확인 전(앱 안 브라우저는 잠금 미지원).
- **1단계에 남은 것**: 진짜 크롬에서 마우스 잠금·소리·로딩 확인(사용자 확인 대기). Vercel 실제 전송 크기는 확인함.
- **배포**: 시험 장면은 새 Vercel 프로젝트 `fishing-game-godot`(scope `bottlepipe`)로 올렸어요. 기존 유니티 주소(`fishing-game-web`)는 그대로. 올리는 법: 빌드 폴더(`fishing-game-build/godot-web`)에서 `npx vercel deploy --prod --yes --scope bottlepipe`. 처음 연결할 때 `vercel link`가 만드는 `.env.local`(인증 토큰)은 올라가지 않게 지울 것.

## 2-2. 2단계 결과 (2026-10-19): 섬·이동·하늘·바다
유니티와 **같은 자리에서 찍은 사진**과 나란히 비교하며 맞췄어요(유니티 기준 사진은 `ScreenShot.Run`, 고닷 사진은 `godot --path godot --write-movie 파일.png --fixed-fps 10 --quit-after 6 -- --cam=a`; 카메라 키는 유니티 사진 시험의 a~j와 같음).
- **섬 놓기**(`scripts/world.gd`): `data/scene.json`의 켜진 물체 중 FBX가 있는 262개를 같은 자리에 놓음(`_Temp` 임시 도형은 꺼져 있어서 건너뜀). 위치는 z 부호 반전, 회전은 쿼터니언 `(x,y,z,w)→(-x,-y,z,w)`, **모델에는 Y축 180도 보정**(`MODEL_FIX`)을 곱함 — 이걸 빼면 모델이 뒤를 봄(햄스터 얼굴로 확인). 색은 FBX 안의 색이 아니라 유니티 `.mat`의 색을 쓰므로 `tools/extract_materials.py`로 뽑은 `data/materials.json`을 재질 이름(Mat_Grass 등)으로 맞춰 입힘(재질 56개, 안 맞는 이름 0개).
- **충돌**: 유니티의 충돌 모양(메시·캡슐·상자·구)을 같은 모양으로 만듦. 바다는 이름이 `Sea`인 300x300 판(높이 -0.1)이라서 나중에 낚싯줄 찌가 바다인지 땅인지 이름으로 가름.
- **플레이어**(`scripts/player.gd`): 속도 4, 마우스 감도 0.1도/픽셀, 중력 20, 캡슐 반지름 0.35·높이 1.8(유니티 CharacterController와 같음), 시야각 **60도**(고닷 기본 75도라서 따로 맞춤). **계단 올라서기 0.4**: 모래 끝(-0.06)에서 부두 바닥(0.3)까지 0.36 턱이 있어서 필요(유니티는 계단 0.3 + 몸 표면 여유 0.08). 시험: 오두막 앞벽에서 막힘, 부두에 올라섬, 바다 판 위를 걸을 수 있음(유니티와 같음).
- **하늘·바다 셰이더**(`shaders/sky.gdshader`, `shaders/sea.gdshader`): 유니티 코드를 그대로 옮김(그라데이션 하늘·해·별·달, 깊이 색·물결·해안 거품·반짝임). 색은 `scripts/atmosphere.gd`가 전역 셰이더 값으로 넣음 → **3단계에서 낮·노을·밤 look을 섞어 `apply_look()`에 넣으면 됨**.

### 색을 맞추며 알게 된 것 (3단계 이후에도 중요)
- **빛 세기**: 고닷은 빛 세기에 내부적으로 π를 곱해서 같은 숫자면 유니티보다 훨씬 밝아요. 유니티 해 세기 2.0 → 고닷 약 0.72(`sun_energy_per_intensity` 0.36), 주변광은 0.1. 이 값 근처가 아니면 풀이 하얗게 날아가요.
- **셰이더 전역 색**: 유니티의 하늘·바다 색은 sRGB→선형 변환 없이 그대로 쓴 값처럼 보여서, 고닷에서도 변환 없이 넣었더니 같은 색이 나왔어요(변환하면 바다가 너무 진해짐).
- **톤매핑**: 유니티는 중립(Neutral)인데 고닷에서는 AgX(`tonemap_mode=4`)가 가장 비슷. Linear/Filmic/ACES는 색이 날아가거나 변함.
- **채도**: 유니티 채도 +14에 맞추면 풀·벽이 덜 진하고, 올리면 하늘·바다가 너무 진해짐 → 1.25로 타협.
- **안개**: 유니티는 지수 제곱(밀도 0.010)인데 고닷은 지수만 있고 같은 숫자로는 훨씬 뿌예서 0.001로 맞춤. 바다는 셰이더가 유니티 식 그대로 직접 계산(0.010).
- **남은 색 차이**: 지붕이 유니티보다 조금 밝고(251 대 208), 먼 바다가 약간 어두움(49 대 69). 풀·모래·하늘은 거의 같음. 사용자 눈으로 보고 거슬리면 조정.
- 시험 명령줄 옵션(`-- --cam=a --look=night --tm= --energy= --amb= --sat= --con= --fd= --spec= --refl= --fog=0 --pos=x,z --walk=좌우,앞뒤 --log=1 --probe=x1,x2,z`)은 `scripts/main.gd`에 남겨 둠.
- **걷기 덜컹거림 수정(2026-10-19, 사용자 제보 "전진할 때 너무 덜컹거린다")**: 계단 올라서기 판정이 바닥의 작은 요철도 "벽"으로 착각해 0.4m씩 올라섰다 떨어졌음(높이 1.07~1.9로 튐). 막힌 면의 기울기가 수직에 가까울 때(`normal.y < 0.3`)만 올라서도록 고치고, 내려올 때 바닥에 붙도록 `floor_snap_length`를 줌 → 평지 높이 0.99~1.01로 안정. 모니터 주사율이 60Hz보다 높을 때를 위해 물리 보간(`physics/common/physics_interpolation=true`)도 켬. **교훈**: `KinematicCollision3D`에는 `get_normal()`이 있고 `get_collision_normal()`은 없음. 스크립트 오류가 물리 함수 안에서 나면 그 프레임의 이동이 통째로 멈추므로, 시험 때 `grep SCRIPT ERROR` 개수를 꼭 볼 것.
- **성능**: 모델 262개 + 그림자로 웹에서 fps가 어떤지 아직 모름(앱 안 브라우저는 느려서 못 잼) → 진짜 크롬에서 확인 필요.

## 2-3. 작업 방식 규칙: 창을 띄우지 않기 (사용자 요청 2026-10-19)
고닷으로 사진을 찍을 때 창이 켜졌다 꺼지면 작업 중인 사용자에게 방해가 돼요. **사진은 반드시 `--no-window`로** 찍어요: `godot --no-window --path godot --write-movie 파일.png --fixed-fps 10 --quit-after 6 -- --cam=a` (창이 생기지 않고도 화면이 제대로 그려짐, 색 값으로 확인함). 그 밖의 검사(스크립트 오류, 걷기, 내보내기, 가져오기)는 `--headless`. `--write-movie`만 단독으로 쓰면 창이 뜨니 쓰지 말 것. 사용자가 직접 열어 둔 고닷 편집기는 건드리지 않음.

## 2-4. 3단계 결과 (2026-10-19): 시간대·날씨
- **시간대**(`scripts/time_of_day.gd`): 하루 600초, 키프레임 [0,210,270,330,390,570,600]의 look(낮·낮·노을·노을·밤·밤·낮)을 smoothstep으로 섞어 매 프레임 `Atmosphere.apply_look(look, overcast)`에 넣음. 시간대(낮 <240, 노을 <360, 밤)와 밤 정도(별)는 `TimeOfDay.period`, `TimeOfDay.night`(정적 변수)로 읽음 → 4단계 낚시가 `TimeOfDay.period`를 씀. 시간은 `delta`로 세므로 `get_tree().paused`면 멈춤.
- **날씨**(`scripts/weather.gd`): 맑음→{맑음 .4, 흐림 .6}, 흐림→{맑음 .4, 흐림 .2, 비 .4}, 비→{흐림 .7, 비 .3}, 70~130초마다 바뀜, 10초에 걸쳐 천천히 따라감. 흐림이면 하늘·안개·바다를 회색빛으로(유니티와 같은 식, `Atmosphere.apply_look`). 비는 `CPUParticles3D`(웹에서 안전), 빗소리는 `rain_loop.wav` 볼륨 0.06(별로면 `RAIN_SOUND_VOLUME`을 0으로).
- **시험용 명령줄**: `--clock=초`(0 낮, 300 노을, 450 밤), `--weather=clear|cloudy|rain`.
- **유니티 사진과 비교(같은 자리 a 구도)**: 밤은 풀·하늘·바다 색이 거의 같음, 흐림·비도 하늘과 바다가 가까움. 낮·노을은 하늘이 유니티보다 약간 밝음(하늘 윗부분 179 대 157 등). 노을의 풀이 유니티보다 노랗고 그림자가 긺.
- **색 맞추기에서 알게 된 것**: ① 고닷은 **전역 색 변수를 받을 때 sRGB→선형 변환을 자동으로** 함(처음엔 모르고 밤 하늘·바다가 값의 제곱만큼 어두워짐). 유니티 셰이더 색은 사진에 맞추면 "값의 약 1.3제곱(선형)"으로 보여서 `Color(pow(값,1.3)).linear_to_srgb()`로 넣음(`Atmosphere.color_power`, 시험 `--cp=`). ② **주변광**도 유니티는 색 값을 그대로 선형으로 쓰는 것처럼 보여서 `linear_to_srgb()`로 넣고 세기 1.0, 대신 해 세기는 유니티 2.0 → 고닷 0.16(`sun_energy_per_intensity` 0.08)로 크게 낮춤(주변광이 크기 때문). 이렇게 해야 밤이 유니티처럼 보임.
- **못 한 것**: 낮·노을 색을 더 줄이는 미세 조정(`color_power` 1.3~1.9를 5개 장면 합계 차이로 고르려던 비교가 사용자 요청으로 중단됨). 밤의 반딧불, 구름 흐름, 풀·야자 흔들림은 아직 없음(장식 단계에서).

## 3. 유니티 → 고닷 대응표
| 유니티에서 | 고닷에서 |
|---|---|
| 스스로 만들어지는 `[RuntimeInitializeOnLoadMethod]` 싱글톤(ResultCard, Weather, SeaEvents, HomeDecor, FarSea, PhotoMode, Contest …) | **Autoload**(프로젝트 설정에 등록하는 전역 노드) 또는 메인 장면 아래 노드 |
| `Time.timeScale = 0` (대화창·도감 중 시간 멈춤) | `get_tree().paused = true` (UI 노드는 `process_mode = ALWAYS`) 또는 `Engine.time_scale`. 시간을 세는 코드는 `delta`를 쓰고 멈춤에 반응하게 |
| `Cursor.lockState` | `Input.mouse_mode = MOUSE_MODE_CAPTURED / VISIBLE` |
| `Physics.Raycast` (던진 찌가 바다인지 땅인지) | `PhysicsDirectSpaceState3D.intersect_ray` |
| `CharacterController` | `CharacterBody3D` + `move_and_slide` |
| `PlayerPrefs`·save.json (`SaveData`) | `FileAccess`로 `user://save.json` (웹은 브라우저 저장소에 자동으로 저장됨) |
| UGUI `Canvas`·`Text` | `CanvasLayer` + `Control` 노드, 테마(Theme)에 크림색 판·주아 글꼴 |
| 입자(비, 물보라, 반딧불) | `GPUParticles3D` 또는 `CPUParticles3D` (웹에서는 CPU 쪽이 안전할 수 있음 → 시험) |
| `LineRenderer` (낚싯줄) | 늘 두 점을 잇는 가는 `MeshInstance3D`(`ImmediateMesh`) |
| 전역 셰이더 값(`Shader.SetGlobalColor`) | 전역 셰이더 변수(`RenderingServer.global_shader_parameter_set`) |
| `Resources.Load` | `preload()` / `load()` |
| 코드로 만든 효과음 `SfxSynth` | **이미 WAV로 뽑아 둠**(`godot/assets/audio/sfx/`). `AudioStreamPlayer` 하나로 재생 |
| 모델 재질 이름 `C_RRGGBB`를 읽어 색 입히기 | 고닷은 FBX 재질을 그대로 읽으니, 색이 필요한 곳(구름 재질 복사·장식 색)만 이름 규칙대로 처리 |
| 유니티 WebGL 템플릿 `WebGLTemplates/FishingIsland` | 고닷 웹 내보내기의 사용자 정의 HTML 셸. 지금 `index.html`·`style.css`의 하늘/크림 디자인·로딩 카드·"PC에서 플레이" 안내를 옮김 |
| 사진 저장(`PhotoDownload.jslib`) | 고닷 `JavaScriptBridge`로 브라우저 다운로드 |

**좌표**: 유니티는 왼손 좌표계, 고닷은 오른손(앞이 −Z)이에요. 위치는 보통 z 부호를 뒤집어서 옮기고, 회전은 눈으로 맞춰 가며 확인해요(`scene.json`은 유니티 세계 좌표 그대로). 모델(FBX)은 고닷이 알아서 가져오니 위치만 틀어지지 않았는지 첫 단계에서 한 번 확인.

## 4. 시스템별 옮길 목록 (유니티 스크립트 → 핵심 규칙이 있는 곳)
| 시스템 | 유니티 파일 | 규칙·숫자 |
|---|---|---|
| 이동·시점 | PlayerController | `scene.json`의 Player, 속도 4, 마우스 감도 0.1°/px, 중력 −20. 시작 위치 (0, 1.1, 0), 눈높이 1.8 |
| 낚시 | FishingRod, Bait | `fishing.json`. 던지기→물 위면 입질 대기→느낌표→클릭→릴 감기. 던지는 중(0.8초)엔 클릭 무시, 대기 중엔 클릭이 회수 |
| 물고기·도감·인벤토리 | Fish, Collection, Inventory | `fish.json`. 도감 기록은 (잡은 수, 최고 cm) |
| 저장 | SaveData | `save.json.example`. 옛 저장도 읽기, 모자란 칸은 0 |
| 시간대·하늘·바다 | TimeOfDay (+하늘·바다 셰이더) | `world.json` |
| 날씨 | Weather | `world.json` weather. 비는 흐림을 거쳐서만 옴 |
| NPC·대화 | ShopNPC, TalkNPC, DialogView | `dialog.json`. 3m 안에서 바라보고 E. 열려 있는 동안 시간 정지 |
| 상점·낚싯대·집 꾸미기 | ShopNPC, DecorShop, HomeDecor, RodUpgrade | `economy.json`, `fishing.json` rods. 꾸미기 창은 상점에서 F, 키 1~6 |
| 먼 바다 | FarSea | `events.json` far_sea. 배 위치 두 곳, 화면 페이드 0.5초, 이동 중 입력 막음 |
| 갈매기·병·쪽지 | SeaEvents | `events.json` |
| 오늘의 목표·낚시 대회 | Goal, Contest | `economy.json`. 대회는 바틀이 대화 중 C |
| 사진 | PhotoMode | `events.json` photo. P, 화면 UI는 한 프레임 숨김 |
| 화면 UI | HudPanel, GuideHint, CatalogUI, ResultCard, MuteToggle, UiTheme, GameFont | 크림색 둥근 판(알파 0.92) + 진한 갈색 글자(0.33,0.23,0.16), 글꼴 주아. GDD 9번. 상태창 5줄(시간+날씨, 미끼, 돈, 도감 n/16, 목표) |
| 소리 | Sfx, BgmPlayer, MuteToggle | BGM은 앞 16.5초 반복(볼륨 0.2, 이음새 0.5초 페이드). M으로 음소거 |
| 장식 효과 | Fireflies, FishShadows, CloudDrift, WindSway, SplashFx, RodLook | 밤에 반딧불, 물 속 물고기 그림자, 구름 흐름, 풀·야자 흔들림, 물보라, 낚싯대 3종 |
| 웹 | WebReady, PhotoDownload.jslib, WebGLTemplates | 첫 몇 프레임 뒤에 로딩 화면을 걷음. 웹에서 첫 클릭은 시작(마우스 잠금)만 |

## 5. 옮기는 순서 (제안, 각 단계 끝에 사용자가 직접 플레이 → 다음 단계)
0. 고닷 설치, 새 프로젝트 만들고 `godot/data`·`godot/assets`를 넣음(`export_assets_for_godot.py` 실행).
1. **빈 장면을 웹으로 내보내 Vercel에 올려 보기**: 마우스 잠금, 한글 글꼴(주아), 로딩 속도, 파일 크기를 먼저 확인. 여기서 "고닷이 기대만큼 가볍다"가 확인돼야 계속 진행.
2. 섬 장면(`scene.json` 배치)과 이동·시점, 하늘·바다 셰이더.
3. 시간대·조명·날씨.
4. 낚시(던지기·입질·릴)와 결과 카드.
5. 도감·인벤토리·판매·저장.
6. NPC·대화·상점·낚싯대 업그레이드.
7. 집 꾸미기, 병·갈매기, 먼 바다.
8. 사진, 낚시 대회, 효과음·BGM, 오늘의 목표.
9. 웹 페이지 틀(BOTTLE ISLAND 디자인)과 배포, 공개 주소 교체.

## 6. 이번 프로젝트에서 겪은 함정 (고닷에서도 피할 것)
- **전역 시간 설정이 저장되어 게임이 멈춘 채 시작했던 일**(유니티 `TimeManager`의 `m_TimeScale: 0`이 단계 23부터 커밋돼 있었음). 시험 코드가 시간·일시정지 같은 전역 값을 건드리면 설정에 남을 수 있어요. 고닷에서도 시작할 때 일시정지·시간 배율을 한 번 되돌려 놓고, 커밋 전에 `project.godot` 변경을 확인.
- **웹 첫 클릭**: 브라우저는 클릭 없이 마우스를 잠글 수 없어요. 첫 클릭을 시작으로만 쓰고(던지기와 분리), 잠금 요청이 거절돼도 게임이 멈추지 않게.
- 화면에 그리는 UI 사진 시험이 어려웠어요(오버레이는 카메라로 찍히지 않음). 고닷에서는 처음부터 화면 캡처로 확인할 방법을 정해 둘 것.
- 웹에서 확인 못 하는 것: 클릭·소리·사진 저장·배 이동은 사용자가 직접 플레이해서 확인.
- **웹 증상 재현법**: 빌드 폴더를 `python -m http.server`로 열고, Claude 앱 안 브라우저에서 콘솔 로그(`print`)를 읽으면 정확해요. 화면은 갱신이 느려 믿을 수 없고 마우스 잠금은 지원되지 않아요.
- 확률·값은 정수로(`p*3/2`), 저장 칸 순서는 절대 바꾸지 않기(물고기는 맨 뒤에만 추가).
- 새 물고기 3D 대신 그림(PNG)+도감 칸이에요. 물고기 그림 파일 이름은 `Fish_번호_영문이름.png`.

## 7. 기록 규칙은 그대로
`CLAUDE.md` 규칙(GDD 먼저, 한 번에 기능 하나, 검수는 다른 에이전트, `changelog/`·`review/` 기록, 쉬운 한국어 짧게)을 고닷 작업에도 그대로 써요. 고닷 작업 기록은 `changelog/`에 새 날짜 파일로 시작하고, 검수 파일은 `review/`에 `godot_stepN_…` 이름으로.

## 8. 아직 확인 안 한 것
- 고닷 4.7.2에서 `--import`로 WAV 15개를 가져오기까지는 오류 없이 됐어요(빗소리는 반복 재생 `loop_mode=2`로 설정). **소리가 제 속도로 나는지(빗소리 22050Hz가 두 배 빠르지 않은지)**와 JSON을 GDScript에서 읽는 것은 아직 확인 전이에요. 1단계에서 같이 확인하세요.
- 고닷 웹 빌드 크기가 유니티(약 21MB)보다 실제로 얼마나 작은지는 측정 전이에요.
