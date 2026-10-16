# 고닷(Godot) 포팅 준비 노트 (2026-10-16)

BOTTLE ISLAND를 유니티에서 고닷으로 옮길 때 보는 문서예요. **오늘은 밑작업만 했어요(코드 이식은 안 함).** 이유(사용자): 웹 로딩이 무겁고, 유니티 사용·용량·라이선스가 걱정돼서.
옮기는 동안에도 유니티 버전이 공개 주소(https://fishing-game-web.vercel.app)에서 계속 돌아가요. 고닷 버전이 같은 수준이 되기 전에는 바꾸지 않아요.

## 1. 밑작업으로 만들어 둔 것
| 무엇 | 어디 | 비고 |
|---|---|---|
| 게임 숫자·글 (JSON) | `godot/data/` : `fish.json`(16종 표·크기·값) `fishing.json`(미끼·던지기·릴·낚싯대) `world.json`(하루·조명 색·날씨) `economy.json`(목표·판매·집 꾸미기·대회) `events.json`(갈매기·병·쪽지 10종·먼 바다·사진) `dialog.json`(NPC 대사) `save.json.example`(저장 칸) | `python tools/extract_godot_data.py`로 다시 만들 수 있음. 물고기 표·크기는 C# 코드를 읽어서 옮겨 적은 실수가 없음 |
| 섬 배치 (JSON) | `godot/data/scene.json` (물체 333개: 이름·부모·위치·회전·크기·FBX 출처·재질 이름·충돌 모양·조명) | 유니티에서 `-executeMethod GodotExport.Dump` (`fish game/Assets/Editor/GodotExport.cs`) |
| 효과음 14개 (WAV) | `godot/assets/audio/sfx/` : cast bite catch miss sell splash new_fish goal_done upgrade shutter chime voice_seagull voice_cat voice_merchant rain_loop | 코드가 숫자로 만들던 소리를 파일로 뽑음 (`GodotExport.DumpSfx`). 44100Hz 모노, 빗소리만 22050Hz 4초(이음새 없이 반복) |
| 에셋 모으는 스크립트 | `tools/export_assets_for_godot.py` (`--dry-run`으로 목록만 보기) | 아직 **실행 안 함**. 모델 36개·물고기 그림 16장·글꼴·BGM(16.5초만 잘라 ogg, 약 0.2MB)을 `godot/assets/`로 복사 |
| 이 문서 | `docs/GODOT_PORT.md` | |

기획의 기준은 계속 `docs/GDD.md`예요. 고닷으로 옮겨도 규칙은 안 바뀌고, 숫자는 위 JSON이 코드와 같아요.

## 2. 시작 전에 정할 것 (아직 안 정함 → 시작할 때 사용자에게 물어볼 것)
1. **언어**: GDScript(고닷 전용, 웹 내보내기 가능)와 C#. 제가 아는 범위로는 고닷 4의 C# 프로젝트는 웹으로 내보낼 수 없어서 **웹이 목표면 GDScript를 권해요.** 시작할 때 최신 고닷 문서로 꼭 다시 확인(제 지식은 최신이 아닐 수 있음).
2. **고닷 버전**: 시작하는 날의 최신 안정판 4.x. 설치 후 `godot --version` 기록.
3. **렌더러**: 웹은 호환성(Compatibility) 렌더러만 쓸 수 있다고 알고 있어요(확인 필요). 그림자·안개·후처리가 유니티 URP보다 약할 수 있어서, 첫 단계에서 섬 한 장면을 웹에서 띄워 보고 분위기가 유지되는지 사용자와 확인.
4. **하늘·바다**: 유니티는 직접 짠 셰이더(SkyGradient, Sea)예요. 고닷 셰이더 언어로 다시 써야 해요(색 값은 `world.json`에 다 있음).

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
- 고닷이 이 컴퓨터에 설치돼 있지 않아서, JSON·WAV·스크립트가 고닷에서 실제로 잘 읽히는지는 **확인하지 못했어요**(WAV 길이·샘플 속도, JSON 형식은 확인함). 1단계(빈 장면 웹 시험)에서 같이 확인하세요.
- 고닷 웹 빌드 크기가 유니티(약 21MB)보다 실제로 얼마나 작은지는 측정 전이에요.
