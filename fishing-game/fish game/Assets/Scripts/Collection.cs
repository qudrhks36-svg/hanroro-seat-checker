using System;
using UnityEngine;

// 도감 기록: 종류별 잡은 마릿수. 저장·불러오기는 SaveData가 한다(GDD 8번).
public static class Collection
{
    public static readonly int[] Counts = new int[FishTable.All.Length];

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Array.Clear(Counts, 0, Counts.Length); }

    public static int IndexOf(FishData f) { return Array.IndexOf(FishTable.All, f); }

    public static void Register(FishData f) { Counts[IndexOf(f)]++; }

    public static int Discovered
    {
        get { int n = 0; foreach (var c in Counts) if (c > 0) n++; return n; }
    }
}
