using UnityEngine;

public class EnemyStats : MonoBehaviour
{
    private float maxHealth;
    private float currentHealth;
    private float attack;
    private float defense;
    private string enemyName;
    private int level;
    private int expReward;
    private EnemyData enemyData;

    public void Initialize(EnemyData data)
    {
        enemyData = data;
        maxHealth = data.maxHealth;
        currentHealth = maxHealth;
        attack = data.attack;
        defense = data.defense;
        enemyName = data.enemyName;
        level = data.level;
        expReward = data.expReward;
    }

    public void TakeDamage(float damage)
    {
        float actualDamage = Mathf.Max(1f, damage - (defense * 0.1f));
        currentHealth -= actualDamage;
    }

    public float GetCurrentHealth() => currentHealth;
    public float GetMaxHealth() => maxHealth;
    public float GetAttack() => attack;
    public float GetDefense() => defense;
    public string GetEnemyName() => enemyName;
    public int GetLevel() => level;
    public int GetExpReward() => expReward;
    public bool IsAlive() => currentHealth > 0f;
}
