using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 살아 있는 섬 장치 놓기 (GDD 8번 3단계): 재질 2개를 만들고, 장면에 `Life` 오브젝트(바람·반딧불·물고기 그림자)를 둔다. 몇 번 돌려도 같은 결과.
// 순서: PropScatter.Run → LandmarkScatter.Run → LifeSetup.Run (WindSway가 Decor·Landmarks를 이름으로 찾는다. 실행 시점엔 이미 장면에 있음)
// 실행: Unity.exe -batchmode -quit -projectPath ... -executeMethod LifeSetup.Run
public static class LifeSetup
{
    static Material GetOrMake(string path, string shader)
    {
        var m = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (m == null) { m = new Material(Shader.Find(shader)); AssetDatabase.CreateAsset(m, path); }
        return m;
    }

    public static void Run()
    {
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var firefly = GetOrMake("Assets/Materials/Mat_Firefly.mat", "FishingGame/SoftDot");
        var shadow = GetOrMake("Assets/Materials/Mat_FishShadow.mat", "FishingGame/FlatShadow");
        var old = GameObject.Find("Life"); if (old != null) Object.DestroyImmediate(old);
        var life = new GameObject("Life");
        life.AddComponent<WindSway>();
        life.AddComponent<Fireflies>().material = firefly;
        life.AddComponent<FishShadows>().material = shadow;
        EditorSceneManager.MarkSceneDirty(scene);
        Debug.Log("LIFE SETUP saved=" + EditorSceneManager.SaveScene(scene) + " shaders=" + firefly.shader.name + "," + shadow.shader.name);
        AssetDatabase.SaveAssets();
    }
}
