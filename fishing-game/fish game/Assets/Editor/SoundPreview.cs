using System.IO;
using UnityEngine;

// 코드로 만든 소리를 WAV 파일로 뽑아서 게임을 안 돌려도 들어볼 수 있게 하는 에디터 도구.
// 사용: SoundPreview.Export(소리 샘플 배열, 2, "저장할 경로.wav")  (스테레오면 channels=2, 모노면 1)
public static class SoundPreview
{
    public static void Export(float[] samples, int channels, string path, int rate = 44100)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        int bytes = samples.Length * 2;
        using (var w = new BinaryWriter(File.Create(path)))
        {
            w.Write(new[] { 'R', 'I', 'F', 'F' }); w.Write(36 + bytes);
            w.Write(new[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' }); w.Write(16);
            w.Write((short)1); w.Write((short)channels); w.Write(rate);
            w.Write(rate * channels * 2); w.Write((short)(channels * 2)); w.Write((short)16);
            w.Write(new[] { 'd', 'a', 't', 'a' }); w.Write(bytes);
            foreach (var s in samples) w.Write((short)(Mathf.Clamp(s, -1f, 1f) * 32767f));
        }
    }
}
