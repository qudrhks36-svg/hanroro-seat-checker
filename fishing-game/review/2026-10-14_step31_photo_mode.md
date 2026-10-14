# 검수: 31단계 사진 찍기 (P키) (2026-10-14)

판정: **통과** (실제 찍기는 사용자 플레이로 확인 필요)

## 확인한 것
- GDD 9번 [확정] 항목과 일치: P키, 깨끗한 사진, 찰칵+번쩍임 0.4초, 토스트 3초, 간격 1.2초, 안내글 "P 사진", 파일명 `낚시섬_날짜_시간.png`.
- 막는 조건: 커서 잠김 아님 / TalkNPC / ShopNPC / DecorShop / CatalogUI 열림 / busy / 쿨다운. 네 IsOpen 모두 실제로 있음.
- 캔버스 숨김: 켜져 있던 루트 오버레이 캔버스만 끄고 그 목록만 다시 켬 -> 원래 꺼져 있던 캔버스는 꺼진 채 유지. 캔버스를 켜고 끄는 다른 스크립트 없음(grep) -> 낚싯대 UI 상태 영향 없음. 다시 켜기는 Save보다 먼저, null 검사 있음.
- 캡처 예외는 try/catch로 잡고 그 뒤에 다시 켬. 찍은 텍스처는 Destroy. timeScale=0이어도 프레임·unscaledTime 기준이라 동작.
- WebGL: `#if UNITY_WEBGL && !UNITY_EDITOR` 가드 OK. jslib는 mergeInto 문법 정상, HEAPU8.slice로 복사 -> Blob -> a.download, UTF8ToString으로 이름, 5초 뒤 revoke. 빌드에 FG_DownloadPng 포함 확인됨(전달받은 사실).
- PC 저장: MyPictures/낚시섬 폴더 만들고 try/catch, 실패 시 토스트 "저장하지 못했어요". Shutter 효과음·GuideHint 문구·PhotoTest는 이상 없음.

## 참고(반려 사유 아님)
- 캡처 자체가 null이면(예외) 토스트·소리 없이 조용히 끝남(로그 경고만).
- 코루틴 도중 PhotoMode가 파괴되면 캔버스가 꺼진 채 남을 수 있으나, 장면 전환이 없는 게임이라 가능성 낮음.
- 배치 테스트는 저장 단계만 검증. 프레임 끝 캡처·웹 다운로드(허용 팝업)는 직접 플레이로 확인 권장.
