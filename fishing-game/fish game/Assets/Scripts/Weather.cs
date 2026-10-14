using UnityEngine;

public enum WeatherKind { Clear, Cloudy, Rain }

// 날씨 (GDD 9번 [확정]): 맑음 → 흐림 → 비로 이어지며 시간이 지나면 저절로 바뀐다. 낚시에는 영향 없고 분위기만 바꾼다(보기·아주 작은 빗소리).
// 하늘·안개·바다 색은 TimeOfDay가 Overcast(0~1)를 읽어 회색빛으로 바꾼다. 비는 카메라 위에서 내리는 빗줄기 파티클.
// 게임이 시작될 때 스스로 만들어진다(장면에 올릴 것 없음). Time.deltaTime을 쓰므로 도감·대화 중에는 멈춘다. 저장하지 않음(시간대처럼 시작은 항상 맑음).
public class Weather : MonoBehaviour
{
    public static WeatherKind Current { get; private set; }
    public static float Overcast { get; private set; }   // 0=맑음 … 0.6=흐림 … 1=비 (천천히 따라감)
    public static float Rain { get; private set; }       // 0~1 비의 세기(천천히 따라감)

    public static string Name(WeatherKind k) { return k == WeatherKind.Clear ? "맑음" : k == WeatherKind.Cloudy ? "흐림" : "비"; }

    const float ChangeMin = 70f, ChangeMax = 130f, FadeSeconds = 10f, RainSoundVolume = 0.06f;

    ParticleSystem rain;
    AudioSource rainSound;
    float timer;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Current = WeatherKind.Clear; Overcast = 0f; Rain = 0f; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("Weather").AddComponent<Weather>(); }

    void Awake()
    {
        timer = Random.Range(ChangeMin, ChangeMax);
        var go = new GameObject("RainStreaks"); go.transform.SetParent(transform, false);
        rain = go.AddComponent<ParticleSystem>(); rain.Stop();
        var m = rain.main; m.loop = true; m.playOnAwake = false; m.simulationSpace = ParticleSystemSimulationSpace.World;
        m.startLifetime = 0.8f; m.startSpeed = 0f; m.startSize = 0.05f; m.maxParticles = 1500;
        m.startColor = new Color(0.8f, 0.9f, 1f, 0.35f);
        var sh = rain.shape; sh.shapeType = ParticleSystemShapeType.Box; sh.scale = new Vector3(36f, 0.1f, 36f);
        var vel = rain.velocityOverLifetime; vel.enabled = true; vel.space = ParticleSystemSimulationSpace.World;
        vel.x = new ParticleSystem.MinMaxCurve(1.5f); vel.y = new ParticleSystem.MinMaxCurve(-17f); vel.z = new ParticleSystem.MinMaxCurve(0f);
        var em = rain.emission; em.rateOverTime = 0f;
        var r = go.GetComponent<ParticleSystemRenderer>();
        r.material = Resources.Load<Material>("Fx/Mat_Droplet");   // 빌드에서 셰이더가 빠지지 않게 Resources에서 읽음
        r.renderMode = ParticleSystemRenderMode.Stretch; r.velocityScale = 0.035f; r.lengthScale = 1f;
        r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        rain.Play();
    }

    void Update()
    {
        timer -= Time.deltaTime;
        if (timer <= 0f) { Current = Next(Current); timer = Random.Range(ChangeMin, ChangeMax); }

        float targetOver = Current == WeatherKind.Clear ? 0f : Current == WeatherKind.Cloudy ? 0.6f : 1f;
        float step = Time.deltaTime / FadeSeconds;
        Overcast = Mathf.MoveTowards(Overcast, targetOver, step);
        Rain = Mathf.MoveTowards(Rain, Current == WeatherKind.Rain ? 1f : 0f, step);

        var em = rain.emission; em.rateOverTime = 1000f * Rain;
        var cam = Camera.main;
        if (cam != null) rain.transform.position = cam.transform.position + Vector3.up * 9f + cam.transform.forward * 6f;   // 늘 시야 위·앞에서 내림
        UpdateSound();
    }

    // 맑음→{맑음 .4, 흐림 .6}, 흐림→{맑음 .4, 흐림 .2, 비 .4}, 비→{흐림 .7, 비 .3}. 비는 흐림을 거쳐서만 온다.
    static WeatherKind Next(WeatherKind k)
    {
        float v = Random.value;
        switch (k)
        {
            case WeatherKind.Clear: return v < 0.4f ? WeatherKind.Clear : WeatherKind.Cloudy;
            case WeatherKind.Cloudy: return v < 0.4f ? WeatherKind.Clear : v < 0.6f ? WeatherKind.Cloudy : WeatherKind.Rain;
            default: return v < 0.7f ? WeatherKind.Cloudy : WeatherKind.Rain;
        }
    }

    // ---- 아주 작은 빗소리: 부드러운 잡음(저역 통과)을 이음새 없이 반복 ----
    void UpdateSound()
    {
        if (rainSound == null)
        {
            if (Rain <= 0f) return;   // 비가 처음 올 때 만든다
            rainSound = gameObject.AddComponent<AudioSource>();
            rainSound.clip = MakeRainClip(); rainSound.loop = true; rainSound.spatialBlend = 0f; rainSound.volume = 0f;
            rainSound.Play();
        }
        rainSound.volume = RainSoundVolume * Rain;
    }

    static AudioClip MakeRainClip()
    {
        const int rate = 22050, len = rate * 4, cross = rate / 4;
        var rng = new System.Random(3);
        var buf = new float[len + cross];
        float lp = 0f, lp2 = 0f;
        for (int i = 0; i < buf.Length; i++)
        {
            float w = (float)rng.NextDouble() * 2f - 1f;
            lp += 0.35f * (w - lp); lp2 += 0.08f * (lp - lp2);      // 거친 소리는 깎고 부드럽게
            buf[i] = lp * 0.5f + lp2 * 1.2f;
        }
        var o = new float[len];
        for (int i = 0; i < len; i++) o[i] = buf[i];
        for (int i = 0; i < cross; i++) { float k = i / (float)cross; o[i] = buf[i] * k + buf[len + i] * (1f - k); }   // 끝과 처음을 이어 붙임
        float peak = 0f; foreach (var v in o) peak = Mathf.Max(peak, Mathf.Abs(v));
        for (int i = 0; i < len; i++) o[i] = o[i] / Mathf.Max(1e-4f, peak) * 0.8f;
        var clip = AudioClip.Create("Rain", len, 1, rate, false);
        clip.SetData(o, 0);
        return clip;
    }
}
