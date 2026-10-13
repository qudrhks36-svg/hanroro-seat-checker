using UnityEngine;

// 밤 반딧불 (GDD 8번 3단계 [확정] ③): 밤에만 풀밭 위를 노란 초록 불빛이 느리게 떠다닌다. 낮엔 사라지고, 시간대가 바뀔 때 서서히 나타나고 사라진다.
// 재질(SoftDot 셰이더)은 장면에서 받는다(빌드에서 셰이더가 빠지지 않게). 반딧불 수는 밤 정도(TimeOfDay.Night)에 비례.
public class Fireflies : MonoBehaviour
{
    public Material material;
    public float perSecondAtNight = 7f;   // 수명 약 7초 → 밤에 약 50개 (장면에 저장된 값이 우선: 지금 7)

    ParticleSystem ps;
    ParticleSystem.EmissionModule emission;

    void Awake()
    {
        var go = new GameObject("FireflyParticles");
        go.transform.SetParent(transform, false);
        go.transform.localPosition = new Vector3(0f, 1.3f, 0f);
        ps = go.AddComponent<ParticleSystem>();
        ps.Stop();
        var main = ps.main;
        main.loop = true; main.playOnAwake = false;
        main.startLifetime = new ParticleSystem.MinMaxCurve(5f, 9f);
        main.startSpeed = 0f;
        main.startSize = new ParticleSystem.MinMaxCurve(0.5f, 0.9f);
        main.startColor = new ParticleSystem.MinMaxGradient(new Color(0.85f, 1f, 0.45f, 1f), new Color(1f, 0.92f, 0.5f, 1f));
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = 200;
        var shape = ps.shape; shape.shapeType = ParticleSystemShapeType.Box; shape.scale = new Vector3(26f, 2.4f, 26f);
        var noise = ps.noise; noise.enabled = true; noise.strength = 0.7f; noise.frequency = 0.25f; noise.scrollSpeed = 0.3f; noise.quality = ParticleSystemNoiseQuality.Low;
        var col = ps.colorOverLifetime; col.enabled = true;
        var g = new Gradient();
        g.SetKeys(new[] { new GradientColorKey(Color.white, 0f), new GradientColorKey(Color.white, 1f) },
                  new[] { new GradientAlphaKey(0f, 0f), new GradientAlphaKey(1f, 0.2f), new GradientAlphaKey(1f, 0.75f), new GradientAlphaKey(0f, 1f) });
        col.color = g;
        var r = go.GetComponent<ParticleSystemRenderer>();
        r.material = material; r.renderMode = ParticleSystemRenderMode.Billboard;
        emission = ps.emission; emission.rateOverTime = 0f;
        ps.Play();
    }

    void Update() { emission.rateOverTime = perSecondAtNight * TimeOfDay.Night; }
}
