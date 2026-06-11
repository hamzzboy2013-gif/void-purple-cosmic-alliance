using UnityEngine;

public class PlayerManager : MonoBehaviour
{
    [SerializeField] private PlayerStats playerStats;
    [SerializeField] private PlayerMovement playerMovement;
    [SerializeField] private PlayerCombat playerCombat;
    [SerializeField] private Animator playerAnimator;

    private bool isInitialized;

    public void Initialize()
    {
        if (isInitialized) return;

        playerStats.Initialize();
        playerMovement.Initialize(playerStats);
        playerCombat.Initialize(playerStats);
        isInitialized = true;

        Debug.Log("Player Manager Initialized");
    }

    public void EnableControls()
    {
        playerMovement.enabled = true;
        playerCombat.enabled = true;
        InputManager.Instance.EnableInput();
    }

    public void DisableControls()
    {
        playerMovement.enabled = false;
        playerCombat.enabled = false;
        InputManager.Instance.DisableInput();
    }

    public PlayerStats GetPlayerStats() => playerStats;
    public PlayerCombat GetPlayerCombat() => playerCombat;

    public void TakeDamage(float damage)
    {
        playerStats.TakeDamage(damage);
        if (playerStats.GetCurrentHealth() <= 0)
        {
            OnPlayerDeath();
        }
    }

    public void Heal(float amount)
    {
        playerStats.Heal(amount);
    }

    private void OnPlayerDeath()
    {
        Debug.Log("Player Defeated!");
        GameManager.Instance.SetGameState(GameManager.GameState.Pause);
    }
}
