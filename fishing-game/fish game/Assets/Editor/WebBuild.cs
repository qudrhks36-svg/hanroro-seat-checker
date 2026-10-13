using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 웹(WebGL) 빌드: 결과물은 저장소 밖(C:\Users\qudrh\fishing-game-build\webgl)에 만든다.
public static class WebBuild
{
    [MenuItem("Tools/Build WebGL")]
    public static void Build()
    {
        Run("Assets/Scenes/SampleScene.unity", @"C:\Users\qudrh\fishing-game-build\webgl");
    }

    // 시험용: 환경변수 FG_CLOCK(초)에서 시작하는 임시 장면으로 FG_OUT 폴더에 빌드한다(노을·밤 모습을 기다리지 않고 보려는 용도). 원본 장면은 건드리지 않음.
    public static void BuildTest()
    {
        const string tmp = "Assets/Scenes/_TestClock.unity";
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        foreach (var t in UnityEngine.Object.FindObjectsByType<TimeOfDay>(FindObjectsSortMode.None))
            t.startClock = float.Parse(Environment.GetEnvironmentVariable("FG_CLOCK"));
        EditorSceneManager.SaveScene(scene, tmp, true);
        try { Run(tmp, Environment.GetEnvironmentVariable("FG_OUT")); }
        finally { AssetDatabase.DeleteAsset(tmp); }
    }

    static void Run(string scenePath, string outDir)
    {
        var r = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = new[] { scenePath },
            locationPathName = outDir,
            target = BuildTarget.WebGL,
            options = BuildOptions.None,
        });
        Debug.Log("WEBGL BUILD " + r.summary.result + " size=" + r.summary.totalSize + " errors=" + r.summary.totalErrors);
    }
}
