using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// 에디터 없이 장면 사진 찍기(작업 확인용): Unity.exe -batchmode -quit ... -executeMethod ScreenShot.Run
// 환경변수 FG_OUT=저장 폴더, FG_CLOCK=시각(초, 0=낮 300=노을 450=밤). 장면은 저장하지 않는다(카메라를 옮기기만 함).
public static class ScreenShot
{
    struct View { public string name; public Vector3 pos, euler; public View(string n, Vector3 p, Vector3 e) { name = n; pos = p; euler = e; } }

    public static void Run()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        float clock = float.Parse(Environment.GetEnvironmentVariable("FG_CLOCK") ?? "0");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var tod = UnityEngine.Object.FindFirstObjectByType<TimeOfDay>(); tod.Apply(clock);
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = true;
        var views = new[]
        {
            new View("a_start_south", new Vector3(0, 1.7f, 0), new Vector3(8, 0, 0)),
            new View("b_start_east", new Vector3(0, 1.7f, 0), new Vector3(8, 90, 0)),
            new View("c_start_west", new Vector3(0, 1.7f, 0), new Vector3(8, 270, 0)),
            new View("d_start_north", new Vector3(0, 1.7f, 0), new Vector3(8, 180, 0)),
            new View("e_overview", new Vector3(0, 38, -34), new Vector3(52, 0, 0)),
            new View("f_beach", new Vector3(-6, 1.7f, -10), new Vector3(6, 20, 0)),
            new View("g_lighthouse", new Vector3(-6, 2f, 3), new Vector3(4, 270, 0)),
            new View("h_fence", new Vector3(-4, 1.7f, -2), new Vector3(6, 330, 0)),
        };
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        foreach (var v in views)
        {
            cam.transform.SetPositionAndRotation(v.pos, Quaternion.Euler(v.euler));
            cam.targetTexture = rt; cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, v.name + ".png"), tex.EncodeToPNG());
        }
        cam.targetTexture = null;
        Debug.Log("SHOTS done " + views.Length);
    }

    // 대화창 모양 사진(편집 중 장면은 저장하지 않음): 상점형(바틀이·돌쇠)과 대사형(끼룩이)을 샘플 글로 그려서 찍는다.
    public static void Dialogs()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var tod = UnityEngine.Object.FindFirstObjectByType<TimeOfDay>(); tod.Apply(0f);
        var cam = Camera.main;
        cam.transform.SetPositionAndRotation(new Vector3(0, 1.7f, 0), Quaternion.Euler(8, 270, 0));
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = true;
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        var cases = new[]
        {
            new[] { "바틀이", "고, 고마워요… 여기 90원이에요.", "끼룩이 x2   모카 x1\n합계 90원\n낚싯대: 기본 낚싯대   —   다음: 튼튼한 낚싯대 200원", "왼쪽 클릭|모두 팔기", "오른쪽 클릭|튼튼한 낚싯대 200원", "E / Esc|닫기" },
            new[] { "돌쇠", "허허, 좋은 물고기구먼! 값을 20% 더 쳐주지.", "붕어 x3   고등어 x1\n합계 150원", "왼쪽 클릭|모두 팔기", "E / Esc|닫기" },
            new[] { "끼룩이", "끼룩! 오늘은 바다가 반짝반짝해서 기분이 좋아~ 같이 낚시하자!", "", "E / Esc|닫기" },
            new[] { "모카", "냐아… 졸려… 햇볕이 따뜻해서 낮잠 자기 딱 좋은 날이야…", "", "E / Esc|닫기" },
        };
        foreach (var c in cases)
        {
            var canvasGo = new GameObject("TmpCanvas"); var canvas = canvasGo.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceCamera; canvas.worldCamera = cam; canvas.planeDistance = 1f;
            bool hasInfo = !string.IsNullOrEmpty(c[2]);
            var hints = new string[c.Length - 3]; Array.Copy(c, 3, hints, 0, hints.Length);
            var view = DialogView.Build(canvas.transform, c[0], hasInfo);
            view.Set(c[1], c[2], hints);
            cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, "dialog_" + c[0] + ".png"), tex.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(canvasGo);
        }
        cam.targetTexture = null;
        Debug.Log("DIALOG SHOTS done");
    }
}
