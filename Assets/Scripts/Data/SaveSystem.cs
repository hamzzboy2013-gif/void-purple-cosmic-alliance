using UnityEngine;
using System.IO;

public class SaveSystem : MonoBehaviour
{
    public static string SAVE_PATH => Application.persistentDataPath + "/saves/";

    public static void SavePlayerData(PlayerSaveData data)
    {
        if (!Directory.Exists(SAVE_PATH))
        {
            Directory.CreateDirectory(SAVE_PATH);
        }

        string json = JsonUtility.ToJson(data, true);
        File.WriteAllText(SAVE_PATH + "player.json", json);
        Debug.Log("Player data saved.");
    }

    public static PlayerSaveData LoadPlayerData()
    {
        string path = SAVE_PATH + "player.json";
        if (File.Exists(path))
        {
            string json = File.ReadAllText(path);
            return JsonUtility.FromJson<PlayerSaveData>(json);
        }
        return new PlayerSaveData();
    }
}

[System.Serializable]
public class PlayerSaveData
{
    public int playerLevel = 1;
    public int playerExp = 0;
    public float currentHealth = 100f;
    public float currentMana = 100f;
    public int currentWorld = 0;
    public int currentLevel = 1;
}
