using UnityEngine;

public class ProgressionManager : MonoBehaviour
{
    [SerializeField] private WorldData[] worlds;
    private int currentWorldIndex = 0;
    private int currentLevelInWorld = 1;

    private bool isInitialized;

    public void Initialize()
    {
        if (isInitialized) return;
        isInitialized = true;
        LoadProgressionData();
    }

    private void LoadProgressionData()
    {
        // Load from PlayerPrefs or database
        currentWorldIndex = PlayerPrefs.GetInt("CurrentWorld", 0);
        currentLevelInWorld = PlayerPrefs.GetInt("CurrentLevel", 1);
    }

    public void CompleteCurrentLevel()
    {
        currentLevelInWorld++;

        if (currentLevelInWorld > 5)
        {
            UnlockNextWorld();
        }

        SaveProgressionData();
    }

    private void UnlockNextWorld()
    {
        if (currentWorldIndex < worlds.Length - 1)
        {
            currentWorldIndex++;
            currentLevelInWorld = 1;
            Debug.Log($"World {currentWorldIndex + 1} Unlocked!");
        }
    }

    private void SaveProgressionData()
    {
        PlayerPrefs.SetInt("CurrentWorld", currentWorldIndex);
        PlayerPrefs.SetInt("CurrentLevel", currentLevelInWorld);
        PlayerPrefs.Save();
    }

    public WorldData GetCurrentWorld() => worlds[currentWorldIndex];
    public int GetCurrentWorldIndex() => currentWorldIndex;
    public int GetCurrentLevel() => currentLevelInWorld;
}

[System.Serializable]
public class WorldData
{
    public string worldName;
    public string theme;
    public BossData bossBattle;
    public int requiredPlayerLevel = 1;
}

[System.Serializable]
public class BossData
{
    public string bossName;
    public float maxHealth = 200f;
    public float attack = 25f;
    public float defense = 15f;
    public int level = 10;
    public int expReward = 500;
}

[System.Serializable]
public class EnemyData
{
    public string enemyName;
    public float maxHealth = 30f;
    public float attack = 8f;
    public float defense = 3f;
    public int level = 1;
    public int expReward = 50;
}
