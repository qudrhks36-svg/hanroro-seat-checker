using UnityEngine;
using UnityEngine.UI;

// 낚시 대회 (GDD 9번 [확정]): 바틀이에게서 시작하는 3분 기록 도전. 점수 = 대회 중 잡은 가장 큰 물고기의 크기(cm).
// 장면에 올려 둘 것이 없고 게임이 시작될 때 스스로 만들어진다. 시간은 Time.deltaTime으로 세므로 대화창·도감이 열려 있으면 멈춘다.
public class Contest : MonoBehaviour
{
    public const float Duration = 180f;
    public static bool Active { get; private set; }
    public static int BestEver;   // 대회 최고 기록(cm). SaveData가 저장·불러온다.

    static Contest inst;
    static float timeLeft, cardUntil;
    static int bestCm;
    static FishData bestFish;

    FishingRod rod;
    GameObject pill, card;
    Text pillText, cardTitle, cardFish, cardPrize;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Active = false; BestEver = 0; inst = null; timeLeft = 0f; cardUntil = 0f; bestCm = 0; bestFish = null; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        var go = new GameObject("Contest");
        if (Application.isPlaying) DontDestroyOnLoad(go);
        go.AddComponent<Contest>();
    }

    // 낚싯대를 거두고 있고 이미 진행 중이 아닐 때만 시작할 수 있다.
    public static bool CanStart { get { return !Active && inst != null && inst.RodIdle(); } }

    public static void Begin()
    {
        if (!CanStart) return;
        Active = true; timeLeft = Duration; bestCm = 0; bestFish = null;
        inst.card.SetActive(false); cardUntil = 0f;
        Sfx.Play(SfxKind.Upgrade);
    }

    // 물고기를 낚을 때마다 FishingRod가 부른다.
    public static void OnCatch(FishData f, int cm)
    {
        if (!Active || (bestFish != null && cm <= bestCm)) return;
        bestFish = f; bestCm = cm;
    }

    bool RodIdle()
    {
        if (rod == null) rod = FindFirstObjectByType<FishingRod>();
        return rod != null && rod.Current == FishingRod.State.Idle && !FarSea.Busy;
    }

    void Awake()
    {
        inst = this;
        var font = GameFont.Get();
        var canvas = new GameObject("ContestCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 6;

        pill = Panel(canvas.transform, "Pill", new Vector2(1f, 1f), new Vector2(-24f, -24f), new Vector2(430f, 52f));
        pillText = Label(pill.transform, font, 26, UiTheme.Ink, new Vector2(430f, 52f), Vector2.zero);
        pill.SetActive(false);

        card = Panel(canvas.transform, "Card", new Vector2(0.5f, 0.5f), new Vector2(0f, 40f), new Vector2(620f, 230f));
        cardTitle = Label(card.transform, font, 40, UiTheme.Ink, new Vector2(600f, 56f), new Vector2(0f, 72f));
        cardFish = Label(card.transform, font, 30, UiTheme.Ink, new Vector2(600f, 44f), new Vector2(0f, 8f));
        cardPrize = Label(card.transform, font, 30, UiTheme.InkSoft, new Vector2(600f, 44f), new Vector2(0f, -56f));
        card.SetActive(false);
    }

    void OnDestroy() { if (inst == this) inst = null; }

    void Update()
    {
        if (Active)
        {
            timeLeft = Mathf.Max(0f, timeLeft - Time.deltaTime);
            // 시간이 다 됐을 때 입질·릴 감기 중이면 그 한 마리까지만 끝내고 마감
            if (timeLeft <= 0f && (rod == null || (rod.Current != FishingRod.State.Biting && rod.Current != FishingRod.State.Reeling))) Finish();
            else RefreshPill();
        }
        if (rod == null) rod = FindFirstObjectByType<FishingRod>();
        pill.SetActive(Active);
        if (cardUntil > 0f && Time.unscaledTime > cardUntil) { card.SetActive(false); cardUntil = 0f; }
    }

    void RefreshPill()
    {
        int s = Mathf.CeilToInt(timeLeft);
        string best = bestFish != null ? "최고 " + bestFish.name + " " + bestCm + "cm" : "아직 한 마리도 없어요";
        pillText.text = "낚시 대회 " + (s / 60) + ":" + (s % 60).ToString("00") + " · " + best;
    }

    void Finish()
    {
        Active = false;
        int prize; bool record = false;
        if (bestFish == null) prize = 10;   // 참가상
        else
        {
            prize = bestCm >= 100 ? 100 : bestCm >= 50 ? 50 : 20;
            if (bestCm > BestEver) { BestEver = bestCm; prize += 30; record = true; }
        }
        Inventory.Money += prize;
        SaveData.Save();
        Sfx.Play(record ? SfxKind.NewFish : SfxKind.GoalDone);

        cardTitle.text = record ? "대회 신기록!" : "대회 끝!";
        cardTitle.color = record ? UiTheme.Coral : UiTheme.Ink;
        cardFish.text = bestFish != null ? "가장 큰 물고기: " + bestFish.name + " " + bestCm + "cm" : "이번엔 한 마리도 못 잡았어요";
        cardPrize.text = (bestFish == null ? "참가상 +" : "상금 +") + prize + "원" + (record ? " (신기록 보너스 포함)" : "");
        card.SetActive(true);
        cardUntil = Time.unscaledTime + 7f;
        pill.SetActive(false);
    }

    static GameObject Panel(Transform parent, string name, Vector2 anchor, Vector2 pos, Vector2 size)
    {
        var img = new GameObject(name).AddComponent<Image>();
        img.transform.SetParent(parent, false);
        img.sprite = HudPanel.RoundedRect(); img.type = Image.Type.Sliced; img.color = UiTheme.Cream; img.raycastTarget = false;
        var o = img.gameObject.AddComponent<Outline>(); o.effectColor = UiTheme.Edge; o.effectDistance = new Vector2(2f, -2f);
        var rt = img.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = anchor;
        rt.anchoredPosition = pos; rt.sizeDelta = size;
        return img.gameObject;
    }

    static Text Label(Transform parent, Font font, int size, Color c, Vector2 sz, Vector2 pos)
    {
        var t = new GameObject("Text").AddComponent<Text>();
        t.transform.SetParent(parent, false);
        t.font = font; t.fontSize = size; t.color = c; t.alignment = TextAnchor.MiddleCenter; t.raycastTarget = false;
        t.resizeTextForBestFit = true; t.resizeTextMinSize = size * 2 / 3; t.resizeTextMaxSize = size;
        var rt = t.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f);
        rt.anchoredPosition = pos; rt.sizeDelta = sz;
        return t;
    }
}
