using System;
using UnityEngine;

// 도감 기록: 종류별 잡은 마릿수와 최고 크기(cm). 저장·불러오기는 SaveData가 한다(GDD 8번).
public static class Collection
{
    public static readonly int[] Counts = new int[FishTable.All.Length];
    public static readonly int[] BestCm = new int[FishTable.All.Length];   // 종류별 최고 기록(0 = 아직 없음)

    // 종류별 크기 범위(cm), FishTable.All 순서: 고등어·도미·가자미·복어·오징어·구름고기·노을별고기·별똥고기·해마·해파리·달빛고기·무지개고기 (GDD 9번 [확정] 크기·기록)
    static readonly int[,] SizeRange = { { 25, 45 }, { 30, 60 }, { 20, 40 }, { 15, 35 }, { 20, 50 }, { 40, 90 }, { 40, 90 }, { 40, 90 }, { 10, 25 }, { 15, 45 }, { 40, 90 }, { 40, 90 } };

    // 크기 뽑기: 범위 가운데가 잘 나오고 양끝(아주 작거나 아주 큼)은 드물게
    public static int RollSize(FishData f)
    {
        int i = IndexOf(f);
        float t = (UnityEngine.Random.value + UnityEngine.Random.value) * 0.5f;
        return Mathf.RoundToInt(Mathf.Lerp(SizeRange[i, 0], SizeRange[i, 1], t));
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Array.Clear(Counts, 0, Counts.Length); Array.Clear(BestCm, 0, BestCm.Length); }

    public static int IndexOf(FishData f) { return Array.IndexOf(FishTable.All, f); }

    // 등록하고, 이미 잡아 본 물고기의 최고 기록을 넘었으면 true (처음 잡은 건 기록 갱신이 아니라 NEW)
    public static bool Register(FishData f, int cm)
    {
        int i = IndexOf(f);
        bool record = Counts[i] > 0 && cm > BestCm[i];
        Counts[i]++;
        if (cm > BestCm[i]) BestCm[i] = cm;
        return record;
    }

    public static int Discovered
    {
        get { int n = 0; foreach (var c in Counts) if (c > 0) n++; return n; }
    }
}
