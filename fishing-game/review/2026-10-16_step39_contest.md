# 검수: 39단계 낚시 대회 (2026-10-16)

## 결과: 통과 (조건부 메모 2건, 반려 사유 없음)

## 근거
1. GDD 일치: 3분(180초), 상금 20/50/100, 신기록 +30, 못 잡으면 참가상 10 모두 코드와 같음. 마감 시 Biting·Reeling이면 Finish를 미루고 Catch 뒤 다음 프레임에 마감(OnCatch는 Active 중이라 그 한 마리 반영). 시간은 Time.deltaTime이고 대화창·도감은 timeScale 0이라 멈춤. 결과 카드는 unscaledTime 7초.
2. 상태 꼬임 없음: CanStart = 비활성 + 낚싯대 Idle + FarSea 이동 중 아님. Finish는 Active를 먼저 false로 바꿔 두 번 불리지 않음. 먼 바다 배 이동·복귀는 시간이 계속 흐르고 영향 없음. Reset(SubsystemRegistration)이 SaveData.Load(BeforeSceneLoad)보다 먼저라 contestBest가 지워지지 않음. 장면 다시 로드 시 rod 참조가 null이면 다시 찾음.
3. FishingRod.Catch 호출 위치, ShopNPC C 키(SetOpen(false)로 timeScale 복구 후 시작)·안내 알약, SaveData contestBest(옛 저장은 필드 없음 = 0, Max(0)으로 방어) 모두 올바름.
4. DialogView 폭·알약 수는 늘리기만 했고 TalkNPC(알약 3개 이하)·DecorShop 레이아웃은 x를 왼쪽부터 쌓는 방식이라 안 깨짐. Sfx.Play의 isPlaying 가드는 Application.isPlaying이며 실제 게임에선 항상 참이라 영향 없음. 사진(대화창 알약 5개, 진행 알약, 결과 카드)도 확인함.
5. changelog 내용은 코드·GDD와 일치(알약 위치 "오른쪽 위", 폭 900→1080 등).

## 남은 위험 / 메모
- GDD는 알약 위치를 "화면 위쪽 가운데"라고 쓰고 코드는 오른쪽 위(changelog도 오른쪽 위). 위치를 GDD 쪽으로 고치거나 GDD 문구를 "오른쪽 위"로 정정 필요(지시: GDD 먼저).
- 대화창 폭 1080은 CanvasScaler가 없어 1080px보다 좁은 창에서는 잘림(이전 900). 웹 창 크기 확인 필요.
- DialogView 주석 "알약(최대 3개)"이 낡음(사소).
- 사진의 막대기가 F 알약을 가린 것은 시험용 카메라 렌더 때문(실제 오버레이에선 해당 없음). 실제 플레이(C 시작·3분 마감·배 이동)는 사용자 확인 필요.
