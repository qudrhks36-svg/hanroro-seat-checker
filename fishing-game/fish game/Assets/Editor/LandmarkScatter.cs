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
        var lh = Spawn("Props/Lighthouse", root, new Vector3(Lighthouse.x, 0f, Lighthouse.y), Quaternion.Euler(0, 20, 0), 1f);
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
            var seg = Spawn("Props/FenceSeg", fence, new Vector3(p0.x, PropScatter.GroundY(FenceR), p0.z), Quaternion.FromToRotation(Vector3.right, d), d.magnitude / 2f);
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
            bool ok = !(p.x > 10f && Mathf.Abs(p.y) < 4.5f)                         // 부두 길
                      && !(r > 12.8f && r < 15.6f && deg > FenceA0 - 8f && deg < FenceA1 + 8f);   // 울타리 호
            foreach (var k in PropScatter.Keepout) if ((p.x - k.x) * (p.x - k.x) + (p.y - k.z) * (p.y - k.z) < (k.r + 1.2f) * (k.r + 1.2f)) ok = false;
            foreach (var q in palmPos) if ((p - q).sqrMagnitude < 5.5f * 5.5f) ok = false;
            if (!ok) continue;
            palmPos.Add(p); made++;
            float s = 0.8f + (float)rng.NextDouble() * 0.4f;
            var rot = Quaternion.Euler((float)rng.NextDouble() * 5f, (float)rng.NextDouble() * 360f, (float)rng.NextDouble() * 5f);
            Spawn("Palm", palms, new Vector3(p.x, PropScatter.GroundY(r), p.y), rot, s);
            clear.Add(new Vector3(p.x, p.y, 1.4f));
        }

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
