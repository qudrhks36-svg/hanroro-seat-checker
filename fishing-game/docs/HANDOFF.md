# 다른 PC에서 이어 하기 (2026-10-20 기준, 마지막 커밋 뽀로)

## 준비
- **Godot 4.7.2 (GL Compatibility)**: 포팅 프로젝트는 `godot/`. 일반 exe로 열면 됨(콘솔 exe는 창이 떠서 쓰지 않음). 내보내기 템플릿 4.7.2 설치 필요(웹).
- Unity **6000.3.26f1** (Hub에서 설치, WebGL 모듈 포함). 프로젝트 폴더: `fish game/`. Library는 처음 열 때 다시 만들어져요(몇 분).
- 블렌더 5.2 (모델 만들 때만). 스크립트는 `blender/make_*.py`, 작업 파일은 `blender/fishing_island.blend`.
- 규칙·기획의 기준: `CLAUDE.md`, `docs/GDD.md`. 클로드에게 "CLAUDE.md, GDD.md, docs/HANDOFF.md, changelog/2026-10-12.md 읽고 이어서 해줘"라고 하면 돼요.

## 현재 상태 (2026-10-20 갱신: 고닷판에 풀섬·3인칭 추가, 공개 주소 반영)
- **공개 주소 https://fishing-game-web.vercel.app = 고닷판 최신(커밋 `950147f`까지)**. 시험 주소 fishing-game-godot.vercel.app도 같은 빌드. 푸시는 사용자가 직접(로컬 커밋이 쌓여 있음).
- **10~11단계(포팅 뒤 추가, 모두 사용자 플레이 확인)**: 집 안·잠자기·옷장, 미니 농장, NPC 대사·친밀도·부탁, 둥근 모델(블렌더 `round_models.py`·`make_cabin.py`), 끊김 없는 BGM, 창 닫은 뒤 클릭 없애기. 기록은 `changelog/2026-10-12.md`.
- **옆 섬 "풀섬"(GDD 8번, 4단계 모두 끝)**: ① 섬·나무다리(32m)·연못·나무·꽃 `scripts/meadow.gd` ② 동물 4마리 쓰다듬기·선물 `animals.gd`+`data/animals.json` ③ 과일나무 열매 따기(사과·귤·복숭아, 하루 뒤 다시 열림) `fruit_trees.gd`, 열매는 `farm.json`의 `"fruit":true`로 작물 가방·판매·선물에 붙음 ④ 연못 낚시: 연못("Pond" 충돌)에서 민물고기 4종(`fish.json` 17~20, 그림은 `blender/make_fish.py`), 도감 20종 5줄.
- **3인칭 시점(GDD 8번, 1~5단계 끝)**: 화면 카메라 `player.view`는 어깨 뒤, 판정용 보이지 않는 눈 `player.cam`은 그대로(조준·E·말 걸기 모두 눈 기준). 몸 `player_body.gd`(옷장 옷, 0.8배, 걷는 방향으로 돌고 다리 흔들림), 팔·낚싯대는 `outfit_view.gd`/눈 아래. 몸이 카메라와 35도 넘게 어긋나면 낚싯대·팔 숨김. 시험 `--fpv=1` = 옛 1인칭.
- **크기 줄이기**: `godot/data/scale.json`(길 이름 앞부분 → 배율, 숫자 또는 [x,y,z])을 `world.gd` `scale_of`가 적용: NPC 0.85, 야자수·덤불·꽃 0.8, 집 0.8, 부두는 길이 그대로 폭·높이 0.8 등. 집을 줄이면 `cabin.gd`(문 자리)·`home_decor.gd`(`CAB_K`, `_cab()`)도 같이 맞춰야 함.
- **병 속 이야기 편지**(GDD 8번): `story.gd`+`data/story.json`(스포일러, 사용자가 스포 없이 플레이하길 원해 플레이 전엔 열지 말 것). 일반 쪽지 3장 후 리본 병, 12통, 챕터 끝 답장(1~3), 하루 뒤 다음 병. 시험 `--storytest=1`.
- **눈 섬 주민 뽀로**(펭귄 상인, 5번째 주민): `dialog.json` 5번째 항목, `snow_island.gd` `_build_penguin`, 물고기 ×1.25로 사 줌, `Game.friend`·`quests` 5칸. 시험 `--npc=4`.
- **섬 여행 1단계 눈 섬**(GDD 8번): `snow_island.gd`·`island_trip.gd`(부두 북쪽 배, 낚싯대 1단계 필요), 얼음 호수 낚시 물고기 4종(`fish.json` 21~24 `"ice":true`), `Game.spots`로 연못·호수 조준 보조. 시험 `--trip=1|2|3 --rodlevel=1`.
- 아직 못 한 것·후보: 방 가구 늘리기, 농장 확장, 땅(섬·바다)·울타리·집 안 방 크기 줄이기, 풀섬 나무·풀 바람 흔들림(`life.gd`), 동물·열매 블렌더 모델. 크롬에서 3인칭 카메라 거리·낚싯대 숨김 방식·다리 흔들림 느낌은 사용자 확인 중.
- ⚠ `tools/export_assets_for_godot.py`를 다시 돌리면 `godot/assets/models/`의 둥글게 만든 모델(Palm·Cabin·Pier·Boat·Props/*)이 유니티 원본으로 덮여요. 돌리지 말 것(필요하면 `blender/round_models.py`·`make_cabin.py`로 다시 내보내기).

## 이전 상태 (2026-10-19, 고닷 포팅 완료 시점)
- **공개 주소 https://fishing-game-web.vercel.app 은 이제 고닷판**이에요(9단계 끝, 사용자가 크롬에서 확인 후 교체). 유니티판은 https://fishing-game-rb0zr6mcu-bottlepipe.vercel.app 에 남아 있어요(되돌리려면 Vercel `fishing-game-web` 프로젝트에서 그 배포를 운영으로 올림). 시험용 고닷 주소 https://fishing-game-godot.vercel.app 도 그대로.
- **고닷 포팅 1~9단계 모두 끝**: 섬·이동·하늘·바다, 시간대·날씨, 낚시, 도감·결과 카드·상태창·저장, NPC·대화·낚싯대 업그레이드, 설정 창(마우스 감도), 먼 바다·병 쪽지·갈매기·집 꾸미기, 오늘의 목표·낚시 대회·사진·BGM·음소거·물보라·반딧불·구름·바람, 웹 페이지 틀. 각 단계 결과와 시험 방법은 `docs/GODOT_PORT.md` 2-1~2-11, 변경 기록은 `changelog/2026-10-12.md`(고닷 1~9단계).
- 고닷 저장 칸은 유니티와 같아서 옛 저장이 읽혀요(`mouseSens`만 고닷이 더함).
- 아직 못 한 것: 푸시는 사용자가 직접(커밋이 로컬에 쌓여 있음), 고닷 웹의 실제 fps·폰 안내는 사용자 크롬 확인 중. 새 기능 후보는 아래 그대로(GDD에 없음 → 정하기 전에 먼저 물어볼 것).
- 아래 "1~39단계…" 부터는 **유니티판** 기록이에요.
- 1~39단계 끝(모두 검수 통과, `review/`에 기록) + 버그 수정 2건. 기록은 `changelog/2026-10-12.md` 맨 아래 "버그 수정" 두 항목.
- 마지막 작업(2026-10-16): 웹에서 "시작하자마자 던지면 찌가 굳고 안 걷힘" 수정. 진짜 원인은 `ProjectSettings/TimeManager.asset`의 `m_TimeScale`이 0으로 저장돼 있던 것(단계 23부터). 1로 고치고 `PlayerController.Awake`에서도 `Time.timeScale = 1f`. 웹 첫 클릭은 시작(마우스 잠금)만 하도록 바꾸고, 마우스 잠금 거절 오류도 받아 넘김. 이 수정은 배포됐고 사용자가 새 빌드로 확인하는 중.
- 만들어진 것: 낚시(16종 도감·크기 기록), 시간대·날씨, 먼 바다 낚시터(배 이동), 오늘의 목표, 효과음·BGM, 낚싯대 3단계, 집 꾸미기·오두막 3단계, 병 쪽지·갈매기, 사진 찍기(P), 낚시 대회(바틀이에게서 C), 힐링 톤 화면(크림 판 + 주아 글꼴), 웹 페이지(BOTTLE ISLAND).
- 사용자가 직접 플레이해서 확인한 마지막 단계: 39단계(낚시 대회) — "괜찮더라". 위 버그 수정은 배포만 했고 사용자 확인은 아직.
- 다음 새 기능 후보(아직 정하지 않음, GDD에 없음 → 정하기 전에 먼저 물어볼 것): 새 장소 / 요리와 보상 / 미끼 만들기.
- 다듬기에서 정한 것: 가격은 먼 바다 물고기만 1.5배, 확률·크기는 그대로. 빗소리가 별로면 `Weather.RainSoundVolume`을 0으로.

## 고닷 빌드·시험·배포
- **창 띄우지 않기(사용자 요청)**: 일반 exe를 `Start-Process -WindowStyle Hidden -Wait`로 `--headless --path godot --quit-after N --log-file <파일> -- --시험옵션`. `_console.exe`·`--write-movie`·`--no-window`는 창이 떠서 금지. 헤드리스는 그림을 못 그려서 화면 사진은 못 찍음.
- 시험 옵션(`scripts/main.gd` `_arg`): `--auto=1 --timescale=20 --freeze=1 --clock=초 --pos=x,z --yaw=도 --nosave=1 --npc=N --give=N --money=N --act=sell,rod --travel=1|2 --bottle=N --gull=1 --decorbuy=0,1,… --fcheck=1 --catalog=N --sens=X --goalcheck=1 --contest=cm,… --contestbest=N --ckey=1 --mute=1 --photosave=폴더 --lifecheck=1 --splashcheck=1 --weather=rain` 그리고 이후 추가: `--talktest=NPC --friend=NPC:점수 --givefish=번호:N --givecrop=번호:N --setquest=NPC:물고기:N --dex=N --rodlevel=N --cabin=enter,target,sleep,wear:N,exit --cabincheck=1 --farm=plant:i:c,water:i,day,harvest:i --farmcheck=1 --meadowcheck=초 --petcheck=초 --fruitcheck=1 --pondcheck=1 --bodycheck=초 --fpv=1 --smooth=도 등`. 테스트 중 저장 파일(`%APPDATA%\Godot\app_userdata\BOTTLE ISLAND\save.json`)이 생기니 끝나면 지울 것.
- 웹 내보내기: `--headless --path godot --export-release "Web"` → `../../fishing-game-build/godot-web`(저장소 밖). 설정은 `godot/export_presets.cfg`(스레드 끔, `data/*.json` 포함, `web/*` 제외, 캔버스 크기 정책 0 — 페이지 셸이 크기를 정함), 페이지 틀 `godot/web/shell.html`. `preview.png`는 내보내기가 복사 안 하니 `godot/web/preview.png`를 배포 폴더에 직접 복사.
- 화면 사진: 빌드 폴더를 임시 폴더에 복사해 `index.html`의 `"args":[]`를 `"args":["--","--pos=…","--yaw=…"]`로 바꾸고 `python -m http.server`로 연 뒤 앱 안 브라우저로 본다(창 안 뜸). 도감·집 안처럼 `paused`로 시작하는 옵션(`--catalog`)은 로딩 카드가 안 걷혀서 쓰지 말고 로딩 뒤 Tab 키를 누를 것.
- 시험 배포: `fishing-game-build/godot-web`에서 `npx vercel@latest deploy --prod --yes --scope bottlepipe`(프로젝트 `fishing-game-godot`).
- **공개 주소 배포**: 그 파일들(`index*`, `preview.png`)을 임시 폴더에 복사하고 `fishing-game-build/webgl/.vercel/project.json`을 `.vercel/`에 넣어 같은 명령으로 배포(프로젝트 `fishing-game-web`).
- Vercel 로그인이 풀리면 `npx vercel@latest login`을 사용자가 직접(브라우저 승인).
- 사용자에게 줄 터미널 명령은 PowerShell 문법으로.

## 유니티 빌드와 배포 (이전 공개판, 지금은 보관용)
- 웹 빌드: `Unity.exe -batchmode -quit -projectPath "…/fish game" -executeMethod WebBuild.Build -logFile …` → 결과 폴더는 저장소 밖(`fishing-game-build/webgl`, 새 PC에선 경로 확인). Unity 에디터가 같은 프로젝트를 열고 있으면 실패하니 먼저 닫을 것.
- 배포: `cd fishing-game-build/webgl && npx vercel deploy --prod --yes --scope bottlepipe` (이 PC에서 Vercel 로그인 필요). 링크: https://fishing-game-web.vercel.app
- **2026-10-16에 링크를 공개로 바꿨어요**(Vercel 로그인 보호 끔). BGM(monume)은 공개해도 된다고 사용자가 확인함. 다시 비공개로 하려면 Vercel 프로젝트 `fishing-game-web`의 Deployment Protection(Vercel Authentication)을 켜면 돼요.
- 저장소 푸시는 사용자가 직접: `git -C "…/fishing-game-repo/fishing-game" push origin claude/quirky-franklin-azysrm`.

## 주의
- **커밋 전에 `git diff -- "fish game/ProjectSettings"`를 볼 것.** 에디터에서 시험 코드를 돌리다 `Time.timeScale` 같은 전역 설정이 바뀐 채 저장되면 ProjectSettings에 섞여 들어가요(실제로 `m_TimeScale: 0`이 몇 단계 동안 커밋돼 있었음). 유니티가 건드린 `Settings/*.asset`, `GraphicsSettings.asset` 같은 줄바꿈만 바뀐 파일은 커밋하지 않아도 돼요.
- 웹 증상은 이 앱 안 브라우저로 재현할 수 있어요: 빌드 폴더를 `python -m http.server`로 열고, 콘솔에서 `Debug.Log` 출력을 읽으면 됨(화면은 갱신이 느려 믿을 수 없음, 로그가 정확). 마우스 잠금은 지원 안 됨.
- 저장소 루트(`fishing-game-repo`)는 다른 프로젝트와 같이 써요. `fishing-game/` 안의 파일만 커밋(`README.md docs changelog review blender tools godot "fish game/Assets" "fish game/ProjectSettings"`). `fish game/Assets/Resources/PerformanceTestRunInfo.json`은 빼기.
- 씬에 저장된 값은 C# 기본값보다 우선해요(예: 도감 그림 목록 `CatalogUI.fishSprites`, FishingRod 값).
- 화면 요소는 대부분 게임이 시작될 때 스스로 만들어져요(`[RuntimeInitializeOnLoadMethod]`). 장면에 올려 둔 게 없어요.
- 모델(FBX)은 `Assets/Resources/Models/`에 둬야 웹 빌드에 들어가요. 블렌더 (x,y,z)는 유니티에서 (x, z, −y). 재질 이름 `C_RRGGBB`를 읽어 색을 입혀요.
- 화면 사진 시험 도구: `fish game/Assets/Editor/ScreenShot.cs` (예: `-executeMethod ScreenShot.Contests`, 환경변수 `FG_OUT`=저장 폴더). 클릭·소리·사진 저장·배 이동은 자동으로 못 보므로 사용자가 직접 플레이해서 확인.
- 저장은 `SaveData`(웹은 브라우저 저장소). 새 저장 칸을 더해도 옛 저장은 안전하게 읽혀요.
- (고닷) 같은 경로 항목이 여러 개(풀·꽃)면 `world.nodes_by_path`는 마지막 하나만 남아요 → 항목의 `it["_node"]`를 쓸 것. (고닷) `await RenderingServer.frame_post_draw`는 화면 없는 실행에서 오지 않아 멈출 수 있어 쓰지 않음. 색은 전역 셰이더 색이 sRGB→선형으로 자동 변환되니 `pow(v,1.3)` 보정(`atmosphere.gd` 주석 참고).
