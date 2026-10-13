using UnityEditor;
using UnityEngine;

// 낚시 연출 재질 만들기 (GDD 9번): 물보라·물결 고리 재질을 Resources/Fx에 둔다(SplashFx가 Resources.Load로 읽음 → 빌드에 꼭 포함됨). 몇 번 돌려도 같은 결과.
// 실행: Unity.exe -batchmode -quit -projectPath ... -executeMethod FxSetup.Run
public static class FxSetup
{
    static void Make(string name, string shader)
    {
        string path = "Assets/Resources/Fx/" + name + ".mat";
        if (AssetDatabase.LoadAssetAtPath<Material>(path) != null) return;
        AssetDatabase.CreateAsset(new Material(Shader.Find(shader)), path);
    }

    public static void Run()
    {
        if (!AssetDatabase.IsValidFolder("Assets/Resources/Fx")) AssetDatabase.CreateFolder("Assets/Resources", "Fx");
        Make("Mat_Ripple", "FishingGame/Ring");
        Make("Mat_Droplet", "FishingGame/SoftDot");
        AssetDatabase.SaveAssets();
        Debug.Log("FX SETUP done ripple=" + (AssetDatabase.LoadAssetAtPath<Material>("Assets/Resources/Fx/Mat_Ripple.mat") != null) + " droplet=" + (AssetDatabase.LoadAssetAtPath<Material>("Assets/Resources/Fx/Mat_Droplet.mat") != null));
    }
}
