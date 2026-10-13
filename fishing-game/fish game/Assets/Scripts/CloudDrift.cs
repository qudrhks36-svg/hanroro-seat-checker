using UnityEngine;

// 하늘의 몽실몽실한 로우폴리 구름 (GDD 8번 1단계 [확정]): 동글동글 공 몇 개를 뭉쳐 구름 덩이를 만들고 천천히 흘려보낸다.
// 재질은 장면에서 받는다(빌드에서 셰이더가 빠지지 않게). 조명을 받으므로 노을엔 물들고 밤엔 어두워진다.
public class CloudDrift : MonoBehaviour
{
    public Material material;
    public int count = 12;
    public float speed = 1.5f;
    public float range = 170f;   // 이 거리를 넘으면 반대편에서 다시 나타남

    Transform[] clouds;

    void Awake()
    {
        var rng = new System.Random(7);   // 항상 같은 하늘
        clouds = new Transform[count];
        for (int i = 0; i < count; i++)
        {
            var c = new GameObject("Cloud" + i).transform;
            c.SetParent(transform, false);
            float ang = (float)rng.NextDouble() * Mathf.PI * 2f, dist = 55f + (float)rng.NextDouble() * 110f;
            c.position = new Vector3(Mathf.Cos(ang) * dist, 38f + (float)rng.NextDouble() * 30f, Mathf.Sin(ang) * dist);
            float s = 1f + (float)rng.NextDouble() * 0.9f;
            int puffs = 4 + rng.Next(3);
            for (int p = 0; p < puffs; p++)
            {
                var puff = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                Destroy(puff.GetComponent<Collider>());
                puff.transform.SetParent(c, false);
                float u = puffs <= 1 ? 0f : (p / (puffs - 1f) - 0.5f);
                float h = 1f - Mathf.Abs(u) * 1.2f;   // 가운데 공이 크고 높게
                puff.transform.localPosition = new Vector3(u * 16f * s, h * 2.5f * s, ((float)rng.NextDouble() - 0.5f) * 3f);
                puff.transform.localScale = new Vector3(9f, 6f, 7f) * (0.55f + 0.45f * h) * s;
                var r = puff.GetComponent<Renderer>();
                r.sharedMaterial = material;
                r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
                r.receiveShadows = false;
            }
            clouds[i] = c;
        }
    }

    void Update()
    {
        foreach (var c in clouds)
        {
            var p = c.position;
            p.x += speed * Time.deltaTime;
            if (p.x > range) p.x = -range;
            c.position = p;
        }
    }
}
