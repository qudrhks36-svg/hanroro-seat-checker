using UnityEditor;
using UnityEngine;

// 웹(WebGL) 빌드: 결과물은 저장소 밖(C:\Users\qudrh\fishing-game-build\webgl)에 만든다.
public static class WebBuild
{
    [MenuItem("Tools/Build WebGL")]
    public static void Build()
    {
        var r = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/SampleScene.unity" },
            locationPathName = @"C:\Users\qudrh\fishing-game-build\webgl",
            target = BuildTarget.WebGL,
            options = BuildOptions.None,
        });
        Debug.Log("WEBGL BUILD " + r.summary.result + " size=" + r.summary.totalSize + " errors=" + r.summary.totalErrors);
    }
}
