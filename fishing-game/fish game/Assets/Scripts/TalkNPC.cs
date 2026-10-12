using System.Text;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.InputSystem;

// 끼룩이·모카·돌쇠(GDD 3번): 3m 안에서 바라보고 E → 대화창, E/Esc로 닫기. 열려 있는 동안 시간이 멈춘다.
// buyMultiplier > 0 이면 상인: 왼쪽 클릭으로 가진 물고기를 모두 (배율만큼 쳐서) 산다. onlySunset이면 노을에만 나타난다.
[DefaultExecutionOrder(-20)]
public class TalkNPC : MonoBehaviour
{
    public static bool IsOpen { get; private set; }
    public static int ClosedFrame = -1; // 닫은 프레임: 같은 프레임의 Esc를 PlayerController가 또 처리하지 않게

    public string npcName;
    public string[] lines;         // 짧은 말 (무작위로 하나)
    public Camera cam;
    public GameObject body;        // 눈에 보이는 모양 (노을에만 나타나는 NPC가 숨길 대상)
    public float talkDistance = 3f;
    public float buyMultiplier;    // 0이면 사지 않음
    public bool onlySunset;
    public TalkVoice voice;        // 말을 걸 때 나는 소리 (None이면 소리 없음)
    public float voiceVolume = 0.5f;

    AudioSource voiceSource;
    AudioClip voiceClip;
    GameObject panel, prompt;
    Text dialogText;
    string message;
    bool open, sold;

    void Awake()
    {
        IsOpen = false;
        Build();
        panel.SetActive(false);
        prompt.SetActive(false);
        voiceClip = SfxSynth.Clip(voice);
        if (voiceClip != null)
        {
            voiceSource = gameObject.AddComponent<AudioSource>();
            voiceSource.playOnAwake = false; voiceSource.spatialBlend = 0f; // 2D(말 거는 순간 또렷하게)
        }
    }

    void OnDestroy() { if (open) { Time.timeScale = 1f; IsOpen = false; } }

    void Update()
    {
        var kb = Keyboard.current; var mouse = Mouse.current;
        if (kb == null || mouse == null) return;

        bool present = !onlySunset || TimeOfDay.Current == Period.Sunset;
        if (body != null && body.activeSelf != present) body.SetActive(present);

        if (open)
        {
            if (kb.eKey.wasPressedThisFrame || kb.escapeKey.wasPressedThisFrame) { SetOpen(false); return; }
            if (buyMultiplier > 0f && mouse.leftButton.wasPressedThisFrame && Inventory.TotalCount > 0)
            {
                int earned = Inventory.SellAll(buyMultiplier);
                SaveData.Save();
                message = "자, 여기 " + earned + "원이야! 또 잡아 오게나!";
                sold = true;
                RefreshDialog();
            }
            return;
        }

        bool near = present && !IsOpen && !ShopNPC.IsOpen && !CatalogUI.IsOpen
                    && Cursor.lockState == CursorLockMode.Locked && Looking();
        prompt.SetActive(near);
        if (near && kb.eKey.wasPressedThisFrame) SetOpen(true);
    }

    bool Looking()
    {
        Vector3 to = transform.position + Vector3.up * 0.5f - cam.transform.position;
        if (to.magnitude > talkDistance) return false;
        return Vector3.Dot(cam.transform.forward, to.normalized) > 0.8f;
    }

    void SetOpen(bool on)
    {
        open = on;
        IsOpen = on;
        if (!on) ClosedFrame = Time.frameCount;
        prompt.SetActive(false);
        panel.SetActive(on);
        Time.timeScale = on ? 0f : 1f;
        Cursor.lockState = on ? CursorLockMode.None : CursorLockMode.Locked;
        Cursor.visible = on;
        if (on)
        {
            if (voiceSource != null) voiceSource.PlayOneShot(voiceClip, voiceVolume);   // 시간이 멈춰도(timeScale 0) 재생됨
            sold = false;
            if (buyMultiplier > 0f)
                message = Inventory.TotalCount > 0 ? "허허, 좋은 물고기구먼! 값을 20% 더 쳐주지." : "허허! 팔 물고기가 없구먼. 잡아 오게나!";
            else message = lines[Random.Range(0, lines.Length)];
            RefreshDialog();
        }
    }

    void RefreshDialog()
    {
        var sb = new StringBuilder(npcName).Append("\n\n").Append(message).Append("\n");
        if (buyMultiplier > 0f && Inventory.TotalCount > 0)
        {
            sb.Append("\n");
            for (int i = 0; i < Inventory.Counts.Length; i++)
                if (Inventory.Counts[i] > 0) sb.Append(FishTable.All[i].name).Append(" x").Append(Inventory.Counts[i]).Append("   ");
            sb.Append("\n합계 ").Append(Inventory.ValueWith(buyMultiplier)).Append("원  —  [왼쪽 클릭] 모두 팔기");
        }
        else if (buyMultiplier > 0f && !sold) sb.Append("\n(팔 물고기가 없어요)");
        sb.Append("\n[E / Esc] 닫기");
        dialogText.text = sb.ToString();
    }

    // ---- UI 만들기 (ShopNPC와 같은 모양) ----
    void Build()
    {
        var font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "Arial" }, 28); // PC 가정
        var canvasGo = new GameObject("TalkCanvas");
        canvasGo.transform.SetParent(transform, false);
        var canvas = canvasGo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 5;

        prompt = MakeText(canvasGo.transform, "Prompt", font, 28, TextAnchor.MiddleCenter, Color.white).gameObject;
        var pt = prompt.GetComponent<Text>(); pt.text = "E: " + npcName + "에게 말 걸기";
        Anchor(pt.rectTransform, new Vector2(0.5f, 0.5f), new Vector2(0, -80), new Vector2(600, 50));

        panel = new GameObject("Dialog");
        panel.transform.SetParent(canvasGo.transform, false);
        var bg = panel.AddComponent<UnityEngine.UI.Image>();
        bg.color = new Color(0.98f, 0.93f, 0.82f, 0.96f);
        bg.raycastTarget = false;
        Anchor(bg.rectTransform, new Vector2(0.5f, 0f), new Vector2(0, 150), new Vector2(900, 320));
        dialogText = MakeText(panel.transform, "Text", font, 26, TextAnchor.UpperLeft, new Color(0.15f, 0.12f, 0.1f));
        Anchor(dialogText.rectTransform, new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(840, 280));
    }

    static Text MakeText(Transform parent, string name, Font font, int size, TextAnchor align, Color c)
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
