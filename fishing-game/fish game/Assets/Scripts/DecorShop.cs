using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

// 꾸미기 창 (GDD 9번 [확정]): 바틀이 대화창에서 F를 누르면 열린다. 숫자 키 1~5 = 장식 사기, 6 = 오두막 키우기, F/Esc = 닫기.
// 바틀이 대화창(ShopNPC)이 이미 시간을 멈추고 마우스를 풀어 둔 상태라, 여기서는 그대로 두고 입력만 가로챈다.
[DefaultExecutionOrder(-10)]
public class DecorShop : MonoBehaviour
{
    public static bool IsOpen { get; private set; }
    public static int ClosedFrame = -1;   // 닫은 프레임: 같은 프레임의 Esc를 바틀이 창이 또 처리하지 않게
    static DecorShop instance;

    static readonly Color Cream = new Color(0.99f, 0.95f, 0.86f, 0.98f), Ink = new Color(0.22f, 0.15f, 0.10f), Brown = new Color(0.45f, 0.30f, 0.18f);
    static readonly Color Green = new Color(0.25f, 0.55f, 0.3f), Gold = new Color(0.8f, 0.55f, 0.1f);

    GameObject root;
    Text moneyText, msgText;
    readonly Text[] names = new Text[Home.ItemCount + 1], infos = new Text[Home.ItemCount + 1], states = new Text[Home.ItemCount + 1];
    int openFrame = -1;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { IsOpen = false; instance = null; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { instance = new GameObject("DecorShop").AddComponent<DecorShop>(); }

    public static void Open() { if (instance != null) instance.SetOpen(true); }

    void Awake() { Build(); root.SetActive(false); }

    void SetOpen(bool on)
    {
        if (on == IsOpen) return;
        IsOpen = on; root.SetActive(on);
        if (on) { openFrame = Time.frameCount; msgText.text = "숫자 키로 사요. 산 물건은 바로 섬에 놓여요."; Refresh(); }
        else ClosedFrame = Time.frameCount;
    }

    void OnDestroy() { IsOpen = false; }

    void Update()
    {
        if (!IsOpen || Time.frameCount == openFrame) return;
        var kb = Keyboard.current; if (kb == null) return;
        if (kb.escapeKey.wasPressedThisFrame || kb.fKey.wasPressedThisFrame) { SetOpen(false); return; }
        Key[] keys = { Key.Digit1, Key.Digit2, Key.Digit3, Key.Digit4, Key.Digit5, Key.Digit6 };
        for (int i = 0; i < keys.Length; i++) if (kb[keys[i]].wasPressedThisFrame) { Buy(i); break; }
    }

    void Buy(int i)
    {
        if (i < Home.ItemCount)
        {
            if (Home.Owns(i)) msgText.text = "이미 있는 물건이에요.";
            else if (Home.BuyItem(i)) { Done("와… " + Home.ItemNames[i] + "이(가) 생겼어요!"); }
            else msgText.text = "돈이 모자라요. " + Home.ItemPrice[i] + "원이 필요해요.";
        }
        else
        {
            if (Home.CabinMax) msgText.text = "오두막은 더 키울 수 없어요.";
            else if (Home.BuyCabin()) Done("오두막이 " + Home.CabinNames[Home.CabinLevel] + "(으)로 바뀌었어요!");
            else msgText.text = "돈이 모자라요. " + Home.CabinPrice[Home.CabinLevel + 1] + "원이 필요해요.";
        }
        Refresh();
    }

    void Done(string message) { msgText.text = message; SaveData.Save(); Sfx.Play(SfxKind.Upgrade); }

    void Refresh()
    {
        moneyText.text = "소지금 " + Inventory.Money + "원";
        for (int i = 0; i < Home.ItemCount; i++)
        {
            names[i].text = Home.ItemNames[i]; infos[i].text = Home.ItemInfo[i];
            bool own = Home.Owns(i);
            states[i].text = own ? "보유 중" : Home.ItemPrice[i] + "원"; states[i].color = own ? Green : (Inventory.Money >= Home.ItemPrice[i] ? Ink : new Color(0.6f, 0.35f, 0.3f));
        }
        int c = Home.ItemCount;
        names[c].text = "오두막 키우기";
        if (Home.CabinMax) { infos[c].text = "지금: " + Home.CabinNames[Home.CabinLevel]; states[c].text = "다 키웠어요"; states[c].color = Green; }
        else
        {
            int next = Home.CabinLevel + 1;
            infos[c].text = Home.CabinNames[next] + (next == 1 ? " (새 지붕, 굴뚝)" : " (깃발, 등불, 창문 불빛)");
            states[c].text = Home.CabinPrice[next] + "원"; states[c].color = Inventory.Money >= Home.CabinPrice[next] ? Ink : new Color(0.6f, 0.35f, 0.3f);
        }
    }

    // ---------------- UI ----------------
    void Build()
    {
        var font = GameFont.Get();
        var canvas = new GameObject("DecorCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay; canvas.sortingOrder = 8;
        root = canvas.gameObject;

        var panel = Img(canvas.transform, "Panel", Cream, new Vector2(820f, 540f));
        var prt = panel.rectTransform; prt.anchorMin = prt.anchorMax = prt.pivot = new Vector2(0.5f, 0.5f); prt.anchoredPosition = Vector2.zero;
        var ol = panel.gameObject.AddComponent<Outline>(); ol.effectColor = new Color(0.45f, 0.30f, 0.18f, 0.9f); ol.effectDistance = new Vector2(2.5f, -2.5f);

        Txt(prt, font, 34, Brown, TextAnchor.MiddleLeft, FontStyle.Bold, new Vector2(-30f, 232f), new Vector2(520f, 50f)).text = "집 꾸미기";
        moneyText = Txt(prt, font, 26, Ink, TextAnchor.MiddleRight, FontStyle.Bold, new Vector2(250f, 232f), new Vector2(300f, 50f));

        for (int i = 0; i <= Home.ItemCount; i++)
        {
            float y = 160f - i * 62f;
            var row = Img(prt, "Row" + i, i == Home.ItemCount ? new Color(1f, 0.93f, 0.7f) : new Color(1f, 1f, 1f, 0.55f), new Vector2(780f, 56f));
            row.rectTransform.anchorMin = row.rectTransform.anchorMax = row.rectTransform.pivot = new Vector2(0.5f, 0.5f); row.rectTransform.anchoredPosition = new Vector2(0f, y);
            var key = Img(row.rectTransform, "Key", Brown, new Vector2(40f, 40f));
            key.rectTransform.anchoredPosition = new Vector2(-355f, 0f);
            Txt(key.rectTransform, font, 24, Color.white, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(40f, 40f)).text = (i + 1).ToString();
            names[i] = Txt(row.rectTransform, font, 28, Ink, TextAnchor.MiddleLeft, FontStyle.Bold, new Vector2(-185f, 0f), new Vector2(200f, 50f));
            infos[i] = Txt(row.rectTransform, font, 19, new Color(0.4f, 0.3f, 0.22f), TextAnchor.MiddleLeft, FontStyle.Normal, new Vector2(85f, 0f), new Vector2(330f, 50f));
            states[i] = Txt(row.rectTransform, font, 26, Ink, TextAnchor.MiddleRight, FontStyle.Bold, new Vector2(310f, 0f), new Vector2(140f, 50f));
        }
        msgText = Txt(prt, font, 24, Brown, TextAnchor.MiddleCenter, FontStyle.Bold, new Vector2(0f, -218f), new Vector2(780f, 40f));
        Txt(prt, font, 22, new Color(0.4f, 0.3f, 0.22f), TextAnchor.MiddleCenter, FontStyle.Normal, new Vector2(0f, -250f), new Vector2(780f, 36f)).text = "숫자 키: 사기      F / Esc: 닫기";
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
