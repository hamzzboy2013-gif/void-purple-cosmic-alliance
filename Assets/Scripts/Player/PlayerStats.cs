using UnityEngine;

public class PlayerStats : MonoBehaviour
{
    [SerializeField] private float maxHealth = 100f;
    [SerializeField] private float maxMana = 100f;
    [SerializeField] private float attack = 15f;
    [SerializeField] private float defense = 10f;
    [SerializeField] private float attackSpeed = 1f;

    private float currentHealth;
    private float currentMana;
    private float ultimateCharge;
    private int playerLevel = 1;
    private int playerExp = 0;
    private int expToLevelUp = 1000;

    public enum VoidRank
    {
        F, E, D, C, B, A, S, SS, Cosmic
    }
    private VoidRank voidRank = VoidRank.F;

    public System.Action<float> OnHealthChanged;
    public System.Action<float> OnManaChanged;
    public System.Action<float> OnUltimateChargeChanged;
    public System.Action OnLevelUp;

    public void Initialize()
    {
        currentHealth = maxHealth;
        currentMana = maxMana;
        ultimateCharge = 0f;
    }

    public void TakeDamage(float damage)
    {
        float actualDamage = Mathf.Max(1f, damage - (defense * 0.1f));
        currentHealth -= actualDamage;
        OnHealthChanged?.Invoke(currentHealth);
    }

    public void Heal(float amount)
    {
        currentHealth = Mathf.Min(maxHealth, currentHealth + amount);
        OnHealthChanged?.Invoke(currentHealth);
    }

    public void UseMana(float amount)
    {
        currentMana = Mathf.Max(0f, currentMana - amount);
        OnManaChanged?.Invoke(currentMana);
    }

    public void RegenerateMana(float amount)
    {
        currentMana = Mathf.Min(maxMana, currentMana + amount);
        OnManaChanged?.Invoke(currentMana);
    }

    public void ChargeUltimate(float amount)
    {
        ultimateCharge = Mathf.Min(100f, ultimateCharge + amount);
        OnUltimateChargeChanged?.Invoke(ultimateCharge);
    }

    public void ResetUltimateCharge()
    {
        ultimateCharge = 0f;
        OnUltimateChargeChanged?.Invoke(ultimateCharge);
    }

    public void GainExperience(int exp)
    {
        playerExp += exp;
        if (playerExp >= expToLevelUp)
        {
            LevelUp();
        }
    }

    private void LevelUp()
    {
        playerLevel++;
        playerExp = 0;
        maxHealth += 10f;
        maxMana += 10f;
        attack += 3f;
        defense += 2f;
        currentHealth = maxHealth;
        currentMana = maxMana;
        OnLevelUp?.Invoke();
        Debug.Log($"Level Up! Now Level {playerLevel}");
    }

    public float GetCurrentHealth() => currentHealth;
    public float GetMaxHealth() => maxHealth;
    public float GetCurrentMana() => currentMana;
    public float GetMaxMana() => maxMana;
    public float GetUltimateCharge() => ultimateCharge;
    public float GetAttack() => attack;
    public float GetDefense() => defense;
    public float GetAttackSpeed() => attackSpeed;
    public int GetPlayerLevel() => playerLevel;
    public int GetPlayerExp() => playerExp;
    public VoidRank GetVoidRank() => voidRank;

    public bool CanCastSkill(float manaCost) => currentMana >= manaCost;
    public bool IsAlive() => currentHealth > 0f;
}
