using UnityEngine;

public enum Period { Day, Sunset, Night }

// 하루 10분: 낮 4분 → 노을 2분 → 밤 4분 (GDD 7번). 조명·하늘·안개·바다 색은 키프레임 사이를 부드럽게 보간한다 (GDD 8번 1단계).
// Time.deltaTime을 쓰므로 도감·대화 중(timeScale 0)에는 시계도 멈춘다.
public class TimeOfDay : MonoBehaviour
{
    public static Period Current { get; private set; }
    public static float Night { get; private set; }   // 0=낮 … 1=한밤 (반딧불 같은 밤 장식이 읽음)

    public Light sun;
    public float dayLength = 600f;
    public float startClock = 0f;   // 0 = 낮의 시작

    float clock;

    struct Look
    {
        public float pitch, intensity;
        public Color light, ambient;
        public Color skyTop, glow, fog, seaShallow, seaDeep, seaFoam;   // 하늘 위쪽, 해 빛무리, 안개·지평선, 바다 얕은/깊은 색, 거품·반짝임 색
        public float skyGlow, stars, seaGlint;
    }
    static Color C(float r, float g, float b) { return new Color(r, g, b); }

    static readonly Look DayLook = new Look
    {
        pitch = 55f, intensity = 2f, light = C(1f, 0.97f, 0.92f), ambient = C(0.45f, 0.50f, 0.60f),
        skyTop = C(0.30f, 0.58f, 0.96f), glow = C(1f, 0.97f, 0.85f), fog = C(0.80f, 0.91f, 0.97f),
        seaShallow = C(0.38f, 0.82f, 0.80f), seaDeep = C(0.12f, 0.45f, 0.65f), seaFoam = C(1f, 1f, 0.96f),
        skyGlow = 0.7f, stars = 0f, seaGlint = 0.9f,
    };
    static readonly Look SunsetLook = new Look
    {
        pitch = 11f, intensity = 2f, light = C(1f, 0.58f, 0.32f), ambient = C(0.62f, 0.46f, 0.48f),
        skyTop = C(0.36f, 0.34f, 0.70f), glow = C(1f, 0.62f, 0.30f), fog = C(0.99f, 0.68f, 0.52f),
        seaShallow = C(0.95f, 0.64f, 0.56f), seaDeep = C(0.36f, 0.32f, 0.56f), seaFoam = C(1f, 0.88f, 0.75f),
        skyGlow = 1.3f, stars = 0f, seaGlint = 1.3f,
    };
    static readonly Look NightLook = new Look
    {
        pitch = -25f, intensity = 0f, light = C(0.4f, 0.5f, 0.9f), ambient = C(0.14f, 0.18f, 0.36f),
        skyTop = C(0.03f, 0.05f, 0.17f), glow = C(0.5f, 0.6f, 1f), fog = C(0.09f, 0.12f, 0.26f),
        seaShallow = C(0.14f, 0.27f, 0.44f), seaDeep = C(0.04f, 0.08f, 0.21f), seaFoam = C(0.62f, 0.72f, 0.96f),
        skyGlow = 0.0f, stars = 1f, seaGlint = 0.5f,
    };

    // 키프레임(초): 0~210 낮, 210~270 낮→노을, 270~330 노을, 330~390 노을→밤, 390~570 밤, 570~600 밤→낮
    static readonly float[] Times = { 0f, 210f, 270f, 330f, 390f, 570f, 600f };
    static readonly Look[] Looks = { DayLook, DayLook, SunsetLook, SunsetLook, NightLook, NightLook, DayLook };

    void Awake()
    {
        clock = startClock;
        RenderSettings.sun = sun;
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        RenderSettings.fog = true;
        RenderSettings.fogMode = FogMode.ExponentialSquared;
        RenderSettings.fogDensity = 0.010f;   // 먼 바다 끝이 하늘과 이어지도록
        Apply(clock);
    }

    void Update()
    {
        clock = (clock + Time.deltaTime) % dayLength;
        Apply(clock);
    }

    public static Period PeriodAt(float t)
    {
        return t < 240f ? Period.Day : t < 360f ? Period.Sunset : Period.Night;
    }

    // 색의 밝기만 남기고 회색 쪽으로 amount만큼 섞은 뒤 dim을 곱함
    static Color Grey(Color c, float amount, float dim)
    {
        float l = c.r * 0.3f + c.g * 0.59f + c.b * 0.11f;
        var g = Color.Lerp(c, new Color(l, l, l), amount);
        return new Color(g.r * dim, g.g * dim, g.b * dim, c.a);
    }

    public void Apply(float t)
    {
        Current = PeriodAt(t);
        int i = 0;
        while (i < Times.Length - 2 && t >= Times[i + 1]) i++;
        float k = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(Times[i], Times[i + 1], t));
        Look a = Looks[i], b = Looks[i + 1];

        sun.transform.rotation = Quaternion.Euler(Mathf.Lerp(a.pitch, b.pitch, k), 330f, 0f);
        float o = Weather.Overcast;   // 흐림·비일 때 회색빛으로 (GDD 9번 날씨)
        sun.color = Color.Lerp(a.light, b.light, k);
        sun.intensity = Mathf.Lerp(a.intensity, b.intensity, k) * (1f - 0.5f * o);
        RenderSettings.ambientLight = Color.Lerp(a.ambient, b.ambient, k);
        RenderSettings.fogColor = Grey(Color.Lerp(a.fog, b.fog, k), o * 0.75f, 1f - 0.12f * o);

        // 하늘(SkyGradient)과 바다(Sea) 셰이더가 읽는 전역 값
        Shader.SetGlobalColor("_SkyTop", Grey(Color.Lerp(a.skyTop, b.skyTop, k), o * 0.8f, 1f - 0.1f * o));
        Shader.SetGlobalColor("_SkyGlowColor", Color.Lerp(a.glow, b.glow, k));
        Shader.SetGlobalVector("_SunDir", -sun.transform.forward);
        Shader.SetGlobalFloat("_SkyGlow", Mathf.Lerp(a.skyGlow, b.skyGlow, k) * (1f - 0.8f * o));
        Night = Mathf.Lerp(a.stars, b.stars, k);
        Shader.SetGlobalFloat("_Stars", Night);
        Shader.SetGlobalColor("_SeaShallow", Grey(Color.Lerp(a.seaShallow, b.seaShallow, k), o * 0.5f, 1f - 0.2f * o));
        Shader.SetGlobalColor("_SeaDeep", Grey(Color.Lerp(a.seaDeep, b.seaDeep, k), o * 0.5f, 1f - 0.2f * o));
        Shader.SetGlobalColor("_SeaFoam", Color.Lerp(a.seaFoam, b.seaFoam, k));
        Shader.SetGlobalFloat("_SeaGlint", Mathf.Lerp(a.seaGlint, b.seaGlint, k) * (1f - 0.7f * o));
    }
}
