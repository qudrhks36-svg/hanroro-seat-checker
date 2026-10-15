using UnityEngine;
using UnityEngine.UI;
using UnityEngine.InputSystem;

// M키 음소거 (GDD 2번): 소리 전체(BGM·효과음·NPC 소리)를 끄고 켠다. 꺼진 동안만 "소리 꺼짐 (M)" 표시. 저장하지 않는다.
// 장면에 올려 둘 것이 없고, 게임이 시작될 때 스스로 만들어진다. 시간(timeScale)이 멈춰도 동작.
public class MuteToggle : MonoBehaviour
{
    static MuteToggle instance;
    bool muted;
    Text label;

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init()
    {
        AudioListener.volume = 1f;   // 항상 소리가 켜진 채로 시작
        var go = new GameObject("MuteToggle");
        DontDestroyOnLoad(go);
        instance = go.AddComponent<MuteToggle>();
    }

    // M키와 같은 동작(시험에서도 부름)
    public static void Toggle() { if (instance != null) instance.Flip(); }
    public static bool IsMuted { get { return instance != null && instance.muted; } }

    void Awake() { BuildLabel(); Apply(); }

    void Update()
    {
        var kb = Keyboard.current;
        if (kb != null && kb.mKey.wasPressedThisFrame) Flip();
    }

    void Flip() { muted = !muted; Apply(); }

    void Apply()
    {
        AudioListener.volume = muted ? 0f : 1f;
        label.transform.parent.gameObject.SetActive(muted);
    }

    void BuildLabel()
    {
        var canvasGo = new GameObject("MuteCanvas");
        canvasGo.transform.SetParent(transform, false);
        var canvas = canvasGo.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 6;
        var go = new GameObject("MuteLabel");
        go.transform.SetParent(canvasGo.transform, false);
        var bg = go.AddComponent<Image>();
        bg.sprite = HudPanel.RoundedRect(); bg.type = Image.Type.Sliced; bg.color = UiTheme.Cream; bg.raycastTarget = false;
        var rt = bg.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(1f, 0f);
        rt.anchoredPosition = new Vector2(-30, 30); rt.sizeDelta = new Vector2(210, 46);
        var tg = new GameObject("Text").AddComponent<Text>();
        tg.transform.SetParent(go.transform, false);
        tg.font = GameFont.Get(); tg.fontSize = 24; tg.alignment = TextAnchor.MiddleCenter; tg.color = UiTheme.Ink; tg.raycastTarget = false; tg.text = "소리 꺼짐 (M)";
        var trt = tg.rectTransform; trt.anchorMin = Vector2.zero; trt.anchorMax = Vector2.one; trt.offsetMin = trt.offsetMax = Vector2.zero;
        label = tg;   // 켜고 끄는 건 부모(알약) 전체
    }
}
