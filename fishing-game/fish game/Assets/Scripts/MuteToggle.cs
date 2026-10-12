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
        label.gameObject.SetActive(muted);
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
        label = go.AddComponent<Text>();
        label.font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "Arial" }, 24); // PC 가정
        label.fontSize = 24; label.alignment = TextAnchor.LowerRight;
        label.color = new Color(1f, 0.96f, 0.88f, 0.85f); label.raycastTarget = false;
        label.text = "소리 꺼짐 (M)";
        var rt = label.rectTransform;
        rt.anchorMin = rt.anchorMax = rt.pivot = new Vector2(1f, 0f);
        rt.anchoredPosition = new Vector2(-30, 75); rt.sizeDelta = new Vector2(400, 40);   // 소지금(아래 30) 바로 위
    }
}
