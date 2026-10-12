using UnityEngine;

// 배경음악 (GDD 2번 [확정]): 음원 하나를 게임 내내 반복 재생. 기본 볼륨은 작게.
// 시간(timeScale)이 멈춰도(도감·대화 중) 계속 나온다.
public class BgmPlayer : MonoBehaviour
{
    public AudioClip clip;
    [Range(0f, 1f)] public float volume = 0.2f;

    void Awake()
    {
        if (clip == null) return;
        var src = gameObject.AddComponent<AudioSource>();
        src.clip = clip; src.loop = true; src.volume = volume; src.spatialBlend = 0f; // 2D(어디서나 같은 소리)
        src.Play();
    }
}
