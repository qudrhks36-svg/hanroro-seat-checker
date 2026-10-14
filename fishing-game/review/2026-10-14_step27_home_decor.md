# 검수: 27단계 집 꾸미기(장식 5개 + 오두막 키우기) - 통과

검수 담당 / 2026-10-14 / 기준: GDD 9번 [확정, 사용자 선택 2026-10-14] "집 꾸미기"

## 항목별
- 사기 규칙: 통과. Home.BuyItem은 이미 샀거나 돈이 모자라면 false, 성공 때만 돈을 깎고 비트를 켬. BuyCabin도 최대면 막고 가격(300/800)대로 한 단계씩만. 사고 나면 Save + 구매 소리.
- 보이기: 통과. 매 프레임 소유 비트대로 SetActive, 오두막 단계가 바뀔 때만 ApplyCabin. 2단계 지붕 덮개·굴뚝·연기, 3단계 깃발·등불·창문 불빛(밤에만 켜짐). 사진(front/chimney)에서 확인.
- 널 안전: 통과. CloudDrift(구름 재질)가 없으면 경고 후 컴포넌트 끔(Update 안 돎). Island/Cabin이나 Mat_Roof/Mat_Window가 없으면 roofMat·windowMat null 검사로 건너뜀.
- 재질: 통과. Tint가 색별 Dictionary 캐시라 늘어나지 않음, Shader.Find 없음(구름 재질 복사), 파티클은 Resources의 Mat_Droplet.
- 움직임·빛: 통과. 흔들림은 Time.time, 풍경 소리는 Time.deltaTime(시간 정지 중 멈춤). 모닥불 (0.8+밤*2.2), 등불 2.2, 창문 1.4. 풍경 AudioSource는 3D(spatialBlend 1, 3~30m), 10~22초 간격.
- 창 처리(DecorShop): 통과. 열린 프레임은 openFrame으로 건너뛰고, 닫는 프레임은 ClosedFrame 기록. 시간·커서는 건드리지 않음(ShopNPC가 이미 정지·해제).
- 실행 순서: 통과. ShopNPC(-20)가 F로 Open -> 같은 프레임 DecorShop(-10) Update는 openFrame 때문에 return, 즉시 닫힘 없음. DecorShop이 F/Esc로 닫는 프레임엔 ShopNPC가 이미 먼저 돌았고(IsOpen=true라 return), 다음 프레임엔 wasPressed가 풀려 이중 처리 없음. ShopNPC.IsOpen은 계속 true라 PlayerController·GuideHint·CatalogUI·SeaEvents·TalkNPC 판단이 그대로.
- 숫자 키: 통과. 1~5 장식, 6 오두막, 한 프레임에 하나만(break). 이미 있음/돈 모자람 문구와 Refresh 정상.
- ShopNPC·DialogView: 통과. 안내 칸 최대 4개(팔기·낚싯대·F·닫기), MaxChips 3->4. TalkNPC는 안내 칸이 더 적어 영향 없음. 사진(home_dialog)에서 4칸이 판 안에 들어옴.
- 저장: 통과. decor는 (1<<5)-1로 마스크, cabin은 0~2로 Clamp, 옛 저장엔 필드 없음 -> 0(JsonUtility 기본값). 시작 때 Reset으로 0 초기화.
- SfxSynth.Chime: 통과. 2.6초, 종소리 3번, Normalize 0.55.

## 참고(반려 사유 아님)
- home_shop 사진에서 6번 줄 설명("예쁜 오두막 (깃발, 등불, 창문 불빛)")이 330폭에 거의 꽉 참. 글꼴이 달라지면 잘릴 수 있으니 플레이에서 확인.
- 사진에선 낚싯대가 창·안내 칸 위로 겹쳐 보임(UI가 아닌 3D라서, 이번 단계 이전부터 있던 모습).
- 실제 F 열기/닫기, 구매 후 저장 왕복, 풍경 소리는 직접 플레이로 확인 필요.

결과: **통과**
