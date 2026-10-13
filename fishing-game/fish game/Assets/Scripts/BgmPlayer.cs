using UnityEngine;

// 배경음악 (GDD 2번 [확정]): 음원의 잔잔한 앞부분(0~loopEnd초)만 게임 내내 반복 재생. 기본 볼륨은 작게.
// 드럼 "딩"이 16.75초에 들어와서 그 전(16.5초)에서 처음으로 돌아간다. 이음새는 0.5초 동안 소리를 줄였다 키워 부드럽게.
// 시간(timeScale)이 멈춰도(도감·대화 중) 계속 나온다.
public class BgmPlayer : MonoBehaviour
{
    public AudioClip clip;
    [Range(0f, 1f)] public float volume = 0.2f;

    public float loopEnd = 16.5f;
    const float Fade = 0.5f;
    AudioSource src;

    void Awake()
    {
        if (clip == null) return;
        src = gameObject.AddComponent<AudioSource>();
        src.clip = clip; src.loop = true; src.volume = volume; src.spatialBlend = 0f; // 2D(어디서나 같은 소리)
        src.Play();
    }

    void Update()
    {
        if (src == null) return;
        float t = src.time;
        if (t >= loopEnd) { src.time = 0f; t = 0f; }
        src.volume = volume * Mathf.Min(1f, t / Fade, (loopEnd - t) / Fade);
    }
}
