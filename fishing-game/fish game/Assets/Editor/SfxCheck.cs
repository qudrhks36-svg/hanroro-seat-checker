using UnityEngine;

// 새 효과음이 비어 있지 않고 터지지 않는지(길이·최고점) 확인하는 시험 (GDD 2번). 실행: -executeMethod SfxCheck.Run
public static class SfxCheck
{
    public static void Run()
    {
        foreach (var k in new[] { SfxKind.Splash, SfxKind.NewFish, SfxKind.GoalDone })
        {
            var s = k == SfxKind.Splash ? SfxSynth.Splash() : k == SfxKind.NewFish ? SfxSynth.NewFish() : SfxSynth.GoalDone();
            float peak = 0f; int first = -1;
            for (int i = 0; i < s.Length; i++) { float a = Mathf.Abs(s[i]); if (a > peak) peak = a; if (first < 0 && a > 0.02f) first = i; }
            Debug.Log("SFXCHECK " + k + " len=" + (s.Length / (float)SfxSynth.Rate).ToString("0.00") + "s peak=" + peak.ToString("0.00") + " start=" + (first / (float)SfxSynth.Rate).ToString("0.00") + "s");
            if (peak < 0.3f || peak > 1f) { Debug.LogError("SFXCHECK 이상: " + k); EditorApplicationExit(1); }
        }
    }
    static void EditorApplicationExit(int c) { UnityEditor.EditorApplication.Exit(c); }
}
