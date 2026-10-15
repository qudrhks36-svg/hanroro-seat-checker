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

    // 집 꾸미기 사진(편집 중 장면은 저장하지 않음): 장식 전부+오두막 3단계를 낮/밤에, 꾸미기 창, 바틀이 대화창 안내 칸
    public static void Homes()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var tod = UnityEngine.Object.FindFirstObjectByType<TimeOfDay>();
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        var bf = System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public;
        Home.OwnedMask = (1 << Home.ItemCount) - 1; Home.CabinLevel = int.Parse(Environment.GetEnvironmentVariable("FG_CABIN") ?? "2");
        var home = new GameObject("TmpHome").AddComponent<HomeDecor>(); home.SendMessage("Awake");
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        System.Action<string> shot = name =>
        {
            cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, name + ".png"), tex.EncodeToPNG());
        };
        var poses = new[] { ("front", new Vector3(-8f, 2.2f, -4.5f), 0f, 6f), ("side", new Vector3(-4.2f, 2.0f, -6f), -42f, 8f), ("parasol", new Vector3(-8f, 2.0f, -2.5f), 28f, 10f), ("chimney", new Vector3(-5.5f, 4.2f, -3f), -30f, -6f), ("above", new Vector3(-1f, 9f, -1f), -52f, 30f), ("hammock", new Vector3(-8f, 1.7f, -3.5f), 270f, 8f) };
        foreach (var clock in new[] { 0f, 470f })
        {
            tod.Apply(clock); home.SendMessage("Update");
            foreach (var ps in home.GetComponentsInChildren<ParticleSystem>()) ps.Simulate(2f, true, true, true);
            foreach (var p in poses)
            {
                cam.transform.SetPositionAndRotation(p.Item2, Quaternion.Euler(p.Item4, p.Item3, 0f));
                shot("home_" + p.Item1 + (clock > 0f ? "_night" : "_day"));
            }
        }
        foreach (var t in home.GetComponentsInChildren<Transform>(true)) if (t.name == "Hammock" || t.name == "Home_Hammock(Clone)" || t.name == "Post") Debug.Log("HMDBG " + t.name + " lp=" + t.localPosition + " lr=" + t.localEulerAngles + " ls=" + t.localScale + " wp=" + t.position);
        // 꾸미기 창
        tod.Apply(0f); Inventory.Money = 250;
        var shop = new GameObject("TmpDecorShop").AddComponent<DecorShop>(); shop.SendMessage("Awake");
        typeof(DecorShop).GetField("instance", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static).SetValue(null, shop);
        Home.OwnedMask = 0b00101; Home.CabinLevel = 1;
        typeof(DecorShop).GetMethod("SetOpen", bf).Invoke(shop, new object[] { true });
        foreach (var cv in shop.GetComponentsInChildren<Canvas>(true)) { cv.renderMode = RenderMode.ScreenSpaceCamera; cv.worldCamera = cam; cv.planeDistance = 1f; }
        cam.transform.SetPositionAndRotation(new Vector3(-15, 1.7f, 0), Quaternion.Euler(8, 270, 0));
        shot("home_shop");
        // 바틀이 대화창의 안내 칸(가장 긴 경우)
        typeof(DecorShop).GetMethod("SetOpen", bf).Invoke(shop, new object[] { false });
        var canvasGo = new GameObject("TmpDlg"); var dc = canvasGo.AddComponent<Canvas>(); dc.renderMode = RenderMode.ScreenSpaceCamera; dc.worldCamera = cam; dc.planeDistance = 1f;
        var view = DialogView.Build(canvasGo.transform, "바틀이", true);
        view.Set("저, 저기… 물고기 잡으셨네요.", "고등어 x2   도미 x1\n합계 30원\n낚싯대: 기본 낚싯대   —   다음: 튼튼한 낚싯대 200원",
                 "왼쪽 클릭|팔기", "오른쪽 클릭|낚싯대 200원", "F|꾸미기", "E / Esc|닫기");
        shot("home_dialog");
        cam.targetTexture = null;
        Debug.Log("HOME SHOTS done");
    }

    // 먼 바다 사진(편집 중 장면은 저장하지 않음): 부두의 배, 먼 바다의 배(낮/밤), 도감 16칸
    public static void Fars()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var tod = UnityEngine.Object.FindFirstObjectByType<TimeOfDay>();
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        var fs = new GameObject("TmpFarSea").AddComponent<FarSea>(); fs.SendMessage("Awake");
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        System.Action<string> shot = name =>
        {
            cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, name + ".png"), tex.EncodeToPNG());
        };
        tod.Apply(0f);
        cam.transform.SetPositionAndRotation(new Vector3(24f, 1.7f, -0.6f), Quaternion.Euler(18f, 180f, 0f)); shot("far_dock_day");
        cam.transform.SetPositionAndRotation(new Vector3(18f, 3f, -7f), Quaternion.Euler(15f, 40f, 0f)); shot("far_dock_side");
        cam.transform.SetPositionAndRotation(new Vector3(95f, 1.9f, -40f), Quaternion.Euler(6f, -67f, 0f)); shot("far_boat_view_island");
        cam.transform.SetPositionAndRotation(new Vector3(88f, 2.5f, -36f), Quaternion.Euler(14f, 120f, 0f)); shot("far_boat_day");
        tod.Apply(450f);
        fs.SendMessage("Update");
        cam.transform.SetPositionAndRotation(new Vector3(88f, 2.5f, -36f), Quaternion.Euler(14f, 120f, 0f)); shot("far_boat_night");
        cam.transform.SetPositionAndRotation(new Vector3(24f, 1.7f, -0.6f), Quaternion.Euler(18f, 180f, 0f)); shot("far_dock_night");
        cam.targetTexture = null;
        Debug.Log("FAR SHOTS done");
    }

    // 임의 시점 사진: FG_CAMS="x,y,z,pitch,yaw;..." (파일 이름 view_0, view_1 ...). 작업 중 자리 확인용.
    public static void Views()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        UnityEngine.Object.FindFirstObjectByType<TimeOfDay>().Apply(float.Parse(Environment.GetEnvironmentVariable("FG_CLOCK") ?? "0"));
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        int i = 0;
        foreach (var spec in Environment.GetEnvironmentVariable("FG_CAMS").Split(';'))
        {
            var v = spec.Split(',');
            float[] f = Array.ConvertAll(v, float.Parse);
            cam.transform.SetPositionAndRotation(new Vector3(f[0], f[1], f[2]), Quaternion.Euler(f[3], f[4], 0f));
            cam.targetTexture = rt; cam.Render();
            RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
            File.WriteAllBytes(Path.Combine(outDir, "view_" + i++ + ".png"), tex.EncodeToPNG());
        }
        cam.targetTexture = null;
        Debug.Log("VIEWS done");
    }

    // 이벤트 사진(편집 중 장면은 저장하지 않음): 해변의 병 + 줍기 안내, 쪽지 카드, 하늘의 갈매기
    public static void Events()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        UnityEngine.Object.FindFirstObjectByType<TimeOfDay>().Apply(0f);
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        cam.transform.SetPositionAndRotation(new Vector3(-15, 1.7f, 0), Quaternion.Euler(14, 270, 0));
        var bf = System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Public;
        var ev = new GameObject("TmpEvents").AddComponent<SeaEvents>(); ev.SendMessage("Awake");
        foreach (var cv in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None))
            if (cv.isRootCanvas && cv.renderMode == RenderMode.ScreenSpaceOverlay) { cv.renderMode = RenderMode.ScreenSpaceCamera; cv.worldCamera = cam; cv.planeDistance = 1f; }
        float bx = -16.8f, bz = 0.4f;
        ev.PlaceBottle(new Vector3(bx, PropScatter.GroundY(bx, bz), bz));
        ev.StartGull(new Vector3(-30, 14, -20), new Vector3(-40, 14, 20));
        var gullGo = (GameObject)typeof(SeaEvents).GetField("gull", bf).GetValue(ev);
        gullGo.transform.position = new Vector3(-34f, 9f, 5f);
        ((CanvasGroup)typeof(SeaEvents).GetField("promptGroup", bf).GetValue(ev)).alpha = 1f;
        ev.ShowNote(2, 50, true);
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        typeof(SeaEvents).GetField("noteT0", bf).SetValue(ev, Time.unscaledTime - 1.5f);
        typeof(SeaEvents).GetMethod("UpdateUi", bf).Invoke(ev, null);
        cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
        RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
        File.WriteAllBytes(Path.Combine(outDir, "ev_scene.png"), tex.EncodeToPNG());
        // 멀리서 본 병과 하늘의 갈매기
        typeof(SeaEvents).GetField("noteT0", bf).SetValue(ev, -999f); typeof(SeaEvents).GetMethod("UpdateUi", bf).Invoke(ev, null);
        ((CanvasGroup)typeof(SeaEvents).GetField("promptGroup", bf).GetValue(ev)).alpha = 0f;
        UnityEngine.Object.DestroyImmediate((GameObject)typeof(SeaEvents).GetField("bottle", bf).GetValue(ev));
        ev.PlaceBottle(new Vector3(-18.6f, PropScatter.GroundY(-18.6f, 0.8f), 0.8f));
        cam.transform.rotation = Quaternion.Euler(6, 270, 0);
        gullGo.transform.position = new Vector3(-30f, 7f, -2f);
        cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
        RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
        File.WriteAllBytes(Path.Combine(outDir, "ev_far.png"), tex.EncodeToPNG());
        cam.targetTexture = null;
        Debug.Log("EVENT SHOTS done");
    }

    // 날씨별 모습 사진(편집 중 장면은 저장하지 않음): 맑음 / 흐림 / 비 (낮과 노을)
    public static void Weathers()
    {
        string outDir = Environment.GetEnvironmentVariable("FG_OUT");
        Directory.CreateDirectory(outDir);
        EditorSceneManager.OpenScene("Assets/Scenes/SampleScene.unity");
        var tod = UnityEngine.Object.FindFirstObjectByType<TimeOfDay>();
        var cam = Camera.main;
        UnityEngine.Rendering.Universal.CameraExtensions.GetUniversalAdditionalCameraData(cam).renderPostProcessing = false;
        cam.transform.SetPositionAndRotation(new Vector3(-15, 1.7f, 0), Quaternion.Euler(8, 270, 0));
        var bf = System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Public;
        var hud = new GameObject("TmpHud").AddComponent<HudPanel>(); hud.SendMessage("Awake");
        foreach (var cv in UnityEngine.Object.FindObjectsByType<Canvas>(FindObjectsSortMode.None))
            if (cv.isRootCanvas && cv.renderMode == RenderMode.ScreenSpaceOverlay) { cv.renderMode = RenderMode.ScreenSpaceCamera; cv.worldCamera = cam; cv.planeDistance = 1f; }
        var w = new GameObject("TmpWeather").AddComponent<Weather>(); w.SendMessage("Awake");
        var rain = (ParticleSystem)typeof(Weather).GetField("rain", bf).GetValue(w);
        var rt = new RenderTexture(1280, 720, 24, RenderTextureFormat.ARGB32);
        var tex = new Texture2D(1280, 720, TextureFormat.RGB24, false);
        var cases = new[] { ("clear", WeatherKind.Clear, 0f, 0f), ("cloudy", WeatherKind.Cloudy, 0.6f, 0f), ("rain", WeatherKind.Rain, 1f, 1f) };
        foreach (var clock in new[] { 0f, 300f })
            foreach (var c in cases)
            {
                typeof(Weather).GetProperty("Current").GetSetMethod(true).Invoke(null, new object[] { c.Item2 });
                typeof(Weather).GetProperty("Overcast").GetSetMethod(true).Invoke(null, new object[] { c.Item3 });
                typeof(Weather).GetProperty("Rain").GetSetMethod(true).Invoke(null, new object[] { c.Item4 });
                tod.Apply(clock); hud.SendMessage("Update");
                rain.Clear();
                if (c.Item4 > 0f)
                {
                    var em = rain.emission; em.rateOverTime = 1000f;
                    rain.transform.position = cam.transform.position + Vector3.up * 9f + cam.transform.forward * 6f;
                    rain.Simulate(1.5f, true, true, true);
                }
                cam.targetTexture = rt; Canvas.ForceUpdateCanvases(); cam.Render();
                RenderTexture.active = rt; tex.ReadPixels(new Rect(0, 0, 1280, 720), 0, 0); tex.Apply(); RenderTexture.active = null;
                File.WriteAllBytes(Path.Combine(outDir, "w_" + c.Item1 + (clock > 0f ? "_sunset" : "_day") + ".png"), tex.EncodeToPNG());
            }
        cam.targetTexture = null;
        Debug.Log("WEATHER SHOTS done");
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
        foreach (var r in cam.GetComponentsInChildren<Renderer>(true)) Debug.Log("RODDBG " + r.name + " enabled=" + r.enabled + " active=" + r.gameObject.activeInHierarchy + " mats=" + string.Join(",", System.Array.ConvertAll(r.sharedMaterials, m => m.name + "/" + m.color)) + " bounds=" + r.bounds.center + r.bounds.size);
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

        ResultCard.Show(FishTable.All[15], true, new Vector3(-23, -0.1f, 0), cam, false, 67, false); setTime(1.5f); shot("fx_card_new_rare");
        Goal.Progress = 2; ResultCard.Show(FishTable.All[0], false, new Vector3(-23, -0.1f, 0), cam, true, 31, true); setTime(1.5f); shot("fx_card_common");
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
        // 도감 화면(최고 기록 줄)
        Collection.BestCm[0] = 31; for (int q = 0; q < Collection.Counts.Length; q++) if (q != 5 && q != 6) Collection.Counts[q] = 1;
        var cat = UnityEngine.Object.FindFirstObjectByType<CatalogUI>(); cat.SendMessage("Awake");
        typeof(CatalogUI).GetMethod("SetOpen", bf).Invoke(cat, new object[] { true });
        foreach (var cv in cat.GetComponentsInChildren<Canvas>(true)) if (cv.isRootCanvas || cv.renderMode == RenderMode.ScreenSpaceOverlay) { cv.renderMode = RenderMode.ScreenSpaceCamera; cv.worldCamera = cam; cv.planeDistance = 1f; }
        shot("fx_catalog");
        foreach (var (idx, nm) in new[] { (15, "fx_catalog_far"), (5, "fx_catalog_unknown"), (11, "fx_catalog_rare") })
        {
            typeof(CatalogUI).GetField("selected", bf).SetValue(cat, idx);
            typeof(CatalogUI).GetMethod("Refresh", bf).Invoke(cat, null);
            shot(nm);
        }
        cam.targetTexture = null;
        Debug.Log("FX SHOTS done");
    }
}
