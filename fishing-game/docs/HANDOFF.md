# 다른 PC에서 이어 하기 (2026-10-14 기준)

## 준비
- Unity **6000.3.26f1** (Hub에서 설치, WebGL 모듈 포함). 프로젝트 폴더: `fish game/`. Library는 처음 열 때 다시 만들어져요(몇 분).
- 이 폴더의 `CLAUDE.md`와 `docs/GDD.md`가 규칙·기획의 기준이에요. 클로드에게 "CLAUDE.md, GDD.md, docs/HANDOFF.md, changelog/2026-10-12.md 읽고 이어서 해줘"라고 하면 돼요.
- 블렌더 작업은 `blender/fishing_island.blend`, 모델은 `fish game/Assets/Models/`.

## 현재 상태
- 1~20단계 끝(검수 통과·배포). 마지막 배포 완료 커밋: `bdf876e` (오늘의 목표).
- 효과음(21단계)은 코드·기록 완료, 검수·배포 진행 중이었음.
  - 남은 일: 컴파일 확인 → GDD 2번에 효과음 3개 [확정] 기록 → changelog "21단계" → 다른 에이전트 검수(`review/`) → 웹 빌드(`WebBuild.Build`) → Vercel 배포 → 사용자 플레이 확인.

## 배포(비공개 유지)
- 웹 빌드: `Unity.exe -batchmode -quit -projectPath "…/fish game" -executeMethod WebBuild.Build -logFile …` → 결과 폴더는 저장소 밖(`fishing-game-build/webgl`, 새 PC에선 경로 확인).
- 배포: `npx vercel deploy --prod --yes --scope bottlepipe` (이 PC에서 로그인 필요). 링크: https://fishing-game-web.vercel.app (비공개).
- 공개 범위와 BGM(monume 무료 음원) 이용 조건은 사용자가 확인하기 전까지 **공개하지 않기**.

## 주의
- 저장소 루트(`fishing-game-repo`)는 다른 프로젝트와 같이 써요. `fishing-game/` 안의 파일만 커밋.
- 씬에 저장된 값은 C# 기본값보다 우선해요(예: FishingRod 값, Fireflies 비율).
