using System;
using UnityEngine;
using UnityEngine.UI;

// 상태창 (GDD 9번 [확정]): 시간대·미끼·소지금을 왼쪽 아래 둥근 판 하나에 `아이콘 + 글자` 줄로 모아 보여준다.
// 장면에 올려 둘 것이 없고, 게임이 시작될 때 스스로 만들어진다. 아이콘은 이미지 파일 없이 코드로 그린다.
public class HudPanel : MonoBehaviour
{
    const int Rows = 4, RowH = 46, Pad = 12, PanelW = 300;
    static readonly Color Cream = new Color(1f, 0.96f, 0.85f);
    static readonly Color Ink = new Color(0.08f, 0.05f, 0.03f, 0.9f);

    Image timeIcon, baitIcon;
    Text timeText, baitText, moneyText, dexText;
    Sprite[] timeIcons, baitIcons;
    FishingRod rod;
    Period shownPeriod = (Period)(-1);
    Bait shownBait = (Bait)(-1);
    int shownMoney = -1, shownDex = -1;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        var go = new GameObject("HudPanel");
        DontDestroyOnLoad(go);
        go.AddComponent<HudPanel>();
    }

    void Awake()
    {
        timeIcons = new[] { Sun(), Sunset(), Moon() };
        baitIcons = new[] { Worm(), Shrimp(), Bread() };
        var coin = Coin();
        var font = GameFont.Get();

        var canvas = new GameObject("HudCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 4;

        var panel = new GameObject("Panel").AddComponent<Image>();
        panel.transform.SetParent(canvas.transform, false);
        panel.sprite = RoundedRect(); panel.type = Image.Type.Sliced;
        panel.color = new Color(0.07f, 0.09f, 0.13f, 0.62f); panel.raycastTarget = false;
        var prt = panel.rectTransform;
        prt.anchorMin = prt.anchorMax = prt.pivot = Vector2.zero;
        prt.anchoredPosition = new Vector2(24, 24);
        prt.sizeDelta = new Vector2(PanelW, Pad * 2 + RowH * Rows);

        timeIcon = MakeIcon(prt, 0, null); timeText = MakeText(prt, 0, font, 26, TextAnchor.MiddleLeft, 170);
        baitIcon = MakeIcon(prt, 1, null); baitText = MakeText(prt, 1, font, 26, TextAnchor.MiddleLeft, 130);
        var hint = MakeText(prt, 1, font, 18, TextAnchor.MiddleRight, 70);
        hint.rectTransform.anchoredPosition = new Vector2(PanelW - 14 - 70, hint.rectTransform.anchoredPosition.y);
        hint.text = "1·2·3"; hint.color = new Color(1f, 0.96f, 0.85f, 0.65f);
        MakeIcon(prt, 2, coin); moneyText = MakeText(prt, 2, font, 26, TextAnchor.MiddleLeft, 200);
        MakeIcon(prt, 3, Book()); dexText = MakeText(prt, 3, font, 26, TextAnchor.MiddleLeft, 200);
    }

    void Update()
    {
        if (rod == null)
        {
            rod = FindFirstObjectByType<FishingRod>();
            if (rod != null && rod.baitLabel != null) rod.baitLabel.gameObject.SetActive(false);   // 예전 따로 떠 있던 미끼 글자
        }
        if (TimeOfDay.Current != shownPeriod)
        {
            shownPeriod = TimeOfDay.Current;
            timeIcon.sprite = timeIcons[(int)shownPeriod];
            timeText.text = shownPeriod == Period.Day ? "낮" : shownPeriod == Period.Sunset ? "노을" : "밤";
        }
        if (rod != null && rod.selectedBait != shownBait)
        {
            shownBait = rod.selectedBait;
            baitIcon.sprite = baitIcons[(int)shownBait];
            baitText.text = BaitInfo.Name(shownBait);
        }
        if (Inventory.Money != shownMoney)
        {
            shownMoney = Inventory.Money;
            moneyText.text = shownMoney + "원";
        }
        if (Collection.Discovered != shownDex)
        {
            shownDex = Collection.Discovered;
            bool done = shownDex >= FishTable.All.Length;
            dexText.text = done ? "도감 완성!" : "도감 " + shownDex + "/" + FishTable.All.Length;
            dexText.color = done ? new Color(1f, 0.85f, 0.3f) : Cream;
        }
    }

    // ---- 만들기 ----
    static float RowY(int row) { return -(Pad + RowH * row + RowH * 0.5f); }

    static Image MakeIcon(RectTransform parent, int row, Sprite sprite)
    {
        var img = new GameObject("Icon" + row).AddComponent<Image>();
        img.transform.SetParent(parent, false);
        img.sprite = sprite; img.raycastTarget = false; img.preserveAspect = true;
        var rt = img.rectTransform;
        rt.anchorMin = rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 0.5f);
        rt.anchoredPosition = new Vector2(14, RowY(row)); rt.sizeDelta = new Vector2(36, 36);
        return img;
    }

    static Text MakeText(RectTransform parent, int row, Font font, int size, TextAnchor align, float width)
    {
        var t = new GameObject("Text" + row).AddComponent<Text>();
        t.transform.SetParent(parent, false);
        t.font = font; t.fontSize = size; t.fontStyle = FontStyle.Bold; t.alignment = align;
        t.color = Cream; t.raycastTarget = false;
        var o = t.gameObject.AddComponent<Outline>(); o.effectColor = Ink; o.effectDistance = new Vector2(1.5f, -1.5f);
        var s = t.gameObject.AddComponent<Shadow>(); s.effectColor = new Color(0, 0, 0, 0.5f); s.effectDistance = new Vector2(2f, -2.5f);
        var rt = t.rectTransform;
        rt.anchorMin = rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 0.5f);
        rt.anchoredPosition = new Vector2(62, RowY(row)); rt.sizeDelta = new Vector2(width, 40);
        return t;
    }

    // ---- 그림 (모양 함수: 좌표 -1..1 → 색, 알파 0이면 비어 있음) ----
    internal static Sprite RoundedRect()
    {
        const int n = 48; const float r = 14f;
        var tex = new Texture2D(n, n, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear };
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                float dx = Mathf.Max(r - x - 0.5f, x + 0.5f - (n - r), 0f), dy = Mathf.Max(r - y - 0.5f, y + 0.5f - (n - r), 0f);
                tex.SetPixel(x, y, new Color(1, 1, 1, Mathf.Clamp01(r - Mathf.Sqrt(dx * dx + dy * dy) + 0.5f)));
            }
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, n, n), new Vector2(0.5f, 0.5f), 100f, 0, SpriteMeshType.FullRect, new Vector4(16, 16, 16, 16));
    }

    static Sprite Paint(Func<Vector2, Color> shape)
    {
        const int n = 64;
        var col = new Color[n * n];
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                Color sum = Color.clear; float a = 0f;   // 2x2 샘플로 가장자리를 부드럽게
                for (int k = 0; k < 4; k++)
                {
                    var p = new Vector2((x + 0.25f + 0.5f * (k % 2)) / n * 2f - 1f, (y + 0.25f + 0.5f * (k / 2)) / n * 2f - 1f);
                    var c = shape(p); sum += new Color(c.r * c.a, c.g * c.a, c.b * c.a, 0f); a += c.a;
                }
                col[y * n + x] = a > 0f ? new Color(sum.r / a, sum.g / a, sum.b / a, a / 4f) : Color.clear;
            }
        var outl = new Color[n * n];   // 짙은 외곽선(2칸)을 둘러 어떤 배경에서도 또렷하게
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                float m = col[y * n + x].a;
                for (int dy = -2; dy <= 2 && m < 1f; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        int xx = x + dx, yy = y + dy;
                        if (xx >= 0 && yy >= 0 && xx < n && yy < n && dx * dx + dy * dy <= 5) m = Mathf.Max(m, col[yy * n + xx].a);
                    }
                var c = col[y * n + x];
                outl[y * n + x] = Color.Lerp(new Color(Ink.r, Ink.g, Ink.b, m), new Color(c.r, c.g, c.b, 1f), c.a);
            }
        var tex = new Texture2D(n, n, TextureFormat.RGBA32, false) { filterMode = FilterMode.Bilinear };
        tex.SetPixels(outl); tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, n, n), new Vector2(0.5f, 0.5f), 64f);
    }

    static Color C(float r, float g, float b) { return new Color(r, g, b, 1f); }

    static Sprite Sun()
    {
        return Paint(p =>
        {
            float d = p.magnitude * 0.9f, a = Mathf.Atan2(p.y, p.x);
            if (d < 0.36f) return C(1f, 0.85f, 0.25f);
            if (d > 0.46f && d < 0.74f && Mathf.Cos(a * 8f) > 0.55f) return C(1f, 0.7f, 0.2f);
            return Color.clear;
        });
    }

    static Sprite Sunset()
    {
        return Paint(p =>
        {
            if (p.y > -0.05f && (p - new Vector2(0f, -0.05f)).magnitude < 0.55f) return C(1f, 0.5f, 0.25f);
            if (p.y > -0.3f && p.y < -0.12f && Mathf.Abs(p.x) < 0.85f) return C(1f, 0.72f, 0.5f);
            if (p.y > -0.55f && p.y < -0.42f && Mathf.Abs(p.x) < 0.5f) return C(1f, 0.72f, 0.5f);
            return Color.clear;
        });
    }

    static Sprite Moon()
    {
        return Paint(p => (p - new Vector2(-0.08f, 0f)).magnitude < 0.68f && (p - new Vector2(0.3f, 0.18f)).magnitude > 0.56f ? C(1f, 0.95f, 0.65f) : Color.clear);
    }

    static Sprite Worm()
    {
        return Paint(p =>
        {
            float best = 9f; int seg = 0;
            for (int i = 0; i <= 24; i++)
            {
                float t = -0.75f + 1.5f * i / 24f;
                float d = (p - new Vector2(t, 0.28f * Mathf.Sin(t * 4.2f))).magnitude;
                if (d < best) { best = d; seg = i; }
            }
            if (best > 0.17f) return Color.clear;
            if ((p - new Vector2(0.72f, 0.28f * Mathf.Sin(0.72f * 4.2f) + 0.05f)).magnitude < 0.045f) return C(0.15f, 0.08f, 0.08f);
            return seg % 6 < 3 ? C(0.96f, 0.58f, 0.62f) : C(0.88f, 0.45f, 0.52f);
        });
    }

    static Sprite Shrimp()
    {
        return Paint(p =>
        {
            float d = p.magnitude, a = Mathf.Atan2(p.y, p.x) * Mathf.Rad2Deg;   // 몸통은 고리의 일부(왼쪽 위가 열린 모양)
            if (d > 0.4f && d < 0.68f && (a > 20f || a < -100f ? false : true)) return d < 0.5f ? C(1f, 0.62f, 0.42f) : C(0.98f, 0.5f, 0.35f);
            if ((p - new Vector2(-0.5f, -0.5f)).magnitude < 0.2f) return C(0.95f, 0.45f, 0.3f);   // 꼬리
            if ((p - new Vector2(0.55f, 0.3f)).magnitude < 0.05f) return C(0.12f, 0.06f, 0.06f);  // 눈
            return Color.clear;
        });
    }

    static Sprite Bread()
    {
        return Paint(p =>
        {
            float e = Mathf.Pow(p.x / 0.82f, 2f) + Mathf.Pow((p.y - 0.05f) / 0.52f, 2f);
            if (e > 1f || p.y < -0.42f) return Color.clear;
            if (e > 0.72f) return C(0.74f, 0.46f, 0.2f);
            if (p.y > -0.05f && Mathf.Abs(Mathf.Repeat((p.x + p.y) * 2.3f, 1f) - 0.5f) < 0.07f) return C(0.99f, 0.88f, 0.6f);
            return C(0.94f, 0.7f, 0.38f);
        });
    }

    static Sprite Book()
    {
        return Paint(p =>
        {
            if (Mathf.Abs(p.x) > 0.62f || Mathf.Abs(p.y) > 0.74f) return Color.clear;
            if (p.x > 0.5f) return C(0.98f, 0.94f, 0.84f);                          // 쪽(종이) 옆면
            if (p.x < -0.42f && p.x > -0.52f) return C(0.55f, 0.2f, 0.2f);          // 책등 줄
            if (p.x > 0.05f && p.x < 0.2f && p.y < 0.2f) return C(1f, 0.82f, 0.3f);   // 노란 책갈피
            if (Mathf.Abs(p.y - 0.2f) < 0.06f && p.x > -0.3f && p.x < 0.4f) return C(0.98f, 0.86f, 0.55f);   // 표지 장식 줄
            return C(0.78f, 0.32f, 0.32f);
        });
    }

    static Sprite Coin()
    {
        return Paint(p =>
        {
            float d = p.magnitude;
            if (d > 0.82f) return Color.clear;
            if (Mathf.Abs(p.x) < 0.08f && Mathf.Abs(p.y) < 0.38f) return C(0.8f, 0.52f, 0.08f);
            if (d > 0.62f) return C(0.88f, 0.62f, 0.1f);
            return C(1f, 0.83f, 0.25f);
        });
    }
}
