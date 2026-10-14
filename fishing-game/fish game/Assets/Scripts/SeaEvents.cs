using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

// 아기자기한 이벤트 (GDD 9번 [확정]): ① 가끔 하늘을 가로지르는 갈매기 ② 몇 분에 한 번 해변에 떠밀려 오는 병(E로 줍기 → 쪽지 + 돈).
// 게임이 시작될 때 스스로 만들어진다(장면에 올릴 것 없음). Time.deltaTime을 써서 도감·대화 중(timeScale 0)에는 멈춘다. 쪽지는 시간을 멈추지 않는 카드로 보여준다.
// 모양 재질은 장면의 구름 재질을 복사해 쓴다(웹 빌드에서 셰이더가 빠지지 않게).
public class SeaEvents : MonoBehaviour
{
    public const int NoteCount = 10;
    public static int NotesFound;   // 읽은 쪽지(비트 마스크, 저장됨)
    public static int FoundCount { get { int n = 0; for (int i = 0; i < NoteCount; i++) if ((NotesFound >> i & 1) != 0) n++; return n; } }

    static readonly string[] Notes =
    {
        "오늘도 파도는 느긋하게 오고 있어요. 서두르지 않아도 괜찮아요.",
        "이 병을 줍는 당신에게, 오늘 하루도 수고했다고 말하고 싶었어요.",
        "물고기가 안 잡혀도 괜찮아요. 바다를 보고 있는 것만으로 충분해요.",
        "저는 아주 먼 곳에 사는 사람이에요. 이 바다가 당신에게 닿길 바라며 병을 띄워요.",
        "노을이 질 때, 잠깐 멈추고 하늘을 올려다보세요. 제가 가장 좋아하는 시간이에요.",
        "작은 일을 오래 하는 것도 대단한 거래요. 낚시처럼요.",
        "밤하늘에 별똥별을 봤다면 소원 하나 빌었길 바라요. 저도 빌었거든요.",
        "비 오는 날의 바다는 조용해서 좋아요. 마음까지 젖지는 않으니까요.",
        "갈매기가 이 병을 여기까지 데려다줬나 봐요. 고마운 친구예요.",
        "여기까지 찾아 줘서 고마워요. 당신의 하루가 따뜻하길 바라요.",
    };

    const float BottleMinDelay = 120f, BottleMaxDelay = 240f, NextMin = 180f, NextMax = 300f;
    const float GullMinDelay = 40f, GullMaxDelay = 90f, GullSpeed = 8f, PickDistance = 2.6f;
    const float NoteHold = 7f, ToastHold = 6f;

    Material baseMat;
    GameObject bottle, gull;
    float bottleTimer, gullTimer, bottleBob;
    Vector3 gullFrom, gullTo; float gullT, gullLen, gullCry; Transform gullWingL, gullWingR; AudioSource gullAudio; AudioClip gullClip;
    Transform diamond;

    // UI
    CanvasGroup noteGroup, toastGroup, promptGroup;
    RectTransform noteRt;
    Text noteTitle, noteText, noteReward, toastText;
    float noteT0 = -999f, toastT0 = -999f;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { NotesFound = 0; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("SeaEvents").AddComponent<SeaEvents>(); }

    void Awake()
    {
        var cd = FindFirstObjectByType<CloudDrift>();
        baseMat = cd != null ? cd.material : null;
        if (baseMat == null) Debug.LogWarning("SeaEvents: 구름 재질이 없어 갈매기·병을 만들 수 없어요.");
        bottleTimer = Random.Range(BottleMinDelay, BottleMaxDelay);
        gullTimer = Random.Range(GullMinDelay, GullMaxDelay);
        gullClip = SfxSynth.Clip(TalkVoice.Seagull);
        BuildUi();
    }

    void Update()
    {
        if (baseMat != null)
        {
            UpdateBottle();
            UpdateGull();
        }
        UpdateUi();
    }

    // ---------------- 병 ----------------
    void UpdateBottle()
    {
        var cam = Camera.main;
        if (bottle == null)
        {
            bottleTimer -= Time.deltaTime;
            if (bottleTimer <= 0f && cam != null && SpawnBottle()) { toastT0 = Time.unscaledTime; toastText.text = "해변에 병이 떠밀려 왔어요!"; }
            promptGroup.alpha = 0f;
            return;
        }
        bottleBob += Time.deltaTime;
        diamond.localPosition = new Vector3(0f, 0.55f + 0.08f * Mathf.Sin(bottleBob * 3f), 0f);
        diamond.Rotate(0f, 90f * Time.deltaTime, 0f, Space.World);

        bool near = cam != null && !TalkNPC.IsOpen && !ShopNPC.IsOpen && !CatalogUI.IsOpen && Cursor.lockState == CursorLockMode.Locked && BottleReachable(cam);
        promptGroup.alpha = near ? 1f : 0f;
        var kb = Keyboard.current;
        if (near && kb != null && kb.eKey.wasPressedThisFrame) PickUp();
    }

    bool BottleReachable(Camera cam)
    {
        Vector3 to = bottle.transform.position - cam.transform.position;
        Vector3 flat = new Vector3(to.x, 0f, to.z);
        return flat.magnitude < PickDistance && Vector3.Dot(cam.transform.forward, to.normalized) > 0.5f;
    }

    void PickUp()
    {
        int idx = PickNoteIndex();
        bool fresh = (NotesFound >> idx & 1) == 0;
        NotesFound |= 1 << idx;
        int reward = Random.Range(3, 9) * 10;   // 30~80원
        Inventory.Money += reward;
        SaveData.Save();
        Sfx.Play(SfxKind.NewFish);
        Destroy(bottle); bottle = null;
        bottleTimer = Random.Range(NextMin, NextMax);
        ShowNote(idx, reward, fresh);
    }

    // 아직 못 읽은 쪽지가 있으면 그 중에서, 다 읽었으면 아무거나
    static int PickNoteIndex()
    {
        var left = new System.Collections.Generic.List<int>();
        for (int i = 0; i < NoteCount; i++) if ((NotesFound >> i & 1) == 0) left.Add(i);
        return left.Count > 0 ? left[Random.Range(0, left.Count)] : Random.Range(0, NoteCount);
    }

    public void ShowNote(int idx, int reward, bool fresh)
    {
        noteTitle.text = "병 속 쪽지   " + FoundCount + "/" + NoteCount + (fresh ? "" : "  (읽은 쪽지)");
        noteText.text = Notes[idx];
        noteReward.text = "+" + reward + "원";
        noteT0 = Time.unscaledTime;
    }

    // 해변(반지름 15.3~16.3, 모래밭)의 비어 있는 자리를 찾아 병을 놓는다
    bool SpawnBottle()
    {
        for (int tries = 0; tries < 30; tries++)
        {
            float a = Random.value * Mathf.PI * 2f, r = Random.Range(15.3f, 16.3f);
            if (TryGround(new Vector3(Mathf.Cos(a) * r, 0f, Mathf.Sin(a) * r), out var p)) { PlaceBottle(p); return true; }
        }
        bottleTimer = 30f;   // 자리를 못 찾으면 잠시 뒤 다시
        return false;
    }

    static bool TryGround(Vector3 xz, out Vector3 point)
    {
        point = Vector3.zero;
        var hits = Physics.RaycastAll(new Vector3(xz.x, 20f, xz.z), Vector3.down, 40f);
        float best = float.NegativeInfinity; RaycastHit top = default;
        foreach (var h in hits) if (h.collider.name != "Sea" && h.point.y > best) { best = h.point.y; top = h; }
        if (best == float.NegativeInfinity || top.normal.y < 0.8f || top.point.y < 0.02f) return false;
        if (Physics.OverlapSphere(top.point + Vector3.up * 0.4f, 0.32f).Length > 0) return false;   // 다른 물건(야자수·바위·울타리)과 겹치지 않게
        point = top.point;
        return true;
    }

    public void PlaceBottle(Vector3 ground)
    {
        bottle = new GameObject("Bottle");
        bottle.transform.position = ground;
        bottle.transform.rotation = Quaternion.Euler(0f, Random.value * 360f, 0f);
        var glass = Tinted(new Color(0.55f, 0.85f, 0.8f)); var cork = Tinted(new Color(0.7f, 0.5f, 0.3f)); var paper = Tinted(new Color(1f, 0.95f, 0.8f));
        Part(PrimitiveType.Cylinder, bottle.transform, new Vector3(0f, 0.13f, 0f), new Vector3(0.26f, 0.2f, 0.26f), Quaternion.Euler(0f, 0f, 90f), glass);        // 몸통(누워 있음)
        Part(PrimitiveType.Cylinder, bottle.transform, new Vector3(0.3f, 0.13f, 0f), new Vector3(0.12f, 0.12f, 0.12f), Quaternion.Euler(0f, 0f, 90f), glass);       // 목
        Part(PrimitiveType.Sphere, bottle.transform, new Vector3(0.44f, 0.13f, 0f), new Vector3(0.12f, 0.12f, 0.12f), Quaternion.identity, cork);                    // 코르크
        Part(PrimitiveType.Cylinder, bottle.transform, new Vector3(-0.02f, 0.13f, 0f), new Vector3(0.14f, 0.14f, 0.14f), Quaternion.Euler(0f, 0f, 90f), paper);       // 안에 든 쪽지(둘둘 말림)
        var d = Part(PrimitiveType.Sphere, bottle.transform, new Vector3(0f, 0.55f, 0f), new Vector3(0.14f, 0.2f, 0.14f), Quaternion.identity, Tinted(new Color(1f, 0.85f, 0.25f)));   // 위에 떠서 도는 노란 반짝이
        diamond = d.transform; bottleBob = 0f;
        bottle.transform.localScale = Vector3.one * 1.4f;   // 멀리서도 눈에 띄게
    }

    // ---------------- 갈매기 ----------------
    void UpdateGull()
    {
        var cam = Camera.main;
        if (gull == null)
        {
            gullTimer -= Time.deltaTime;
            if (gullTimer <= 0f)
            {
                if (cam != null && Weather.Rain < 0.3f && TimeOfDay.Night < 0.5f) SpawnGull();   // 비 오는 날·밤에는 날지 않음
                gullTimer = Random.Range(GullMinDelay, GullMaxDelay);
            }
            return;
        }
        gullT += Time.deltaTime * GullSpeed / gullLen;
        if (gullT >= 1f) { Destroy(gull); gull = null; return; }
        Vector3 p = Vector3.Lerp(gullFrom, gullTo, gullT); p.y += Mathf.Sin(gullT * 9f) * 0.7f;
        gull.transform.position = p;
        float flap = Mathf.Sin(Time.time * 9f) * 35f;
        gullWingL.localRotation = Quaternion.Euler(flap, 0f, 0f); gullWingR.localRotation = Quaternion.Euler(-flap, 0f, 0f);
        gullCry -= Time.deltaTime;
        if (gullCry <= 0f && cam != null && Vector3.Distance(p, cam.transform.position) < 70f && gullClip != null)
        {
            gullAudio.PlayOneShot(gullClip, 0.4f); gullCry = Random.Range(5f, 9f);
        }
    }

    void SpawnGull()
    {
        float a = Random.value * Mathf.PI * 2f, h = Random.Range(12f, 20f);
        Vector3 dir = new Vector3(Mathf.Cos(a), 0f, Mathf.Sin(a)), side = new Vector3(-dir.z, 0f, dir.x);
        StartGull(dir * 90f + Vector3.up * h + side * Random.Range(-25f, 25f), -dir * 90f + Vector3.up * h + side * Random.Range(-25f, 25f));
    }

    public void StartGull(Vector3 from, Vector3 to)
    {
        if (gull != null) Destroy(gull);
        gull = new GameObject("Seagull");
        gullFrom = from; gullTo = to; gullT = 0f; gullLen = Vector3.Distance(from, to); gullCry = 1f;
        Vector3 dir = (to - from).normalized;
        gull.transform.position = from; gull.transform.rotation = Quaternion.LookRotation(dir) * Quaternion.Euler(0f, -90f, 0f);   // 몸의 앞(+x)이 날아가는 쪽
        var white = Tinted(new Color(0.97f, 0.97f, 0.98f)); var beak = Tinted(new Color(1f, 0.7f, 0.2f)); var tip = Tinted(new Color(0.35f, 0.38f, 0.45f));
        Part(PrimitiveType.Sphere, gull.transform, Vector3.zero, new Vector3(0.9f, 0.4f, 0.4f), Quaternion.identity, white);                                // 몸
        Part(PrimitiveType.Sphere, gull.transform, new Vector3(0.5f, 0.12f, 0f), new Vector3(0.3f, 0.28f, 0.28f), Quaternion.identity, white);              // 머리
        Part(PrimitiveType.Cylinder, gull.transform, new Vector3(0.74f, 0.1f, 0f), new Vector3(0.07f, 0.12f, 0.07f), Quaternion.Euler(0f, 0f, 90f), beak);  // 부리
        Part(PrimitiveType.Cube, gull.transform, new Vector3(-0.55f, 0.04f, 0f), new Vector3(0.5f, 0.05f, 0.3f), Quaternion.identity, white);               // 꼬리
        gullWingL = Wing(white, tip, 1f); gullWingR = Wing(white, tip, -1f);
        gull.transform.localScale = Vector3.one * 1.8f;
        gullAudio = gull.AddComponent<AudioSource>();
        gullAudio.spatialBlend = 1f; gullAudio.rolloffMode = AudioRolloffMode.Linear; gullAudio.minDistance = 8f; gullAudio.maxDistance = 80f;
    }

    Transform Wing(Material white, Material tip, float side)
    {
        var pivot = new GameObject("Wing").transform; pivot.SetParent(gull.transform, false);
        pivot.localPosition = new Vector3(0.05f, 0.08f, 0.15f * side);
        Part(PrimitiveType.Cube, pivot, new Vector3(0f, 0f, 0.55f * side), new Vector3(0.42f, 0.03f, 1.1f), Quaternion.identity, white);                    // 날개
        Part(PrimitiveType.Cube, pivot, new Vector3(-0.02f, 0f, 1.08f * side), new Vector3(0.3f, 0.032f, 0.28f), Quaternion.identity, tip);                // 날개 끝(어두운 색)
        return pivot;
    }

    // ---------------- 공통 ----------------
    readonly System.Collections.Generic.Dictionary<Color, Material> tints = new System.Collections.Generic.Dictionary<Color, Material>();
    Material Tinted(Color c)   // 같은 색은 한 번만 만들어 재사용(스폰할 때마다 재질이 쌓이지 않게)
    {
        Material m;
        if (!tints.TryGetValue(c, out m)) tints[c] = m = new Material(baseMat) { color = c };
        return m;
    }

    static GameObject Part(PrimitiveType type, Transform parent, Vector3 pos, Vector3 scale, Quaternion rot, Material m)
    {
        var go = GameObject.CreatePrimitive(type);
        Destroy(go.GetComponent<Collider>());
        go.transform.SetParent(parent, false); go.transform.localPosition = pos; go.transform.localRotation = rot; go.transform.localScale = scale;
        var r = go.GetComponent<Renderer>(); r.sharedMaterial = m; r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
        return go;
    }

    // ---------------- UI ----------------
    static readonly Color Cream = new Color(0.99f, 0.95f, 0.86f, 0.98f), Ink = new Color(0.22f, 0.15f, 0.10f);

    void BuildUi()
    {
        var font = GameFont.Get();
        var canvas = new GameObject("EventCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay; canvas.sortingOrder = 6;

        // 쪽지 카드 (화면 가운데 위쪽)
        var card = Img(canvas.transform, "NoteCard", Cream, new Vector2(760f, 230f));
        noteRt = card.rectTransform; noteRt.anchorMin = noteRt.anchorMax = noteRt.pivot = new Vector2(0.5f, 0.5f); noteRt.anchoredPosition = new Vector2(0f, 130f);
        var ol = card.gameObject.AddComponent<Outline>(); ol.effectColor = new Color(0.45f, 0.30f, 0.18f, 0.9f); ol.effectDistance = new Vector2(2.5f, -2.5f);
        noteGroup = card.gameObject.AddComponent<CanvasGroup>(); noteGroup.alpha = 0f; noteGroup.blocksRaycasts = false; noteGroup.interactable = false;
        noteTitle = Txt(noteRt, font, 24, new Color(0.45f, 0.30f, 0.18f), TextAnchor.MiddleLeft, FontStyle.Bold, new Vector2(0f, 90f), new Vector2(700f, 36f));
        noteText = Txt(noteRt, font, 30, Ink, TextAnchor.MiddleCenter, FontStyle.Normal, new Vector2(0f, 10f), new Vector2(690f, 110f));
        var chip = Img(noteRt, "Reward", new Color(1f, 0.82f, 0.28f), new Vector2(150f, 42f));
        chip.rectTransform.anchorMin = chip.rectTransform.anchorMax = chip.rectTransform.pivot = new Vector2(0.5f, 0.5f); chip.rectTransform.anchoredPosition = new Vector2(0f, -82f);
        noteReward = Txt(chip.rectTransform, font, 26, Ink, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(150f, 42f));

        // 알림(위쪽 가운데)
        var toast = Img(canvas.transform, "Toast", new Color(0.07f, 0.09f, 0.13f, 0.7f), new Vector2(520f, 54f));
        var trt = toast.rectTransform; trt.anchorMin = trt.anchorMax = trt.pivot = new Vector2(0.5f, 1f); trt.anchoredPosition = new Vector2(0f, -24f);
        toastGroup = toast.gameObject.AddComponent<CanvasGroup>(); toastGroup.alpha = 0f; toastGroup.blocksRaycasts = false;
        toastText = Txt(trt, font, 28, new Color(1f, 0.96f, 0.85f), TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(500f, 50f));

        // 줍기 안내 (대화 안내와 같은 자리)
        var pr = Img(canvas.transform, "Prompt", new Color(0.07f, 0.09f, 0.13f, 0.62f), new Vector2(260f, 50f));
        var prt = pr.rectTransform; prt.anchorMin = prt.anchorMax = prt.pivot = new Vector2(0.5f, 0.5f); prt.anchoredPosition = new Vector2(0f, -80f);
        promptGroup = pr.gameObject.AddComponent<CanvasGroup>(); promptGroup.alpha = 0f; promptGroup.blocksRaycasts = false;
        Txt(prt, font, 28, Color.white, TextAnchor.MiddleCenter, FontStyle.Bold, Vector2.zero, new Vector2(250f, 46f)).text = "E: 병 줍기";
    }

    void UpdateUi()
    {
        float t = Time.unscaledTime - noteT0;
        if (t > NoteHold + 0.5f) noteGroup.alpha = 0f;
        else
        {
            float pt = Mathf.Clamp01(t / 0.3f);
            noteRt.localScale = Vector3.one * Mathf.Lerp(0.85f, 1f, pt);
            noteGroup.alpha = Mathf.Clamp01(pt * 3f) * (1f - Mathf.Clamp01((t - NoteHold) / 0.5f));
        }
        float tt = Time.unscaledTime - toastT0;
        toastGroup.alpha = tt > ToastHold + 0.5f ? 0f : Mathf.Clamp01(tt * 4f) * (1f - Mathf.Clamp01((tt - ToastHold) / 0.5f));
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
