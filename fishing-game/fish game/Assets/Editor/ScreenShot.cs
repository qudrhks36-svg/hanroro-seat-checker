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
        // 반딧불은 실행 중에만 만들어지므로, 편집 중엔 Awake/Update를 직접 불러 8초치를 미리 돌려서 찍는다
        var ff = UnityEngine.Object.FindFirstObjectByType<Fireflies>();
        if (ff != null)
        {
            ff.SendMessage("Awake"); ff.SendMessage("Update");
            var fps = ff.GetComponentInChildren<ParticleSystem>(); if (fps != null) fps.Simulate(8f, true, true);
        }
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
            new View("i_islet", new Vector3(-12, 2f, -8), new Vector3(3, 238, 0)),
            new View("j_boat", new Vector3(-14, 2f, -6), new Vector3(4, 227, 0)),
            new View("k_hills", new Vector3(0, 6f, 4), new Vector3(14, 195, 0)),
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

    // 낚싯대 단계별 모습 사진(편집 중 장면은 저장하지 않음)
    public static void Rods()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        UnityEngine.Object.FindFirstObjectByType<TimeOfDay>().Apply(0f);
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        cam.transform.SetPositionAndRotation(new Vector3(-15, 1.7f, 0), Quaternion.Euler(8, 270, 0));
        var look = new GameObject("TmpRodLook").AddComponent<RodLook>();
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        for (int lv = 0; lv < 3; lv++)
        {
            RodUpgrade.Level = lv; look.SendMessage("Update");
            cam.targetTexture = rt; cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, "rod_" + lv + ".png"), tex.EncodeToPNG());
        }
        cam.targetTexture = null; RodUpgrade.Level = 0;
        Debug.Log("ROD SHOTS done");
    }

    // 낚시 연출 사진(편집 중 장면은 저장하지 않음): 결과 카드(새로 잡은 희귀 / 흔함 / 튀어오르는 순간), 상태창의 도감 줄, 물보라를 찍는다.
    public static void Fx()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        UnityEngine.Object.FindFirstObjectByType<TimeOfDay>().Apply(0f);
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        cam.transform.SetPositionAndRotation(new Vector3(-15, 1.7f, 0), Quaternion.Euler(8, 270, 0));
        var bf = System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Static;

        Collection.Counts[0] = 2; Collection.Counts[3] = 1;   // 도감 줄 보여주기용(저장하지 않음)
        var hud = new GameObject("TmpHud").AddComponent<HudPanel>(); hud.SendMessage("Awake"); hud.SendMessage("Update");
        var card = new GameObject("TmpCard").AddComponent<ResultCard>(); card.SendMessage("Awake");
        typeof(ResultCard).GetField("instance", bf).SetValue(null, card);
        foreach (var cv in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None))
            if (cv.isRootCanvas && cv.renderMode == RenderMode.ScreenSpaceOverlay && (cv.transform.parent == hud.transform || cv.transform.parent == card.transform))
            { cv.renderMode = RenderMode.ScreenSpaceCamera; cv.worldCamera = cam; cv.planeDistance = 1f; }

        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        System.Action<string> shot = name =>
        {
            cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, name + ".png"), tex.EncodeToPNG());
        };
        System.Action<float> setTime = back => { typeof(ResultCard).GetField("t0", bf).SetValue(card, Time.unscaledTime - back); card.SendMessage("Update"); };

        ResultCard.Show(FishTable.All[7], true, new Vector3(-23, -0.1f, 0), cam); setTime(1.5f); shot("fx_card_new_rare");
        Goal.Progress = 2; ResultCard.Show(FishTable.All[0], false, new Vector3(-23, -0.1f, 0), cam, true); setTime(1.5f); shot("fx_card_common");
        ResultCard.Show(FishTable.All[3], true, new Vector3(-23, -0.1f, 0), cam); setTime(0.35f); shot("fx_jump");
        setTime(99f);   // 카드 숨김

        var fxGo = new GameObject("TmpSplash"); var fxo = fxGo.AddComponent<SplashFx>(); fxo.SendMessage("Awake");   // 편집 모드에선 Awake가 안 불려서 직접
        typeof(SplashFx).GetField("instance", bf).SetValue(null, fxo);
        SplashFx.Splash(new Vector3(-23, -0.1f, 0), true);
        foreach (var name in new[] { "rings", "drops" })
        {
            var ps = (ParticleSystem)typeof(SplashFx).GetField(name, bf).GetValue(fxo);
            ps.Simulate(0.45f, true, false, true);
        }
        shot("fx_splash");
        cam.targetTexture = null;
        Debug.Log("FX SHOTS done");
    }
}
