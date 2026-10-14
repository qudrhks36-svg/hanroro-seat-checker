using UnityEngine;

// NPC가 말 걸 때 나는 소리 종류 (GDD 2번).
public enum TalkVoice { None, Seagull, Cat, Merchant }

// 코드로 만든 효과음 (GDD 2번 [확정]: 소리 파일이 없어서 합성으로 시작). 소리 하나 = 모노 샘플 배열.
public static class SfxSynth
{
    public const int Rate = 44100;

    // 소리 종류에 맞는 재생용 클립(없으면 null). 나중에 진짜 소리 파일로 바꾸려면 여기만 바꾸면 됨.
    public static AudioClip Clip(TalkVoice v)
    {
        float[] samples = null;
        switch (v)
        {
            case TalkVoice.Seagull: samples = Seagull(); break;
            case TalkVoice.Cat: samples = Cat(); break;
            case TalkVoice.Merchant: samples = Merchant(); break;
        }
        if (samples == null) return null;
        var clip = AudioClip.Create(v.ToString(), samples.Length, 1, Rate, false);
        clip.SetData(samples, 0);
        return clip;
    }

    // 갈매기 끼룩이: "끼-룩 끼룩" 세 번. 음높이가 올라갔다 내려오는 거친(떨리는) 소리.
    public static float[] Seagull()
    {
        var rnd = new System.Random(7);
        float[] startAt = { 0f, 0.30f, 0.54f };       // 각 울음의 시작(초)
        float[] length = { 0.26f, 0.24f, 0.30f };     // 길이(초)
        float[] pitch = { 1.00f, 1.08f, 0.92f };      // 높낮이 변화
        var o = new float[(int)(Rate * 0.95f)];
        for (int k = 0; k < startAt.Length; k++) Call(o, rnd, startAt[k], length[k], pitch[k]);
        Normalize(o, 0.8f);
        return o;
    }

    // ---- 낚시 효과음 (GDD 2번 [제안]) : 잡음 없이 맑고 짧게 ----

    // 던지기 "휙": 음높이가 쭉 올라갔다 내려오는 가벼운 소리
    public static float[] Cast()
    {
        var o = new float[(int)(Rate * 0.32f)];
        double phase = 0;
        for (int i = 0; i < o.Length; i++)
        {
            float t = i / (float)o.Length;
            float f = Mathf.Lerp(320f, 900f, Mathf.Sin(t * Mathf.PI * 0.5f)) * (1f - 0.25f * t * t);   // 빨리 올라가고 끝에서 살짝 처짐
            phase += 2.0 * Mathf.PI * f / Rate;
            float env = Mathf.Sin(Mathf.PI * t); env *= env;                                          // 종 모양으로 커졌다 작아짐
            o[i] = (Mathf.Sin((float)phase) + 0.25f * Mathf.Sin(2f * (float)phase)) * env;
        }
        Normalize(o, 0.5f);                         // 길게 이어지는 소리라 작게 맞춤
        return o;
    }

    // 입질 "띠링": 밝은 두 음(느낌표가 뜨는 순간)
    public static float[] Bite()
    {
        var o = new float[(int)(Rate * 0.45f)];
        Bell(o, 0.00f, 880f, 0.30f, 1f, 7f);
        Bell(o, 0.11f, 1318.5f, 0.34f, 1f, 6f);
        Normalize(o, 0.8f);
        return o;
    }

    // 낚기 성공 "딩딩딩딩~": 밝게 올라가는 네 음(도·미·솔·높은 도)
    public static float[] Catch()
    {
        var o = new float[(int)(Rate * 0.85f)];
        float[] notes = { 523.25f, 659.25f, 783.99f, 1046.5f };
        for (int k = 0; k < 4; k++) Bell(o, k * 0.095f, notes[k], k == 3 ? 0.55f : 0.30f, k == 3 ? 1f : 0.8f, k == 3 ? 4f : 7f);
        Normalize(o, 0.8f);
        return o;
    }

    // 물보라 "퐁": 높은 음에서 낮은 음으로 뚝 떨어지는 물방울 소리 + 작은 방울 하나
    public static float[] Splash()
    {
        var o = new float[(int)(Rate * 0.3f)];
        Drop(o, 0f, 0.16f, 720f, 240f, 1f);
        Drop(o, 0.07f, 0.1f, 980f, 420f, 0.35f);
        Normalize(o, 0.55f);
        return o;
    }

    static void Drop(float[] o, float startSec, float lenSec, float f0, float f1, float amp)
    {
        int a = (int)(startSec * Rate), n = (int)(lenSec * Rate);
        double phase = 0;
        for (int i = 0; i < n && a + i < o.Length; i++)
        {
            float t = i / (float)n;
            phase += 2.0 * Mathf.PI * Mathf.Lerp(f0, f1, Mathf.Sqrt(t)) / Rate;
            float env = Mathf.Min(1f, i / (0.003f * Rate)) * Mathf.Exp(-5f * t);
            o[a + i] += Mathf.Sin((float)phase) * env * amp;
        }
    }

    // 새 물고기 도감 등록 "띠-링": 낚기 소리(0.85초)가 끝나갈 즈음 맑고 높은 두 음
    public static float[] NewFish()
    {
        var o = new float[(int)(Rate * 1.45f)];
        Bell(o, 0.55f, 1318.5f, 0.35f, 0.8f, 6f);
        Bell(o, 0.70f, 1760f, 0.75f, 1f, 4f);
        Normalize(o, 0.7f);
        return o;
    }

    // 오늘의 목표 달성 팡파르: 올라가는 세 음 + 마지막은 길게 (앞 소리들이 끝난 뒤에 시작)
    public static float[] GoalDone()
    {
        var o = new float[(int)(Rate * 2.8f)];
        float[] notes = { 783.99f, 987.77f, 1174.66f, 1567.98f };
        for (int k = 0; k < 4; k++) Bell(o, 1.45f + k * 0.12f, notes[k], k == 3 ? 0.9f : 0.3f, k == 3 ? 1f : 0.8f, k == 3 ? 3.5f : 6f);
        Normalize(o, 0.75f);
        return o;
    }

    // 낚싯대 구매 "착-띠링": 낮고 짧은 "착" 한 번 + 반짝이는 두 음
    public static float[] Upgrade()
    {
        var o = new float[(int)(Rate * 1.1f)];
        Soft(o, 0f, 0.12f, 220f, 150f, 0.9f);
        Bell(o, 0.14f, 1046.5f, 0.35f, 0.8f, 6f);
        Bell(o, 0.26f, 1568f, 0.8f, 1f, 4f);
        Normalize(o, 0.7f);
        return o;
    }

    // 놓침 "뿌-웅": 낮게 내려가는 두 음. 동그랗고 부드럽게
    public static float[] Miss()
    {
        var o = new float[(int)(Rate * 0.62f)];
        Soft(o, 0.00f, 0.22f, 392f, 330f, 1f);     // 솔 → 미 쪽으로 처지며
        Soft(o, 0.24f, 0.36f, 294f, 233f, 0.9f);   // 레 → 낮은 시 b 쪽으로 더 처짐
        Normalize(o, 0.36f);                        // 낮은 소리는 같은 최고점이어도 훨씬 크게 들려서 작게 맞춤
        return o;
    }

    // 판매 "짤랑": 동전 두 개가 부딪히는 소리(금속 느낌의 배음)
    public static float[] Sell()
    {
        var o = new float[(int)(Rate * 0.6f)];
        float[] partial = { 1f, 2.76f, 5.4f };      // 금속 소리는 배음이 정수배가 아님
        float[] gain = { 1f, 0.45f, 0.18f };
        for (int k = 0; k < 2; k++)
            for (int p = 0; p < 3; p++)
                Bell(o, k * 0.085f, (k == 0 ? 1568f : 2093f) * partial[p], 0.28f, gain[p] * (k == 0 ? 1f : 0.85f), 11f);
        Normalize(o, 0.8f);
        return o;
    }

    // 종소리 한 번: 순식간에 시작해서 지수적으로 사라지는 맑은 소리(+옅은 2배음)
    static void Bell(float[] o, float startSec, float freq, float lenSec, float amp, float decay)
    {
        int a = (int)(startSec * Rate), n = (int)(lenSec * Rate);
        for (int i = 0; i < n && a + i < o.Length; i++)
        {
            float t = i / (float)n;
            float x = 2f * Mathf.PI * freq * i / Rate;
            float env = Mathf.Min(1f, i / (0.004f * Rate)) * Mathf.Exp(-decay * t) * Mathf.SmoothStep(0f, 1f, (n - i) / (0.02f * Rate));
            o[a + i] += (Mathf.Sin(x) + 0.25f * Mathf.Sin(2f * x)) * env * amp;
        }
    }

    // 부드러운 낮은 음 하나: 시작 음높이에서 끝 음높이로 처짐. 둥근 소리(셋째 배음만 아주 조금)
    static void Soft(float[] o, float startSec, float lenSec, float f0, float f1, float amp)
    {
        int a = (int)(startSec * Rate), n = (int)(lenSec * Rate);
        double phase = 0;
        for (int i = 0; i < n && a + i < o.Length; i++)
        {
            float t = i / (float)n;
            phase += 2.0 * Mathf.PI * Mathf.Lerp(f0, f1, t) / Rate;
            float env = Mathf.SmoothStep(0f, 1f, i / (0.03f * Rate)) * Mathf.SmoothStep(0f, 1f, (n - i) / (0.08f * Rate));
            o[a + i] += (Mathf.Sin((float)phase) + 0.2f * Mathf.Sin(3f * (float)phase)) * env * amp;
        }
    }

    // 고양이 모카: 상인처럼 짧고 부드러운 소리가 반복되는 NPC 느낌 "냐-냥-냐". 동물을 흉내 내지 않고 귀엽게.
    // 낮고(440~520Hz) 둥글게(높은 소리를 많이 줄임), 잡음 없음.
    public static float[] Cat()
    {
        var o = new float[(int)(Rate * 0.62f)];
        float[] start = { 0.02f, 0.21f, 0.40f }, amp = { 1f, 0.85f, 0.7f }, basePitch = { 470f, 520f, 440f };
        for (int k = 0; k < 3; k++)
        {
            float b = basePitch[k]; bool falling = k == 2;
            Voiced(o, start[k], 0.15f,
                t => falling ? b * (1.05f - 0.15f * t) : b * (0.94f + 0.14f * Mathf.Sin(Mathf.PI * t)),   // 살짝 올랐다 내려오는 귀여운 높낮이(마지막은 내려감)
                t => Mathf.Lerp(500f, 800f, t),                                                           // "ㄴ→ㅑ" 입이 열림
                t => Mathf.Lerp(1900f, 1400f, t),
                0f, 0f, amp[k], null, 0.01f, 0f, 1.1f);                                                   // 높은 소리 없음, 부드럽게
        }
        Normalize(o, 0.8f);
        return o;
    }

    // 상인 돌쇠: 호탕한 "허-허-허". 낮은 아저씨 목소리 세 번, 점점 작아지고 낮아짐.
    public static float[] Merchant()
    {
        var o = new float[(int)(Rate * 0.85f)];
        float[] start = { 0.02f, 0.26f, 0.50f }, amp = { 1f, 0.8f, 0.6f }, low = { 1f, 0.95f, 0.88f };
        for (int k = 0; k < 3; k++)
        {
            float lk = low[k];
            Voiced(o, start[k], 0.19f,
                t => Mathf.Lerp(135f, 105f, t) * lk,       // 낮은 목소리, 끝에서 살짝 내려옴
                t => 620f, t => 1050f,                      // "어" 모음
                0f, 0f, amp[k]);
        }
        Normalize(o, 0.8f);
        return o;
    }

    // 목소리 만들기: 기본 음 + 배음들을 입 모양(포먼트 두 개) 모양으로 걸러서 합침. 잡음은 넣지 않음.
    // f0/f1/f2: 소리 안에서의 위치(0~1) → Hz. vibHz/vibDepth: 떨림. amp: 크기.
    // ampCurve: 소리 안에서의 위치(0~1) → 크기 배율(없으면 1). jitter: 음높이 불규칙 흔들림 정도(살아있는 목소리 느낌).
    // f3Gain: 3천Hz대 높은 입 모양(포먼트 3)의 세기(날카롭고 밝은 소리, 0이면 없음).
    static void Voiced(float[] o, float startSec, float lenSec, System.Func<float, float> f0, System.Func<float, float> f1, System.Func<float, float> f2,
                       float vibHz, float vibDepth, float amp, System.Func<float, float> ampCurve = null, float jitter = 0f, float f3Gain = 0f, float rolloff = 0.7f)
    {   // rolloff: 클수록 높은 배음이 빨리 줄어 소리가 둥글고 부드러움(작으면 날카로움)
        int a = (int)(startSec * Rate), n = (int)(lenSec * Rate);
        double phase = 0;
        var rnd = new System.Random(11);
        float wob = 0f, target = 0f;
        for (int i = 0; i < n && a + i < o.Length; i++)
        {
            float t = i / (float)n;
            if (i % 441 == 0) target = (float)rnd.NextDouble() * 2f - 1f;       // 약 10ms마다 새 목표, 부드럽게 따라감
            wob += (target - wob) * 0.004f;
            float f = f0(t) * (1f + vibDepth * Mathf.Sin(2f * Mathf.PI * vibHz * i / Rate)) * (1f + jitter * wob);
            phase += 2.0 * Mathf.PI * f / Rate;
            float F1 = f1(t), F2 = f2(t), s = 0f;
            for (int h = 1; h * f < 9000f; h++)                                  // 배음을 9천Hz 아래까지만(깨진 소리 방지)
            {
                float hf = h * f;
                float g = Mathf.Exp(-0.5f * Mathf.Pow((hf - F1) / 160f, 2f)) + 0.6f * Mathf.Exp(-0.5f * Mathf.Pow((hf - F2) / 260f, 2f))
                        + f3Gain * Mathf.Exp(-0.5f * Mathf.Pow((hf - 3200f) / 400f, 2f)) + 0.03f;
                s += g / Mathf.Pow(h, rolloff) * Mathf.Sin(h * (float)phase);
            }
            float env = Mathf.SmoothStep(0f, 1f, i / (0.04f * Rate)) * Mathf.SmoothStep(0f, 1f, (n - i) / (0.06f * Rate));  // 부드러운 시작·끝
            o[a + i] += s * env * amp * (ampCurve != null ? ampCurve(t) : 1f);
        }
    }

    static void Call(float[] o, System.Random rnd, float start, float len, float pitch)
    {
        int a = (int)(start * Rate), n = (int)(len * Rate);
        double phase = 0, lp = 0;
        for (int i = 0; i < n && a + i < o.Length; i++)
        {
            float t = i / (float)n;                                              // 0~1
            // 음높이: 1400Hz에서 올라 25% 지점에 2300Hz, 끝에서 1700Hz로 내려옴
            float f = t < 0.25f ? Mathf.Lerp(1400f, 2300f, t / 0.25f) : Mathf.Lerp(2300f, 1700f, (t - 0.25f) / 0.75f);
            f *= pitch * (1f + 0.02f * Mathf.Sin(2f * Mathf.PI * 22f * i / Rate));  // 아주 약한 떨림(깔끔하게)
            phase += 2.0 * Mathf.PI * f / Rate;
            // 배음은 약하게만: 맑은 휘파람 같은 소리에 살짝 새 느낌. 잡음(숨소리)은 넣지 않음
            float s = Mathf.Sin((float)phase) + 0.30f * Mathf.Sin(2f * (float)phase) + 0.10f * Mathf.Sin(3f * (float)phase);
            lp += 0.35 * (s - lp);                                               // 높은 쪽을 눌러 부드럽게
            float fadeIn = Mathf.SmoothStep(0f, 1f, i / (0.035f * Rate));        // 35ms에 걸쳐 부드럽게 시작
            float fadeOut = Mathf.SmoothStep(0f, 1f, (n - i) / (0.030f * Rate));  // 끝도 부드럽게(딱 소리 방지)
            float env = fadeIn * fadeOut * Mathf.Exp(-2.6f * t);
            o[a + i] += (float)lp * env;
        }
    }

    static void Normalize(float[] x, float peakTarget)
    {
        float peak = 0f; foreach (var v in x) peak = Mathf.Max(peak, Mathf.Abs(v));
        if (peak > 1e-6f) { float g = peakTarget / peak; for (int i = 0; i < x.Length; i++) x[i] *= g; }
    }
}
