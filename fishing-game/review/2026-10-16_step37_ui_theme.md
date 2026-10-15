# 검수: 37단계 게임 안 화면 힐링 톤 (크림 판 + 주아 글꼴) (2026-10-16)

판정: **통과** (참고 2건)

## 확인한 것
- GDD 확정 항목("게임 안 화면도 힐링 톤으로 통일") 있음. 사용자 승인 근거 적혀 있음.
- 나눔고딕 남은 참조: Scripts/Scenes/Editor 0건. changelog·옛 review(과거 기록)에만 있음. 씬이 옛 글꼴 guid를 쓰지 않아 깨질 곳 없음.
- GameFont: Fonts/Jua-Regular 로드, 없으면 OS 글꼴 대체 유지. Jua .ttf/.meta/OFL_Jua.txt 있음, 글꼴 시험(FontCheck) 코드 정상.
- UiTheme.Prompt: GameObject 반환, 기존 SetActive 그대로 사용 가능. 폭은 preferredWidth로 정함(글자 먼저 넣은 뒤 계산이라 정상).
- HudPanel: Cream->TextInk 이름 변경 후 남은 Cream 참조 없음. 아이콘 외곽선용 Ink는 별도로 남아 있어 컴파일 문제 없음. 글자 윤곽/그림자 제거 확인.
- 어두운 판 -> 크림 판으로 바꾼 곳(GuideHint, FarSea, SeaEvents, PhotoMode, MuteToggle)은 글자색도 모두 갈색(Ink)으로 바뀜. 크림 판 위 흰 글자 남은 곳 없음. 흰 글자는 갈색 번호 뱃지·파란 칩·이름표 위만 남음(의도대로).
- MuteToggle: label은 자식 Text, 켜고 끄기는 부모 알약. label.text 영향 없음.
- FishingRod 게이지: 크림 바탕 + 연두 구간 + 주황 물고기로 대비 충분.
- 스크린샷(hints, home_shop, fx_catalog_far): 글자 잘 읽힘, 글꼴 깨짐 없음. DialogView/CatalogUI/ResultCard 정상(글꼴만 바뀜).
- README·웹 페이지 크레딧에 주아(OFL) 표기, 나눔 표기 없음.

## 참고(반려 사유 아님)
1. GDD 11번(약 147행)에 "나눔고딕, OFL"이 현재 글꼴처럼 남아 있음 -> 주아로 고쳐야 함(GDD 먼저 수정 규칙).
2. ShopNPC의 moneyText는 옛 크림 글자색이지만 항상 숨김 처리라 보이지 않음(죽은 코드).
3. WebGL 빌드에서 글꼴 2.1MB 늘어난 것과 실제 한글 표시는 사용자 플레이로 확인 필요.
