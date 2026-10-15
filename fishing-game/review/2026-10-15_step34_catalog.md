# 검수: 34단계 도감 고도화 (보기 좋게만) - 2026-10-15

판정: **통과**

## 확인한 것
- 동작 그대로: Tab/Esc 열기·닫기, ClosedFrame, 시간 0, 커서 해제, ShopNPC/TalkNPC 중일 땐 Tab 무시 - 이전 코드와 같음.
- 클릭 선택: RectangleContainsScreenPoint를 cells[](테두리 칸)에 그대로 사용. 좌표 판정이라 raycastTarget과 무관 -> 속/그림/글자가 false여도 선택됨.
- 공개 항목: IsOpen, RarityColor(internal), fishSprites(public, 이름 그대로). SampleScene.unity에 fishSprites 연결 1건 유지, ResultCard가 계속 사용.
- 진행 막대: 최소 폭 24, 0마리면 숨김. 14/16 화면에서 정상.
- 16칸: 4x4가 판 안에 들어가고 겹침 없음. 5글자 이름(무지개고기)도 칸 안에 들어옴.
- 먼 바다 칩: farSea 물고기만(별고래 확인), 일반 물고기엔 없음.
- 못 잡은 물고기: 실루엣 / "???" / 값 "—" 확인.
- 정보 보존: 구분(등급 칩), 잡은 수, 최고 기록 유지, 판매 값은 Inventory.Price(rarity) 사용(희귀 100원 일치).
- FarSea.Busy: 이동(페이드) 동안만 true, Reset()에서 false, 이동 끝에 false로 복귀 -> 평소 낚시는 영향 없음.

## 참고(반려 사유 아님)
- 먼 바다 칩이 없을 때 등급 칩이 가운데가 아니라 약간 왼쪽(-30)에 있음. 거슬리면 다음에 중앙 정렬.
- 스크린샷의 "최고 기록 0cm"는 테스트용 값으로 보임(실제 기록과 무관).
