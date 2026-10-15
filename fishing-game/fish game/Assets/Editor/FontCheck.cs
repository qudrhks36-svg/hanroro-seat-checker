using System.IO;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

// 글꼴에 게임 글자(코드 속 문자열)가 모두 있는지 확인하는 시험 (GDD 11번 글꼴). 실행: -executeMethod FontCheck.Run (환경변수 FG_FONT = Resources 안 글꼴 이름)
public static class FontCheck
{
    public static void Run()
    {
        string name = System.Environment.GetEnvironmentVariable("FG_FONT") ?? "Jua-Regular";
        AssetDatabase.Refresh();
        var font = AssetDatabase.LoadAssetAtPath<Font>("Assets/Resources/Fonts/" + name + ".ttf");
        if (font == null) { Debug.Log("FONTCHECK font not found"); return; }
        var chars = new System.Collections.Generic.HashSet<char>();
        foreach (var f in Directory.GetFiles("Assets/Scripts", "*.cs"))
            foreach (Match m in Regex.Matches(File.ReadAllText(f), "\"((?:[^\"\\\n]|\\.)*)\""))
                foreach (char c in m.Groups[1].Value.Replace("\n", "")) chars.Add(c);
        var missing = new System.Text.StringBuilder();
        foreach (char c in chars) if (c > 127 && !font.HasCharacter(c)) missing.Append(c);
        Debug.Log("FONTCHECK missing=[" + missing + "] total=" + chars.Count);
    }
}
