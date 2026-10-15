# 검수: 35단계 공개 준비 (웹 페이지 틀·README) - 2026-10-15

판정: **통과**

## 확인한 것
- 템플릿 문법: Unity 6 기본 틀과 같은 매크로(LOADER/DATA/FRAMEWORK/WORKER/CODE/SYMBOLS, COMPANY/PRODUCT_NAME/VERSION)와 #if 블록 사용. 빌드 결과물(`fishing-game-build/webgl/index.html`)에 `{{{`/`#if` 잔재 0건, 파일명이 webgl.*로 치환됨.
- 캔버스: fit()이 16:9, 최대 1600x900, 최소 480폭으로 맞추고 resize에 연결됨.
- 터치 기기(UA 또는 coarse 포인터)는 게임을 안 불러오고 "PC에서 플레이" 안내만 보임.
- 불러오기 화면: 로드 완료 시 숨김, 실패 시 한국어 오류 문구(+원인) 표시. 경고/오류 띠(showBanner) 유지. 전체 화면 버튼은 로드 후 연결됨.
- 외부 연결: og:image 절대 주소 1개뿐(글꼴·CDN 없음). 한글 문구 정상(UTF-8, lang=ko). 개인정보·키 노출 없음.
- WebBuild.cs: `PROJECT:FishingIsland` 설정 1줄만 추가. ProjectSettings.asset은 webGLTemplate 줄만 바뀜. companyName "DefaultCompany", productName "fish game"은 최초 커밋과 같음 -> 브라우저 저장(PlayerPrefs) 유지됨. 빌드 index.html의 config에도 같은 값.
- 빌드 폴더 TemplateData: favicon.ico, preview.png(268KB), style.css(원본과 동일) 있음. preview.png: 석양 섬 사진+"낚시 섬" 제목, 깨짐 없음.
- README: GDD와 일치(16종, 먼 바다, 조작키, 크레딧 BGM monume / 나눔고딕 OFL).
- Vercel: 이 단계에서 보호 설정을 바꾸지 않음. 현재 `fishing-game-web` ssoProtection 켜짐(all) = 비공개 유지. 사용자 확인 전 해제 금지.

## 참고(반려 사유 아님)
- 비공개인 동안 og:image(공유 미리보기)는 외부에서 안 보임. 공개로 바꾼 뒤에야 확인 가능.
- 도메인이 바뀌면 og:image 주소를 고쳐야 함.
- 스크린샷 도구(ScreenShot.cs)에 노을 컷 추가가 같이 들어 있음(게임 동작 영향 없음).
- 실제 브라우저 로드 테스트는 이 검수에서 못 함(코드·산출물 확인만). 배포 후 사용자 확인 권장.
