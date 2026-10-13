using UnityEngine;

// 오늘의 목표 (GDD 9번 [확정]): 물고기 3마리를 낚으면 50원을 받고, 바로 다음 3마리 목표가 시작된다.
// 진행(Progress)은 SaveData가 저장·불러온다.
public static class Goal
{
    public const int Target = 3, Reward = 50;
    public static int Progress;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Progress = 0; }

    // 한 마리 낚을 때마다 부른다. 목표를 채우면 보상을 주고 true.
    public static bool OnCatch()
    {
        if (++Progress < Target) return false;
        Progress = 0;
        Inventory.Money += Reward;
        return true;
    }
}
