using UnityEngine;
using UnityEngine.UI;

// 낚시 안내 판 (GDD 6번 16-1 [확정]): 화면 위쪽 가운데에 "지금 할 일"을 단계마다 보여준다.
// 장면에 올려 둘 것이 없고, 게임이 시작될 때 스스로 만들어진다. 대화창·상점·도감이 열려 있으면 숨긴다.
public class GuideHint : MonoBehaviour
{
    const float PanelW = 820f;
    GameObject panel;
    RectTransform panelRt, line1Rt;
    Text line1, line2;
    FishingRod rod;
    string shown1, shown2;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        var go = new GameObject("GuideHint");
        DontDestroyOnLoad(go);
        go.AddComponent<GuideHint>();
    }

    void Awake()
    {
        var canvas = new GameObject("GuideCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 3;

        var img = new GameObject("Panel").AddComponent<Image>();
        img.transform.SetParent(canvas.transform, false);
        img.sprite = HudPanel.RoundedRect(); img.type = Image.Type.Sliced;
        img.color = UiTheme.Cream; img.raycastTarget = false;
        var gol = img.gameObject.AddComponent<Outline>(); gol.effectColor = UiTheme.Edge; gol.effectDistance = new Vector2(2f, -2f);
        panel = img.gameObject; panelRt = img.rectTransform;
        panelRt.anchorMin = panelRt.anchorMax = panelRt.pivot = new Vector2(0.5f, 1f);
        panelRt.anchoredPosition = new Vector2(0, -24);

        var font = GameFont.Get();
        line1 = MakeText(panelRt, font, 28, UiTheme.Ink, FontStyle.Normal); line1Rt = line1.rectTransform;
        line2 = MakeText(panelRt, font, 19, UiTheme.InkSoft, FontStyle.Normal);
        panel.SetActive(false);
    }

    static Text MakeText(RectTransform parent, Font font, int size, Color c, FontStyle style)
    {
        var t = new GameObject("Text").AddComponent<Text>();
        t.transform.SetParent(parent, false);
        t.font = font; t.fontSize = size; t.fontStyle = style; t.color = c; t.alignment = TextAnchor.MiddleCenter; t.raycastTarget = false;
        t.resizeTextForBestFit = true; t.resizeTextMinSize = size * 2 / 3; t.resizeTextMaxSize = size;
        var rt = t.rectTransform;
        rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 1f); rt.pivot = new Vector2(0.5f, 1f);
        return t;
    }

    void Update()
    {
        if (rod == null) rod = FindFirstObjectByType<FishingRod>();
        bool busy = TalkNPC.IsOpen || ShopNPC.IsOpen || CatalogUI.IsOpen;
        string a = null, b = null;
        if (rod != null && !busy)
        {
            if (Cursor.lockState != CursorLockMode.Locked || !FishingRod.Armed) { a = "화면을 한 번 클릭하면 시작해요"; }
            else switch (rod.Current)
            {
                case FishingRod.State.Idle:
                    a = "왼쪽 클릭: 바다 쪽으로 낚싯대 던지기";
                    b = FarSea.Active ? "E: 배 가까이에서 부두로 돌아가기 · 1·2·3 미끼 · Tab 도감 · P 사진 · M 소리" : "WASD 이동 · 마우스 시점 · 1·2·3 미끼 · Tab 도감 · E 말 걸기 · P 사진 · M 소리";
                    break;
                case FishingRod.State.Floating:
                    a = "찌를 지켜보세요… 느낌표(!)가 뜨면 바로 왼쪽 클릭!";
                    b = "기다리다 마음이 바뀌면 왼쪽 클릭: 낚싯대 거두기";
                    break;
                case FishingRod.State.Biting:
                    a = "지금! 왼쪽 클릭!";
                    break;
                case FishingRod.State.Reeling:
                    a = "왼쪽 버튼을 꾹 누르면 초록 칸이 오른쪽으로, 떼면 왼쪽으로 가요";
                    b = "주황 물고기 위에 초록 칸을 맞추세요. 노란 게이지가 가득 차면 성공!";
                    break;
            }
        }
        panel.SetActive(a != null);
        if (a == null) return;
        if (a != shown1 || b != shown2)
        {
            shown1 = a; shown2 = b;
            line1.text = a; line2.text = b ?? ""; line2.gameObject.SetActive(b != null);
            float h1 = 40f, h2 = b != null ? 28f : 0f;   // 글자는 칸 안에 맞게 자동으로 줄어듦(bestFit)
            panelRt.sizeDelta = new Vector2(PanelW, 10f + h1 + h2 + 8f);
            line1Rt.sizeDelta = new Vector2(PanelW - 40f, h1); line1Rt.anchoredPosition = new Vector2(0, -10f);
            if (b != null) { line2.rectTransform.sizeDelta = new Vector2(PanelW - 40f, h2); line2.rectTransform.anchoredPosition = new Vector2(0, -(10f + h1)); }
        }
        // 입질이면 크게 깜빡여서 놓치지 않게
        panelRt.localScale = Vector3.one * (rod.Current == FishingRod.State.Biting ? 1f + 0.08f * Mathf.Sin(Time.unscaledTime * 12f) : 1f);
        line1.color = rod.Current == FishingRod.State.Biting ? UiTheme.Coral : UiTheme.Ink;
    }
}
