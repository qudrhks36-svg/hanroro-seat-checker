# 낚시 게임 프로젝트 규칙

## 기준 문서
- 모든 작업은 `docs/GDD.md`를 기준으로 해요.
- GDD에 없거나 `[제안]` 상태인 내용은 짐작으로 구현하지 말고, 먼저 사용자에게 확인해요.
- 기획이 바뀌면 코드보다 GDD를 먼저 고쳐요.

## 역할 분담 (서브에이전트)
- 설계 담당: 구조와 작업 계획 작성
- 모델링 담당: 블렌더 에셋 제작 (섬, 야자수, 부두, 배, 오두막)
- 텍스처 담당: 머티리얼과 색감
- 구현 담당: 유니티·고닷 스크립트와 씬
- 검수 담당: 결과물을 보고 통과/반려만 결정해요. 직접 고치지 않아요.

## 현재 상태
- 원본 Unity 6.3(`fish game/`), 포팅 Godot 4.7.2(`godot/`). 고닷 1~9단계 완료 + 집 안·농장·NPC 친밀도·풀섬(동물·과일나무·연못 낚시)·3인칭·크기 줄이기까지 반영. 공개 주소 fishing-game-web.vercel.app = 고닷판 최신.
- 자세한 것: `docs/GODOT_PORT.md`(포팅 기록·시험 방법), `docs/HANDOFF.md`(인수인계), 변경 기록 `changelog/2026-10-12.md`.

## 고닷 실행·시험 (창을 띄우지 말 것 — 사용자가 업무 중에 거슬려 함)
- 일반 exe(`Godot_v4.7.2-stable_win64.exe`)를 `Start-Process -WindowStyle Hidden -Wait`로,
  `--headless --path godot --quit-after N --log-file <파일> -- --시험옵션` 형태로 돌리고 로그 파일을 읽는다.
- `_console.exe`, `--write-movie`, `--no-window`는 창이 떠서 금지. 화면 그림은 못 찍음(그림이 꼭 필요하면 먼저 물어볼 것).
- 웹 내보내기: `--headless --path godot --export-release "Web"` → `../../fishing-game-build/godot-web`.
- 배포: 그 폴더에서 `npx vercel@latest deploy --prod --yes --scope bottlepipe` (`.env*`는 지우고). 공개 주소는 `fishing-game-build/webgl/.vercel`의 연결 정보를 쓴다.

## 커밋·푸시
- git 최상위가 다른 프로젝트와 같다. 이 폴더 경로만 add: `README.md docs changelog review blender tools godot "fish game/Assets" "fish game/ProjectSettings"`.
  `Resources/PerformanceTestRunInfo.json*`은 제외. 푸시는 사용자가 직접 한다.

## 함정
- 시험 코드가 `timeScale` 같은 전역 값을 건드리면 설정 파일에 남아 게임이 멈춘다(유니티에서 겪음).
- 같은 경로 항목이 여러 개(풀·꽃)면 `nodes_by_path`는 마지막 하나만 남는다 → 항목의 `_node`를 쓴다.
- 막힌 결정은 답변 끝에 `@@ASK@@ 질문` 한 줄, 선택지는 번호와 추천을 붙인다.

## 두 가지 철칙
1. 검수는 만든 에이전트가 아닌 다른 에이전트가 해요. 검수 결과는 `review/`에 남겨요.
2. 고친 내용은 전부 파일로 남겨요. `changelog/`에 날짜별로 "무엇이/왜 바뀌었는지"를 기록해서 다음 프로젝트에 재사용해요.

## 작업 방식
- 한 번에 기능 하나만 붙이고, 사용자가 직접 플레이해서 피드백하기 전에는 다음 기능으로 넘어가지 않아요.
- 맵은 임시 도형으로 먼저 짜고, 마지막에 블렌더 모델로 교체해요.
- 피드백은 이유가 붙어서 와요(예: "해 질 녘이 너무 어두워요"). 이유를 changelog에 함께 적어요.

## 안전
- 블렌더 MCP는 AI가 만든 코드를 보호 장치 없이 실행해요. 중요한 파일이 없는 환경(가상 머신 등)에서 쓰고, 작업 전 프로젝트를 백업해요.
- 유니티 MCP는 Project Settings > AI > Unity MCP에서 켜고, 클로드 코드 연결을 한 번 승인해요.

## 말투
- 한국어, 쉬운 말로 짧게 답해요. 질문은 한 번에 하나씩 해요.
