# 검수: 23단계 크기·기록 - 통과

검수 담당 / 2026-10-14 / 기준: GDD 9번 [확정, 사용자 선택 2026-10-14] "크기·기록"

## 항목별
- Collection.cs: 통과. SizeRange 8줄이 FishTable.All 순서(고등어·도미·가자미·복어·오징어·구름·노을별·별똥)와 같고 값이 GDD와 일치. RollSize는 두 난수의 평균이라 범위 안, 가운데가 잘 나옴. Register는 `Counts>0 && cm>Best`일 때만 true, 처음 잡은 건 false(NEW 우선). Reset에서 BestCm도 비움.
- SaveData.cs: 통과. best 저장·불러오기 있음. 옛 저장에 best가 없으면 null이라 건너뛰고 0 유지(오류 없음).
- FishingRod.Catch: 통과. cm은 한 번만 뽑아 Register와 ResultCard에 같이 넘김. Save는 Register 뒤.
- ResultCard.cs: 통과. 크기 글자는 이름 줄 오른쪽, 배지 글자는 NEW/기록 갱신 전환, 둘 다 아니면 숨김. 사진(31cm 기록 갱신, 67cm NEW)에서 겹침 없음.
- CatalogUI.cs: 통과. "최고 기록"은 잡은 물고기에만, 못 잡으면 "아직 못 잡았어요". 사진에서 줄이 패널 안에 들어옴.
- 판매 값: 통과. Inventory.Price(rarity)만 사용, 크기와 무관.

## 참고(반려 사유 아님)
- 기록 갱신 사진의 고등어는 31cm(범위 25~45 안), 별똥고기 67cm(40~90 안).
- 크기 추가 전 저장(잡은 수만 있고 best=0)은 첫 낚기가 "기록 갱신!"으로 뜰 수 있음. 한 번뿐이라 허용.
- 범위·분포는 임시값. 플레이해 보고 조정 필요. 반짝이는 연출은 사진으로 확인 못 함.

결과: **통과**
