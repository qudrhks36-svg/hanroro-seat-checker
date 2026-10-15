using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

// 먼 바다 낚시터 (GDD 9번 [확정]): 부두 옆에 매어 둔 배에서 E → 화면이 어두워졌다 밝아지며 먼 바다의 작은 배 위로 순간 이동. 배에서 E → 부두로 돌아옴.
// 먼 바다(Active)에서는 먼 바다 전용 물고기만 낚인다(FishTable.Pick). 낚싯줄이 나가 있으면(대기 상태가 아니면) 못 탄다. 저장하지 않음(늘 섬에서 시작).
// 게임이 시작될 때 스스로 만들어진다(장면에 올릴 것 없음). 배 모델은 Resources/Models/Sea_Rowboat(블렌더 make_boat.py), 재질은 장면의 구름 재질을 복사.
public class FarSea : MonoBehaviour
{
    public static bool Active { get; private set; }
    public static bool Busy { get; private set; }   // 이동(페이드) 중

    static readonly Vector3 DockBoat = new Vector3(24f, -0.1f, -2.7f);      // 부두 남쪽에 매어 둔 배(뱃머리 +x)
    static readonly Vector3 DockStand = new Vector3(24f, 0f, -0.6f);        // 돌아왔을 때 서는 부두 위 자리(높이는 땅을 재서)
    static readonly Vector3 FarBoat = new Vector3(95f, -0.1f, -40f);        // 섬에서 약 100m
    const float BoardDistance = 2.6f, FadeTime = 0.5f, ToastHold = 4f, StandHeight = 1.02f;   // StandHeight: 땅에서 플레이어 중심까지(시작 위치 y 1.1 − 땅 0.08)

    Material baseMat;
    readonly Dictionary<Color, Material> tints = new Dictionary<Color, Material>();
    Transform dockBoat, farBoat;
    Light dockLight, farLight;
    PlayerController player; FishingRod rod;
    bool busy;

    CanvasGroup promptGroup, toastGroup; Text promptText, toastText; Image fade;
    float toastT0 = -999f;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { Active = false; Busy = false; }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("FarSea").AddComponent<FarSea>(); }

    void Awake()
    {
        var cd = FindFirstObjectByType<CloudDrift>();
        baseMat = cd != null ? cd.material : null;
        if (baseMat == null) { Debug.LogWarning("FarSea: 구름 재질이 없어 배를 만들 수 없어요."); enabled = false; return; }
        dockBoat = MakeBoat("DockBoat", DockBoat, 0f, out dockLight);
        farBoat = MakeBoat("FarBoat", FarBoat, Mathf.Atan2(-FarBoat.x, -FarBoat.z) * Mathf.Rad2Deg - 90f, out farLight);   // 뱃머리가 섬 쪽
        BuildUi();
    }

    void Update()
    {
        if (player == null) player = FindFirstObjectByType<PlayerController>();
        if (rod == null) rod = FindFirstObjectByType<FishingRod>();
        float t = Time.time, night = Mathf.SmoothStep(0f, 1f, TimeOfDay.Night);
        Bob(dockBoat, DockBoat, 0f, t); Bob(farBoat, FarBoat, 1.7f, t);
        dockLight.intensity = farLight.intensity = night * 2.2f;   // 밤엔 뱃머리 등불이 켜짐

        var cam = Camera.main; var kb = Keyboard.current;
        bool free = !busy && cam != null && player != null && kb != null && Cursor.lockState == CursorLockMode.Locked
                    && !TalkNPC.IsOpen && !ShopNPC.IsOpen && !DecorShop.IsOpen && !CatalogUI.IsOpen;
        bool near = free && Near(cam, Active ? FarBoat : DockBoat);
        if (near)
        {
            bool idle = rod == null || rod.Current == FishingRod.State.Idle;
            promptText.text = !idle ? "낚싯줄을 먼저 거둬 주세요" : Active ? "E: 부두로 돌아가기" : "E: 배 타고 먼 바다로 가기";
            if (idle && kb.eKey.wasPressedThisFrame) StartCoroutine(Travel(!Active));
        }
        promptGroup.alpha = near ? 1f : 0f;
        UpdateToast();
    }

    // 배 가까이(수평 거리)에 있고, (부두 쪽에서는) 배를 바라보고 있나
    bool Near(Camera cam, Vector3 boat)
    {
        Vector3 to = boat - cam.transform.position; to.y = 0f;
        if (to.magnitude > BoardDistance) return false;
        return Active || Vector3.Dot(cam.transform.forward, (boat - cam.transform.position).normalized) > 0.3f;
    }

    IEnumerator Travel(bool toFar)
    {
        busy = true; Busy = true;
        yield return Fade(0f, 1f);
        Vector3 dest = toFar ? FarBoat : DockStand;
        float yaw = toFar ? Mathf.Atan2(-FarBoat.x, -FarBoat.z) * Mathf.Rad2Deg : 180f;   // 먼 바다: 섬 쪽을 봄 / 부두: 배(바다) 쪽을 봄
        var cc = player.GetComponent<CharacterController>();
        cc.enabled = false;
        player.transform.SetPositionAndRotation(new Vector3(dest.x, GroundY(dest.x, dest.z) + StandHeight, dest.z), Quaternion.Euler(0f, yaw, 0f));
        cc.enabled = true;
        Active = toFar;
        toastText.text = toFar ? "먼 바다에 도착했어요! 여기서만 잡히는 물고기가 있어요" : "부두로 돌아왔어요";
        toastT0 = Time.unscaledTime;
        yield return Fade(1f, 0f);
        busy = false; Busy = false;
    }

    IEnumerator Fade(float from, float to)
    {
        for (float t = 0f; t < FadeTime; t += Time.unscaledDeltaTime)
        {
            fade.color = new Color(0.03f, 0.05f, 0.1f, Mathf.Lerp(from, to, Mathf.SmoothStep(0f, 1f, t / FadeTime)));
            yield return null;
        }
        fade.color = new Color(0.03f, 0.05f, 0.1f, to);
    }

    // 위에서 아래로 쏴서 가장 높은 곳(부두·바다 포함)의 높이
    static float GroundY(float x, float z)
    {
        float best = -0.1f;
        foreach (var h in Physics.RaycastAll(new Vector3(x, 20f, z), Vector3.down, 40f)) if (h.point.y > best) best = h.point.y;
        return best;
    }

    // ---------------- 배 ----------------
    Transform MakeBoat(string name, Vector3 pos, float yaw, out Light lamp)
    {
        var root = new GameObject(name).transform;
        root.SetParent(transform, false); root.SetPositionAndRotation(pos, Quaternion.Euler(0f, yaw, 0f));
        if (!SpawnModel("Sea_Rowboat", root))
        {   // 모델이 없으면 간단한 나무 상자 배
            var g = GameObject.CreatePrimitive(PrimitiveType.Cube); Destroy(g.GetComponent<Collider>());
            g.transform.SetParent(root, false); g.transform.localPosition = new Vector3(0f, 0.25f, 0f); g.transform.localScale = new Vector3(2.6f, 0.5f, 1.1f);
            g.GetComponent<Renderer>().sharedMaterial = Tinted(new Color(0.62f, 0.42f, 0.26f));
        }
        var go = new GameObject("Lamp"); go.transform.SetParent(root, false); go.transform.localPosition = new Vector3(1.35f, 1.3f, 0f);
        lamp = go.AddComponent<Light>(); lamp.type = LightType.Point; lamp.color = new Color(1f, 0.8f, 0.45f); lamp.range = 8f; lamp.intensity = 0f; lamp.shadows = LightShadows.None;
        return root;
    }

    static void Bob(Transform boat, Vector3 basePos, float phase, float t)
    {
        boat.position = basePos + Vector3.up * (0.04f * Mathf.Sin(t * 1.3f + phase));
        var e = boat.eulerAngles; boat.rotation = Quaternion.Euler(Mathf.Sin(t * 0.9f + phase) * 1.5f, e.y, Mathf.Sin(t * 1.1f + phase) * 2f);
    }

    bool SpawnModel(string res, Transform parent)
    {
        var prefab = Resources.Load<GameObject>("Models/" + res);
        if (prefab == null) return false;
        var t = Instantiate(prefab, parent).transform;
        t.localPosition = Vector3.zero; t.localRotation = Quaternion.identity; t.localScale = Vector3.one;
        foreach (var r in t.GetComponentsInChildren<Renderer>())
        {
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
            var src = r.sharedMaterials; var dst = new Material[src.Length];
            for (int i = 0; i < src.Length; i++) dst[i] = Tinted(ColorOf(src[i] != null ? src[i].name : ""));
            r.sharedMaterials = dst;
        }
        return true;
    }

    static Color ColorOf(string name)
    {
        int k = name.IndexOf("C_");
        if (k >= 0 && name.Length >= k + 8 && int.TryParse(name.Substring(k + 2, 6), System.Globalization.NumberStyles.HexNumber, null, out int v))
            return new Color32((byte)(v >> 16), (byte)(v >> 8), (byte)v, 255);
        return new Color(0.8f, 0.8f, 0.8f);
    }

    Material Tinted(Color c)
    {
        Material m;
        if (!tints.TryGetValue(c, out m)) tints[c] = m = new Material(baseMat) { color = c };
        return m;
    }

    // ---------------- UI ----------------
    void BuildUi()
    {
        var font = GameFont.Get();
        var canvas = new GameObject("FarSeaCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay; canvas.sortingOrder = 6;

        var pr = Panel(canvas.transform, "Prompt", UiTheme.Cream, new Vector2(520f, 50f));
        var prt = pr.rectTransform; prt.anchorMin = prt.anchorMax = prt.pivot = new Vector2(0.5f, 0.5f); prt.anchoredPosition = new Vector2(0f, -80f);
        promptGroup = pr.gameObject.AddComponent<CanvasGroup>(); promptGroup.alpha = 0f; promptGroup.blocksRaycasts = false;
        promptText = Txt(prt, font, 28, UiTheme.Ink, new Vector2(510f, 46f));

        var toast = Panel(canvas.transform, "Toast", UiTheme.Cream, new Vector2(760f, 54f));
        var trt = toast.rectTransform; trt.anchorMin = trt.anchorMax = trt.pivot = new Vector2(0.5f, 1f); trt.anchoredPosition = new Vector2(0f, -24f);
        toastGroup = toast.gameObject.AddComponent<CanvasGroup>(); toastGroup.alpha = 0f; toastGroup.blocksRaycasts = false;
        toastText = Txt(trt, font, 28, UiTheme.Ink, new Vector2(740f, 50f));

        var fc = new GameObject("FadeCanvas").AddComponent<Canvas>();
        fc.transform.SetParent(transform, false); fc.renderMode = RenderMode.ScreenSpaceOverlay; fc.sortingOrder = 21;
        fade = new GameObject("Fade").AddComponent<Image>();
        fade.transform.SetParent(fc.transform, false); fade.color = new Color(0.03f, 0.05f, 0.1f, 0f); fade.raycastTarget = false;
        var frt = fade.rectTransform; frt.anchorMin = Vector2.zero; frt.anchorMax = Vector2.one; frt.offsetMin = frt.offsetMax = Vector2.zero;
    }

    void UpdateToast()
    {
        float tt = Time.unscaledTime - toastT0;
        toastGroup.alpha = tt > ToastHold + 0.5f ? 0f : Mathf.Clamp01(tt * 4f) * (1f - Mathf.Clamp01((tt - ToastHold) / 0.5f));
    }

    static Image Panel(Transform parent, string name, Color c, Vector2 size)
    {
        var img = new GameObject(name).AddComponent<Image>();
        img.transform.SetParent(parent, false);
        img.sprite = HudPanel.RoundedRect(); img.type = Image.Type.Sliced; img.color = c; img.raycastTarget = false;
        img.rectTransform.sizeDelta = size;
        return img;
    }

    static Text Txt(Transform parent, Font font, int size, Color c, Vector2 sz)
    {
        var t = new GameObject("Text").AddComponent<Text>();
        t.transform.SetParent(parent, false);
        t.font = font; t.fontSize = size; t.fontStyle = FontStyle.Bold; t.color = c; t.alignment = TextAnchor.MiddleCenter; t.raycastTarget = false;
        var rt = t.rectTransform; rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f); rt.anchoredPosition = Vector2.zero; rt.sizeDelta = sz;
        return t;
    }
}
