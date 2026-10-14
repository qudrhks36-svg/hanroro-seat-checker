using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 사진 찍기가 재생 모드에서 실제로 파일을 만드는지 시험 (GDD 9번). 실행: Unity.exe -batchmode -projectPath ... -executeMethod PhotoTest.Run (끝나면 스스로 종료)
public static class PhotoTest
{
    const string Flag = "PHOTOTEST";
    static int frames;

    public static void Run()
    {
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        SessionState.SetBool(Flag, true);
        EditorApplication.EnterPlaymode();
    }

    [InitializeOnLoadMethod]
    static void Hook()
    {
        if (SessionState.GetBool(Flag, false)) EditorApplication.update += Tick;
    }

    static string Dir { get { return Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.MyPictures), "낚시섬"); } }

    static void Tick()
    {
        if (!EditorApplication.isPlaying) return;
        frames++;
        if (frames == 30)
        {
            // 배치 모드 편집기에서는 프레임 끝 신호(WaitForEndOfFrame)가 안 와서 찍기 단계는 시험할 수 없다. 저장 단계(폴더 만들기·한글 파일 이름·PNG)만 시험한다.
            var tex = new Texture2D(8, 8); tex.SetPixel(0, 0, Color.red); tex.Apply();
            var save = typeof(PhotoMode).GetMethod("Save", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
            Debug.Log("PHOTOTEST save=" + save.Invoke(null, new object[] { tex.EncodeToPNG(), "낚시섬_시험_" + System.DateTime.Now.ToString("HHmmss") + ".png" }));
        }
        if (frames == 120)
        {
            var files = Directory.Exists(Dir) ? Directory.GetFiles(Dir, "낚시섬_시험_*.png") : new string[0];
            long size = files.Length > 0 ? new FileInfo(files[files.Length - 1]).Length : 0;
            Debug.Log("PHOTOTEST files=" + files.Length + " lastSize=" + size + " last=" + (files.Length > 0 ? files[files.Length - 1] : "-"));
            Finish();
        }
    }

    static void Finish()
    {
        SessionState.SetBool(Flag, false);
        EditorApplication.update -= Tick;
        EditorApplication.Exit(0);
    }
}
