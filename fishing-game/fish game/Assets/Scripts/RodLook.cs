using UnityEngine;

// 낚싯대 모습 (GDD 3번 [확정] 업그레이드 연출): 단계에 따라 색·길이·끝 장식이 달라진다.
// 0 기본: 갈색 막대 / 1 튼튼: 밝은 나무색 + 조금 길게 + 작은 금색 구슬 / 2 반짝: 금색 + 더 길게 + 큰 금색 구슬(은은하게 반짝).
// 게임이 시작될 때 스스로 만들어지고(장면에 올릴 것 없음), 단계가 바뀌면 바로 반영한다. 재질은 낚싯대 것을 복사해서 쓴다(웹 빌드에서 셰이더가 빠지지 않게).
public class RodLook : MonoBehaviour
{
    static readonly Color[] Body = { default(Color), new Color(0.86f, 0.64f, 0.38f), new Color(1f, 0.82f, 0.30f) };
    static readonly float[] Length = { 1f, 1.15f, 1.3f };      // 기본 길이에 곱함
    static readonly float[] Orb = { 0f, 0.05f, 0.07f };      // 끝 구슬 지름(m)
    static readonly Color OrbColor = new Color(1f, 0.9f, 0.45f);

    Transform rod, orb;
    Renderer rodRenderer;
    Vector3 baseScale;
    Color baseColor;
    int shown = -1;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("RodLook").AddComponent<RodLook>(); }

    void Update()
    {
        if (rod == null && !Find()) return;
        if (RodUpgrade.Level != shown) Apply(RodUpgrade.Level);
        if (orb != null && shown >= 2) SetOrbSize(Orb[2] * (1f + 0.12f * Mathf.Sin(Time.time * 4f)));   // 반짝이는 느낌으로 살짝 커졌다 작아짐
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
        rodRenderer.material.color = level == 0 ? baseColor : Body[level];
        rod.localScale = new Vector3(baseScale.x, baseScale.y, baseScale.z * Length[level]);   // 끝(RodTip)은 자식이라 같이 따라감
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
