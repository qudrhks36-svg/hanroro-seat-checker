using UnityEngine;

// 낚시 물보라·물결 (GDD 9번 [확정] 낚시 연출 ③): 찌가 물에 닿을 때·입질이 올 때·낚았을 때 쓰는 효과.
// 필요할 때 처음 한 번 스스로 만들어지고, 재질은 Resources/Fx에서 읽는다(빌드에서 셰이더가 빠지지 않게). 효과는 파티클 한 방울씩 Emit한다.
public class SplashFx : MonoBehaviour
{
    static SplashFx instance;
    ParticleSystem rings, drops;

    static SplashFx I
    {
        get
        {
            if (instance == null)
            {
                var go = new GameObject("SplashFx");
                if (Application.isPlaying) DontDestroyOnLoad(go);
                instance = go.AddComponent<SplashFx>();
            }
            return instance;
        }
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { instance = null; }

    // 가운데에서 퍼지는 물결 고리 한 개 (size = 다 퍼졌을 때 지름, m)
    public static void Ring(Vector3 pos, float size) { I.EmitRing(pos, size, 1.2f); }

    // 물보라: 물결 고리 두 개 + 물방울 (big이면 더 크게)
    public static void Splash(Vector3 pos, bool big)
    {
        var s = I;
        s.EmitRing(pos, big ? 2.4f : 1.5f, 1.1f);
        s.EmitRing(pos, big ? 4.0f : 2.4f, 1.7f);
        s.EmitDrops(pos, big ? 16 : 9, big ? 1.4f : 1f);
    }

    void Awake()
    {
        var ringMat = Resources.Load<Material>("Fx/Mat_Ripple");
        var dropMat = Resources.Load<Material>("Fx/Mat_Droplet");

        var rg = new GameObject("Rings"); rg.transform.SetParent(transform, false);
        rg.transform.rotation = Quaternion.Euler(-90f, 0f, 0f);   // 고리가 물 위에 눕도록(Local 정렬)
        rings = rg.AddComponent<ParticleSystem>(); rings.Stop();
        var m = rings.main; m.loop = false; m.playOnAwake = false; m.startSpeed = 0f; m.startSize = 1f; m.startLifetime = 1.4f;
        m.simulationSpace = ParticleSystemSimulationSpace.World; m.maxParticles = 30;
        var e = rings.emission; e.enabled = false;
        var sz = rings.sizeOverLifetime; sz.enabled = true;
        sz.size = new ParticleSystem.MinMaxCurve(1f, new AnimationCurve(new Keyframe(0f, 0.12f), new Keyframe(0.35f, 0.62f), new Keyframe(1f, 1f)));
        var col = rings.colorOverLifetime; col.enabled = true;
        var g = new Gradient();
        g.SetKeys(new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                  new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(0.9f, 0.1f), new GradientAlphaKey(0f, 1f) });
        col.color = g;
        var rr = rg.GetComponent<ParticleSystemRenderer>();
        rr.material = ringMat; rr.alignment = ParticleSystemRenderSpace.Local; rr.renderMode = ParticleSystemRenderMode.Billboard;
        rings.Play();

        var dg = new GameObject("Drops"); dg.transform.SetParent(transform, false);
        drops = dg.AddComponent<ParticleSystem>(); drops.Stop();
        var dm = drops.main; dm.loop = false; dm.playOnAwake = false; dm.startSpeed = 0f;
        dm.startSize = new ParticleSystem.MinMaxCurve(0.12f, 0.24f); dm.startLifetime = new ParticleSystem.MinMaxCurve(0.7f, 1.0f);
        dm.gravityModifier = 1.7f; dm.simulationSpace = ParticleSystemSimulationSpace.World; dm.maxParticles = 80;
        dm.startColor = new Color(0.8f, 0.95f, 1f, 1f);
        var de = drops.emission; de.enabled = false;
        var dcol = drops.colorOverLifetime; dcol.enabled = true;
        var dgr = new Gradient();
        dgr.SetKeys(new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                    new[] { new GradientAlphaKey(1f, 0f), new GradientAlphaKey(0.9f, 0.6f), new GradientAlphaKey(0f, 1f) });
        dcol.color = dgr;
        var dr = dg.GetComponent<ParticleSystemRenderer>(); dr.material = dropMat; dr.renderMode = ParticleSystemRenderMode.Billboard;
        drops.Play();
    }

    void EmitRing(Vector3 pos, float size, float life)
    {
        var ep = new ParticleSystem.EmitParams { position = pos + Vector3.up * 0.04f, startSize = size, startLifetime = life, startColor = new Color(0.85f, 0.97f, 1f, 1f) };
        rings.Emit(ep, 1);
    }

    void EmitDrops(Vector3 pos, int n, float power)
    {
        for (int i = 0; i < n; i++)
        {
            var v = new Vector3(Random.Range(-1f, 1f) * 1.1f, Random.Range(2.5f, 4.6f) * power, Random.Range(-1f, 1f) * 1.1f);
            var ep = new ParticleSystem.EmitParams { position = pos + Vector3.up * 0.05f + new Vector3(v.x, 0f, v.z) * 0.1f, velocity = v };
            drops.Emit(ep, 1);
        }
    }
}
