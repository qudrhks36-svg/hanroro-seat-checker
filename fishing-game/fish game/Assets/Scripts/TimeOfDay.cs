using UnityEngine;
using UnityEngine.UI;

public enum Period { Day, Sunset, Night }

// 하루 10분: 낮 4분 → 노을 2분 → 밤 4분 (GDD 7번). 조명은 키프레임 사이를 부드럽게 보간한다.
// Time.deltaTime을 쓰므로 도감·대화 중(timeScale 0)에는 시계도 멈춘다.
public class TimeOfDay : MonoBehaviour
{
    public static Period Current { get; private set; }

    public Light sun;
    public float dayLength = 600f;
    public float startClock = 0f;   // 0 = 낮의 시작

    float clock;
    Text label;

    struct Look { public float pitch, intensity; public Color light, ambient; }
    static readonly Look DayLook = new Look { pitch = 55f, intensity = 2f, light = new Color(1f, 0.97f, 0.92f), ambient = new Color(0.45f, 0.50f, 0.60f) };
    static readonly Look SunsetLook = new Look { pitch = 6f, intensity = 1.6f, light = new Color(1f, 0.55f, 0.30f), ambient = new Color(0.50f, 0.35f, 0.38f) };
    static readonly Look NightLook = new Look { pitch = -25f, intensity = 0f, light = new Color(0.4f, 0.5f, 0.9f), ambient = new Color(0.10f, 0.13f, 0.28f) };

    // 키프레임(초): 0~210 낮, 210~270 낮→노을, 270~330 노을, 330~390 노을→밤, 390~570 밤, 570~600 밤→낮
    static readonly float[] Times = { 0f, 210f, 270f, 330f, 390f, 570f, 600f };
    static readonly Look[] Looks = { DayLook, DayLook, SunsetLook, SunsetLook, NightLook, NightLook, DayLook };

    void Awake()
    {
        clock = startClock;
        RenderSettings.sun = sun;
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        BuildLabel();
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

    public void Apply(float t)
    {
        Current = PeriodAt(t);
        int i = 0;
        while (i < Times.Length - 2 && t >= Times[i + 1]) i++;
        float k = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(Times[i], Times[i + 1], t));
        Look a = Looks[i], b = Looks[i + 1];

        sun.transform.rotation = Quaternion.Euler(Mathf.Lerp(a.pitch, b.pitch, k), 330f, 0f);
        sun.color = Color.Lerp(a.light, b.light, k);
        sun.intensity = Mathf.Lerp(a.intensity, b.intensity, k);
        RenderSettings.ambientLight = Color.Lerp(a.ambient, b.ambient, k);
        if (label != null) label.text = Current == Period.Day ? "낮" : Current == Period.Sunset ? "노을" : "밤";
    }

    void BuildLabel()
    {
        var canvasGo = new GameObject("TimeCanvas");
        canvasGo.transform.SetParent(transform, false);
        canvasGo.AddComponent<Canvas>().renderMode = RenderMode.ScreenSpaceOverlay;
        var go = new GameObject("PeriodLabel");
        go.transform.SetParent(canvasGo.transform, false);
        label = go.AddComponent<Text>();
        label.font = GameFont.Get();
        label.fontSize = 28; label.alignment = TextAnchor.LowerLeft;
        label.color = new Color(1f, 0.96f, 0.88f); label.raycastTarget = false;
        var rt = label.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0f, 0f);
        rt.anchoredPosition = new Vector2(30, 30); rt.sizeDelta = new Vector2(300, 50);
    }
}
