using UnityEngine;

public class EnemyManager : MonoBehaviour
{
    [SerializeField] private EnemyStats enemyStats;
    [SerializeField] private EnemyAI enemyAI;
    [SerializeField] private Animator animator;
    [SerializeField] private CombatManager combatManager;

    private bool isInitialized;

    public void Initialize(EnemyData enemyData)
    {
        if (isInitialized) return;

        enemyStats.Initialize(enemyData);
        enemyAI.Initialize(this);
        isInitialized = true;
    }

    public void TakeDamage(float damage)
    {
        enemyStats.TakeDamage(damage);

        if (enemyStats.GetCurrentHealth() <= 0)
        {
            OnEnemyDefeated();
        }
    }

    public void PerformAttack(float damage)
    {
        // Attack animation and logic
        animator.SetTrigger("Attack");
    }

    private void OnEnemyDefeated()
    {
        Debug.Log($"Enemy Defeated: {enemyStats.GetEnemyName()}");
        animator.SetTrigger("Death");
        combatManager.OnEnemyDefeated(this);
        Destroy(gameObject, 2f);
    }

    public EnemyStats GetEnemyStats() => enemyStats;
    public EnemyAI GetEnemyAI() => enemyAI;
}
