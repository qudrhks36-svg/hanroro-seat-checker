using System.Collections.Generic;
using UnityEngine;

// 살아 있는 섬 (GDD 8번 3단계 [확정] ①②): 바람에 야자수·풀·꽃이 흔들리고, 배가 물결 따라 출렁인다.
// 장면의 `Life` 오브젝트에 올려 두면 시작할 때 이름으로 대상을 찾는다(Decor/Grass·Flowers, Landmarks/Palms, PalmTree_0N, SeaDecor·BoatSpot의 배).
// 한 번에 한꺼번에 움직이는 가벼운 계산뿐이라(수백 개) 웹에서도 부담이 적다. Time.time을 쓰므로 대화·도감 중(시간 멈춤)엔 같이 멈춘다.
public class WindSway : MonoBehaviour
{
    struct Sway { public Transform t; public Quaternion rot; public float amp, speed, phase; }
    struct Bob { public Transform t; public Vector3 pos; public Quaternion rot; public float phase; }
    readonly List<Sway> sways = new List<Sway>();
    readonly List<Bob> boats = new List<Bob>();

    void Start()
    {
        var decor = GameObject.Find("Decor");
        if (decor != null)
        {
            AddChildren(decor.transform.Find("Grass"), 4f, 1.6f);
            AddChildren(decor.transform.Find("Flowers"), 5f, 1.4f);
        }
        var landmarks = GameObject.Find("Landmarks");
        if (landmarks != null) AddChildren(landmarks.transform.Find("Palms"), 1.2f, 0.8f);
        for (int i = 1; i <= 4; i++) { var p = GameObject.Find("PalmTree_0" + i); if (p != null) Add(p.transform, 1.2f, 0.8f); }

        var sea = GameObject.Find("SeaDecor");
        if (sea != null) foreach (Transform c in sea.transform) if (c.name.StartsWith("Boat")) AddBoat(c);
        var spot = GameObject.Find("BoatSpot"); if (spot != null) AddBoat(spot.transform);
    }

    void AddChildren(Transform parent, float amp, float speed) { if (parent != null) foreach (Transform c in parent) Add(c, amp, speed); }
    void Add(Transform t, float amp, float speed)
    {
        float ph = (t.position.x * 0.37f + t.position.z * 0.53f) % (Mathf.PI * 2f);   // 자리마다 다른 박자
        sways.Add(new Sway { t = t, rot = t.localRotation, amp = amp, speed = speed, phase = ph });
    }
    void AddBoat(Transform t) { boats.Add(new Bob { t = t, pos = t.position, rot = t.rotation, phase = t.position.x * 0.2f + t.position.z * 0.3f }); }

    void Update()
    {
        float time = Time.time;
        float gust = 0.8f + 0.2f * Mathf.Sin(time * 0.25f);   // 바람 세기가 천천히 오르내림
        foreach (var s in sways)
        {
            float a = s.amp * gust, w = time * s.speed + s.phase;
            s.t.localRotation = s.rot * Quaternion.Euler(a * Mathf.Sin(w), 0f, a * 0.8f * Mathf.Sin(w * 0.87f + 1.3f));
        }
        foreach (var b in boats)
        {
            float w = time * 0.9f + b.phase;
            b.t.position = b.pos + Vector3.up * 0.06f * Mathf.Sin(w);
            b.t.rotation = b.rot * Quaternion.Euler(1.5f * Mathf.Sin(w * 0.8f + 0.7f), 0f, 2f * Mathf.Sin(w + 1.9f));
        }
    }
}
