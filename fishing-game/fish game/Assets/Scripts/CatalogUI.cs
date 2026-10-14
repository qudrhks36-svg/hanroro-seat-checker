using UnityEngine;
using UnityEngine.UI;
using UnityEngine.InputSystem;

// Tab으로 여는 도감. 열려 있는 동안 시간이 멈추고 커서가 나타난다.
// 버튼 대신 마우스 좌표로 칸을 직접 판정해서 EventSystem 없이 동작한다.
[DefaultExecutionOrder(-20)]
public class CatalogUI : MonoBehaviour
{
    public Sprite[] fishSprites;   // FishTable.All과 같은 순서 (Assets/Fish/*.png)
    public static bool IsOpen { get; private set; }
    public static int ClosedFrame = -1; // 닫은 프레임: 같은 프레임의 Esc를 PlayerController가 또 처리하지 않게

    GameObject panel;
    Text countText, nameText, infoText;
    Image bigPicture, bigBg;
    Image[] cellIcon;
    RectTransform[] cells;
    Image[] cellBg;
    Text[] cellText;
    int selected;
    Font font;

    static readonly Color Dark = new Color(0.08f, 0.08f, 0.08f);
    static readonly Color Unknown = new Color(0.80f, 0.77f, 0.70f);   // 못 잡은 칸 바탕(검은 실루엣이 보이도록 밝게)

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
        countText.text = "도감  " + Collection.Discovered + "/" + all.Length;
        for (int i = 0; i < all.Length; i++)
        {
            bool got = Collection.Counts[i] > 0;
            cellBg[i].color = got ? RarityColor(all[i].rarity) : Unknown;
            cellIcon[i].color = got ? Color.white : Color.black;   // 못 잡은 물고기는 검은 실루엣
            cellText[i].text = got ? all[i].name : "???";
            cellText[i].color = Dark;
            cellBg[i].transform.localScale = Vector3.one * (i == selected ? 1.08f : 1f);
        }
        var f = all[selected]; bool seen = Collection.Counts[selected] > 0;
        bigBg.color = seen ? RarityColor(f.rarity) : Unknown;
        bigPicture.sprite = SpriteOf(selected);
        bigPicture.color = seen ? Color.white : Color.black;   // 실루엣
        nameText.text = seen ? f.name : "???";
        infoText.text = seen ? "구분: " + FishTable.RarityName(f.rarity) + "\n잡은 수: " + Collection.Counts[selected] + "\n최고 기록: " + Collection.BestCm[selected] + "cm" : "아직 못 잡았어요";
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

        panel = new GameObject("Panel");
        panel.transform.SetParent(canvasGo.transform, false);
        var bg = panel.AddComponent<Image>();
        bg.color = new Color(0.98f, 0.93f, 0.82f, 0.96f);
        Place(bg.rectTransform, Vector2.zero, new Vector2(900, 520));

        countText = MakeText("Count", 36, TextAnchor.MiddleCenter, new Vector2(0, 230), new Vector2(600, 50));

        var bgGo = new GameObject("BigBg");
        bgGo.transform.SetParent(panel.transform, false);
        bigBg = bgGo.AddComponent<Image>();
        Place(bigBg.rectTransform, new Vector2(-270, 60), new Vector2(240, 240));
        var bigGo = new GameObject("BigPicture");
        bigGo.transform.SetParent(panel.transform, false);
        bigPicture = bigGo.AddComponent<Image>();
        bigPicture.preserveAspect = true;
        Place(bigPicture.rectTransform, new Vector2(-270, 60), new Vector2(224, 224));
        nameText = MakeText("Name", 40, TextAnchor.MiddleCenter, new Vector2(-270, -90), new Vector2(360, 60));
        infoText = MakeText("Info", 28, TextAnchor.UpperCenter, new Vector2(-270, -200), new Vector2(360, 130));

        int n = FishTable.All.Length;
        cells = new RectTransform[n]; cellBg = new Image[n]; cellText = new Text[n]; cellIcon = new Image[n];
        for (int i = 0; i < n; i++)
        {
            var c = new GameObject("Cell" + i);
            c.transform.SetParent(panel.transform, false);
            cellBg[i] = c.AddComponent<Image>();
            cells[i] = cellBg[i].rectTransform;
            Place(cells[i], new Vector2(32.5f + (i % 4) * 117, 70 - (i / 4) * 117), new Vector2(105, 105)); // 4칸이 패널(폭 900) 안에 들어오게
            var iconGo = new GameObject("Icon");
            iconGo.transform.SetParent(c.transform, false);
            cellIcon[i] = iconGo.AddComponent<Image>();
            cellIcon[i].preserveAspect = true; cellIcon[i].raycastTarget = false;
            cellIcon[i].sprite = SpriteOf(i);
            Place(cellIcon[i].rectTransform, new Vector2(0, 14), new Vector2(92, 64));
            var t = MakeText("Label", 18, TextAnchor.MiddleCenter, Vector2.zero, new Vector2(105, 26));
            t.transform.SetParent(c.transform, false);
            Place(t.rectTransform, new Vector2(0, -38), new Vector2(105, 26));
            cellText[i] = t;
        }
        MakeText("Hint", 22, TextAnchor.MiddleCenter, new Vector2(0, -235), new Vector2(600, 40)).text = "Tab 또는 Esc: 닫기";
    }

    Text MakeText(string name, int size, TextAnchor align, Vector2 pos, Vector2 sz)
    {
        var go = new GameObject(name);
        go.transform.SetParent(panel.transform, false);
        var t = go.AddComponent<Text>();
        t.font = font; t.fontSize = size; t.alignment = align; t.color = Dark; t.raycastTarget = false;
        Place(t.rectTransform, pos, sz);
        return t;
    }

    static void Place(RectTransform rt, Vector2 pos, Vector2 size)
    {
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = pos; rt.sizeDelta = size;
    }
}
