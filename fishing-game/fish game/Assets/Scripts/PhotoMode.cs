using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.UI;

// 사진 찍기 (GDD 9번 [확정]): P키 → 화면 글자(상태창·안내)를 빼고 풍경(낚싯대 포함)만 찍어 저장한다. 찰칵 소리 + 하얀 번쩍임 + "사진을 저장했어요!".
// 웹: 브라우저 다운로드(PhotoDownload.jslib). PC/편집기: 내 사진 폴더 아래 "BottleIsland"에 저장. 대화창·상점·꾸미기·도감이 열려 있거나 커서가 풀려 있으면 안 찍힘.
// 게임이 시작될 때 스스로 만들어진다(장면에 올릴 것 없음).
public class PhotoMode : MonoBehaviour
{
#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport("__Internal")] static extern void FG_DownloadPng(byte[] data, int length, string name);
#endif

    const float FlashTime = 0.4f, ToastHold = 3f, Cooldown = 1.2f;
    bool busy; float cooldownUntil;
    Image flash; CanvasGroup toastGroup; Text toastText;
    float flashT0 = -999f, toastT0 = -999f;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("PhotoMode").AddComponent<PhotoMode>(); }

    void Awake() { BuildUi(); }

    void Update()
    {
        var kb = Keyboard.current;
        if (kb != null && kb.pKey.wasPressedThisFrame && !busy && Time.unscaledTime >= cooldownUntil
            && Cursor.lockState == CursorLockMode.Locked && !TalkNPC.IsOpen && !ShopNPC.IsOpen && !DecorShop.IsOpen && !CatalogUI.IsOpen)
            StartCoroutine(Shoot());
        UpdateUi();
    }

    IEnumerator Shoot()
    {
        busy = true;
        // 화면 글자(오버레이 캔버스)만 한 프레임 꺼서 풍경만 찍는다
        var hidden = new List<Canvas>();
        foreach (var c in FindObjectsByType<Canvas>(FindObjectsSortMode.None))
            if (c.enabled && c.isRootCanvas && c.renderMode == RenderMode.ScreenSpaceOverlay) { c.enabled = false; hidden.Add(c); }
        yield return null;
        yield return new WaitForEndOfFrame();
        Texture2D tex = null;
        try { tex = ScreenCapture.CaptureScreenshotAsTexture(); }
        catch (System.Exception e) { Debug.LogWarning("사진을 찍지 못했어요: " + e.Message); }
        foreach (var c in hidden) if (c != null) c.enabled = true;
        if (tex != null)
        {
            string name = "BottleIsland_" + System.DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".png";
            bool ok = Save(tex.EncodeToPNG(), name);
            Destroy(tex);
            Sfx.Play(SfxKind.Shutter);
            flashT0 = Time.unscaledTime;
            toastText.text = ok ? "사진을 저장했어요!" : "사진을 저장하지 못했어요";
            toastT0 = Time.unscaledTime;
        }
        cooldownUntil = Time.unscaledTime + Cooldown;
        busy = false;
    }

    static bool Save(byte[] png, string name)
    {
        try
        {
#if UNITY_WEBGL && !UNITY_EDITOR
            FG_DownloadPng(png, png.Length, name);
#else
            string dir = Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.MyPictures), "BottleIsland");
            Directory.CreateDirectory(dir);
            File.WriteAllBytes(Path.Combine(dir, name), png);
#endif
            return true;
        }
        catch (System.Exception e) { Debug.LogWarning("사진 저장 실패: " + e.Message); return false; }
    }

    // ---------------- UI ----------------
    void BuildUi()
    {
        var canvas = new GameObject("PhotoCanvas").AddComponent<Canvas>();
        canvas.transform.SetParent(transform, false);
        canvas.renderMode = RenderMode.ScreenSpaceOverlay; canvas.sortingOrder = 20;

        flash = new GameObject("Flash").AddComponent<Image>();
        flash.transform.SetParent(canvas.transform, false);
        flash.color = new Color(1f, 1f, 1f, 0f); flash.raycastTarget = false;
        var frt = flash.rectTransform; frt.anchorMin = Vector2.zero; frt.anchorMax = Vector2.one; frt.offsetMin = frt.offsetMax = Vector2.zero;

        var toast = new GameObject("Toast").AddComponent<Image>();
        toast.transform.SetParent(canvas.transform, false);
        toast.sprite = HudPanel.RoundedRect(); toast.type = Image.Type.Sliced; toast.color = new Color(0.07f, 0.09f, 0.13f, 0.7f); toast.raycastTarget = false;
        var trt = toast.rectTransform; trt.anchorMin = trt.anchorMax = trt.pivot = new Vector2(0.5f, 1f); trt.anchoredPosition = new Vector2(0f, -24f); trt.sizeDelta = new Vector2(420f, 54f);
        toastGroup = toast.gameObject.AddComponent<CanvasGroup>(); toastGroup.alpha = 0f; toastGroup.blocksRaycasts = false;
        var t = new GameObject("Text").AddComponent<Text>();
        t.transform.SetParent(trt, false);
        t.font = GameFont.Get(); t.fontSize = 28; t.fontStyle = FontStyle.Bold; t.color = new Color(1f, 0.96f, 0.85f); t.alignment = TextAnchor.MiddleCenter; t.raycastTarget = false;
        var rt = t.rectTransform; rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(0.5f, 0.5f); rt.anchoredPosition = Vector2.zero; rt.sizeDelta = new Vector2(400f, 50f);
        toastText = t;
    }

    void UpdateUi()
    {
        float f = (Time.unscaledTime - flashT0) / FlashTime;
        flash.color = new Color(1f, 1f, 1f, f >= 1f ? 0f : 0.85f * (1f - f) * (1f - f));
        float tt = Time.unscaledTime - toastT0;
        toastGroup.alpha = tt > ToastHold + 0.5f ? 0f : Mathf.Clamp01(tt * 5f) * (1f - Mathf.Clamp01((tt - ToastHold) / 0.5f));
    }
}
