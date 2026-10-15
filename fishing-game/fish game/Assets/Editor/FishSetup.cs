using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 새 물고기 그림(Assets/Fish/Fish_09~12)을 스프라이트로 설정하고 도감(CatalogUI.fishSprites)에 이어 붙인다. 몇 번 돌려도 같은 결과.
// 실행: Unity.exe -batchmode -quit -projectPath ... -executeMethod FishSetup.Run
public static class FishSetup
{
    static readonly string[] Files = { "Fish_09_Seahorse", "Fish_10_Jelly", "Fish_11_Moonfish", "Fish_12_Rainbow", "Fish_13_Tuna", "Fish_14_Marlin", "Fish_15_Angler", "Fish_16_StarWhale" };

    public static void Run()
    {
        foreach (var f in Files)
        {
            string path = "Assets/Fish/" + f + ".png";
            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceUpdate);
            var imp = (TextureImporter)AssetImporter.GetAtPath(path);
            imp.textureType = TextureImporterType.Sprite; imp.spriteImportMode = SpriteImportMode.Single;
            imp.alphaIsTransparency = true; imp.mipmapEnabled = false; imp.filterMode = FilterMode.Bilinear; imp.maxTextureSize = 512;
            imp.SaveAndReimport();
        }
        var scene = EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var cat = Object.FindFirstObjectByType<CatalogUI>();
        var all = new System.Collections.Generic.List<Sprite>(cat.fishSprites);
        foreach (var f in Files)
        {
            var sp = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/Fish/" + f + ".png");
            if (sp != null && !all.Contains(sp)) all.Add(sp);
        }
        cat.fishSprites = all.ToArray();
        EditorUtility.SetDirty(cat);
        EditorSceneManager.MarkSceneDirty(scene);
        EditorSceneManager.SaveScene(scene);
        Debug.Log("FISH SETUP sprites=" + cat.fishSprites.Length + " fish=" + FishTable.All.Length);
    }
}
