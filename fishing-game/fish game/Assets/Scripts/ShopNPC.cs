using System.Text;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.InputSystem;

// 바틀이(햄스터): 3m 안에서 바라보고 E → 대화창. 왼쪽 클릭 = 물고기 모두 판매. E/Esc = 닫기.
// 열려 있는 동안 시간이 멈춘다. 소지금 표시(화면 하단 오른쪽)도 여기서 만든다.
[DefaultExecutionOrder(-20)]
public class ShopNPC : MonoBehaviour
{
    public static bool IsOpen { get; private set; }
    public static int ClosedFrame = -1; // 닫은 프레임: 같은 프레임의 Esc를 PlayerController가 또 처리하지 않게

    public Transform player;
    public Camera cam;
    public float talkDistance = 3f;

    static readonly string[] Tips =
    {
        "바, 바다 쪽으로 던져야 해요… 땅에 던지면 찌가 그냥 돌아와 버려요.",
        "찌 위에 느낌표가 뜨면… 바로 클릭하는 거예요. 금방 사라지니까 조, 조심하세요.",
        "가끔 구름이나 별 모양 물고기가 있대요… 정말인지는, 저도 모르겠지만요.",
    };

    GameObject panel, prompt;
    Text dialogText, moneyText;
    Font font;
    string message;
    bool sold;

    void Awake()
    {
        IsOpen = false;
        font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "Arial" }, 28); // PC 가정
        Build();
        panel.SetActive(false);
        prompt.SetActive(false);
        UpdateMoney();
    }

    void OnDestroy() { if (IsOpen) Time.timeScale = 1f; IsOpen = false; }

    void Update()
    {
        var kb = Keyboard.current; var mouse = Mouse.current;
        if (kb == null || mouse == null) return;

        if (IsOpen)
        {
            if (kb.eKey.wasPressedThisFrame || kb.escapeKey.wasPressedThisFrame) { SetOpen(false); return; }
            if (mouse.leftButton.wasPressedThisFrame && Inventory.TotalCount > 0)
            {
                int earned = Inventory.SellAll();
                message = "고, 고마워요… 여기 " + earned + "원이에요.";
                sold = true;
                UpdateMoney();
                RefreshDialog();
            }
            else if (mouse.rightButton.wasPressedThisFrame)
            {
                if (RodUpgrade.IsMax) message = "더, 더 좋은 낚싯대는… 저도 없어요.";
                else if (RodUpgrade.TryBuy()) message = "와… " + RodUpgrade.Name + "예요. 잘 어울려요!";
                else message = "으음… 돈이 조금 모자라요. " + RodUpgrade.NextCost + "원이 필요해요.";
                sold = true;
                UpdateMoney();
                RefreshDialog();
            }
            return;
        }

        if (shownMoney != Inventory.Money) UpdateMoney(); // 상인(돌쇠)에게 판 돈도 반영
        bool near = !CatalogUI.IsOpen && !TalkNPC.IsOpen && Cursor.lockState == CursorLockMode.Locked && Looking();
        prompt.SetActive(near);
        if (near && kb.eKey.wasPressedThisFrame) SetOpen(true);
    }

    bool Looking()
    {
        Vector3 to = transform.position + Vector3.up * 0.7f - cam.transform.position;
        if (to.magnitude > talkDistance) return false;
        return Vector3.Dot(cam.transform.forward, to.normalized) > 0.8f;
    }

    void SetOpen(bool open)
    {
        IsOpen = open;
        if (!open) ClosedFrame = Time.frameCount;
        prompt.SetActive(false);
        panel.SetActive(open);
        Time.timeScale = open ? 0f : 1f;
        Cursor.lockState = open ? CursorLockMode.None : CursorLockMode.Locked;
        Cursor.visible = open;
        if (open)
        {
            sold = false;
            message = Inventory.TotalCount > 0 ? "저, 저기… 물고기 잡으셨네요." : Tips[Random.Range(0, Tips.Length)];
            RefreshDialog();
        }
    }

    void RefreshDialog()
    {
        var sb = new StringBuilder("바틀이\n\n").Append(message).Append("\n");
        if (Inventory.TotalCount > 0)
        {
            sb.Append("\n");
            for (int i = 0; i < Inventory.Counts.Length; i++)
                if (Inventory.Counts[i] > 0) sb.Append(FishTable.All[i].name).Append(" x").Append(Inventory.Counts[i]).Append("   ");
            sb.Append("\n합계 ").Append(Inventory.TotalValue).Append("원  —  [왼쪽 클릭] 모두 팔기");
        }
        else if (!sold) sb.Append("\n(팔 물고기가 없어요)");
        sb.Append("\n낚싯대: ").Append(RodUpgrade.Name);
        if (!RodUpgrade.IsMax) sb.Append("   —   [오른쪽 클릭] ").Append(RodUpgrade.NextName).Append(" ").Append(RodUpgrade.NextCost).Append("원");
        sb.Append("\n[E / Esc] 닫기");
        dialogText.text = sb.ToString();
    }

    int shownMoney = -1;
    void UpdateMoney() { shownMoney = Inventory.Money; moneyText.text = "소지금 " + Inventory.Money + "원"; }

    // ---- UI 만들기 ----
    void Build()
    {
        var canvasGo = new GameObject("ShopCanvas");
        canvasGo.transform.SetParent(transform, false);
        var canvas = canvasGo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 5;

        moneyText = MakeText(canvasGo.transform, "Money", 28, TextAnchor.LowerRight, new Color(1f, 0.96f, 0.88f));
        Anchor(moneyText.rectTransform, new Vector2(1, 0), new Vector2(-30, 30), new Vector2(400, 50));

        prompt = MakeText(canvasGo.transform, "Prompt", 28, TextAnchor.MiddleCenter, Color.white).gameObject;
        var pt = prompt.GetComponent<Text>(); pt.text = "E: 바틀이와 이야기하기";
        Anchor(pt.rectTransform, new Vector2(0.5f, 0.5f), new Vector2(0, -80), new Vector2(600, 50));

        panel = new GameObject("Dialog");
        panel.transform.SetParent(canvasGo.transform, false);
        var bg = panel.AddComponent<Image>();
        bg.color = new Color(0.98f, 0.93f, 0.82f, 0.96f);
        bg.raycastTarget = false;
        Anchor(bg.rectTransform, new Vector2(0.5f, 0f), new Vector2(0, 150), new Vector2(900, 320));
        dialogText = MakeText(panel.transform, "Text", 26, TextAnchor.UpperLeft, new Color(0.15f, 0.12f, 0.1f));
        Anchor(dialogText.rectTransform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(840, 280));
    }

    Text MakeText(Transform parent, string name, int size, TextAnchor align, Color c)
    {
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        var t = go.AddComponent<Text>();
        t.font = font; t.fontSize = size; t.alignment = align; t.color = c; t.raycastTarget = false;
        return t;
    }

    static void Anchor(RectTransform rt, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        rt.anchorMin = rt.anchorMax = rt.pivot = anchor;
        rt.anchoredPosition = pos; rt.sizeDelta = size;
    }
}
