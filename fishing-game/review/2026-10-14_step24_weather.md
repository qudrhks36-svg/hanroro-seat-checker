# 검수: 24단계 날씨 - 통과

검수 담당 / 2026-10-14 / 기준: GDD 9번 [확정, 사용자 선택 2026-10-14] "날씨"

## 항목별
- Weather.cs: 통과. 스스로 만들어지는 싱글톤(AfterSceneLoad), Shader.Find 없음(Resources/Fx/Mat_Droplet, 파일 있음). SubsystemRegistration에서 맑음·0으로 초기화. 전이 확률 맑음 40/60, 흐림 40/20/40, 비 70/30이 GDD와 같고 비는 흐림에서만 옴. 70~130초, 10초 보간(Time.deltaTime이라 timeScale 0이면 멈춤). Camera.main이 null이면 위치 갱신만 건너뜀.
- 빗소리: 통과. 볼륨 0.06×비 세기, 4초 잡음에 0.25초 교차 이음으로 반복, AudioListener.volume(MuteToggle)을 따름. 비가 처음 올 때만 만듦.
- 파티클 성능: 통과. 초당 1000개 x 수명 0.8초 = 약 800개 유지, 최대 1500개라 WebGL에서도 가벼움. 그림자 끔.
- TimeOfDay.cs: 통과. Grey 헬퍼, 해/안개/하늘/바다/반짝임/해빛무리에 Overcast 적용. 편집 모드 Apply는 Weather.Overcast 기본값 0이라 예전과 같은 결과.
- HudPanel.cs: 통과. "낮 · 흐림" 글자(너비 190), 오른쪽 구름/비 아이콘, 맑음은 아이콘 숨김. 사진에서 겹침 없음.
- 낚시 영향: 통과. Weather는 HudPanel과 TimeOfDay에서만 쓰이고 낚시 코드(입질·물고기 종류)에는 연결 없음.
- 사진(w1): 맑음/흐림/비 x 낮/노을 모두 정상. 흐림은 하늘·바다가 회색빛, 비는 가장 어둡고 빗줄기 보임.

## 참고(반려 사유 아님)
- 흐림 낮 사진은 회색빛이 약해 맑음과 차이가 작음. 플레이해 보고 조정.
- 빗소리 실제 청감과 10초 전환은 사진으로 확인 못 함.
- ScreenShot.Weathers는 편집용 도구(게임에 영향 없음).

결과: **통과**
