using System.Collections.Generic;
using UnityEngine;

public enum SfxKind { Cast, Bite, Catch, Miss, Sell, Splash, NewFish, GoalDone, Upgrade }

// 낚시 효과음 재생 (GDD 2번). 처음 필요할 때 소리를 한 번 만들어 두고 계속 재사용.
// 장면에 따로 올려 둘 것이 없고, 어디서든 Sfx.Play(SfxKind.Cast) 하면 됨. 시간(timeScale)이 멈춰도 재생.
public static class Sfx
{
    const float Volume = 0.5f;
    static AudioSource source;
    static readonly Dictionary<SfxKind, AudioClip> clips = new Dictionary<SfxKind, AudioClip>();

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    static void Reset() { source = null; clips.Clear(); }   // Play를 껐다 켜면 오브젝트가 사라지므로 처음부터

    public static void Play(SfxKind kind)
    {
        if (source == null)
        {
            var go = new GameObject("SfxPlayer");
            Object.DontDestroyOnLoad(go);
            source = go.AddComponent<AudioSource>();
            source.playOnAwake = false; source.spatialBlend = 0f;   // 2D
        }
        AudioClip clip;
        if (!clips.TryGetValue(kind, out clip))
        {
            float[] samples = Make(kind);
            clip = AudioClip.Create(kind.ToString(), samples.Length, 1, SfxSynth.Rate, false);
            clip.SetData(samples, 0);
            clips[kind] = clip;
        }
        source.PlayOneShot(clip, Volume);
    }

    static float[] Make(SfxKind kind)
    {
        switch (kind)
        {
            case SfxKind.Cast: return SfxSynth.Cast();
            case SfxKind.Bite: return SfxSynth.Bite();
            case SfxKind.Catch: return SfxSynth.Catch();
            case SfxKind.Miss: return SfxSynth.Miss();
            case SfxKind.Splash: return SfxSynth.Splash();
            case SfxKind.NewFish: return SfxSynth.NewFish();
            case SfxKind.GoalDone: return SfxSynth.GoalDone();
            case SfxKind.Upgrade: return SfxSynth.Upgrade();
            default: return SfxSynth.Sell();
        }
    }
}
