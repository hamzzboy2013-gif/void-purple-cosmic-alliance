using UnityEngine;
using System.Collections.Generic;

public class DataManager : MonoBehaviour
{
    public static DataManager Instance { get; private set; }

    [SerializeField] private List<AllyDatabase> allyDatabase;
    [SerializeField] private List<EnemyDatabase> enemyDatabase;
    [SerializeField] private List<WorldData> worldDatabase;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    public AllyDatabase GetAllyData(string allyName)
    {
        return allyDatabase.Find(a => a.name == allyName);
    }

    public EnemyDatabase GetEnemyData(string enemyName)
    {
        return enemyDatabase.Find(e => e.name == enemyName);
    }

    public WorldData GetWorldData(int worldIndex)
    {
        return worldIndex >= 0 && worldIndex < worldDatabase.Count ? worldDatabase[worldIndex] : null;
    }
}

[System.Serializable]
public class AllyDatabase
{
    public string name;
    public string description;
    public AllyRarity rarity;
    public Sprite artwork;
    public List<SkillData> skills;
}

[System.Serializable]
public class EnemyDatabase
{
    public string name;
    public string description;
    public int level;
    public float maxHealth;
    public float attack;
    public float defense;
    public int expReward;
}

[System.Serializable]
public class SkillData
{
    public string skillName;
    public float damage;
    public float manaCost;
    public float cooldown;
    public string description;
}
