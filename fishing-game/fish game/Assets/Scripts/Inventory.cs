using System;
using UnityEngine;

// 보유 물고기(판매 대기)와 소지금. 도감 기록(Collection)과는 별개. 저장·불러오기는 SaveData가 한다(GDD 8번).
public static class Inventory
{
    public static readonly int[] Counts = new int[FishTable.All.Length];
    public static int Money;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Array.Clear(Counts, 0, Counts.Length); Money = 0; }

    public static void Add(FishData f) { Counts[Collection.IndexOf(f)]++; }

    // GDD [제안] 임시 가격
    public static int Price(FishData f)
    {
        int p = f.rarity == Rarity.Common ? 10 : f.rarity == Rarity.Uncommon ? 30 : 100;
        return f.farSea ? p * 3 / 2 : p;   // 먼 바다 물고기는 1.5배 (GDD 3번)
    }

    public static int TotalCount { get { int n = 0; foreach (var c in Counts) n += c; return n; } }

    public static int TotalValue
    {
        get
        {
            int v = 0;
            for (int i = 0; i < Counts.Length; i++) v += Counts[i] * Price(FishTable.All[i]);
            return v;
        }
    }

    // 배율을 곱해 반올림 (상인 돌쇠는 1.2배, GDD 3번)
    public static int ValueWith(float multiplier) { return Mathf.RoundToInt(TotalValue * multiplier); }

    public static int SellAll(float multiplier = 1f)
    {
        int earned = ValueWith(multiplier);
        Array.Clear(Counts, 0, Counts.Length);
        Money += earned;
        return earned;
    }
}
