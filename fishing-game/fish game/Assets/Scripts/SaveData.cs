using System;
using System.IO;
using UnityEngine;

// 저장 (GDD 8번 [확정]): 도감·가진 물고기·소지금·낚싯대 단계를 save.json 하나에 저장/불러오기.
// 시간대·미끼·위치는 저장하지 않는다. 불러오기는 시작할 때, 저장은 낚기·판매·구매 때와 끌 때(Application.quitting).
public static class SaveData
{
    [Serializable]
    class Data { public int[] collection, inventory; public int money, rod; }

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
            };
            string p = Path_, tmp = p + ".tmp";
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(p));
            File.WriteAllText(tmp, JsonUtility.ToJson(d));      // 먼저 임시 파일에 쓰고
            if (File.Exists(p)) File.Replace(tmp, p, null);       // 성공하면 바꿔치기 (쓰다 꺼져도 옛 저장은 남음)
            else File.Move(tmp, p);
        }
        catch (Exception e) { Debug.LogWarning("저장하지 못했어요: " + e.Message); }
    }

    public static void Load()
    {
        try
        {
            string p = Path_;
            if (!File.Exists(p)) return;
            var d = JsonUtility.FromJson<Data>(File.ReadAllText(p));
            if (d == null) return;
            CopyCounts(d.collection, Collection.Counts);
            CopyCounts(d.inventory, Inventory.Counts);
            Inventory.Money = Mathf.Max(0, d.money);
            RodUpgrade.Level = Mathf.Clamp(d.rod, 0, RodUpgrade.MaxLevel);
        }
        catch (Exception e) { Debug.LogWarning("save.json을 읽지 못해 새로 시작해요: " + e.Message); }
    }

    // 물고기 종류 수가 바뀐 저장 파일도 읽을 수 있게 짧은 쪽에 맞춰 복사, 음수는 0으로.
    static void CopyCounts(int[] src, int[] dst)
    {
        if (src == null) return;
        for (int i = 0; i < dst.Length && i < src.Length; i++) dst[i] = Mathf.Max(0, src[i]);
    }
}
