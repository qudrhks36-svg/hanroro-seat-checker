using UnityEngine;

// 모든 글자에 쓰는 글꼴 (GDD 11번 [확정]): 게임에 넣은 나눔고딕(Resources/Fonts, OFL 라이선스).
// 웹(WebGL)에서는 컴퓨터에 깔린 글꼴을 못 쓰므로 파일로 넣어야 한글이 나온다.
public static class GameFont
{
    static Font font;

    public static Font Get()
    {
        if (font == null)
        {
            font = Resources.Load<Font>("Fonts/NanumGothic");
            if (font == null) font = Font.CreateDynamicFontFromOSFont(new[] { "Malgun Gothic", "Arial" }, 28); // 글꼴 파일이 없을 때만(PC)
        }
        return font;
    }
}
