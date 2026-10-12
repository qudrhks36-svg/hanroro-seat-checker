# 인수인계: 사주 v2 개선안을 `starlight-saju`(사주볼래말래)에 옮기기

작성일 2026-10-12. 이 문서는 **다른 컴퓨터에서 Claude 세션을 새로 열어 이어서 작업**하기 위한 자료입니다. 아직 `starlight-saju`에는 아무것도 적용하지 않았습니다 (읽기만 함).

## 1. 한 줄 요약

사용 후기(MBTI 벤다이어그램 시각화, 줄글이 길다, 사주아이와 비슷하고 지루하다)를 반영해 **`saju_web/`(Vite 앱)에 v2 개선안을 만들어 두었고**, 원래 목표는 이것을 **Next.js 앱 `starlight-saju`에 적용하는 것**이었습니다. 이 컴퓨터에는 `starlight-saju` 소스가 없어서 적용하지 못했습니다. 다른 컴퓨터(소스가 있는 곳)에서 이 저장소를 받아 이어가면 됩니다.

## 2. 가져오는 방법

저장소: https://github.com/qudrhks36-svg/hanroro-seat-checker (PUBLIC, `main` 브랜치)

```bash
git clone https://github.com/qudrhks36-svg/hanroro-seat-checker.git
cd hanroro-seat-checker/saju_web
npm install
npm test        # 107개 통과해야 정상
```

이미 받아 둔 저장소라면 `git pull`. 이 문서 위치: `docs/handoff/2026-10-12-starlight-saju-port.md`.

## 3. 어디에 무엇이 있나 (`main`)

| 내용 | 경로 |
|---|---|
| 설계 (v2) | `docs/superpowers/specs/2026-10-12-saju-v2-design.md` (**변경 이력까지 읽을 것**) |
| 구현 계획 (v2) | `docs/superpowers/plans/2026-10-12-saju-v2.md` |
| v1 설계·계획 | `docs/superpowers/specs/2026-10-08-saju-web-design.md`, `docs/superpowers/plans/2026-10-08-saju-web.md` |
| 브레인스토밍 메모 | `docs/superpowers/specs/2026-10-12-saju-v2-brainstorm-notes.md` |
| **MBTI 4축 예측** (순수 함수) | `saju_web/src/lib/mbti.ts`, `saju_web/src/data/mbti.json`, `saju_web/tests/mbti.test.ts` |
| 실제 MBTI와 비교 | `saju_web/src/lib/compare.ts`, `saju_web/src/components/VennCompare.tsx`, `saju_web/src/components/MbtiCard.tsx`, `saju_web/tests/compare.test.ts` |
| **캐릭터** (순수 함수 + 데이터) | `saju_web/src/lib/character.ts`, `saju_web/src/data/character.json`, `saju_web/tests/character.test.ts` |
| **카드형 풀이** 데이터와 규칙 | `saju_web/src/data/readings.json` (`cards` 키), `saju_web/src/lib/interpret.ts`, `saju_web/tests/readings-data.test.ts` |
| 화면 컴포넌트 | `saju_web/src/components/{CharacterCard,SituationBubbles,ReadingCard,ShareCard,Result}.tsx` |
| 계산 엔진 (v1) | `saju_web/src/lib/{tables,saju,analysis}.ts` |

커밋: `c5dd337`이 v2 최종. 기능은 6개 커밋(`e0f1d02`, `f0a1e3e`, `db53159`, `5e95856`, `8eb21c1`, `c5dd337`).

## 4. `starlight-saju`에서 확인한 사실

Vercel 프로젝트 `starlight-saju` (팀 `bottlepipe`, 프로젝트 ID `prj_xLfk02kh27bt3EWZiLRMGTNA9EEw`)를 읽기 전용으로 살펴본 결과입니다. 소스는 이 컴퓨터에 없고 GitHub에도 없습니다 (Vercel에 파일 업로드 방식으로만 존재).

- 주소: https://starlight-saju-pi.vercel.app , https://starlight-saju-bottlepipe.vercel.app (Vercel 로그인 보호가 켜져 있음)
- 제목 "사주볼래말래 · 내 운세, 오늘 한 번 볼래?", 설명 "생년월일만 넣으면 끝! 오늘 운세부터 연애·돈·일, MBTI 궁합까지 쉽고 가볍게 풀어드려요". 어두운 별 배경 디자인.
- 스택: Next.js 16.4, React 19, Tailwind 4, shadcn(base-ui), `lunar-javascript`, Vitest. 루트 `AGENTS.md`에 "Next.js 문서는 `node_modules/next/dist/docs/`를 먼저 읽고 코드를 쓸 것"이라는 규칙이 있음 (이번 Next 버전은 기존 지식과 다를 수 있음).
- 파일 구성(확인된 이름): `app/{page,match/page,me/page,me/[topic]/page,api/reading}`, `components/{birth-form,chart-table,element-radar,mbti-picker,night-sky,reading,score-gauge,use-chart}`, `lib/{saju,mbti,partner,radar,prompts,openrouter,budget,fun-note,storage,time,validate}` (각각 `.test.ts` 있음), `docs/design-system.md`, `docs/specs/2026-10-11-saju-web-design.md`, `docs/specs/2026-10-12-mbti-design.md`, `docs/plans/2026-10-11-saju-web.md`, `docs/plans/2026-10-12-mbti.md`.
- 풀이는 **AI가 씁니다** (`openrouter.ts`, `prompts.ts`, `/api/reading`, `budget.ts`로 사용량 제한). 그래서 `saju_web`의 규칙 기반 문구를 그대로 옮길 수 없습니다.
- **이미 MBTI 기능이 있습니다.** `docs/specs/2026-10-12-mbti-design.md`의 제목은 "MBTI 연동 설계 (사주 × MBTI, 둘의 궁합)"이고, 앞부분이 읽힌 범위로는 "내 사주 × MBTI 비교, 잘 맞는 MBTI 추천, 둘의 궁합"을 다루는 것으로 보입니다. 파일이 잘려서 **세부 내용은 확인하지 못했습니다.** 새 컴퓨터에서 원본을 읽고 겹치는 부분을 먼저 정리하세요.

## 5. 옮길 개선안과 옮길 때 판단할 것

| 개선안 | 성격 | 옮길 때 |
|---|---|---|
| **사주 → MBTI 4축 예측** | 순수 TS 함수. 입력은 오행 개수, 십성 그룹 가중치, 일간, 신강/신약 비율 | 입력을 `starlight-saju`의 `lib/saju.ts` 결과에서 만드는 어댑터가 필요. 공식과 문구는 그대로 사용 가능. 배율 `MBTI_GAIN=50`은 `saju_web`의 분포 검증으로 정한 값이라, 입력(계산 엔진)이 다르면 **분포 검증 테스트를 다시 돌려야 함** |
| 실제 MBTI와 벤다이어그램 비교 | SVG 컴포넌트 + 비교 함수 | `mbti-picker.tsx`가 받는 MBTI를 그대로 입력으로 사용 |
| 사주 캐릭터 | 표 조합 (일간→동물·직업, 일지→소품, 십성→수식어) | 거의 그대로 이식 가능. 디자인 시스템에 맞게 색 조정 |
| 카드형 풀이 (요약·칩 3·불릿 3·막대) | `saju_web`은 정적 문구, `starlight-saju`는 AI 생성 | **결정 필요**: AI 응답을 구조화(JSON)해서 카드로 렌더링할지, 규칙 기반 카드 데이터를 쓸지 |
| 공유 카드 (PNG) | `html-to-image` 클라이언트 컴포넌트 | Next.js에서는 `'use client'` 필요. 한글·이모지 렌더 확인 필요 |

### 정직하게 지켜야 할 문구 원칙 (v2 스펙에서 가져옴)
- MBTI 예측에는 반드시 "사주 기운을 MBTI 축으로 번역한 경향" 표기. 정확도를 주장하지 않는다. 사주와 MBTI를 잇는 검증된 대응표는 없고, 가중치는 우리가 정한 해석 규칙이다.
- 전문가 톤, "재미/오락용" 면책 문구 금지, 흉운·질병·사망 단정 금지, 의료·투자 판단 금지.
- 받침에 따라 달라지는 조사("을(를)" 병기)는 쓰지 않고, 조사가 필요 없는 문장 구조로 쓴다.
- 유료 API(AI 이미지 생성 등)는 쓰기 전에 사용자에게 먼저 묻는다.

## 6. 아직 확인하지 못한 것

- 내장 브라우저 한계로 **화면을 눈으로 확인하지 못함**. 모든 확인은 DOM 값 기준. 특히 PNG 저장·공유 결과, 이모지 렌더링(기기마다 다름), 벤다이어그램 글자 배치(칸당 4글자일 때), 공유 카드 세로 비율.
- 외부 만세력과 4주 대조는 안 함 (입춘, 윤달, 자시). 과거 한국 표준시(UTC+8:30)와 서머타임은 `saju_web` 계산에 반영되지 않음. `starlight-saju`의 계산 엔진이 어떻게 처리하는지는 미확인.
- `starlight-saju`의 기존 MBTI 설계 세부 내용 (위 4번 참고).

## 7. 현재 배포 상태

- `saju_web`(Vite, v2 최종): Vercel 프로젝트 `saju-web` → https://saju-web-eta-nine.vercel.app (로그인 없이 열림). `starlight-saju`와 **별개 프로젝트**이고, 이번에 건드린 것은 이 프로젝트뿐입니다.
- 이전 버전(v1) 배포는 https://saju-503zy3iqa-bottlepipe.vercel.app 에 그대로 남아 있음.
- 재배포 방식: Git 연동 없이 `create_deployment`에 `gitSource`(org `qudrhks36-svg`, repo `hanroro-seat-checker`, ref `main`, sha 지정) + `projectSettings.rootDirectory=saju_web`. 이 저장소는 좌석 알림 봇이 1분마다 main에 커밋을 올려서 Git 연동을 걸면 빌드가 계속 걸린다.
- `starlight-saju`는 파일 업로드 배포(`create_deployment`의 `files`)이므로, 업데이트도 같은 방식으로 해야 한다. Vercel 로그인 보호는 사용자가 직접 설정하며 AI가 바꾸지 않는다.

## 8. 새 컴퓨터의 Claude 세션에 붙여 넣을 프롬프트

```
이 저장소의 docs/handoff/2026-10-12-starlight-saju-port.md 를 읽고 이어서 진행해 줘.
목표: saju_web(Vite)에 만들어 둔 v2 개선안(사주 기반 MBTI 4축 예측, 실제 MBTI와 벤다이어그램 비교,
사주 캐릭터, 카드형 풀이, 공유 카드)을 이 컴퓨터에 있는 Next.js 앱 starlight-saju(사주볼래말래)에 적용하는 거야.
먼저 starlight-saju의 기존 코드와 docs/specs/2026-10-12-mbti-design.md 를 읽고 이미 있는 MBTI 기능과 겹치는 부분을 정리한 뒤,
그 앱 구조에 맞게 설계해서 내 승인을 받고(brainstorming), 스펙과 계획을 쓰고, 서브에이전트 방식으로 구현해 줘.
saju_web 쪽 파일은 읽기 전용 참고 자료로만 쓰고 수정하지 마. 배포는 내 확인을 받은 뒤에 해.
```

## 9. 작업 방식 (이 사용자와의 약속)

- 큰 작업은 brainstorming → 스펙 → 계획 → 서브에이전트 구현 → 리뷰 순서. 설계 섹션별로 승인받는다.
- 병합·push·배포처럼 바깥에 보이는 작업은 사용자 확인 후에 한다.
- 확인하지 못한 것은 "못 봤다"고 말하고, 추측으로 채우지 않는다.
- 에이전트가 실행하는 명령은 `taskkill /IM node.exe`처럼 다른 프로세스를 죽일 수 있는 것을 쓰지 않는다 (이번에 그런 사고가 한 번 있었다).
