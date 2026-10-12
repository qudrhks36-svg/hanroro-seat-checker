using UnityEngine;
using UnityEngine.InputSystem;

// 왼쪽 클릭: 던지기 / 입질 타이밍에 맞춰 낚기 / 회수. 릴 감기는 이후 단계.
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
    public Bait castBait;                 // 마지막으로 던진 미끼 (효과는 GDD 확정 후)
    public UnityEngine.UI.Text bangLabel;   // 입질 시 찌 위 느낌표
    public UnityEngine.UI.Text resultLabel; // 낚기 결과
    public float biteWaitMin = 3f, biteWaitMax = 8f; // 입질까지 대기(초) [제안]
    public float biteWindow = 1f;                    // 입질 후 클릭 가능 시간(초) [제안]
    public FishData lastCatch;                       // 마지막으로 낚은 물고기 (6단계 도감·판매에서 사용)

    enum State { Idle, Flying, Floating, Biting }
    State state = State.Idle;
    Vector3 startPos, endPos;
    float t;
    float biteTimer;
    float resultHideTime;

    void Start()
    {
        SetCasting(false);
        if (baitLabel != null)
            baitLabel.font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "Arial" }, 28); // PC 가정
        var font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "Arial" }, 28);
        if (bangLabel != null) { bangLabel.font = font; bangLabel.gameObject.SetActive(false); }
        if (resultLabel != null) { resultLabel.font = font; resultLabel.text = ""; }
        UpdateLabel();
    }

    void Update()
    {
        var mouse = Mouse.current;
        var kb = Keyboard.current;
        if (mouse == null || kb == null) return;

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
                else if (biteTimer <= 0f) { ShowResult("놓쳤어요..."); SetCasting(false); }
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
    }

    void Land()
    {
        // 위에서 아래로 쏴서 바다가 먼저 맞으면 물 위, 섬·부두·배가 맞으면 육지.
        var from = new Vector3(endPos.x, 20f, endPos.z);
        bool water = Physics.Raycast(from, Vector3.down, out var hit, 40f) && hit.collider.name == "Sea";
        if (water)
        {
            state = State.Floating;
            biteTimer = Random.Range(biteWaitMin, biteWaitMax);
        }
        else SetCasting(false); // 육지: 회수
    }

    void StartBite()
    {
        state = State.Biting;
        biteTimer = biteWindow;
        if (bangLabel != null) bangLabel.gameObject.SetActive(true);
    }

    void Hook()
    {
        lastCatch = FishTable.Pick(TimeOfDay.Current);
        Collection.Register(lastCatch);
        Inventory.Add(lastCatch);
        ShowResult("낚았다! " + lastCatch.name + " (" + FishTable.RarityName(lastCatch.rarity) + ")  미끼: " + BaitInfo.Name(castBait));
        SetCasting(false);
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
