using UnityEngine;
using UnityEngine.UI;
using UnityEngine.InputSystem;

// Tab으로 여는 도감 (GDD 9번 [확정] 도감 고도화: 보기 좋게만). 열려 있는 동안 시간이 멈추고 커서가 나타난다.
// 버튼 대신 마우스 좌표로 칸을 직접 판정해서 EventSystem 없이 동작한다.
// 모양: 둥근 크림색 판(대화창·꾸미기 창과 같은 색), 위쪽 진행 막대, 왼쪽 상세 카드(그림·이름·칩·기록), 오른쪽 둥근 칸(등급 색 테두리, 못 잡은 건 실루엣).
[DefaultExecutionOrder(-20)]
public class CatalogUI : MonoBehaviour
{
    public Sprite[] fishSprites;   // FishTable.All과 같은 순서 (Assets/Fish/*.png)
    public static bool IsOpen { get; private set; }
    public static int ClosedFrame = -1; // 닫은 프레임: 같은 프레임의 Esc를 PlayerController가 또 처리하지 않게

    GameObject panel;
    Text countText, nameText, hintText, caughtValue, bestValue, priceValue;
    Image bigPicture, bigBg, progressFill, rarityChip, farChip;
    Text rarityChipText, farChipText;
    Image[] cellIcon, cellBorder;
    RectTransform[] cells;
    Outline[] cellOutline;
    Text[] cellText;
    int selected;
    Font font;

    const float BarWidth = 440f;
    static readonly Color Cream = new Color(0.99f, 0.95f, 0.86f, 0.98f), Ink = new Color(0.22f, 0.15f, 0.10f), Brown = new Color(0.45f, 0.30f, 0.18f);
    static readonly Color UnknownBorder = new Color(0.78f, 0.72f, 0.62f), UnknownInner = new Color(0.92f, 0.88f, 0.80f), UnknownText = new Color(0.55f, 0.47f, 0.38f);

    Sprite SpriteOf(int i) { return fishSprites != null && i < fishSprites.Length ? fishSprites[i] : null; }

    void Awake()
    {
        IsOpen = false;
        font = GameFont.Get();
        Build();
        panel.SetActive(false);
    }

    void OnDestroy() { if (IsOpen) Time.timeScale = 1f; IsOpen = false; }

    void Update()
    {
        var kb = Keyboard.current; var mouse = Mouse.current;
        if (kb == null || mouse == null) return;

        if (kb.tabKey.wasPressedThisFrame && !ShopNPC.IsOpen && !TalkNPC.IsOpen) { SetOpen(!IsOpen); return; }
        if (!IsOpen) return;
        if (kb.escapeKey.wasPressedThisFrame) { SetOpen(false); return; }

        if (mouse.leftButton.wasPressedThisFrame)
        {
            Vector2 p = mouse.position.ReadValue();
            for (int i = 0; i < cells.Length; i++)
                if (RectTransformUtility.RectangleContainsScreenPoint(cells[i], p)) { selected = i; Refresh(); }
        }
    }

    void SetOpen(bool open)
    {
        IsOpen = open;
        if (!open) ClosedFrame = Time.frameCount;
        panel.SetActive(open);
        Time.timeScale = open ? 0f : 1f;
        Cursor.lockState = open ? CursorLockMode.None : CursorLockMode.Locked;
        Cursor.visible = open;
        if (open) Refresh();
    }

    void Refresh()
    {
        var all = FishTable.All;
        int found = Collection.Discovered;
        countText.text = found + " / " + all.Length;
        progressFill.rectTransform.sizeDelta = new Vector2(Mathf.Max(24f, BarWidth * found / all.Length), 26f);   // 최소 폭 = 둥근 모서리가 찌그러지지 않게
        progressFill.gameObject.SetActive(found > 0);
        for (int i = 0; i < all.Length; i++)
        {
            bool got = Collection.Counts[i] > 0;
            cellBorder[i].color = got ? RarityColor(all[i].rarity) : UnknownBorder;
            cellIcon[i].color = got ? Color.white : new Color(0.15f, 0.12f, 0.1f, 0.8f);   // 못 잡은 물고기는 어두운 실루엣
            cellText[i].text = got ? all[i].name : "???";
            cellText[i].color = got ? Ink : UnknownText;
            bool sel = i == selected;
            cells[i].localScale = Vector3.one * (sel ? 1.07f : 1f);
            cellOutline[i].enabled = sel;
        }
        var f = all[selected]; bool seen = Collection.Counts[selected] > 0;
        bigBg.color = seen ? RarityColor(f.rarity) : UnknownBorder;
        bigPicture.sprite = SpriteOf(selected);
        bigPicture.color = seen ? Color.white : new Color(0.15f, 0.12f, 0.1f, 0.8f);   // 실루엣
        nameText.text = seen ? f.name : "???";
        rarityChip.gameObject.SetActive(seen); farChip.gameObject.SetActive(seen && f.farSea);
        if (seen)
        {
            rarityChip.color = Color.Lerp(RarityColor(f.rarity), Color.white, 0.1f); rarityChipText.text = FishTable.RarityName(f.rarity);
            rarityChip.rectTransform.anchoredPosition = new Vector2(f.farSea ? -62f : 0f, -68f);   // 먼 바다 칩이 없으면 등급 칩이 가운데
            farChip.rectTransform.anchoredPosition = new Vector2(52f, -68f);
        }
        caughtValue.text = seen ? Collection.Counts[selected] + "마리" : "—";
        bestValue.text = seen ? Collection.BestCm[selected] + "cm" : "—";
        priceValue.text = seen ? Inventory.Price(f.rarity) + "원" : "—";
        hintText.text = seen ? "칸을 클릭하면 물고기를 볼 수 있어요      Tab / Esc: 닫기" : "아직 못 잡았어요. 낚아서 도감을 채워 보세요      Tab / Esc: 닫기";
    }

    internal static Color RarityColor(Rarity r)
    {
        switch (r)
        {
            case Rarity.Common: return new Color(0.70f, 0.85f, 0.95f);
            case Rarity.Uncommon: return new Color(0.75f, 0.90f, 0.60f);
            default: return new Color(1f, 0.85f, 0.45f);
        }
    }

    // ---- UI 만들기 ----
    void Build()
    {
        var canvasGo = new GameObject("CatalogCanvas");
        canvasGo.transform.SetParent(transform, false);
        var canvas = canvasGo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 10;

        var bg = Rounded(canvasGo.transform, "Panel", Cream, new Vector2(900f, 540f), Vector2.zero);
        panel = bg.gameObject;
        var ol = panel.AddComponent<Outline>(); ol.effectColor = new Color(0.45f, 0.30f, 0.18f, 0.9f); ol.effectDistance = new Vector2(2.5f, -2.5f);
        var pt = panel.transform;

        Text(pt, "Title", 36, Brown, TextAnchor.MiddleLeft, new Vector2(-290f, 238f), new Vector2(220f, 50f), FontStyle.Bold).text = "도감";
        Rounded(pt, "BarBg", new Color(0.86f, 0.78f, 0.66f), new Vector2(BarWidth, 26f), new Vector2(150f, 238f));
        progressFill = Rounded(pt, "BarFill", new Color(1f, 0.8f, 0.3f), new Vector2(BarWidth, 26f), new Vector2(150f - BarWidth / 2f, 238f));
        progressFill.rectTransform.pivot = new Vector2(0f, 0.5f); progressFill.rectTransform.anchoredPosition = new Vector2(150f - BarWidth / 2f, 238f);
        countText = Text(pt, "Count", 22, Ink, TextAnchor.MiddleCenter, new Vector2(150f, 238f), new Vector2(200f, 30f), FontStyle.Bold);

        // 왼쪽 상세 카드
        var card = Rounded(pt, "DetailCard", new Color(1f, 1f, 1f, 0.55f), new Vector2(360f, 410f), new Vector2(-255f, -18f)).transform;
        bigBg = Rounded(card, "BigBg", Color.white, new Vector2(320f, 190f), new Vector2(0f, 95f));
        var bigGo = new GameObject("BigPicture"); bigGo.transform.SetParent(bigBg.transform, false);
        bigPicture = bigGo.AddComponent<Image>(); bigPicture.preserveAspect = true; bigPicture.raycastTarget = false;
        Place(bigPicture.rectTransform, Vector2.zero, new Vector2(290f, 170f));
        nameText = Text(card, "Name", 38, Ink, TextAnchor.MiddleCenter, new Vector2(0f, -22f), new Vector2(330f, 44f), FontStyle.Bold);
        rarityChip = Rounded(card, "RarityChip", Color.white, new Vector2(96f, 32f), new Vector2(-30f, -68f));
        rarityChipText = Text(rarityChip.transform, "T", 22, Ink, TextAnchor.MiddleCenter, Vector2.zero, new Vector2(96f, 34f), FontStyle.Bold);
        farChip = Rounded(card, "FarChip", new Color(0.35f, 0.5f, 0.72f), new Vector2(110f, 32f), new Vector2(80f, -68f));
        farChipText = Text(farChip.transform, "T", 20, Color.white, TextAnchor.MiddleCenter, Vector2.zero, new Vector2(110f, 34f), FontStyle.Bold); farChipText.text = "먼 바다";
        string[] labels = { "잡은 수", "최고 기록", "판매 값" };
        for (int i = 0; i < 3; i++)
        {
            float y = -113f - i * 36f;
            Rounded(card, "Line" + i, new Color(0.45f, 0.3f, 0.18f, 0.18f), new Vector2(320f, 2f), new Vector2(0f, y + 19f));
            Text(card, "Label" + i, 22, Brown, TextAnchor.MiddleLeft, new Vector2(-70f, y), new Vector2(170f, 34f), FontStyle.Normal).text = labels[i];
            var v = Text(card, "Value" + i, 24, Ink, TextAnchor.MiddleRight, new Vector2(80f, y), new Vector2(160f, 34f), FontStyle.Bold);
            if (i == 0) caughtValue = v; else if (i == 1) bestValue = v; else priceValue = v;
        }

        // 오른쪽 칸(4열 4줄)
        int n = FishTable.All.Length;
        cells = new RectTransform[n]; cellBorder = new Image[n]; cellText = new Text[n]; cellIcon = new Image[n]; cellOutline = new Outline[n];
        for (int i = 0; i < n; i++)
        {
            var pos = new Vector2(12.5f + (i % 4) * 117f, 138f - (i / 4) * 102f);
            cellBorder[i] = Rounded(pt, "Cell" + i, UnknownBorder, new Vector2(105f, 92f), pos);
            cells[i] = cellBorder[i].rectTransform;
            cellOutline[i] = cellBorder[i].gameObject.AddComponent<Outline>(); cellOutline[i].effectColor = new Color(0.35f, 0.22f, 0.12f, 1f); cellOutline[i].effectDistance = new Vector2(2.5f, -2.5f); cellOutline[i].enabled = false;
            var inner = Rounded(cells[i], "Inner", UnknownInner, new Vector2(97f, 84f), Vector2.zero);
            inner.color = new Color(1f, 0.98f, 0.93f, 1f);
            var iconGo = new GameObject("Icon"); iconGo.transform.SetParent(inner.transform, false);
            cellIcon[i] = iconGo.AddComponent<Image>(); cellIcon[i].preserveAspect = true; cellIcon[i].raycastTarget = false; cellIcon[i].sprite = SpriteOf(i);
            Place(cellIcon[i].rectTransform, new Vector2(0f, 12f), new Vector2(82f, 50f));
            cellText[i] = Text(inner.transform, "Label", 18, Ink, TextAnchor.MiddleCenter, new Vector2(0f, -29f), new Vector2(97f, 24f), FontStyle.Bold);
        }
        hintText = Text(pt, "Hint", 20, new Color(0.4f, 0.3f, 0.22f), TextAnchor.MiddleCenter, new Vector2(0f, -250f), new Vector2(840f, 30f), FontStyle.Normal);
    }

    static Image Rounded(Transform parent, string name, Color c, Vector2 size, Vector2 pos)
    {
        var img = new GameObject(name).AddComponent<Image>();
        img.transform.SetParent(parent, false);
        img.sprite = HudPanel.RoundedRect(); img.type = Image.Type.Sliced; img.color = c; img.raycastTarget = name.StartsWith("Cell") && !name.EndsWith("r");
        Place(img.rectTransform, pos, size);
        return img;
    }

    Text Text(Transform parent, string name, int size, Color c, TextAnchor align, Vector2 pos, Vector2 sz, FontStyle style)
    {
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        var t = go.AddComponent<Text>();
        t.font = font; t.fontSize = size; t.fontStyle = style; t.alignment = align; t.color = c; t.raycastTarget = false;
        Place(t.rectTransform, pos, sz);
        return t;
    }

    static void Place(RectTransform rt, Vector2 pos, Vector2 size)
    {
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = pos; rt.sizeDelta = size;
    }
}
