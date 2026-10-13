using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

// 낚은 물고기 결과 카드 (GDD 9번 [확정] ①③): 물고기가 찌 자리에서 포물선으로 튀어올라 카드 그림 자리로 들어가고, 카드가 팝업으로 나타났다가 서서히 사라진다.
// 새로 잡은 물고기면 "NEW! 도감 등록" 배지와 반짝이는 조각이 퍼진다. 게임이 시작될 때 스스로 만들어진다(장면에 올릴 것 없음). 시간(timeScale)이 멈춰도 unscaledTime으로 진행.
public class ResultCard : MonoBehaviour
{
    static ResultCard instance;

    const float W = 560f, H = 184f, JumpTime = 0.8f, PopStart = 0.6f, PopTime = 0.35f, HoldTime = 3.5f, FadeTime = 0.5f;
    static readonly Color Cream = new Color(0.99f, 0.95f, 0.86f, 0.98f);
    static readonly Color Ink = new Color(0.22f, 0.15f, 0.10f);

    CanvasGroup group;
    RectTransform card, iconBg, jumper;
    Image iconBgImg, icon, jumpImg, chipImg, newBadge, goalBadge;
    Text title, nameText, chipText, priceText, newText;
    readonly List<RectTransform> sparks = new List<RectTransform>();
    readonly List<Vector2> sparkDir = new List<Vector2>();
    Sprite[] sprites;
    float t0 = -999f;
    Vector2 jumpFrom;
    bool showNew, rare;
    const string GoalMsg = "오늘의 목표 달성!  +";

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        var go = new GameObject("ResultCard");
        DontDestroyOnLoad(go);
        instance = go.AddComponent<ResultCard>();
    }

    // 낚았을 때 FishingRod가 부른다. bobberWorld = 찌 위치(튀어오르는 시작 자리).
    public static void Show(FishData fish, bool isNew, Vector3 bobberWorld, Camera cam, bool goalDone = false)
    {
        if (instance != null) instance.Begin(fish, isNew, bobberWorld, cam, goalDone);
    }

    void Awake()
    {
        var font = GameFont.Get();
        var canvas = new GameObject("CardCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay; canvas.sortingOrder = 7;
        
        var body = Img(canvas.transform, "Card", Cream, new Vector2(W, H)); card = body.rectTransform;
        group = body.gameObject.AddComponent<CanvasGroup>(); group.alpha = 0f; group.blocksRaycasts = false; group.interactable = false;   // 카드만 투명하게(튀는 물고기는 따로)
        card.anchorMin = card.anchorMax = card.pivot = new Vector2(0.5f, 0.5f); card.anchoredPosition = new Vector2(0f, 110f);
        var ol = body.gameObject.AddComponent<Outline>(); ol.effectColor = new Color(0.45f, 0.30f, 0.18f, 0.9f); ol.effectDistance = new Vector2(2.5f, -2.5f);

        iconBgImg = Img(card, "IconBg", Color.white, new Vector2(150f, 150f)); iconBg = iconBgImg.rectTransform;
        iconBg.anchorMin = iconBg.anchorMax = iconBg.pivot = new Vector2(0.5f, 0.5f); iconBg.anchoredPosition = new Vector2(-190f, 0f);
        icon = new GameObject("Icon").AddComponent<Image>(); icon.transform.SetParent(iconBg, false); icon.preserveAspect = true; icon.raycastTarget = false;
        icon.rectTransform.sizeDelta = new Vector2(132f, 110f);

        title = Txt(card, font, 24, new Color(0.45f, 0.30f, 0.18f), TextAnchor.MiddleLeft, FontStyle.Bold, new Vector2(70f, 62f), new Vector2(330f, 32f)); title.text = "낚았다!";
        nameText = Txt(card, font, 46, Ink, TextAnchor.MiddleLeft, FontStyle.Bold, new Vector2(70f, 14f), new Vector2(330f, 60f));
        chipImg = Img(card, "Chip", Color.white, new Vector2(96f, 36f)); chipImg.rectTransform.anchorMin = chipImg.rectTransform.anchorMax = chipImg.rectTransform.pivot = new Vector2(0.5f, 0.5f);
        chipImg.rectTransform.anchoredPosition = new Vector2(-30f, -42f);
        chipText = Txt(chipImg.rectTransform, font, 22, Ink, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(96f, 36f));
        priceText = Txt(card, font, 24, Ink, TextAnchor.MiddleLeft, FontStyle.Normal, new Vector2(135f, -42f), new Vector2(200f, 36f));

        newBadge = Img(card, "NewBadge", new Color(0.95f, 0.45f, 0.25f), new Vector2(190f, 42f));
        var nb = newBadge.rectTransform; nb.anchorMin = nb.anchorMax = nb.pivot = new Vector2(0.5f, 0.5f); nb.anchoredPosition = new Vector2(185f, 90f); nb.localRotation = Quaternion.Euler(0, 0, -6f);
        var nol = newBadge.gameObject.AddComponent<Outline>(); nol.effectColor = new Color(0.55f, 0.2f, 0.08f, 1f); nol.effectDistance = new Vector2(2f, -2f);
        newText = Txt(nb, font, 24, Color.white, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(190f, 42f)); newText.text = "NEW! 도감 등록";

        goalBadge = Img(card, "GoalBadge", new Color(1f, 0.82f, 0.28f), new Vector2(360f, 44f));   // 목표를 채웠을 때만 카드 아래에 붙는 금색 띠
        var gb = goalBadge.rectTransform; gb.anchorMin = gb.anchorMax = gb.pivot = new Vector2(0.5f, 0.5f); gb.anchoredPosition = new Vector2(0f, -(H * 0.5f) - 30f);
        var gol = goalBadge.gameObject.AddComponent<Outline>(); gol.effectColor = new Color(0.55f, 0.38f, 0.08f, 1f); gol.effectDistance = new Vector2(2f, -2f);
        var gt = Txt(gb, font, 26, Ink, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(360f, 44f)); gt.text = GoalMsg + Goal.Reward + "원";

        for (int i = 0; i < 12; i++)   // 반짝이는 조각(마름모)
        {
            var s = Img(card, "Spark" + i, new Color(1f, 0.92f, 0.5f), new Vector2(18f, 18f)); var rt = s.rectTransform;
            rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f); rt.localRotation = Quaternion.Euler(0, 0, 45f);
            s.gameObject.SetActive(false); sparks.Add(rt);
            float a = i / 12f * Mathf.PI * 2f; sparkDir.Add(new Vector2(Mathf.Cos(a), Mathf.Sin(a)));
        }

        jumpImg = new GameObject("Jumper").AddComponent<Image>(); jumpImg.transform.SetParent(canvas.transform, false); jumpImg.preserveAspect = true; jumpImg.raycastTarget = false;
        jumper = jumpImg.rectTransform; jumper.anchorMin = jumper.anchorMax = Vector2.zero; jumper.pivot = new Vector2(0.5f, 0.5f); jumper.sizeDelta = new Vector2(120f, 90f);
        jumpImg.gameObject.SetActive(false);
    }

    void Begin(FishData fish, bool isNew, Vector3 bobberWorld, Camera cam, bool goalDone)
    {
        if (sprites == null) { var cat = FindFirstObjectByType<CatalogUI>(); sprites = cat != null ? cat.fishSprites : null; }
        int idx = Collection.IndexOf(fish);
        var sp = sprites != null && idx < sprites.Length ? sprites[idx] : null;
        var rc = CatalogUI.RarityColor(fish.rarity);
        iconBgImg.color = rc; icon.sprite = sp; jumpImg.sprite = sp;
        nameText.text = fish.name;
        chipImg.color = Color.Lerp(rc, Color.white, 0.25f); chipText.text = FishTable.RarityName(fish.rarity);
        priceText.text = "판매 값 " + Inventory.Price(fish.rarity) + "원";
        showNew = isNew || goalDone; rare = fish.rarity == Rarity.Rare;
        newBadge.gameObject.SetActive(isNew);
        goalBadge.gameObject.SetActive(goalDone);
        Vector3 sp3 = cam != null ? cam.WorldToScreenPoint(bobberWorld) : new Vector3(Screen.width * 0.5f, Screen.height * 0.4f);
        if (sp3.z < 0f) sp3 = new Vector3(Screen.width * 0.5f, Screen.height * 0.4f);
        jumpFrom = new Vector2(sp3.x, sp3.y);
        foreach (var s in sparks) s.gameObject.SetActive(false);
        t0 = Time.unscaledTime;
        group.alpha = 0f; card.localScale = Vector3.one * 0.6f;
    }

    void Update()
    {
        float t = Time.unscaledTime - t0;
        float total = PopStart + PopTime + HoldTime + FadeTime;
        if (t > total) { group.alpha = 0f; jumpImg.gameObject.SetActive(false); return; }

        // 물고기가 찌 자리에서 포물선으로 튀어올라 카드 그림 자리로 들어감
        var target = new Vector2(Screen.width * 0.5f - 190f, Screen.height * 0.5f + 110f);
        if (t < JumpTime)
        {
            float k = t / JumpTime;
            jumpImg.gameObject.SetActive(true);
            var p = Vector2.Lerp(jumpFrom, target, Mathf.SmoothStep(0f, 1f, k)) + Vector2.up * Mathf.Sin(k * Mathf.PI) * 200f;
            jumper.anchoredPosition = p;
            jumper.localRotation = Quaternion.Euler(0f, 0f, -360f * k);
            jumper.localScale = Vector3.one * (1f + 0.5f * Mathf.Sin(k * Mathf.PI));
        }
        else jumpImg.gameObject.SetActive(false);

        // 카드 팝업(살짝 튀어나왔다 자리잡음) → 유지 → 사라짐
        float pt = Mathf.Clamp01((t - PopStart) / PopTime);
        float back = 1f + 2.2f * Mathf.Pow(pt - 1f, 3f) + 1.2f * Mathf.Pow(pt - 1f, 2f);   // easeOutBack
        card.localScale = Vector3.one * Mathf.LerpUnclamped(0.6f, 1f, back);
        float fade = 1f - Mathf.Clamp01((t - (PopStart + PopTime + HoldTime)) / FadeTime);
        group.alpha = t < PopStart ? 0f : Mathf.Clamp01(pt * 3f) * fade;

        // 반짝이는 조각: 새로 잡았거나 희귀하면 카드 그림 둘레로 퍼짐
        if (showNew || rare)
        {
            float st = (t - PopStart) / 1.0f;
            for (int i = 0; i < sparks.Count; i++)
            {
                bool on = st > 0f && st < 1f;
                sparks[i].gameObject.SetActive(on);
                if (!on) continue;
                float r = 80f + 70f * Mathf.Sqrt(st) + (i % 2) * 14f;
                sparks[i].anchoredPosition = iconBg.anchoredPosition + sparkDir[i] * r;
                float sc = (1f - st) * (0.7f + 0.5f * (i % 3) / 2f);
                sparks[i].localScale = Vector3.one * sc;
                sparks[i].GetComponent<Image>().color = new Color(1f, 0.92f, 0.5f, 1f - st);
            }
        }
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
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = pos; rt.sizeDelta = sz;
        return t;
    }
}
