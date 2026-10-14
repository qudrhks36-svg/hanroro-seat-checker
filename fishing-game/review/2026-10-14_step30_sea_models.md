# 검수: 30단계 블렌더 모델 교체 ③ 갈매기·병 (2026-10-14)

판정: **통과**

## 확인한 것
- make_sea.py: 재질 이름 `C_RRGGBB`, 갈매기 앞 = +X, WingL(-Y)·WingR(+Y) 원점 = 어깨, 병 Gem 원점 = 반짝이 가운데(0,0,0.55), export 전 transform_apply 모두 OK.
- Sea_Gull / Sea_Bottle .fbx + .meta가 Resources/Models 안에 있음 (Resources.Load 가능).
- SeaEvents.cs: SpawnModel은 모델이 없으면 null -> 임시 도형으로 대체. "Gem"·"WingL"·"WingR"를 못 찾으면 모델을 먼저 Destroy한 뒤 도형을 만들어 중복 없음. Tinted 캐시로 재질 재사용(Shader.Find 없음).
- 갈매기 방향: LookRotation * Euler(0,-90,0)은 모델 +X를 날아가는 쪽으로 돌림. 맞음. 좌/우 날개는 임시 도형(Wing(+1)=왼쪽 +Z)과 같은 부호라 퍼덕임 방향 일치. 퍼덕임은 모델 날개 transform을 그대로 돌림.
- 병: diamond = 모델의 Gem, 위아래 떠다님 + 회전 코드 그대로 동작(0.55 기준 높이 일치). 쪽지·줍기(E, 거리, 보상, 저장) 코드는 변경 없음 -> 회귀 없음.
- 스크린샷 ev_scene(병 + 반짝이 + "E: 병 줍기"), ev_far(하늘의 갈매기, 해변의 병): 모양·색 정상.

## 참고(반려 사유 아님)
- 날개 퍼덕임은 정지 화면이라 눈으로는 확인 못 함. 코드 경로상 문제 없음, 플레이로 확인 권장.
