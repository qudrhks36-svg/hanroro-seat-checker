public enum Bait { Worm, Shrimp, Bread }

public static class BaitInfo
{
    // 표시 이름. 물고기별 효과는 5단계 이후 GDD에서 정해지면 여기에 붙인다.
    public static string Name(Bait b)
    {
        switch (b)
        {
            case Bait.Worm: return "지렁이";
            case Bait.Shrimp: return "새우";
            default: return "빵 조각";
        }
    }
}
