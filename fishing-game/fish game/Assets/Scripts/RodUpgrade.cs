using UnityEngine;

// 낚싯대 단계 (GDD 3번 [제안] 수치). 효과: 릴 감기 내 칸 너비. 저장·불러오기는 SaveData가 한다.
public static class RodUpgrade
{
    public static int Level;
    static readonly string[] Names = { "기본 낚싯대", "튼튼한 낚싯대", "반짝 낚싯대" };
    static readonly float[] Width = { 0.30f, 0.36f, 0.43f };
    static readonly int[] Cost = { 0, 200, 600 };

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Level = 0; }

    public static string Name { get { return Names[Level]; } }
    public static float ZoneWidth { get { return Width[Level]; } }
    public static int MaxLevel { get { return Names.Length - 1; } }
    public static bool IsMax { get { return Level >= MaxLevel; } }
    public static string NextName { get { return Names[Level + 1]; } }
    public static int NextCost { get { return Cost[Level + 1]; } }

    // 성공하면 true (돈이 모자라거나 최고 단계면 false)
    public static bool TryBuy()
    {
        if (IsMax || Inventory.Money < NextCost) return false;
        Inventory.Money -= NextCost;
        Level++;
        return true;
    }
}
