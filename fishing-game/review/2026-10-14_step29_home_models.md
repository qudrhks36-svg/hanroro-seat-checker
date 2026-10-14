# 검수: 29단계 블렌더 모델 교체 ② 집 장식 (2026-10-14)

판정: **통과**

## 확인한 것
- make_home.py: 재질 이름 `C_RRGGBB`, 원점(바닥/걸이점/깃대/흔들 축), export 전 transform_apply(회전·크기 굽기), Hammock·FlagCloth 분리 모두 OK. GDD ② 설명과 일치.
- Home_*.fbx 8개 + meta 모두 Resources/Models 안에 있음 (Resources.Load 가능).
- HomeDecor.cs: SpawnModel은 모델이 없으면 null 반환 -> 8개 항목 전부 임시 도형으로 대체됨. 부모 아래 생성, Tint 캐시로 재질 교체(Shader.Find 없음).
- 중복 없음: 모델이 성공하면 도형은 안 만듦. 해먹/깃발은 "Hammock"/"FlagCloth"를 못 찾으면 모델을 Destroy한 뒤 도형으로 대체. 풍경은 모델 루트를 흔듦(원점 = 걸이점). 굴뚝은 -0.4 내려 연기 위치와 맞음.
- Update: hammock/flag/chime 모두 모델 또는 도형 어느 쪽이든 null 아님. 해먹 흔들림은 긴 축(Z)으로 바뀐 것도 모델 방향과 맞음.
- DecorShop/Home 상태 코드는 변경 없음, 회귀 없음.
- 스크린샷(hm5 sheet, front_night, hammock_day): 화분·파라솔·풍경·등불·모닥불·해먹·깃발·굴뚝 모두 보이고 야간 등불 빛도 정상.

## 참고(반려 사유 아님)
- 모닥불 가운데로 풀이 살짝 삐져나옴(섬 풀 배치 문제, 다음에 풀 위치 조정 가능).
- 해먹/깃발/풍경의 흔들림은 정지 화면이라 눈으로는 확인 못 함. 코드 경로상 문제 없음, 플레이로 확인 권장.
