# 검수: 19단계 게임다운 맛 (결과 카드·도감 진행도·낚시 연출) - 통과

검수 담당 / 2026-10-13 / 기준: GDD 9번 [확정] "게임다운 맛"

## 항목별
- ① 결과 카드: 통과. 팝업 0.35초(PopTime) → 유지 3.5초(HoldTime) → 0.5초 서서히 사라짐. 물고기 점프 0.8초 후 팝업. 희귀도 색 바탕 큰 그림, "낚았다!"/이름/알약/"판매 값 n원", NEW 배지("NEW! 도감 등록")와 반짝이는 조각(새로 잡음 또는 희귀). 사진 fx_card_new_rare.png 로 확인. 놓쳤을 때 글자는 그대로.
- ② 도감 진행도: 통과. 상태창 4번째 줄 책 아이콘 + "도감 n/8", 8개면 "도감 완성!"(노란색). 사진에서 "도감 2/8" 보임. 패널 높이는 Rows=4로 같이 늘어남.
- ③ 낚시 연출: 통과. 찌 착수 Splash(작게), 입질 Ring, 낚음 Splash(크게), 물고기 포물선 점프+회전. 사진 fx_splash.png 에서 고리·물방울 확인.

## 안전
- isNew는 Collection.Register 직전에 계산함(올바른 순서).
- 널 안전: fishSprites 없으면 sprite null(오류 없이 빈 그림), idx 범위 검사, 카메라 null이면 화면 중앙 대체, 카메라 뒤(z<0)도 대체. aimCamera는 기존 코드(108행)도 같은 방식으로 쓰는 값.
- 재질: Resources.Load("Fx/Mat_Ripple", "Fx/Mat_Droplet")로 읽음. 런타임 Shader.Find 없음(FxSetup의 Shader.Find는 에디터 전용). 재질 셰이더 GUID가 Ring.shader / SoftDot.shader meta와 일치 → 빌드에 셰이더 포함됨.
- 시간: 카드는 Time.unscaledTime 사용. 파티클은 게임 시간이라 멈추면 같이 멈춤(의도 무난).
- WebGL: 새 에셋 없이 UI·파티클·단순 셰이더(URP). 파티클 최대 110개, 매 프레임 비용 작음. 셰이더 문제 없음.
- 게임 규칙(저장·판매·낚시 확률) 변경 없음. 파일 변경은 RarityColor를 internal로 연 것뿐.

## 참고(반려 사유 아님)
- SplashFx/ResultCard의 실제 움직임(점프 곡선, 사라짐)은 코드로만 판단. 사용자 플레이 확인 필요.
- 결과 카드 그림은 FindFirstObjectByType<CatalogUI>로 찾음. CatalogUI가 장면에서 꺼져 있으면 그림이 비어 보일 수 있음(현재 켜져 있어 문제 없음).

결과: **통과**
