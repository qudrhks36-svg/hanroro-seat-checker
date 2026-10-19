using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 고닷 포팅 밑작업(docs/GODOT_PORT.md): 장면(SampleScene)의 모든 물체 위치·모양을 godot/data/scene.json 으로 뽑는다. 장면은 저장하지 않는다.
// 실행: Unity.exe -batchmode -quit -projectPath "…/fish game" -executeMethod GodotExport.Dump -logFile …   (환경변수 FG_OUT=저장 폴더, 없으면 ../godot/data)
public static class GodotExport
{
    [Serializable]
    class Item
    {
        public string path, name, parent, source, mesh;
        public bool active;
        public float[] pos, euler, quat, scale;   // 세계 좌표(유니티: 왼손, Y 위, 단위 m), 회전은 오일러 각도(도)
        public string[] materials, colliders, components;
        public string light;                // "Directional color=… intensity=…" 같은 한 줄
    }

    [Serializable]
    class SceneDump { public string scene, note; public List<Item> items = new List<Item>(); }

    static float[] V(Vector3 v) { return new[] { Round(v.x), Round(v.y), Round(v.z) }; }
    static float Round(float f) { return Mathf.Round(f * 10000f) / 10000f; }

    static string PathOf(Transform t)
    {
        string p = t.name;
        while (t.parent != null) { t = t.parent; p = t.name + "/" + p; }
        return p;
    }

    // 효과음(코드가 숫자로 만드는 소리)을 WAV 파일로 저장: godot/assets/audio/sfx/*.wav (16비트 모노). 빗소리는 이음새 없이 반복되는 4초짜리.
    // 실행: -executeMethod GodotExport.DumpSfx
    public static void DumpSfx()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        if (string.IsNullOrEmpty(outDir)) outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "..", "godot", "assets", "audio", "sfx"));
        Directory.CreateDirectory(outDir);
        var all = new Dictionary<string, float[]>
        {
            { "cast", SfxSynth.Cast() }, { "bite", SfxSynth.Bite() }, { "catch", SfxSynth.Catch() }, { "miss", SfxSynth.Miss() },
            { "sell", SfxSynth.Sell() }, { "splash", SfxSynth.Splash() }, { "new_fish", SfxSynth.NewFish() }, { "goal_done", SfxSynth.GoalDone() },
            { "upgrade", SfxSynth.Upgrade() }, { "shutter", SfxSynth.Shutter() }, { "chime", SfxSynth.Chime() },
            { "voice_seagull", SfxSynth.Seagull() }, { "voice_cat", SfxSynth.Cat() }, { "voice_merchant", SfxSynth.Merchant() },
        };
        var rainM = typeof(Weather).GetMethod("MakeRainClip", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
        if (rainM != null)
        {
            var clip = (AudioClip)rainM.Invoke(null, null);
            var data = new float[clip.samples * clip.channels];
            if (clip.GetData(data, 0)) { WriteWav(Path.Combine(outDir, "rain_loop.wav"), data, clip.frequency); Debug.Log("GODOT SFX rain_loop samples=" + data.Length + " rate=" + clip.frequency); }   // 빗소리는 22050Hz라 따로 저장
        }
        foreach (var kv in all)
        {
            WriteWav(Path.Combine(outDir, kv.Key + ".wav"), kv.Value, SfxSynth.Rate);
            Debug.Log("GODOT SFX " + kv.Key + " samples=" + kv.Value.Length + " sec=" + (kv.Value.Length / (float)SfxSynth.Rate));
        }
        Debug.Log("GODOT SFX done: " + all.Count + " files, rate=" + SfxSynth.Rate + " -> " + outDir);
    }

    static void WriteWav(string path, float[] samples, int rate)
    {
        using (var w = new BinaryWriter(File.Create(path)))
        {
            int bytes = samples.Length * 2;
            w.Write(System.Text.Encoding.ASCII.GetBytes("RIFF")); w.Write(36 + bytes); w.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt "));
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(rate); w.Write(rate * 2); w.Write((short)2); w.Write((short)16);
            w.Write(System.Text.Encoding.ASCII.GetBytes("data")); w.Write(bytes);
            foreach (var s in samples) w.Write((short)Mathf.RoundToInt(Mathf.Clamp(s, -1f, 1f) * 32767f));
        }
    }

    public static void Dump()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        if (string.IsNullOrEmpty(outDir)) outDir = Path.GetFullPath(Path.Combine(Application.dataPath, "..", "..", "godot", "data"));
        Directory.CreateDirectory(outDir);
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var d = new SceneDump
        {
            scene = "SampleScene",
            note = "세계 좌표. 유니티=왼손 좌표계(Y 위), 고닷=오른손(Y 위, 앞이 -Z). 위치는 z 부호를 뒤집고, 회전은 고닷에서 눈으로 맞출 것(docs/GODOT_PORT.md).",
        };
        foreach (var root in scene.GetRootGameObjects())
            foreach (var t in root.GetComponentsInChildren<Transform>(true))
            {
                var go = t.gameObject;
                var it = new Item
                {
                    path = PathOf(t), name = go.name, parent = t.parent != null ? PathOf(t.parent) : "",
                    active = go.activeInHierarchy, pos = V(t.position), euler = V(t.rotation.eulerAngles), scale = V(t.lossyScale),
                    quat = new[] { Round(t.rotation.x), Round(t.rotation.y), Round(t.rotation.z), Round(t.rotation.w) },
                };
                var src = PrefabUtility.GetCorrespondingObjectFromOriginalSource(go);
                if (src != null) it.source = AssetDatabase.GetAssetPath(src);
                var mf = go.GetComponent<MeshFilter>();
                if (mf != null && mf.sharedMesh != null) it.mesh = mf.sharedMesh.name;
                var mr = go.GetComponent<Renderer>();
                if (mr != null)
                {
                    var names = new List<string>();
                    foreach (var m in mr.sharedMaterials) names.Add(m != null ? m.name : "");
                    it.materials = names.ToArray();
                }
                var cols = new List<string>();
                foreach (var c in go.GetComponents<Collider>())
                {
                    if (c is BoxCollider b) cols.Add("Box center=" + b.center + " size=" + b.size);
                    else if (c is SphereCollider s) cols.Add("Sphere center=" + s.center + " radius=" + s.radius);
                    else if (c is CapsuleCollider cp) cols.Add("Capsule center=" + cp.center + " radius=" + cp.radius + " height=" + cp.height);
                    else cols.Add(c.GetType().Name);
                }
                if (cols.Count > 0) it.colliders = cols.ToArray();
                var comps = new List<string>();
                foreach (var c in go.GetComponents<Component>())
                {
                    if (c == null) continue;
                    string n = c.GetType().Name;
                    if (n == "Transform" || n == "MeshFilter" || n == "MeshRenderer") continue;
                    comps.Add(n);
                }
                if (comps.Count > 0) it.components = comps.ToArray();
                var lt = go.GetComponent<Light>();
                if (lt != null) it.light = lt.type + " color=" + lt.color + " intensity=" + lt.intensity + " range=" + lt.range;
                d.items.Add(it);
            }
        File.WriteAllText(Path.Combine(outDir, "scene.json"), JsonUtility.ToJson(d, true));
        Debug.Log("GODOT EXPORT done: " + d.items.Count + " objects -> " + outDir);
    }
}
