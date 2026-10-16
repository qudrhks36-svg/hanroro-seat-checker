# 다른 PC에서 이어 하기 (2026-10-16 기준)

## 준비
- Unity **6000.3.26f1** (Hub에서 설치, WebGL 모듈 포함). 프로젝트 폴더: `fish game/`. Library는 처음 열 때 다시 만들어져요(몇 분).
- 블렌더 5.2 (모델 만들 때만). 스크립트는 `blender/make_*.py`, 작업 파일은 `blender/fishing_island.blend`.
- 규칙·기획의 기준: `CLAUDE.md`, `docs/GDD.md`. 클로드에게 "CLAUDE.md, GDD.md, docs/HANDOFF.md, changelog/2026-10-12.md 읽고 이어서 해줘"라고 하면 돼요.

## 현재 상태
- 1~39단계 끝(모두 검수 통과, `review/`에 기록). 마지막 커밋 `7beeb80` (낚시 대회, 39단계). 기록은 `changelog/2026-10-12.md`.
- 만들어진 것: 낚시(16종 도감·크기 기록), 시간대·날씨, 먼 바다 낚시터(배 이동), 오늘의 목표, 효과음·BGM, 낚싯대 3단계, 집 꾸미기·오두막 3단계, 병 쪽지·갈매기, 사진 찍기(P), 낚시 대회(바틀이에게서 C), 힐링 톤 화면(크림 판 + 주아 글꼴), 웹 페이지(BOTTLE ISLAND).
- 사용자가 직접 플레이해서 확인한 마지막 단계: 39단계(낚시 대회) — "괜찮더라".
- 다음 새 기능 후보(아직 정하지 않음, GDD에 없음 → 정하기 전에 먼저 물어볼 것): 새 장소 / 요리와 보상 / 미끼 만들기.
- 다듬기에서 정한 것: 가격은 먼 바다 물고기만 1.5배, 확률·크기는 그대로. 빗소리가 별로면 `Weather.RainSoundVolume`을 0으로.

## 빌드와 배포
- 웹 빌드: `Unity.exe -batchmode -quit -projectPath "…/fish game" -executeMethod WebBuild.Build -logFile …` → 결과 폴더는 저장소 밖(`fishing-game-build/webgl`, 새 PC에선 경로 확인). Unity 에디터가 같은 프로젝트를 열고 있으면 실패하니 먼저 닫을 것.
- 배포: `cd fishing-game-build/webgl && npx vercel deploy --prod --yes --scope bottlepipe` (이 PC에서 Vercel 로그인 필요). 링크: https://fishing-game-web.vercel.app
- **2026-10-16에 링크를 공개로 바꿨어요**(Vercel 로그인 보호 끔). BGM(monume)은 공개해도 된다고 사용자가 확인함. 다시 비공개로 하려면 Vercel 프로젝트 `fishing-game-web`의 Deployment Protection(Vercel Authentication)을 켜면 돼요.
- 저장소 푸시는 사용자가 직접: `git -C "…/fishing-game-repo/fishing-game" push origin claude/quirky-franklin-azysrm`.

## 주의
- 저장소 루트(`fishing-game-repo`)는 다른 프로젝트와 같이 써요. `fishing-game/` 안의 파일만 커밋(`README.md docs changelog review blender "fish game/Assets" "fish game/ProjectSettings"`). `fish game/Assets/Resources/PerformanceTestRunInfo.json`은 빼기.
- 씬에 저장된 값은 C# 기본값보다 우선해요(예: 도감 그림 목록 `CatalogUI.fishSprites`, FishingRod 값).
- 화면 요소는 대부분 게임이 시작될 때 스스로 만들어져요(`[RuntimeInitializeOnLoadMethod]`). 장면에 올려 둔 게 없어요.
- 모델(FBX)은 `Assets/Resources/Models/`에 둬야 웹 빌드에 들어가요. 블렌더 (x,y,z)는 유니티에서 (x, z, −y). 재질 이름 `C_RRGGBB`를 읽어 색을 입혀요.
- 화면 사진 시험 도구: `fish game/Assets/Editor/ScreenShot.cs` (예: `-executeMethod ScreenShot.Contests`, 환경변수 `FG_OUT`=저장 폴더). 클릭·소리·사진 저장·배 이동은 자동으로 못 보므로 사용자가 직접 플레이해서 확인.
- 저장은 `SaveData`(웹은 브라우저 저장소). 새 저장 칸을 더해도 옛 저장은 안전하게 읽혀요.
