using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

// 대화창 모양 (GDD 9번 [확정]): 색깔 이름표 + 크림색 대사 판 + (상점 NPC만) 정보 칸 + 아래 `[키] 설명` 알약 줄.
// ShopNPC·TalkNPC가 같이 쓴다. 내용(말·판매·구매)은 각 NPC가 정하고, 여기는 보이는 모양만 맡는다.
public class DialogView
{
    const float W = 1080f, MaxChips = 5;
    static readonly Color Cream = new Color(0.99f, 0.95f, 0.86f, 0.97f);
    static readonly Color CreamDark = new Color(0.96f, 0.87f, 0.70f, 1f);
    static readonly Color Ink = new Color(0.22f, 0.15f, 0.10f);

    GameObject root;
    Text message, info;
    GameObject infoBox;
    readonly List<Chip> chips = new List<Chip>();
    float heightWithInfo;

    class Chip { public GameObject go; public RectTransform rt, badgeRt, labelRt; public Text key, label; }

    public static Color AccentFor(string npcName)
    {
        switch (npcName)
        {
            case "바틀이": return new Color(0.95f, 0.62f, 0.25f);
            case "끼룩이": return new Color(0.30f, 0.62f, 0.95f);
            case "모카": return new Color(0.95f, 0.50f, 0.65f);
            case "돌쇠": return new Color(0.38f, 0.70f, 0.38f);
            default: return new Color(0.5f, 0.5f, 0.5f);
        }
    }

    public static DialogView Build(Transform canvas, string npcName, bool hasInfo)
    {
        var v = new DialogView();
        var font = GameFont.Get();
        float h = hasInfo ? 346f : 196f;
        v.heightWithInfo = h;

        var body = Img(canvas, "Dialog", Cream, new Vector2(W, h));
        v.root = body.gameObject;
        var rt = body.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0f);
        rt.anchoredPosition = new Vector2(0, 150);
        var outline = body.gameObject.AddComponent<Outline>(); outline.effectColor = new Color(0.45f, 0.30f, 0.18f, 0.9f); outline.effectDistance = new Vector2(2.5f, -2.5f);

        // 이름표: 판 왼쪽 위에 걸침
        var accent = AccentFor(npcName);
        var tag = Img(rt, "NameTag", accent, new Vector2(Mathf.Max(170f, 40f + npcName.Length * 34f), 54f));
        var trt = tag.rectTransform; trt.anchorMin = trt.anchorMax = new Vector2(0f, 1f); trt.pivot = new Vector2(0f, 0.5f); trt.anchoredPosition = new Vector2(28f, 0f);
        var to = tag.gameObject.AddComponent<Outline>(); to.effectColor = new Color(accent.r * 0.5f, accent.g * 0.5f, accent.b * 0.5f, 1f); to.effectDistance = new Vector2(2f, -2f);
        var nameText = Txt(trt, font, 30, Color.white, TextAnchor.MiddleCenter, FontStyle.Bold, new Vector2(0, 0), trt.sizeDelta);
        nameText.text = npcName;
        var no = nameText.gameObject.AddComponent<Outline>(); no.effectColor = new Color(0.2f, 0.12f, 0.06f, 0.8f); no.effectDistance = new Vector2(1.5f, -1.5f);

        // 대사
        v.message = Txt(rt, font, 28, Ink, TextAnchor.UpperLeft, FontStyle.Normal, new Vector2(36f, -40f), new Vector2(W - 72f, 112f));

        // 정보 칸
        if (hasInfo)
        {
            var box = Img(rt, "InfoBox", CreamDark, new Vector2(W - 60f, 118f));
            var brt = box.rectTransform; brt.anchorMin = brt.anchorMax = new Vector2(0f, 1f); brt.pivot = new Vector2(0f, 1f); brt.anchoredPosition = new Vector2(30f, -156f);
            v.infoBox = box.gameObject;
            v.info = Txt(brt, font, 24, Ink, TextAnchor.UpperLeft, FontStyle.Normal, new Vector2(16f, -10f), new Vector2(W - 92f, 100f));
            v.info.resizeTextForBestFit = true; v.info.resizeTextMinSize = 17; v.info.resizeTextMaxSize = 24;
        }

        // 키 안내 알약(최대 5개)
        for (int i = 0; i < MaxChips; i++)
        {
            var c = new Chip();
            var chip = Img(rt, "Chip" + i, new Color(0.38f, 0.26f, 0.17f, 0.92f), new Vector2(200f, 40f));
            c.go = chip.gameObject; c.rt = chip.rectTransform;
            c.rt.anchorMin = c.rt.anchorMax = new Vector2(0f, 0f); c.rt.pivot = new Vector2(0f, 0f);
            var badge = Img(c.rt, "Badge", Cream, new Vector2(100f, 30f));
            c.badgeRt = badge.rectTransform; c.badgeRt.anchorMin = c.badgeRt.anchorMax = new Vector2(0f, 0.5f); c.badgeRt.pivot = new Vector2(0f, 0.5f); c.badgeRt.anchoredPosition = new Vector2(5f, 0f);
            c.key = Txt(c.badgeRt, font, 20, Ink, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(100f, 30f));
            c.label = Txt(c.rt, font, 22, Cream, TextAnchor.MiddleLeft, FontStyle.Normal, Vector2.zero, new Vector2(100f, 40f));
            c.labelRt = c.label.rectTransform; c.labelRt.anchorMin = c.labelRt.anchorMax = new Vector2(0f, 0.5f); c.labelRt.pivot = new Vector2(0f, 0.5f);
            c.go.SetActive(false);
            v.chips.Add(c);
        }
        return v;
    }

    public void SetActive(bool on) { root.SetActive(on); }

    // message: 대사, infoText: 정보 칸 글(없으면 빈 문자열), hints: "키|설명" 목록
    public void Set(string msg, string infoText, params string[] hints)
    {
        message.text = msg;
        root.transform.localScale = Vector3.one * Mathf.Min(1f, Screen.width / (W + 40f));   // 화면(웹 상자)이 대화창보다 좁으면 줄여서 안 잘리게
        if (info != null) info.text = infoText ?? "";
        float x = 30f;
        for (int i = 0; i < chips.Count; i++)
        {
            var c = chips[i];
            bool on = i < hints.Length;
            c.go.SetActive(on);
            if (!on) continue;
            string[] kv = hints[i].Split('|');
            c.key.text = kv[0]; c.label.text = kv[1];
            float bw = 22f + Width(kv[0], 20f), lw = 16f + Width(kv[1], 22f);
            c.badgeRt.sizeDelta = new Vector2(bw, 30f); c.key.rectTransform.sizeDelta = new Vector2(bw, 30f);
            c.labelRt.anchoredPosition = new Vector2(5f + bw + 8f, 0f); c.labelRt.sizeDelta = new Vector2(lw, 40f);
            c.rt.sizeDelta = new Vector2(5f + bw + 8f + lw, 40f);
            c.rt.anchoredPosition = new Vector2(x, 20f);
            x += c.rt.sizeDelta.x + 14f;
        }
    }

    // 글자 폭 어림: 한글 등은 글자 크기만큼, 영문·숫자·기호는 반 정도
    static float Width(string s, float size)
    {
        float w = 0f;
        foreach (char ch in s) w += ch < 128 ? size * 0.58f : size * 1.0f;
        return w;
    }

    static Image Img(Transform parent, string name, Color c, Vector2 size)
    {
        var img = new GameObject(name).AddComponent<Image>();
        img.transform.SetParent(parent, false);
        img.sprite = HudPanel.RoundedRect(); img.type = Image.Type.Sliced; img.color = c; img.raycastTarget = false;
        img.rectTransform.sizeDelta = size;
        return img;
    }

    static Text Txt(Transform parent, Font font, int size, Color c, TextAnchor align, FontStyle style, Vector2 pos, Vector2 sz)
    {
        var t = new GameObject("Text").AddComponent<Text>();
        t.transform.SetParent(parent, false);
        t.font = font; t.fontSize = size; t.fontStyle = style; t.color = c; t.alignment = align; t.raycastTarget = false;
        var rt = t.rectTransform;
        bool stretch = align == TextAnchor.UpperLeft;
        rt.anchorMin = rt.anchorMax = stretch ? new Vector2(0f, 1f) : new Vector2(0.5f, 0.5f);
        rt.pivot = stretch ? new Vector2(0f, 1f) : new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = pos; rt.sizeDelta = sz;
        return t;
    }
}
