using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 섬의 큰 구경거리 (GDD 8번 15-2): 야자수 8그루 더, 울타리 호, 등대를 장면의 `Landmarks` 아래에 놓고, 겹치는 소품(Decor)은 치운다.
// 순서: PropScatter.Run을 다시 돌렸다면 이것도 다시 돌릴 것(소품이 새로 깔리므로). 몇 번 돌려도 같은 결과.
// 실행: Unity.exe -batchmode -quit -projectPath ... -executeMethod LandmarkScatter.Run
public static class LandmarkScatter
{
    static readonly Vector2 Lighthouse = new Vector2(-17f, 3f);
    const float FenceR = 14.2f, FenceA0 = 100f, FenceA1 = 200f;
    static readonly Vector2[] OldPalms = { new Vector2(-12, -8), new Vector2(-3, -13), new Vector2(10, -10), new Vector2(12, 10) };

    static GameObject Spawn(string model, Transform parent, Vector3 pos, Quaternion rot, float scale)
    {
        var go = (GameObject)PrefabUtility.InstantiatePrefab(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Models/" + model + ".fbx"), parent);
        go.transform.SetPositionAndRotation(pos, rot);
        go.transform.localScale = Vector3.one * scale;
        foreach (var rend in go.GetComponentsInChildren<Renderer>())
        {
            var src = rend.sharedMaterials; var dst = new Material[src.Length];
            for (int i = 0; i < src.Length; i++) dst[i] = PropScatter.GetMat(src[i].name) ?? src[i];
            rend.sharedMaterials = dst;
        }
        return go;
    }

    public static void Run()
    {
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var old = GameObject.Find("Landmarks"); if (old != null) Object.DestroyImmediate(old);
        var root = new GameObject("Landmarks").transform;
        var clear = new List<Vector3>();   // 소품을 치울 자리 (x, z, 반지름)

        // 등대: 서쪽 해변, 충돌 있음
        var lh = Spawn("Props/Lighthouse", root, new Vector3(Lighthouse.x, PropScatter.GroundY(Lighthouse.x, Lighthouse.y), Lighthouse.y), Quaternion.Euler(0, 20, 0), 1f);
        var col = lh.AddComponent<CapsuleCollider>(); col.center = new Vector3(0, 3.8f, 0); col.radius = 1.3f; col.height = 7.6f;
        clear.Add(new Vector3(Lighthouse.x, Lighthouse.y, 2.6f));

        // 울타리: 오두막 뒤쪽 풀밭 가장자리를 따라 호 모양으로
        var fence = new GameObject("Fence").transform; fence.SetParent(root, false);
        int segs = 12;
        for (int i = 0; i < segs; i++)
        {
            float a0 = Mathf.Deg2Rad * Mathf.Lerp(FenceA0, FenceA1, i / (float)segs), a1 = Mathf.Deg2Rad * Mathf.Lerp(FenceA0, FenceA1, (i + 1) / (float)segs);
            var p0 = new Vector3(Mathf.Cos(a0) * FenceR, 0, Mathf.Sin(a0) * FenceR); var p1 = new Vector3(Mathf.Cos(a1) * FenceR, 0, Mathf.Sin(a1) * FenceR);
            var d = p1 - p0;
            var seg = Spawn("Props/FenceSeg", fence, new Vector3(p0.x, PropScatter.GroundY(p0.x, p0.z), p0.z), Quaternion.FromToRotation(Vector3.right, d), d.magnitude / 2f);
            seg.transform.localScale = new Vector3(d.magnitude / 2f, 1f, 1f);   // 호의 한 칸 길이에 맞춰 늘임
        }

        // 야자수 8그루 더: 풀밭 가장자리와 해변에 퍼뜨림 (겹치지 않게 간격 5.5 이상)
        var rng = new System.Random(33);
        var palmPos = new List<Vector2>(OldPalms);
        palmPos.Add(Lighthouse);
        var palms = new GameObject("Palms").transform; palms.SetParent(root, false);
        int made = 0;
        for (int tries = 0; tries < 800 && made < 8; tries++)
        {
            float a = (float)rng.NextDouble() * Mathf.PI * 2f, r = 11f + (float)rng.NextDouble() * 6.5f;
            var p = new Vector2(Mathf.Cos(a) * r, Mathf.Sin(a) * r);
            float deg = Mathf.Repeat(a * Mathf.Rad2Deg, 360f);
            bool ok = r <= 16.8f && !(p.x > 10f && Mathf.Abs(p.y) < 4.5f)                         // 부두 길
                      && !(r > 12.8f && r < 15.6f && deg > FenceA0 - 8f && deg < FenceA1 + 8f);   // 울타리 호
            foreach (var k in PropScatter.Keepout) if ((p.x - k.x) * (p.x - k.x) + (p.y - k.z) * (p.y - k.z) < (k.r + 1.2f) * (k.r + 1.2f)) ok = false;
            foreach (var q in palmPos) if ((p - q).sqrMagnitude < 5.5f * 5.5f) ok = false;
            if (!ok) continue;
            palmPos.Add(p); made++;
            float s = 0.8f + (float)rng.NextDouble() * 0.4f;
            var rot = Quaternion.Euler((float)rng.NextDouble() * 5f, (float)rng.NextDouble() * 360f, (float)rng.NextDouble() * 5f);
            Spawn("Palm", palms, new Vector3(p.x, PropScatter.GroundY(p.x, p.y), p.y), rot, s);
            clear.Add(new Vector3(p.x, p.y, 1.4f));
        }

        // 기존 야자수 4그루를 새 땅 높이에 맞춤
        for (int i = 1; i <= 4; i++)
        {
            var pt = GameObject.Find("PalmTree_0" + i);
            if (pt != null) { var q = pt.transform.position; pt.transform.position = new Vector3(q.x, PropScatter.GroundY(q.x, q.z), q.z); }
        }

        // 먼 바다의 바위섬 5개(충돌 있음) + 배 3척(충돌 없음)
        var sea = new GameObject("SeaDecor").transform; sea.SetParent(root, false);
        const float WaterY = -0.1f;
        var islets = new[]
        {
            new { model = "Props/IsletA", x = -50f, z = -32f, yaw = 30f, palm = true },
            new { model = "Props/IsletA", x = 28f, z = 56f, yaw = 200f, palm = true },
            new { model = "Props/IsletB", x = -18f, z = -58f, yaw = 80f, palm = false },
            new { model = "Props/IsletB", x = 60f, z = 22f, yaw = 150f, palm = false },
            new { model = "Props/IsletB", x = -60f, z = 30f, yaw = 310f, palm = false },
        };
        foreach (var it in islets)
        {
            var go = Spawn(it.model, sea, new Vector3(it.x, WaterY, it.z), Quaternion.Euler(0, it.yaw, 0), 1f);
            foreach (var mf in go.GetComponentsInChildren<MeshFilter>()) mf.gameObject.AddComponent<MeshCollider>().sharedMesh = mf.sharedMesh;
            if (it.palm) Spawn("Palm", sea, new Vector3(it.x + 0.3f, 3.2f, it.z + 0.2f), Quaternion.Euler(0, it.yaw * 2f, 3f), 0.7f);
        }
        var boats = new[] { new Vector3(-27f, 0.1f, -18f), new Vector3(4f, 0.1f, 30f), new Vector3(-30f, 0.1f, 22f) };
        var boatYaw = new[] { 35f, 100f, 250f }; var boatScale = new[] { 0.9f, 1f, 0.8f };
        for (int i = 0; i < boats.Length; i++) Spawn("Boat", sea, boats[i], Quaternion.Euler(0, boatYaw[i], 0), boatScale[i]);

        // 바다 거품이 새 해안선(반지름 약 17.6)에 맞도록
        var seaMat = AssetDatabase.LoadAssetAtPath<Material>("Assets/Materials/Mat_Sea.mat");
        seaMat.SetFloat("_ShoreRadius", 17.6f); EditorUtility.SetDirty(seaMat);

        // 겹치는 소품 치우기
        var decor = GameObject.Find("Decor"); int removed = 0;
        if (decor != null)
        {
            var kill = new List<GameObject>();
            foreach (var t in decor.GetComponentsInChildren<Transform>())
            {
                if (t.parent == null || t.parent == decor.transform || t.parent.parent != decor.transform) continue;   // 소품 하나(각 모델 루트)만 검사
                var pos = t.position; float r = Mathf.Sqrt(pos.x * pos.x + pos.z * pos.z), deg = Mathf.Repeat(Mathf.Atan2(pos.z, pos.x) * Mathf.Rad2Deg, 360f);
                bool hit = r > 13.4f && r < 15.0f && deg > FenceA0 - 4f && deg < FenceA1 + 4f;
                foreach (var c in clear) if ((pos.x - c.x) * (pos.x - c.x) + (pos.z - c.y) * (pos.z - c.y) < c.z * c.z) hit = true;
                if (hit) kill.Add(t.gameObject);
            }
            foreach (var g in kill) { Object.DestroyImmediate(g); removed++; }
        }

        EditorSceneManager.MarkSceneDirty(scene);
        Debug.Log("LANDMARK SCATTER saved=" + EditorSceneManager.SaveScene(scene) + " palms=" + made + " fenceSegs=" + segs + " removedProps=" + removed);
        AssetDatabase.SaveAssets();
    }
}
