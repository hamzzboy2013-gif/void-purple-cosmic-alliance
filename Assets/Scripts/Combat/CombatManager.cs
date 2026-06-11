using UnityEngine;
using System.Collections.Generic;

public class CombatManager : MonoBehaviour
{
    [SerializeField] private Transform playerSpawnPoint;
    [SerializeField] private Transform enemySpawnPoint;
    [SerializeField] private UIManager uiManager;

    private bool isInitialized;
    private List<EnemyManager> activeEnemies = new List<EnemyManager>();
    private PlayerManager playerManager;
    private BossData currentBossData;

    public void Initialize()
    {
        if (isInitialized) return;
        isInitialized = true;
    }

    public void StartCombat()
    {
        playerManager = GameManager.Instance.GetComponent<PlayerManager>();
        if (playerManager == null) return;

        Debug.Log("Combat Started!");
        uiManager.ShowCombatUI();
    }

    public void InitializeBossBattle(BossData bossData)
    {
        currentBossData = bossData;
        Debug.Log($"Boss Battle Started: {bossData.bossName}");
        // Spawn boss enemy
    }

    public void OnEnemyDefeated(EnemyManager enemy)
    {
        activeEnemies.Remove(enemy);
        
        if (activeEnemies.Count == 0)
        {
            OnCombatVictory();
        }
    }

    private void OnCombatVictory()
    {
        Debug.Log("Combat Victory!");
        GameManager.Instance.CompleteLevel();
    }

    public void OnPlayerDefeated()
    {
        Debug.Log("Player Defeated in Combat!");
        // Show game over screen
    }
}
