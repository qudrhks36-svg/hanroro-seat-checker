using UnityEngine;

// 물고기 그림자 (GDD 8번 3단계 [확정] ④): 섬 둘레 바다를 어두운 반투명 물고기 모양 6마리가 천천히 헤엄친다. 장식일 뿐 낚시와 무관하다.
// 재질(FlatShadow 셰이더)은 장면에서 받는다. 모양은 코드로 만든 납작한 메시(몸통 타원 + 꼬리, 가장자리 알파 0으로 부드럽게).
public class FishShadows : MonoBehaviour
{
    public Material material;
    const float WaterY = -0.07f;   // 바다(-0.1) 바로 위

    struct Fish { public Transform t; public float radius, speed, phase, wobble; }
    Fish[] fish;

    void Awake()
    {
        var mesh = BuildMesh();
        fish = new Fish[6];
        float[] radius = { 23f, 27f, 31f, 25f, 36f, 29f };
        float[] speed = { 0.05f, -0.04f, 0.035f, -0.06f, 0.03f, 0.045f };
        float[] size = { 1.0f, 1.3f, 2.4f, 0.9f, 1.6f, 1.1f };   // 셋째는 큰 그림자
        for (int i = 0; i < fish.Length; i++)
        {
            var go = new GameObject("FishShadow" + i);
            go.transform.SetParent(transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>(); mr.sharedMaterial = material;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; mr.receiveShadows = false;
            go.transform.localScale = Vector3.one * size[i];
            fish[i] = new Fish { t = go.transform, radius = radius[i], speed = speed[i], phase = i * 1.7f, wobble = 0.6f + 0.2f * i };
        }
    }

    void Update()
    {
        float time = Time.time;
        foreach (var f in fish)
        {
            float a = f.phase + time * f.speed;
            float r = f.radius + Mathf.Sin(time * 0.15f + f.phase) * 1.5f;
            var p = new Vector3(Mathf.Cos(a) * r, WaterY, Mathf.Sin(a) * r);
            f.t.position = p;
            float dir = Mathf.Sign(f.speed);
            var tangent = new Vector3(-Mathf.Sin(a) * dir, 0f, Mathf.Cos(a) * dir);
            f.t.rotation = Quaternion.LookRotation(tangent) * Quaternion.Euler(0f, Mathf.Sin(time * f.wobble + f.phase) * 12f, 0f);   // 헤엄치며 살짝 꼬리질
        }
    }

    // +Z가 머리 방향. 길이 약 1.6, 폭 약 0.55.
    static Mesh BuildMesh()
    {
        var v = new System.Collections.Generic.List<Vector3>(); var c = new System.Collections.Generic.List<Color>(); var t = new System.Collections.Generic.List<int>();
        v.Add(new Vector3(0, 0, 0.1f)); c.Add(new Color(1, 1, 1, 1));   // 몸통 가운데
        const int n = 14;
        for (int i = 0; i < n; i++)
        {
            float a = i / (float)n * Mathf.PI * 2f;
            v.Add(new Vector3(Mathf.Sin(a) * 0.28f, 0f, 0.1f + Mathf.Cos(a) * 0.62f)); c.Add(new Color(1, 1, 1, 0));   // 가장자리는 투명
        }
        for (int i = 0; i < n; i++) { t.Add(0); t.Add(1 + i); t.Add(1 + (i + 1) % n); }
        int tail = v.Count;   // 꼬리: 몸통 뒤쪽 끝에서 갈라지는 삼각형
        v.Add(new Vector3(0, 0, -0.5f)); c.Add(new Color(1, 1, 1, 0.9f));
        v.Add(new Vector3(-0.25f, 0, -0.95f)); c.Add(new Color(1, 1, 1, 0));
        v.Add(new Vector3(0.25f, 0, -0.95f)); c.Add(new Color(1, 1, 1, 0));
        t.Add(tail); t.Add(tail + 2); t.Add(tail + 1);
        var m = new Mesh { name = "FishShadow" };
        m.SetVertices(v); m.SetColors(c); m.SetTriangles(t, 0); m.RecalculateBounds();
        return m;
    }
}
