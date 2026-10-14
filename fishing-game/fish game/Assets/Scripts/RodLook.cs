using System.Collections.Generic;
using UnityEngine;

// 낚싯대 모습 (GDD 3번 [확정] 업그레이드 연출 + 9번 블렌더 모델 교체): 단계에 따라 모습이 달라진다.
// 0 기본: 갈색 대 + 코르크 손잡이 / 1 튼튼: 밝은 나무색 + 붉은 실 + 금색 구슬 / 2 반짝: 금색 + 청록 손잡이 + 큰 구슬(은은하게 반짝).
// 모델은 Resources/Models/Rod_0~2(블렌더 make_rod.py). 모델이 없으면 예전 임시 모양(색·길이·구슬)으로 대신한다.
// 게임이 시작될 때 스스로 만들어지고(장면에 올릴 것 없음), 단계가 바뀌면 바로 반영한다. 재질은 낚싯대 것을 복사해서 쓴다(웹 빌드에서 셰이더가 빠지지 않게).
public class RodLook : MonoBehaviour
{
    static readonly Color[] Body = { default(Color), new Color(0.86f, 0.64f, 0.38f), new Color(1f, 0.82f, 0.30f) };
    static readonly float[] Length = { 1f, 1.15f, 1.3f };      // 기본 길이에 곱함 (RodTip이 모델 끝과 맞도록 모델 길이도 1.4 / 1.61 / 1.82)
    static readonly float[] Orb = { 0f, 0.05f, 0.07f };        // (모델이 없을 때) 끝 구슬 지름(m)
    static readonly Color OrbColor = new Color(1f, 0.9f, 0.45f);

    Transform rod, orb, model, modelOrb;
    Renderer rodRenderer;
    Vector3 baseScale;
    Color baseColor;
    int shown = -1;
    readonly Dictionary<Color32, Material> tints = new Dictionary<Color32, Material>();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("RodLook").AddComponent<RodLook>(); }

    void Update()
    {
        if (rod == null && !Find()) return;
        if (RodUpgrade.Level != shown) Apply(RodUpgrade.Level);
        float pulse = 1f + 0.12f * Mathf.Sin(Time.time * 4f);
        if (shown >= 2)
        {
            if (modelOrb != null) modelOrb.localScale = Vector3.one * pulse;                    // 모델 구슬은 제자리에서 커졌다 작아짐
            else if (orb != null) SetOrbSize(Orb[2] * pulse);
        }
    }

    bool Find()
    {
        var fr = FindFirstObjectByType<FishingRod>();
        if (fr == null || fr.rodTip == null || fr.rodTip.parent == null) return false;
        rod = fr.rodTip.parent;
        rodRenderer = rod.GetComponent<Renderer>();
        if (rodRenderer == null) { rod = null; return false; }
        baseScale = rod.localScale;
        baseColor = rodRenderer.material.color;   // 복사본(인스턴스)이 만들어지고, 이 색이 기본(0단계) 색
        return true;
    }

    void Apply(int level)
    {
        shown = level;
        level = Mathf.Clamp(level, 0, Length.Length - 1);
        rod.localScale = new Vector3(baseScale.x, baseScale.y, baseScale.z * Length[level]);   // 끝(RodTip)은 자식이라 같이 따라감(모델 끝 위치와 같음)
        if (model != null) { if (Application.isPlaying) Destroy(model.gameObject); else DestroyImmediate(model.gameObject); model = null; modelOrb = null; }   // 편집 모드 시험에서는 바로 지움
        var prefab = Resources.Load<GameObject>("Models/Rod_" + level);
        if (prefab != null) { ApplyModel(prefab, level); return; }
        ApplyPlaceholder(level);
    }

    // 블렌더 모델: 임시 막대는 숨기고, 같은 자리(대의 손잡이 끝 → 끝)에 모델을 놓는다. 크기 1(대는 눌려 있어서 자식으로 두지 않고 카메라 쪽 부모에 둠).
    void ApplyModel(GameObject prefab, int level)
    {
        rodRenderer.enabled = false;
        if (orb != null) orb.gameObject.SetActive(false);
        float len = rod.localScale.z;
        model = Instantiate(prefab, rod.parent).transform;
        model.localRotation = rod.localRotation;
        model.localPosition = rod.localPosition - rod.localRotation * new Vector3(0f, 0f, len * 0.5f);   // 막대 가운데에서 손잡이 쪽으로 반 길이
        model.localScale = Vector3.one;
        foreach (var r in model.GetComponentsInChildren<Renderer>())
        {
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
            var src = r.sharedMaterials; var dst = new Material[src.Length];
            for (int i = 0; i < src.Length; i++) dst[i] = ColorMaterial(src[i] != null ? src[i].name : "");
            r.sharedMaterials = dst;
        }
        modelOrb = model.Find("Orb");
    }

    // 재질 이름 "C_RRGGBB" → 그 색의 재질(낚싯대 재질을 복사, 같은 색은 한 번만)
    Material ColorMaterial(string name)
    {
        var c = new Color32(200, 200, 200, 255);
        int k = name.IndexOf("C_");
        if (k >= 0 && name.Length >= k + 8)
        {
            string h = name.Substring(k + 2, 6);
            if (int.TryParse(h, System.Globalization.NumberStyles.HexNumber, null, out int v)) c = new Color32((byte)(v >> 16), (byte)(v >> 8), (byte)v, 255);
        }
        Material m;
        if (!tints.TryGetValue(c, out m)) tints[c] = m = new Material(rodRenderer.sharedMaterial) { color = c };
        return m;
    }

    // 모델이 없을 때(예전 임시 모양)
    void ApplyPlaceholder(int level)
    {
        rodRenderer.enabled = true;
        rodRenderer.material.color = level == 0 ? baseColor : Body[level];
        if (Orb[level] <= 0f) { if (orb != null) orb.gameObject.SetActive(false); return; }
        if (orb == null)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            Destroy(go.GetComponent<Collider>());
            go.name = "RodOrb"; go.transform.SetParent(rod, false);
            go.transform.localPosition = new Vector3(0f, 0f, 0.5f);     // 막대 끝(RodTip 자리)
            var r = go.GetComponent<Renderer>(); r.material = new Material(rodRenderer.sharedMaterial) { color = OrbColor };
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            orb = go.transform;
        }
        orb.gameObject.SetActive(true);
        SetOrbSize(Orb[level]);
    }

    // 낚싯대는 가늘고 길게 눌려 있어서, 구슬이 찌그러지지 않게 부모 크기를 나눠 준다.
    void SetOrbSize(float d)
    {
        var s = rod.lossyScale;
        orb.localScale = new Vector3(d / Mathf.Max(1e-4f, s.x), d / Mathf.Max(1e-4f, s.y), d / Mathf.Max(1e-4f, s.z));
    }
}
