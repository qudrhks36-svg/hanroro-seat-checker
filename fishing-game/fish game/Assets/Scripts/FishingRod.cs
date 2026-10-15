using UnityEngine;
using UnityEngine.InputSystem;

// 왼쪽 클릭: 던지기 / 입질 타이밍에 맞춰 낚기 / 회수. 낚기 성공 뒤엔 릴 감기(왼쪽 버튼 누르고 있기).
// PlayerController보다 먼저 실행해서, 커서를 다시 고정하는 클릭은 던지기로 쓰지 않는다.
[DefaultExecutionOrder(-10)]
public class FishingRod : MonoBehaviour
{
    public Transform aimCamera;
    public Transform rodTip;
    public Transform bobber;
    public LineRenderer line;
    public float castDistance = 12f;
    public float castTime = 0.8f;
    public float arcHeight = 3f;
    public float waterY = -0.1f;
    public UnityEngine.UI.Text baitLabel;
    public Bait selectedBait = Bait.Worm; // 고른 미끼
    public Bait castBait;                 // 마지막으로 던진 미끼 (입질 시간·물고기 확률에 쓰임)
    public UnityEngine.UI.Text bangLabel;   // 입질 시 찌 위 느낌표
    public UnityEngine.UI.Text resultLabel; // 낚기 결과
    public float biteWindow = 1.6f;                  // 입질 후 클릭 가능 시간(초) (GDD 6번 16-1: 1.0→1.6)
    public FishData lastCatch;                       // 마지막으로 낚은 물고기 (6단계 도감·판매에서 사용)

    // 릴 감기 수치 (GDD 6번 [제안])
    public float reelZoneSpeed = 0.7f; // 내 칸 너비는 낚싯대 단계(RodUpgrade)에서 정해짐
    public float reelStart = 0.4f, reelGain = 0.4f, reelLoss = 0.2f;   // GDD 6번 16-1: 조금 더 쉽게
    static readonly float[] FishSpeed = { 0.3f, 0.5f, 0.75f }; // 흔함/보통/희귀

    public enum State { Idle, Flying, Floating, Biting, Reeling }
    State state = State.Idle;
    public State Current { get { return state; } }   // 안내 판(GuideHint)이 읽음
    FishData hooked;
    float zonePos, fishPos, fishTarget, retargetTimer, gauge;
    GameObject reelRoot;
    RectTransform zoneRt, fishRt, gaugeRt;
    const float BarW = 600f;
    Vector3 startPos, endPos;
    float t;
    float biteTimer;
    float resultHideTime;

    void Start()
    {
        SetCasting(false);
        if (baitLabel != null)
            baitLabel.font = GameFont.Get();
        var font = GameFont.Get();
        if (bangLabel != null) { bangLabel.font = font; bangLabel.gameObject.SetActive(false); }
        if (resultLabel != null) { resultLabel.font = font; resultLabel.text = ""; }
        UpdateLabel();
    }

    void Update()
    {
        var mouse = Mouse.current;
        var kb = Keyboard.current;
        if (mouse == null || kb == null) return;
        if (FarSea.Busy) return;   // 배로 이동하는 동안(화면이 어두워지는 사이)엔 던지기 등 입력을 막음

        // 미끼 선택: 숫자키 1·2·3 (대기 중일 때만)
        if (state == State.Idle && Cursor.lockState == CursorLockMode.Locked)
        {
            if (kb.digit1Key.wasPressedThisFrame) SelectBait(Bait.Worm);
            else if (kb.digit2Key.wasPressedThisFrame) SelectBait(Bait.Shrimp);
            else if (kb.digit3Key.wasPressedThisFrame) SelectBait(Bait.Bread);
        }
        bool click = mouse.leftButton.wasPressedThisFrame && Cursor.lockState == CursorLockMode.Locked;

        switch (state)
        {
            case State.Idle:
                if (click) Cast();
                break;
            case State.Flying:
                t += Time.deltaTime / castTime;
                float k = Mathf.Clamp01(t);
                bobber.position = Vector3.Lerp(startPos, endPos, k) + Vector3.up * Mathf.Sin(k * Mathf.PI) * arcHeight;
                if (k >= 1f) Land();
                break;
            case State.Floating:
                bobber.position = endPos + Vector3.up * Mathf.Sin(Time.time * 2f) * 0.03f;
                biteTimer -= Time.deltaTime;
                if (click) SetCasting(false);   // 입질 전에 감으면 그냥 회수
                else if (biteTimer <= 0f) StartBite();
                break;
            case State.Biting:
                bobber.position = endPos + Vector3.down * 0.15f; // 찌가 가라앉음
                biteTimer -= Time.deltaTime;
                if (click) Hook();
                else if (biteTimer <= 0f) { ShowResult("놓쳤어요..."); Sfx.Play(SfxKind.Miss); SetCasting(false); }
                break;
            case State.Reeling:
                bobber.position = endPos + Vector3.down * 0.15f;
                Reel(mouse.leftButton.isPressed && Cursor.lockState == CursorLockMode.Locked);
                break;
        }
        if (resultLabel != null && resultHideTime > 0f && Time.time > resultHideTime)
        {
            resultLabel.text = "";
            resultHideTime = 0f;
        }
    }

    void LateUpdate()
    {
        if (state == State.Idle) return;
        if (state == State.Biting && bangLabel != null)
            bangLabel.rectTransform.position = aimCamera.GetComponent<Camera>().WorldToScreenPoint(bobber.position + Vector3.up * 0.8f);
        line.SetPosition(0, rodTip.position);
        line.SetPosition(1, bobber.position);
    }

    void Cast()
    {
        Vector3 dir = aimCamera.forward; dir.y = 0f;
        if (dir.sqrMagnitude < 0.0001f) dir = transform.forward; // 바로 위/아래를 볼 때
        dir.Normalize();
        castBait = selectedBait;
        startPos = rodTip.position;
        endPos = new Vector3(startPos.x, waterY, startPos.z) + dir * castDistance;
        t = 0f;
        state = State.Flying;
        SetCasting(true);
        bobber.position = startPos;
        Sfx.Play(SfxKind.Cast);
    }

    void Land()
    {
        // 위에서 아래로 쏴서 바다가 먼저 맞으면 물 위, 섬·부두·배가 맞으면 육지.
        var from = new Vector3(endPos.x, 20f, endPos.z);
        bool water = Physics.Raycast(from, Vector3.down, out var hit, 40f) && hit.collider.name == "Sea";
        if (water)
        {
            state = State.Floating;
            biteTimer = Random.Range(BaitInfo.WaitMin(castBait), BaitInfo.WaitMax(castBait)); // 미끼마다 다름 (GDD 6번)
            Sfx.Play(SfxKind.Splash); SplashFx.Splash(endPos, false);   // 찌가 물에 닿는 물보라 (GDD 9번 낚시 연출)
        }
        else SetCasting(false); // 육지: 회수
    }

    void StartBite()
    {
        state = State.Biting;
        biteTimer = biteWindow;
        if (bangLabel != null) bangLabel.gameObject.SetActive(true);
        Sfx.Play(SfxKind.Bite);
        SplashFx.Ring(endPos, 1.1f);   // 입질 물결
    }

    // 입질 타이밍 성공 → 물고기를 정하고 릴 감기 시작
    void Hook()
    {
        hooked = FishTable.Pick(TimeOfDay.Current, castBait, FarSea.Active);   // 먼 바다에서는 먼 바다 전용 물고기만
        if (bangLabel != null) bangLabel.gameObject.SetActive(false);
        zonePos = 0.5f; fishPos = 0.5f; fishTarget = 0.5f; retargetTimer = 0f;
        gauge = reelStart;
        BuildReelUI();
        zoneRt.sizeDelta = new Vector2(RodUpgrade.ZoneWidth * BarW, 36f);
        reelRoot.SetActive(true);
        state = State.Reeling;
    }

    void Reel(bool held)
    {
        float dt = Time.deltaTime;
        zonePos = Mathf.Clamp01(zonePos + (held ? 1f : -1f) * reelZoneSpeed * dt);

        retargetTimer -= dt;
        if (retargetTimer <= 0f) { fishTarget = Random.value; retargetTimer = Random.Range(0.6f, 1.2f); }
        fishPos = Mathf.MoveTowards(fishPos, fishTarget, FishSpeed[(int)hooked.rarity] * dt);

        bool inside = Mathf.Abs(fishPos - zonePos) <= RodUpgrade.ZoneWidth * 0.5f;
        gauge = Mathf.Clamp01(gauge + (inside ? reelGain : -reelLoss) * dt);
        zoneRt.GetComponent<UnityEngine.UI.Image>().color = inside ? new Color(0.35f, 1f, 0.5f, 0.9f) : new Color(0.95f, 0.45f, 0.35f, 0.8f);   // 물고기를 잡고 있으면 밝은 초록, 놓치면 붉은 주황

        zoneRt.anchoredPosition = new Vector2((zonePos - 0.5f) * BarW, 0f);
        fishRt.anchoredPosition = new Vector2((fishPos - 0.5f) * BarW, 0f);
        gaugeRt.sizeDelta = new Vector2(gauge * BarW, gaugeRt.sizeDelta.y);

        if (gauge >= 1f) Catch();
        else if (gauge <= 0f) { ShowResult("물고기가 도망갔어요..."); Sfx.Play(SfxKind.Miss); EndReel(); }
    }

    void Catch()
    {
        lastCatch = hooked;
        bool isNew = Collection.Counts[Collection.IndexOf(lastCatch)] == 0;   // 처음 잡은 물고기인지 (결과 카드의 NEW 배지)
        int cm = Collection.RollSize(lastCatch);
        bool isRecord = Collection.Register(lastCatch, cm);   // 이미 잡아 본 물고기의 최고 크기를 넘었나 (GDD 9번)
        Inventory.Add(lastCatch);
        bool goalDone = Goal.OnCatch();   // 오늘의 목표 (GDD 9번)
        SaveData.Save();
        Sfx.Play(SfxKind.Catch);
        if (isNew) Sfx.Play(SfxKind.NewFish);   // 새 물고기 도감 등록 (GDD 2번)
        if (goalDone) Sfx.Play(SfxKind.GoalDone);   // 오늘의 목표 달성
        SplashFx.Splash(endPos, true);
        ResultCard.Show(lastCatch, isNew, bobber.position, aimCamera.GetComponent<Camera>(), goalDone, cm, isRecord);   // 물고기가 튀어오르고 결과 카드가 뜸 (GDD 9번)
        EndReel();
    }

    void EndReel()
    {
        reelRoot.SetActive(false);
        SetCasting(false);
    }

    // 릴 감기 화면: 임시 도형 (GDD 9번 [제안]). 처음 필요할 때 한 번만 만든다.
    void BuildReelUI()
    {
        if (reelRoot != null) return;
        var canvasGo = new GameObject("ReelCanvas");
        canvasGo.transform.SetParent(transform, false);
        var canvas = canvasGo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 4;
        reelRoot = canvasGo;

        MakeBox(canvasGo.transform, "Bar", new Color(1f, 0.97f, 0.9f, 0.82f), new Vector2(BarW, 36f), new Vector2(0f, -140f), 0.5f);
        var bar = canvasGo.transform.Find("Bar");
        zoneRt = MakeBox(bar, "Zone", new Color(0.5f, 0.82f, 0.6f, 0.9f), new Vector2(RodUpgrade.ZoneWidth * BarW, 36f), Vector2.zero, 0.5f);
        fishRt = MakeBox(bar, "Fish", new Color(1f, 0.55f, 0.35f), new Vector2(18f, 36f), Vector2.zero, 0.5f);
        MakeBox(canvasGo.transform, "GaugeBg", new Color(1f, 0.97f, 0.9f, 0.82f), new Vector2(BarW, 14f), new Vector2(0f, -185f), 0.5f);
        gaugeRt = MakeBox(canvasGo.transform.Find("GaugeBg"), "Gauge", new Color(1f, 0.9f, 0.4f), new Vector2(0f, 14f), new Vector2(-BarW * 0.5f, 0f), 0f);
    }

    // pivotX 0.5 = 가운데 기준, 0 = 왼쪽 기준
    static RectTransform MakeBox(Transform parent, string name, Color c, Vector2 size, Vector2 pos, float pivotX)
    {
        var go = new GameObject(name);
        go.transform.SetParent(parent, false);
        var img = go.AddComponent<UnityEngine.UI.Image>();
        img.color = c; img.raycastTarget = false;
        var rt = img.rectTransform;
        rt.anchorMin = rt.anchorMax = new Vector2(0.5f, 0.5f);
        rt.pivot = new Vector2(pivotX, 0.5f);
        rt.anchoredPosition = pos; rt.sizeDelta = size;
        return rt;
    }

    void ShowResult(string msg)
    {
        if (resultLabel == null) return;
        resultLabel.text = msg;
        resultHideTime = Time.time + 3f;
    }

    void SelectBait(Bait b)
    {
        selectedBait = b;
        UpdateLabel();
    }

    void UpdateLabel()
    {
        if (baitLabel != null) baitLabel.text = "미끼: " + BaitInfo.Name(selectedBait) + "  (1·2·3)";
    }

    void SetCasting(bool on)
    {
        if (!on) state = State.Idle;
        if (bangLabel != null) bangLabel.gameObject.SetActive(false);
        bobber.gameObject.SetActive(on);
        line.enabled = on;
    }
}
