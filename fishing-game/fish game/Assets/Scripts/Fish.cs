using UnityEngine;

public enum Rarity { Common, Uncommon, Rare }

public class FishData
{
    public string name;
    public Rarity rarity;
    public Period[] periods; // 잡히는 시간대
    public FishData(string name, Rarity rarity, params Period[] periods)
    {
        this.name = name; this.rarity = rarity; this.periods = periods;
    }
    public bool In(Period p) { return System.Array.IndexOf(periods, p) >= 0; }
}

// GDD 7번 물고기 표(1차 8종 + 2차 4종)와 시간대. 새 물고기는 맨 뒤에 붙여서 저장 파일·그림 순서가 어긋나지 않게 한다.
public static class FishTable
{
    const Period D = Period.Day, S = Period.Sunset, N = Period.Night;

    public static readonly FishData[] All =
    {
        new FishData("고등어", Rarity.Common, D, S, N),
        new FishData("도미", Rarity.Common, D),
        new FishData("가자미", Rarity.Common, D, S),
        new FishData("복어", Rarity.Uncommon, S),
        new FishData("오징어", Rarity.Uncommon, N),
        new FishData("구름고기", Rarity.Rare, D),
        new FishData("노을별고기", Rarity.Rare, S),
        new FishData("별똥고기", Rarity.Rare, N),
        new FishData("해마", Rarity.Uncommon, D, S),
        new FishData("해파리", Rarity.Uncommon, N),
        new FishData("달빛고기", Rarity.Rare, N),
        new FishData("무지개고기", Rarity.Rare, D, S),
    };

    public static string RarityName(Rarity r)
    {
        switch (r)
        {
            case Rarity.Common: return "흔함";
            case Rarity.Uncommon: return "보통";
            default: return "희귀";
        }
    }

    // 구분 확률은 미끼마다 다름(BaitInfo.Weights), 같은 구분 안에서는 균등.
    // 현재 시간대에 물고기가 없는 구분의 확률은 흔함으로 합친다 (GDD 7번).
    public static FishData Pick(Period period, Bait bait)
    {
        float[] w = BaitInfo.Weights(bait);
        var pool = new System.Collections.Generic.List<FishData>[3];
        for (int i = 0; i < 3; i++) pool[i] = new System.Collections.Generic.List<FishData>();
        foreach (var f in All) if (f.In(period)) pool[(int)f.rarity].Add(f);

        for (int i = 1; i < 3; i++)
            if (pool[i].Count == 0) { w[0] += w[i]; w[i] = 0f; }

        float roll = Random.value * (w[0] + w[1] + w[2]);
        int tier = roll < w[0] ? 0 : roll < w[0] + w[1] ? 1 : 2;
        var list = pool[tier];
        return list[Random.Range(0, list.Count)];
    }
}
