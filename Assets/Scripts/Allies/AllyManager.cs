using UnityEngine;
using System.Collections.Generic;

public class AllyManager : MonoBehaviour
{
    [SerializeField] private int maxAllies = 6;
    private List<AllyData> recruitedAllies = new List<AllyData>();
    private List<AllyData> activeAllies = new List<AllyData>();

    private bool isInitialized;

    public void Initialize()
    {
        if (isInitialized) return;
        isInitialized = true;
        LoadAllies();
    }

    private void LoadAllies()
    {
        // Load starter allies from data
        AllyData starterAlly = new AllyData
        {
            name = "Soul Blade Warrior",
            rarity = AllyRarity.Legendary,
            level = 1,
            currentForm = TransformationForm.Base
        };
        recruitedAllies.Add(starterAlly);
    }

    public void RecruitAlly(AllyData allyData)
    {
        if (recruitedAllies.Count >= maxAllies)
        {
            Debug.Log("Ally roster is full!");
            return;
        }

        recruitedAllies.Add(allyData);
        Debug.Log($"Recruited: {allyData.name}");
    }

    public void SetActiveAllies(List<AllyData> allies)
    {
        if (allies.Count > 3)
        {
            Debug.LogWarning("Maximum 3 active allies allowed");
            return;
        }
        activeAllies = allies;
    }

    public List<AllyData> GetRecruitedAllies() => recruitedAllies;
    public List<AllyData> GetActiveAllies() => activeAllies;
}

public enum AllyRarity
{
    Common,
    Rare,
    Epic,
    Legendary,
    Mythic,
    Voidborn
}

public enum TransformationForm
{
    Base,
    Awakened,
    VoidCorrupted
}

[System.Serializable]
public class AllyData
{
    public string name;
    public AllyRarity rarity;
    public int level = 1;
    public int affinity = 0;
    public int affinity_max = 100;
    public float attack = 15f;
    public float defense = 10f;
    public float health = 80f;
    public TransformationForm currentForm = TransformationForm.Base;
    public int stars = 0; // 1-6 star rating
}
