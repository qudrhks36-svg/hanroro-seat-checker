public enum Bait { Worm, Shrimp, Bread }

// 미끼 3종의 이름과 효과 (GDD 6번 [확정]): 입질까지 대기 시간, 흔함/보통/희귀 확률(%).
public static class BaitInfo
{
    public static string Name(Bait b)
    {
        switch (b)
        {
            case Bait.Worm: return "지렁이";
            case Bait.Shrimp: return "새우";
            default: return "빵 조각";
        }
    }

    public static float WaitMin(Bait b) { return b == Bait.Shrimp ? 5f : b == Bait.Bread ? 1.5f : 3f; }
    public static float WaitMax(Bait b) { return b == Bait.Shrimp ? 10f : b == Bait.Bread ? 4f : 8f; }

    public static float[] Weights(Bait b)
    {
        switch (b)
        {
            case Bait.Shrimp: return new[] { 65f, 25f, 10f };
            case Bait.Bread: return new[] { 72.5f, 25f, 2.5f };
            default: return new[] { 70f, 25f, 5f };
        }
    }
}
