using UnityEngine;

// 집 꾸미기 상태 (GDD 9번 [확정]): 산 장식(비트 마스크)과 오두막 단계. 저장·불러오기는 SaveData가 한다.
public static class Home
{
    public const int ItemCount = 5, MaxCabin = 2;
    public static readonly string[] ItemNames = { "화분", "해변 파라솔", "풍경", "모닥불", "해먹" };
    public static readonly string[] ItemInfo = { "오두막 문 옆에 꽃이 피어요", "오두막 앞에 그늘이 생겨요", "처마에서 바람 따라 딸랑딸랑", "밤이면 불빛이 따뜻해요", "느긋하게 살랑살랑 흔들려요" };
    public static readonly int[] ItemPrice = { 80, 100, 120, 150, 200 };
    public static readonly string[] CabinNames = { "낡은 오두막", "튼튼한 오두막", "예쁜 오두막" };
    public static readonly int[] CabinPrice = { 0, 300, 800 };

    public static int OwnedMask;   // 비트 i = ItemNames[i]를 샀음
    public static int CabinLevel;  // 0~2

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { OwnedMask = 0; CabinLevel = 0; }

    public static bool Owns(int i) { return (OwnedMask >> i & 1) != 0; }
    public static bool CabinMax { get { return CabinLevel >= MaxCabin; } }

    // 성공하면 true (이미 샀거나 돈이 모자라면 false)
    public static bool BuyItem(int i)
    {
        if (Owns(i) || Inventory.Money < ItemPrice[i]) return false;
        Inventory.Money -= ItemPrice[i]; OwnedMask |= 1 << i;
        return true;
    }

    public static bool BuyCabin()
    {
        if (CabinMax || Inventory.Money < CabinPrice[CabinLevel + 1]) return false;
        Inventory.Money -= CabinPrice[CabinLevel + 1]; CabinLevel++;
        return true;
    }
}

// 산 장식·오두막 모양을 섬에 보여준다. 게임이 시작될 때 스스로 만들어지고(장면에 올릴 것 없음), 상태가 바뀌면 바로 반영.
// 모양은 임시 도형(블렌더 모델은 나중에). 재질은 장면의 구름 재질을 복사해 같은 색은 한 번만 만든다(웹 빌드에서 셰이더가 빠지지 않게).
// 자리: 오두막은 (-8,0,6), 문은 앞쪽 z=3 벽의 x -8.9~-7.1, 처마 높이 3.5.
public class HomeDecor : MonoBehaviour
{
    Material baseMat, dropletMat;
    readonly System.Collections.Generic.Dictionary<Color, Material> tints = new System.Collections.Generic.Dictionary<Color, Material>();
    GameObject[] items = new GameObject[Home.ItemCount];
    GameObject chimney, flagGroup, lanternGroup, roofCover;
    Transform chime, hammock, flag;
    Light fireLight, lanternLight, windowLightL, windowLightR;
    ParticleSystem smoke;
    AudioSource chimeAudio; AudioClip chimeClip; float chimeTimer;
    Material roofMat, windowMat; Color roofBase, windowBase;
    int shownCabin = -1;
    readonly bool[] cleared = new bool[Home.ItemCount];
    // 장식을 사면 그 둘레의 풀·꽃·덤불·바위(섬 소품 "Decor")를 치운다. {x, z, 반폭 x, 반폭 z}
    static readonly float[][] Clear = { new[] { -9.8f, 2.4f, 0.6f, 0.6f }, new[] { -4.6f, 1.0f, 1.5f, 1.5f }, null, new[] { -7.5f, -1.2f, 1.0f, 1.0f }, new[] { -11.4f, -3.5f, 1.0f, 2.0f } };

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("HomeDecor").AddComponent<HomeDecor>(); }

    void Awake()
    {
        var cd = FindFirstObjectByType<CloudDrift>();
        baseMat = cd != null ? cd.material : null;
        dropletMat = Resources.Load<Material>("Fx/Mat_Droplet");
        if (baseMat == null) { Debug.LogWarning("HomeDecor: 구름 재질이 없어 장식을 만들 수 없어요."); enabled = false; return; }
        BuildPot(); BuildParasol(); BuildChime(); BuildFire(); BuildHammock();
        BuildCabinExtras();
        var cs = SfxSynth.Chime(); chimeClip = AudioClip.Create("Chime", cs.Length, 1, SfxSynth.Rate, false); chimeClip.SetData(cs, 0);
        chimeTimer = Random.Range(8f, 16f);
    }

    void Update()
    {
        for (int i = 0; i < items.Length; i++)
        {
            if (items[i].activeSelf != Home.Owns(i)) items[i].SetActive(Home.Owns(i));
            if (Home.Owns(i) && !cleared[i]) { cleared[i] = true; ClearNear(i); }
        }
        if (Home.CabinLevel != shownCabin) ApplyCabin(Home.CabinLevel);

        float t = Time.time, night = Mathf.Clamp01(TimeOfDay.Night);
        float wind = Mathf.Sin(t * 1.7f) * 0.6f + Mathf.Sin(t * 0.7f + 1f) * 0.4f;
        if (items[2].activeSelf)
        {
            chime.localRotation = Quaternion.Euler(wind * 9f, 0f, Mathf.Sin(t * 1.3f) * 7f);
            chimeTimer -= Time.deltaTime;
            if (chimeTimer <= 0f) { chimeTimer = Random.Range(10f, 22f); chimeAudio.PlayOneShot(chimeClip, 0.5f); }
        }
        if (items[4].activeSelf) hammock.localRotation = Quaternion.Euler(0f, 0f, Mathf.Sin(t * 0.9f) * 3f);
        if (items[3].activeSelf) fireLight.intensity = (0.8f + night * 2.2f) * (0.85f + 0.15f * Mathf.Sin(t * 17f) + 0.08f * Mathf.Sin(t * 29f));
        if (Home.CabinLevel >= 1) { var e = smoke.emission; e.rateOverTime = 6f; }
        if (Home.CabinLevel >= 2 && windowMat != null)
        {
            flag.localRotation = Quaternion.Euler(0f, Mathf.Sin(t * 3f) * 14f, 0f);
            float glow = Mathf.SmoothStep(0f, 1f, night);
            lanternLight.intensity = glow * 2.2f; windowLightL.intensity = windowLightR.intensity = glow * 1.4f;
            windowMat.color = Color.Lerp(windowBase, new Color(1f, 0.82f, 0.4f), glow);
        }
    }

    // ---------------- 오두막 단계 ----------------
    void ApplyCabin(int level)
    {
        shownCabin = level;
        if (roofMat == null)
        {
            var mr = GameObject.Find("Island/Cabin") != null ? GameObject.Find("Island/Cabin").GetComponent<MeshRenderer>() : null;
            if (mr != null)
            {
                var mats = mr.materials;   // 이 오두막 전용 복사본
                for (int i = 0; i < mats.Length; i++)
                {
                    if (mats[i].name.StartsWith("Mat_Roof")) { roofMat = mats[i]; roofBase = roofMat.color; }
                    if (mats[i].name.StartsWith("Mat_Window")) { windowMat = mats[i]; windowBase = windowMat.color; }
                }
            }
        }
        if (roofMat != null) roofMat.color = level >= 1 ? new Color(0.28f, 0.58f, 0.66f) : roofBase;
        chimney.SetActive(level >= 1); roofCover.SetActive(level >= 1);
        flagGroup.SetActive(level >= 2); lanternGroup.SetActive(level >= 2);
        if (level < 2 && windowMat != null) windowMat.color = windowBase;
    }

    void BuildCabinExtras()
    {
        // 2단계: 새 지붕 색. 오두막 모델의 지붕 윗면이 벽과 같은 재질이라 색만 바꿀 수 없어, 지붕 위에 살짝 덮는 피라미드를 얹는다.
        roofCover = new GameObject("RoofCover"); roofCover.transform.SetParent(transform, false);
        roofCover.AddComponent<MeshFilter>().sharedMesh = GableMesh(-11.58f, -4.42f, -8f, 2.94f, 9.06f, 3.46f, 5.56f);
        var rcr = roofCover.AddComponent<MeshRenderer>(); rcr.sharedMaterial = Tint(new Color(0.28f, 0.58f, 0.66f));
        rcr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; rcr.receiveShadows = false;

        // 2단계: 굴뚝(+ 연기)
        chimney = new GameObject("Chimney"); chimney.transform.SetParent(transform, false); chimney.transform.position = new Vector3(-9.6f, 4.75f, 7.4f);
        var cmod = SpawnModel("Home_Chimney", chimney.transform);
        if (cmod != null) cmod.localPosition = new Vector3(0f, -0.4f, 0f);
        else
        {
        Part(PrimitiveType.Cylinder, chimney.transform, new Vector3(0f, 0.25f, 0f), new Vector3(0.7f, 0.65f, 0.7f), Tint(new Color(0.62f, 0.4f, 0.34f)));
        Part(PrimitiveType.Cylinder, chimney.transform, new Vector3(0f, 0.92f, 0f), new Vector3(0.82f, 0.07f, 0.82f), Tint(new Color(0.4f, 0.28f, 0.24f)));
        }
        var sg = new GameObject("Smoke"); sg.transform.SetParent(chimney.transform, false); sg.transform.localPosition = new Vector3(0f, 1.0f, 0f);
        smoke = sg.AddComponent<ParticleSystem>(); smoke.Stop();
        var m = smoke.main; m.loop = true; m.startLifetime = 3.2f; m.startSpeed = 0.7f; m.startSize = new ParticleSystem.MinMaxCurve(0.4f, 0.7f);
        m.startColor = new Color(0.85f, 0.88f, 0.95f, 0.22f); m.maxParticles = 40; m.simulationSpace = ParticleSystemSimulationSpace.World;
        var sh = smoke.shape; sh.shapeType = ParticleSystemShapeType.Cone; sh.angle = 6f; sh.radius = 0.12f; sh.rotation = new Vector3(-90f, 0f, 0f);
        var sz = smoke.sizeOverLifetime; sz.enabled = true; sz.size = new ParticleSystem.MinMaxCurve(1f, new AnimationCurve(new Keyframe(0f, 0.5f), new Keyframe(1f, 2.2f)));
        var col = smoke.colorOverLifetime; col.enabled = true; var g = new Gradient();
        g.SetKeys(new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) }, new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(1f, 0.15f), new GradientAlphaKey(0f, 1f) });
        col.color = g;
        var em = smoke.emission; em.rateOverTime = 0f;
        var r = sg.GetComponent<ParticleSystemRenderer>(); r.material = dropletMat; r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        smoke.Play();

        // 3단계: 지붕 깃발 + 문 옆 등불 + 창문 불빛
        flagGroup = new GameObject("Flag"); flagGroup.transform.SetParent(transform, false); flagGroup.transform.position = new Vector3(-8f, 5.5f, 6f);
        var fmod = SpawnModel("Home_Flag", flagGroup.transform);
        if (fmod != null) flag = fmod.Find("FlagCloth");   // 천(원점 = 깃대)만 살랑
        if (flag == null)
        {
            if (fmod != null) Destroy(fmod.gameObject);
            Part(PrimitiveType.Cylinder, flagGroup.transform, new Vector3(0f, 0.9f, 0f), new Vector3(0.08f, 0.9f, 0.08f), Tint(new Color(0.55f, 0.4f, 0.28f)));
            var fp = new GameObject("FlagPivot").transform; fp.SetParent(flagGroup.transform, false); fp.localPosition = new Vector3(0f, 1.55f, 0f); flag = fp;
            Part(PrimitiveType.Cube, fp, new Vector3(0.45f, 0f, 0f), new Vector3(0.9f, 0.5f, 0.04f), Tint(new Color(0.95f, 0.35f, 0.35f)));
        }
        lanternGroup = new GameObject("Lantern"); lanternGroup.transform.SetParent(transform, false); lanternGroup.transform.position = new Vector3(-6.7f, 2.3f, 2.8f);
        if (SpawnModel("Home_Lantern", lanternGroup.transform) == null)
        {
            Part(PrimitiveType.Cube, lanternGroup.transform, new Vector3(0f, 0.32f, 0.04f), new Vector3(0.06f, 0.3f, 0.06f), Tint(new Color(0.34f, 0.22f, 0.13f)));
            Part(PrimitiveType.Sphere, lanternGroup.transform, Vector3.zero, new Vector3(0.3f, 0.36f, 0.3f), Tint(new Color(1f, 0.85f, 0.4f)));
        }
        lanternLight = MakeLight(lanternGroup.transform, Vector3.zero, new Color(1f, 0.8f, 0.45f), 7f);
        windowLightL = MakeLight(lanternGroup.transform, new Vector3(-11.9f + 6.7f, -0.7f, 6f - 2.8f), new Color(1f, 0.8f, 0.45f), 5f);   // 서쪽 창 앞
        windowLightR = MakeLight(lanternGroup.transform, new Vector3(-3.9f + 6.7f, -0.7f, 6f - 2.8f), new Color(1f, 0.8f, 0.45f), 5f);    // 동쪽 창 앞
    }

    // 박공지붕(앞뒤가 삼각형 벽, 지붕면은 서쪽·동쪽 두 장)에 덮는 얇은 판 두 장. 어느 쪽에서 봐도 보이게 앞뒤 면을 모두 넣는다.
    static Mesh GableMesh(float x0, float x1, float xm, float z0, float z1, float yEave, float yRidge)
    {
        var verts = new System.Collections.Generic.List<Vector3>(); var tris = new System.Collections.Generic.List<int>();
        System.Action<Vector3, Vector3, Vector3, Vector3> quad = (a, b, c, d) =>   // a-b-c-d 순서의 사각형, 양면
        {
            int i = verts.Count; verts.AddRange(new[] { a, b, c, d });
            tris.AddRange(new[] { i, i + 1, i + 2, i, i + 2, i + 3 });
            int j = verts.Count; verts.AddRange(new[] { a, b, c, d });
            tris.AddRange(new[] { j, j + 2, j + 1, j, j + 3, j + 2 });
        };
        quad(new Vector3(x0, yEave, z0), new Vector3(xm, yRidge, z0), new Vector3(xm, yRidge, z1), new Vector3(x0, yEave, z1));   // 서쪽 지붕면
        quad(new Vector3(x1, yEave, z1), new Vector3(xm, yRidge, z1), new Vector3(xm, yRidge, z0), new Vector3(x1, yEave, z0));   // 동쪽 지붕면
        var m = new Mesh { name = "RoofCover", vertices = verts.ToArray(), triangles = tris.ToArray() };
        m.RecalculateNormals(); m.RecalculateBounds();
        return m;
    }

    // ---------------- 장식 ----------------
    void BuildPot()
    {
        var g = Item(0, -9.8f, 2.4f);
        if (SpawnModel("Home_Pot", g.transform) != null) return;   // 블렌더 모델이 있으면 그걸 씀(없으면 아래 임시 도형)
        Part(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 0.2f, 0f), new Vector3(0.5f, 0.2f, 0.5f), Tint(new Color(0.8f, 0.45f, 0.3f)));
        Part(PrimitiveType.Sphere, g.transform, new Vector3(0f, 0.42f, 0f), new Vector3(0.44f, 0.12f, 0.44f), Tint(new Color(0.3f, 0.2f, 0.14f)));
        var pink = Tint(new Color(1f, 0.55f, 0.7f)); var yel = Tint(new Color(1f, 0.85f, 0.3f)); var green = Tint(new Color(0.4f, 0.7f, 0.35f));
        float[] xs = { -0.12f, 0.1f, 0f }, zs = { 0f, 0.05f, -0.12f }, hs = { 0.35f, 0.5f, 0.28f };
        for (int i = 0; i < 3; i++)
        {
            Part(PrimitiveType.Cylinder, g.transform, new Vector3(xs[i], 0.45f + hs[i] * 0.5f, zs[i]), new Vector3(0.03f, hs[i] * 0.5f, 0.03f), green);
            Part(PrimitiveType.Sphere, g.transform, new Vector3(xs[i], 0.45f + hs[i], zs[i]), Vector3.one * 0.17f, i == 1 ? yel : pink);
        }
    }

    void BuildParasol()
    {
        var g = Item(1, -4.6f, 1.0f);
        if (SpawnModel("Home_Parasol", g.transform) != null) return;
        Part(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 0.95f, 0f), new Vector3(0.08f, 0.95f, 0.08f), Tint(new Color(0.75f, 0.6f, 0.4f)));
        Part(PrimitiveType.Sphere, g.transform, new Vector3(0f, 1.95f, 0f), new Vector3(2.5f, 0.55f, 2.5f), Tint(new Color(0.98f, 0.45f, 0.42f)));
        Part(PrimitiveType.Sphere, g.transform, new Vector3(0f, 1.98f, 0f), new Vector3(1.5f, 0.62f, 1.5f), Tint(new Color(1f, 0.96f, 0.9f)));   // 하얀 줄무늬 느낌의 안쪽 둥근 부분
        Part(PrimitiveType.Sphere, g.transform, new Vector3(0f, 2.28f, 0f), Vector3.one * 0.14f, Tint(new Color(1f, 0.85f, 0.4f)));
        Part(PrimitiveType.Cylinder, g.transform, new Vector3(0.9f, 0.15f, 0.7f), new Vector3(0.45f, 0.14f, 0.45f), Tint(new Color(0.7f, 0.5f, 0.32f)));   // 작은 의자(통나무)
    }

    void BuildChime()
    {
        var g = Item(2, -6f, 2.85f); g.transform.position = new Vector3(-6f, 3.45f, 2.85f);   // 처마 끝에 걸림
        var cm = SpawnModel("Home_Chime", g.transform);   // 모델의 원점 = 처마에 거는 점이라 통째로 흔들면 됨
        if (cm != null) chime = cm;
        else
        {
        chime = new GameObject("ChimeSwing").transform; chime.SetParent(g.transform, false);
        var gold = Tint(new Color(1f, 0.84f, 0.4f)); var wood = Tint(new Color(0.55f, 0.38f, 0.25f));
        Part(PrimitiveType.Cylinder, chime, new Vector3(0f, -0.25f, 0f), new Vector3(0.02f, 0.25f, 0.02f), wood);   // 줄
        Part(PrimitiveType.Cylinder, chime, new Vector3(0f, -0.52f, 0f), new Vector3(0.38f, 0.02f, 0.38f), wood);   // 윗판
        float[] len = { 0.34f, 0.46f, 0.28f, 0.4f, 0.32f }, ang = { 0f, 72f, 144f, 216f, 288f };
        for (int i = 0; i < 5; i++)
        {
            float a = ang[i] * Mathf.Deg2Rad;
            Part(PrimitiveType.Cylinder, chime, new Vector3(Mathf.Cos(a) * 0.14f, -0.55f - len[i] * 0.5f, Mathf.Sin(a) * 0.14f), new Vector3(0.045f, len[i] * 0.5f, 0.045f), gold);
        }
        }
        chimeAudio = g.AddComponent<AudioSource>();
        chimeAudio.spatialBlend = 1f; chimeAudio.rolloffMode = AudioRolloffMode.Linear; chimeAudio.minDistance = 3f; chimeAudio.maxDistance = 30f;
    }

    void BuildFire()
    {
        var g = Item(3, -7.5f, -1.2f);
        bool fireModel = SpawnModel("Home_Fire", g.transform) != null;
        if (!fireModel)
        {
        var stone = Tint(new Color(0.55f, 0.55f, 0.58f)); var log = Tint(new Color(0.45f, 0.3f, 0.2f));
        for (int i = 0; i < 8; i++)
        {
            float a = i / 8f * Mathf.PI * 2f;
            Part(PrimitiveType.Sphere, g.transform, new Vector3(Mathf.Cos(a) * 0.55f, 0.1f, Mathf.Sin(a) * 0.55f), new Vector3(0.26f, 0.2f, 0.24f), stone);
        }
        for (int i = 0; i < 3; i++)
        {
            var l = Part(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 0.16f, 0f), new Vector3(0.12f, 0.45f, 0.12f), log);
            l.transform.localRotation = Quaternion.Euler(0f, i * 60f, 80f);
        }
        }
        var fg = new GameObject("Flames"); fg.transform.SetParent(g.transform, false); fg.transform.localPosition = new Vector3(0f, 0.2f, 0f);
        var ps = fg.AddComponent<ParticleSystem>(); ps.Stop();
        var m = ps.main; m.loop = true; m.startLifetime = 0.8f; m.startSpeed = 1.1f; m.startSize = new ParticleSystem.MinMaxCurve(0.28f, 0.45f);
        m.startColor = new Color(1f, 0.6f, 0.2f, 0.9f); m.maxParticles = 60; m.simulationSpace = ParticleSystemSimulationSpace.World;
        var sh = ps.shape; sh.shapeType = ParticleSystemShapeType.Cone; sh.angle = 9f; sh.radius = 0.14f; sh.rotation = new Vector3(-90f, 0f, 0f);
        var sz = ps.sizeOverLifetime; sz.enabled = true; sz.size = new ParticleSystem.MinMaxCurve(1f, new AnimationCurve(new Keyframe(0f, 0.8f), new Keyframe(1f, 0f)));
        var col = ps.colorOverLifetime; col.enabled = true; var gr = new Gradient();
        gr.SetKeys(new[] { new GradientColorKey(new Color(1f, 0.9f, 0.4f), 0f), new GradientColorKey(new Color(1f, 0.4f, 0.1f), 0.6f), new GradientColorKey(new Color(0.6f, 0.15f, 0.05f), 1f) },
                   new[] { new GradientAlphaKey(0.9f, 0f), new GradientAlphaKey(0.7f, 0.6f), new GradientAlphaKey(0f, 1f) });
        col.color = gr;
        var em = ps.emission; em.rateOverTime = 28f;
        var r = fg.GetComponent<ParticleSystemRenderer>(); r.material = dropletMat; r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        ps.Play();
        fireLight = MakeLight(g.transform, new Vector3(0f, 0.7f, 0f), new Color(1f, 0.6f, 0.25f), 9f);
    }

    void BuildHammock()
    {
        var g = Item(4, -11.4f, -3.5f);   // 기둥 두 개(z ±1.5) 사이
        var hm = SpawnModel("Home_Hammock", g.transform);
        if (hm != null && (hammock = hm.Find("Hammock")) != null) return;   // 모델의 "Hammock" 부분(원점 = 흔들리는 축)만 흔듦
        if (hm != null) Destroy(hm.gameObject);
        var wood = Tint(new Color(0.5f, 0.36f, 0.24f));
        foreach (float z in new[] { -1.5f, 1.5f }) Part(PrimitiveType.Cylinder, g.transform, new Vector3(0f, 0.85f, z), new Vector3(0.14f, 0.85f, 0.14f), wood);
        hammock = new GameObject("HammockSway").transform; hammock.SetParent(g.transform, false); hammock.localPosition = new Vector3(0f, 1.35f, 0f);
        var a = Tint(new Color(0.35f, 0.72f, 0.72f)); var b = Tint(new Color(0.98f, 0.9f, 0.7f));
        const int n = 9;
        for (int i = 0; i < n; i++)
        {
            float u = i / (n - 1f) * 2f - 1f, z = u * 1.4f, y = -0.55f * (1f - u * u);   // 가운데가 처진 모양
            var seg = Part(PrimitiveType.Cube, hammock, new Vector3(0f, y, z), new Vector3(0.75f, 0.05f, 0.4f), i % 2 == 0 ? a : b);
            seg.transform.localRotation = Quaternion.Euler(-Mathf.Atan(1.1f * u) * Mathf.Rad2Deg * 0.8f, 0f, 0f);
        }
    }

    // ---------------- 공통 ----------------
    void ClearNear(int item)
    {
        var box = Clear[item]; var decor = GameObject.Find("Decor");
        if (box == null || decor == null) return;
        foreach (Transform group in decor.transform)
        {
            if (group.name == "Beach") continue;   // 해변 조개 등은 그대로
            foreach (Transform t in group)
                if (Mathf.Abs(t.position.x - box[0]) < box[2] && Mathf.Abs(t.position.z - box[1]) < box[3]) t.gameObject.SetActive(false);
        }
    }

    // 블렌더 모델(Resources/Models/<이름>.fbx)을 부모 아래에 놓는다. 없으면 null(임시 도형으로 대신).
    // 재질 이름 "C_RRGGBB"에서 색을 읽어 구름 재질 복사본(Tint)으로 바꾼다(웹 빌드에서 셰이더가 빠지지 않게).
    Transform SpawnModel(string res, Transform parent)
    {
        var prefab = Resources.Load<GameObject>("Models/" + res);
        if (prefab == null) return null;
        var t = Instantiate(prefab, parent).transform;
        t.localPosition = Vector3.zero; t.localRotation = Quaternion.identity; t.localScale = Vector3.one;
        foreach (var r in t.GetComponentsInChildren<Renderer>())
        {
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
            var src = r.sharedMaterials; var dst = new Material[src.Length];
            for (int i = 0; i < src.Length; i++) dst[i] = Tint(ColorOf(src[i] != null ? src[i].name : ""));
            r.sharedMaterials = dst;
        }
        return t;
    }

    static Color ColorOf(string name)
    {
        int k = name.IndexOf("C_");
        if (k >= 0 && name.Length >= k + 8 && int.TryParse(name.Substring(k + 2, 6), System.Globalization.NumberStyles.HexNumber, null, out int v))
            return new Color32((byte)(v >> 16), (byte)(v >> 8), (byte)v, 255);
        return new Color(0.8f, 0.8f, 0.8f);
    }

    GameObject Item(int i, float x, float z)
    {
        var g = new GameObject("Decor_" + Home.ItemNames[i]); g.transform.SetParent(transform, false);
        g.transform.position = new Vector3(x, GroundY(x, z), z);
        items[i] = g; g.SetActive(false);
        return g;
    }

    // 위에서 아래로 쏴서 바다가 아닌 가장 높은 곳(섬 땅)의 높이. 못 찾으면 0.
    static float GroundY(float x, float z)
    {
        float best = 0f;
        foreach (var h in Physics.RaycastAll(new Vector3(x, 20f, z), Vector3.down, 40f)) if (h.collider.name != "Sea" && h.point.y > best) best = h.point.y;
        return best;
    }

    Material Tint(Color c)
    {
        Material m;
        if (!tints.TryGetValue(c, out m)) tints[c] = m = new Material(baseMat) { color = c };
        return m;
    }

    static GameObject Part(PrimitiveType type, Transform parent, Vector3 pos, Vector3 scale, Material m)
    {
        var go = GameObject.CreatePrimitive(type);
        Destroy(go.GetComponent<Collider>());   // 걸리적거리지 않게 (장식만)
        go.transform.SetParent(parent, false); go.transform.localPosition = pos; go.transform.localScale = scale;
        var r = go.GetComponent<Renderer>(); r.sharedMaterial = m; r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
        return go;
    }

    static Light MakeLight(Transform parent, Vector3 localPos, Color c, float range)
    {
        var go = new GameObject("Light"); go.transform.SetParent(parent, false); go.transform.localPosition = localPos;
        var l = go.AddComponent<Light>(); l.type = LightType.Point; l.color = c; l.range = range; l.intensity = 0f; l.shadows = LightShadows.None;
        return l;
    }
}
