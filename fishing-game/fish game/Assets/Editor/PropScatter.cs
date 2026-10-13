using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 섬 소품 흩뿌리기 (GDD 8번 2단계 15-1): 풀·꽃·덤불·바위·조개·불가사리를 장면의 `Decor` 아래에 놓는다. 몇 번 돌려도 같은 결과(고정 씨앗).
// 비워 두는 곳: 시작 위치, 오두막·바틀이·모카·야자수 둘레, 부두 길. 소품엔 충돌체가 없어 걸리지 않는다.
// 에디터 없이 실행: Unity.exe -batchmode -quit -projectPath ... -executeMethod PropScatter.Run
public static class PropScatter
{
    internal struct Zone { public float x, z, r; public Zone(float x, float z, float r) { this.x = x; this.z = z; this.r = r; } }

    internal static readonly Zone[] Keepout =
    {
        new Zone(0, 0, 3.2f),          // 시작 위치
        new Zone(-8, 6, 5.4f),         // 오두막
        new Zone(-3, 4, 1.9f),         // 바틀이
        new Zone(-7.5f, 2.2f, 1.6f),   // 모카
        new Zone(-12, -8, 1.8f), new Zone(-3, -13, 1.8f), new Zone(10, -10, 1.8f), new Zone(12, 10, 1.8f),   // 야자수
    };

    // 섬 윗면 높이: 풀밭(r≤14.5)은 0.08, 해변으로 갈수록 0까지 내려옴(Island.fbx 기준)
    internal static float GroundY(float r) { return r <= 14.5f ? 0.08f : r < 16.5f ? Mathf.Lerp(0.08f, 0f, (r - 14.5f) / 2f) : 0f; }

    static readonly Dictionary<string, Color> Colors = new Dictionary<string, Color>
    {
        { "Mat_Blade", new Color(0.42f, 0.72f, 0.28f) }, { "Mat_BladeLight", new Color(0.58f, 0.80f, 0.36f) },
        { "Mat_Bush", new Color(0.33f, 0.60f, 0.30f) }, { "Mat_BushLight", new Color(0.50f, 0.75f, 0.36f) },
        { "Mat_Stem", new Color(0.36f, 0.62f, 0.28f) },
        { "Mat_PetalPink", new Color(1f, 0.62f, 0.74f) }, { "Mat_PetalYellow", new Color(1f, 0.86f, 0.35f) }, { "Mat_PetalWhite", new Color(0.98f, 0.97f, 0.92f) },
        { "Mat_FlowerCenter", new Color(1f, 0.72f, 0.2f) },
        { "Mat_Rock", new Color(0.64f, 0.62f, 0.60f) }, { "Mat_RockDark", new Color(0.47f, 0.46f, 0.48f) },
        { "Mat_Shell", new Color(0.98f, 0.86f, 0.80f) }, { "Mat_Starfish", new Color(0.96f, 0.55f, 0.42f) },
        { "Mat_LHWhite", new Color(0.97f, 0.95f, 0.92f) }, { "Mat_LHRed", new Color(0.88f, 0.30f, 0.28f) }, { "Mat_LHDark", new Color(0.36f, 0.31f, 0.33f) },
        { "Mat_LHGlass", new Color(1f, 0.90f, 0.50f) }, { "Mat_Fence", new Color(0.78f, 0.60f, 0.40f) }, { "Mat_FenceCap", new Color(0.62f, 0.45f, 0.30f) },
    };

    internal static Material GetMat(string name)
    {
        string path = "Assets/Materials/" + name + ".mat";
        var m = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (m != null) return m;
        m = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = name };
        m.SetColor("_BaseColor", Colors[name]);
        m.SetFloat("_Smoothness", 0.1f);
        if (name == "Mat_LHGlass") { m.EnableKeyword("_EMISSION"); m.SetColor("_EmissionColor", new Color(1f, 0.85f, 0.4f) * 1.6f); }   // 등대 램프는 스스로 빛남
        AssetDatabase.CreateAsset(m, path);
        return m;
    }

    static System.Random rng;
    static readonly List<Zone> placed = new List<Zone>();
    static float R(float a, float b) { return a + (float)rng.NextDouble() * (b - a); }

    static bool Free(float x, float z, float gap)
    {
        foreach (var k in Keepout) if ((x - k.x) * (x - k.x) + (z - k.z) * (z - k.z) < k.r * k.r) return false;
        if (x > 11f && Mathf.Abs(z) < 3.6f) return false;   // 부두로 가는 길
        foreach (var p in placed) if ((x - p.x) * (x - p.x) + (z - p.z) * (z - p.z) < (gap + p.r) * (gap + p.r)) return false;
        return true;
    }

    // 반지름 [r0, r1] 안의 빈자리를 찾아 놓는다. 못 찾으면 건너뜀.
    static bool Place(Transform parent, string model, float r0, float r1, float gap, float s0, float s1, float sink, float cx = 0f, float cz = 0f, float spread = 0f)
    {
        var prefab = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Models/Props/" + model + ".fbx");
        for (int tries = 0; tries < 60; tries++)
        {
            float x, z;
            if (spread > 0f) { x = cx + R(-spread, spread); z = cz + R(-spread, spread); }
            else { float a = R(0f, Mathf.PI * 2f), r = Mathf.Sqrt(R(r0 * r0, r1 * r1)); x = Mathf.Cos(a) * r; z = Mathf.Sin(a) * r; }
            float rr = Mathf.Sqrt(x * x + z * z);
            if (rr < r0 || rr > r1 || !Free(x, z, gap)) continue;
            var go = (GameObject)PrefabUtility.InstantiatePrefab(prefab, parent);
            float s = R(s0, s1);
            go.transform.SetPositionAndRotation(new Vector3(x, GroundY(rr) - sink, z), Quaternion.Euler(0f, R(0f, 360f), 0f));
            go.transform.localScale = Vector3.one * s;
            foreach (var rend in go.GetComponentsInChildren<Renderer>())
            {
                var src = rend.sharedMaterials; var dst = new Material[src.Length];
                for (int i = 0; i < src.Length; i++) dst[i] = Colors.ContainsKey(src[i].name) ? GetMat(src[i].name) : src[i];
                rend.sharedMaterials = dst;
                rend.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;   // 작은 소품은 그림자 생략(가볍게)
            }
            foreach (var t in go.GetComponentsInChildren<Transform>()) GameObjectUtility.SetStaticEditorFlags(t.gameObject, StaticEditorFlags.BatchingStatic);
            placed.Add(new Zone(x, z, gap > 0.4f ? gap * 0.5f : 0f));
            return true;
        }
        return false;
    }

    static Transform Group(Transform root, string name) { var g = new GameObject(name).transform; g.SetParent(root, false); return g; }

    public static void Run()
    {
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var old = GameObject.Find("Decor"); if (old != null) Object.DestroyImmediate(old);
        var root = new GameObject("Decor").transform;
        rng = new System.Random(21); placed.Clear();

        var bushes = Group(root, "Bushes"); var rocks = Group(root, "Rocks"); var grass = Group(root, "Grass");
        var flowers = Group(root, "Flowers"); var beach = Group(root, "Beach");

        int nb = 0, nr = 0, ng = 0, nf = 0, ns = 0;
        for (int i = 0; i < 16; i++) if (Place(bushes, "Bush", 5f, 13.8f, 2.2f, 0.8f, 1.35f, 0.04f)) nb++;
        for (int i = 0; i < 6; i++) if (Place(rocks, "RockA", 9f, 17.5f, 2.4f, 0.8f, 1.5f, 0.12f)) nr++;
        for (int i = 0; i < 10; i++) if (Place(rocks, "RockB", 8f, 18.5f, 1.6f, 0.8f, 1.5f, 0.08f)) nr++;
        for (int i = 0; i < 110; i++) if (Place(grass, "Grass", 2f, 15.5f, 0.55f, 0.8f, 1.4f, 0.0f)) ng++;
        string[] kinds = { "FlowerPink", "FlowerYellow", "FlowerWhite" };
        for (int c = 0; c < 15; c++)   // 꽃은 무리 지어 핀다
        {
            float a = R(0f, Mathf.PI * 2f), r = R(3.5f, 13.5f); float cx = Mathf.Cos(a) * r, cz = Mathf.Sin(a) * r;
            string kind = kinds[c % kinds.Length];   // 분홍·노랑·하양 무리를 번갈아
            int n = 5 + rng.Next(5);
            for (int i = 0; i < n; i++) if (Place(flowers, rng.NextDouble() < 0.85 ? kind : kinds[rng.Next(kinds.Length)], 2f, 15f, 0.4f, 1.4f, 2.0f, 0f, cx, cz, 1.5f)) nf++;
        }
        for (int i = 0; i < 16; i++) if (Place(beach, "Shell", 16.8f, 19.2f, 0.9f, 0.9f, 1.5f, 0.0f)) ns++;
        for (int i = 0; i < 7; i++) if (Place(beach, "Starfish", 16.8f, 19.0f, 1.8f, 0.9f, 1.4f, 0.0f)) ns++;

        EditorSceneManager.MarkSceneDirty(scene);
        bool ok = EditorSceneManager.SaveScene(scene);
        AssetDatabase.SaveAssets();
        Debug.Log("PROP SCATTER saved=" + ok + " bush=" + nb + " rock=" + nr + " grass=" + ng + " flower=" + nf + " beach=" + ns);
    }
}
