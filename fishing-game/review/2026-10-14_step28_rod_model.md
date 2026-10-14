# 검수: 28단계 블렌더 모델 교체 ① 낚싯대 - 통과

검수 담당 / 2026-10-14 / 기준: GDD 9번 [확정, 사용자 선택 2026-10-14] "블렌더 모델 교체"

## 항목별
- make_rod.py: 통과. 재질 이름 `C_RRGGBB`, 막대는 블렌더 -Y(유니티 +Z)로 뻗고 원점=손잡이 끝, 길이 1.4/1.61/1.82 = 1.4 x (1/1.15/1.3). "Orb"는 level 1·2만, 원점이 끝(y=-L). FBX는 mesh만 내보냄.
- FBX 3개 + .meta: 통과. Resources/Models 안이라 WebGL 빌드에 포함됨(Resources.Load 경로 "Models/Rod_n"과 일치).
- RodLook 널 안전: 통과. FishingRod·rodTip·부모·Renderer 없으면 Find가 false로 대기. 모델 없으면 예전 임시 모양으로 대신. 구슬·모델 구슬 null 검사 있음.
- 단계 변경: 통과. 옛 모델은 Destroy(편집 모드는 DestroyImmediate, Application.isPlaying 검사), shown으로 단계가 바뀔 때만 Apply.
- 줄 시작 위치: 통과. FishingRod는 rodTip.position(줄 SetPosition(0)·던지기 startPos)만 씀. RodTip은 Rod의 자식이라 Rod 길이 배율이 바뀌면 같이 움직이고, 모델 끝(손잡이 끝 + 길이)과 같은 자리. 줄·찌 로직은 건드리지 않음.
- 큐브 숨김: 통과. 모델이 있을 때만 rodRenderer.enabled=false, 없으면 다시 켬.
- 재질: 통과. Shader.Find 없음, 낚싯대 재질 복사(new Material(sharedMaterial)) + Color32 Dictionary 캐시. 이름 못 읽으면 회색.
- 구슬 반짝임: 통과. shown>=2일 때만 펄스, 모델 구슬은 localScale(원점이 끝이라 제자리), 임시 구슬은 SetOrbSize.
- 사진(rod_0~2, sheet): 통과. 3단계 모두 끝이 앞으로 뻗고 색(갈색/밝은 나무+붉은 실/금색+흰 실)과 고리가 보임. 1·2단계 끝에 금색 구슬.

## 참고(반려 사유 아님)
- 위치 계산은 Rod 부모 크기가 1이고 Rod 기본 길이가 1.4라는 전제(현재 카메라 자식 구조에서 성립). 부모 크기를 바꾸면 다시 맞춰야 함.
- 코드로 못 본 것: 유니티 안에서 FBX 재질 이름이 그대로 읽히는지는 사진(색이 맞게 나옴)으로 확인.
