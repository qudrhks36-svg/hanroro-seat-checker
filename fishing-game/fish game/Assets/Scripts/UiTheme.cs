using UnityEngine;
using UnityEngine.UI;

// 화면 글자·판의 공통 색과 만드는 법 (GDD 9번 [확정] 힐링 톤): 크림색 둥근 판 + 진한 갈색 글자. 어두운 남색 반투명 판은 더 쓰지 않는다.
public static class UiTheme
{
    public static readonly Color Cream = new Color(1f, 0.97f, 0.90f, 0.92f);
    public static readonly Color Ink = new Color(0.33f, 0.23f, 0.16f);
    public static readonly Color InkSoft = new Color(0.50f, 0.40f, 0.32f);
    public static readonly Color Edge = new Color(0.45f, 0.30f, 0.18f, 0.5f);
    public static readonly Color Coral = new Color(0.92f, 0.38f, 0.27f);

    // 화면 가운데 아래쪽 "E: ~" 안내 알약. 글자 길이에 맞춰 폭이 정해진다.
    public static GameObject Prompt(Transform canvas, string text, Vector2 pos, int size = 28)
    {
        var bg = new GameObject("Prompt").AddComponent<Image>();
        bg.transform.SetParent(canvas, false);
        bg.sprite = HudPanel.RoundedRect(); bg.type = Image.Type.Sliced; bg.color = Cream; bg.raycastTarget = false;
        var o = bg.gameObject.AddComponent<Outline>(); o.effectColor = Edge; o.effectDistance = new Vector2(2f, -2f);
        var t = new GameObject("Text").AddComponent<Text>();
        t.transform.SetParent(bg.transform, false);
        t.font = GameFont.Get(); t.fontSize = size; t.color = Ink; t.alignment = TextAnchor.MiddleCenter; t.raycastTarget = false; t.text = text;
        var rt = t.rectTransform; rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f); rt.anchoredPosition = Vector2.zero;
        float w = Mathf.Max(160f, t.preferredWidth + 56f);
        rt.sizeDelta = new Vector2(w, size + 16f);
        var brt = bg.rectTransform; brt.anchorMin = brt.anchorMax = brt.pivot = new Vector2(0.5f, 0.5f); brt.anchoredPosition = pos; brt.sizeDelta = new Vector2(w, size + 24f);
        return bg.gameObject;
    }
}
