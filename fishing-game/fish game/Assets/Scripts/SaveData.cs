using System;
using System.IO;
using UnityEngine;

// 저장 (GDD 8번 [확정]): 도감·가진 물고기·소지금·낚싯대 단계·오늘의 목표 진행을 save.json 하나(웹은 브라우저 저장소)에 저장/불러오기.
// 시간대·미끼·위치는 저장하지 않는다. 불러오기는 시작할 때, 저장은 낚기·판매·구매 때와 끌 때(Application.quitting; 웹은 탭을 닫아도 불리지 않으므로 이벤트 저장이 전부).
public static class SaveData
{
    [Serializable]
    class Data { public int[] collection, inventory; public int money, rod, goal; }

    public static string FilePath; // 비어 있으면 기본 위치(게임 데이터 폴더). 시험할 때 다른 파일로 바꿔 쓴다.

    static string Path_
    {
        get { return string.IsNullOrEmpty(FilePath) ? System.IO.Path.Combine(Application.persistentDataPath, "save.json") : FilePath; }
    }

    // 저장 기록(Reset)이 먼저 지워진 뒤, 첫 장면이 열리기 전에 불러온다.
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Init()
    {
        Load();
        Application.quitting -= Save;
        Application.quitting += Save;
    }

    public static void Save()
    {
        try
        {
            var d = new Data
            {
                collection = (int[])Collection.Counts.Clone(),
                inventory = (int[])Inventory.Counts.Clone(),
                money = Inventory.Money,
                rod = RodUpgrade.Level,
                goal = Goal.Progress,
            };
            Write(JsonUtility.ToJson(d));
        }
        catch (Exception e) { Debug.LogWarning("저장하지 못했어요: " + e.Message); }
    }

    public static void Load()
    {
        try
        {
            string json = Read();
            if (json == null) return;
            var d = JsonUtility.FromJson<Data>(json);
            if (d == null) return;
            CopyCounts(d.collection, Collection.Counts);
            CopyCounts(d.inventory, Inventory.Counts);
            Inventory.Money = Mathf.Max(0, d.money);
            RodUpgrade.Level = Mathf.Clamp(d.rod, 0, RodUpgrade.MaxLevel);
            Goal.Progress = Mathf.Clamp(d.goal, 0, Goal.Target - 1);
        }
        catch (Exception e) { Debug.LogWarning("save.json을 읽지 못해 새로 시작해요: " + e.Message); }
    }

    // 저장 위치: 웹(WebGL)에서는 컴퓨터 파일을 못 쓰므로 브라우저 저장소(PlayerPrefs), 그 밖에는 save.json 파일.
#if UNITY_WEBGL && !UNITY_EDITOR
    const string PrefsKey = "fishing_save";
    static void Write(string json) { PlayerPrefs.SetString(PrefsKey, json); PlayerPrefs.Save(); }
    static string Read() { return PlayerPrefs.HasKey(PrefsKey) ? PlayerPrefs.GetString(PrefsKey) : null; }
#else
    static void Write(string json)
    {
        string p = Path_, tmp = p + ".tmp";
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(p));
        File.WriteAllText(tmp, json);                           // 먼저 임시 파일에 쓰고
        if (File.Exists(p)) File.Replace(tmp, p, null);          // 성공하면 바꿔치기 (쓰다 꺼져도 옛 저장은 남음)
        else File.Move(tmp, p);
    }

    static string Read() { string p = Path_; return File.Exists(p) ? File.ReadAllText(p) : null; }
#endif

    // 물고기 종류 수가 바뀐 저장 파일도 읽을 수 있게 짧은 쪽에 맞춰 복사, 음수는 0으로.
    static void CopyCounts(int[] src, int[] dst)
    {
        if (src == null) return;
        for (int i = 0; i < dst.Length && i < src.Length; i++) dst[i] = Mathf.Max(0, src[i]);
    }
}
