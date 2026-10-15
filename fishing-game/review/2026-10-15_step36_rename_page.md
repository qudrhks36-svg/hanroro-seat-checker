# 검수: 36단계 게임 이름 BOTTLE ISLAND + 힐링 웹 페이지 (2026-10-15)

판정: **통과**

## 확인한 것
- GDD 확정 항목(BOTTLE ISLAND, 톤, FG_Ready) 있음. 제품 이름(productName=fish game, companyName=DefaultCompany) 그대로.
- 제목·og:title·README·사진 이름(PhotoMode/PhotoTest) 모두 BottleIsland로 통일. 옛 이름 "낚시 섬/낚시섬" 남은 곳 없음.
- 글꼴: 구글 웹폰트 + 맑은 고딕 등 대체 글꼴 줄이 있어 오프라인에서도 레이아웃 유지.
- 불러오는 화면: window.fgGameReady 또는 25초 뒤 걷힘, hideLoading은 한 번만 실행(idempotent). 오류 시 안내 문구 표시. 모바일은 불러오지 않고 안내만.
- WebReady.cs: DllImport는 UNITY_WEBGL && !UNITY_EDITOR 안에서만, 90프레임 뒤 한 번 호출 후 자기 삭제, 편집기 영향 없음. jslib: mergeInto 정상, fgGameReady 없어도 안전.
- 애니메이션은 CSS(구름 3개 translate)뿐이라 가벼움. 칩 글자색 대비 충분.
- preview.png: 게임 장면 + 제목, 글자 잘 읽힘.
- 빌드 결과물 index.html: 새 제목 있음, {{{ }}} 매크로 0개.
- Vercel 설정 변경 파일 없음(이번 단계에서 공개 전환 안 함).

## 참고(반려 사유 아님)
1. og:image가 fishing-game-web.vercel.app 주소라, 비공개인 동안은 공유 미리보기가 안 보일 수 있어요(공개 때 해결).
2. 25초 보험 타이머는 게임 로딩이 끝난 뒤에 시작돼요. 로딩이 아예 멈추면 오류 문구가 대신 보여요(의도대로).
3. 빌드 .unityweb이 압축이라 FG_Ready 포함 여부는 파일 검색으로 못 봤어요. 실제 플레이로 까만 화면이 사라지는지 사용자 확인 필요.
4. fit()의 210px 여백은 새 헤더 높이 기준 추정치. 작은 창에서 스크롤 생기는지 눈으로 확인 권장.
