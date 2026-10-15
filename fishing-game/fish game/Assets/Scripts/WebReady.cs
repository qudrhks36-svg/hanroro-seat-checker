using System.Collections;
using System.Runtime.InteropServices;
using UnityEngine;

// 웹 페이지의 "불러오는 화면"을 걷어도 될 때를 알려 준다(GDD 9번 공개 준비): 게임이 실제로 화면을 몇 프레임 그린 뒤 한 번 FG_Ready를 부른다.
// 게임이 시작될 때 스스로 만들어진다(장면에 올릴 것 없음). 웹 밖(편집기·PC)에서는 아무 일도 안 한다.
public class WebReady : MonoBehaviour
{
#if UNITY_WEBGL && !UNITY_EDITOR
    [DllImport("__Internal")] static extern void FG_Ready();
#endif
    const int Frames = 90;   // 약 1.5초 분량의 프레임

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Init() { new GameObject("WebReady").AddComponent<WebReady>(); }

    IEnumerator Start()
    {
        for (int i = 0; i < Frames; i++) yield return null;
        yield return new WaitForEndOfFrame();
#if UNITY_WEBGL && !UNITY_EDITOR
        FG_Ready();
#endif
        Destroy(gameObject);
    }
}
