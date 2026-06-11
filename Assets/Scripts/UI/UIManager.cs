using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class UIManager : MonoBehaviour
{
    [SerializeField] private GameObject hudCanvas;
    [SerializeField] private GameObject pauseMenuCanvas;
    [SerializeField] private GameObject combatUICanvas;
    [SerializeField] private GameObject dialogueUICanvas;
    [SerializeField] private TextMeshProUGUI playerHealthText;
    [SerializeField] private TextMeshProUGUI playerManaText;
    [SerializeField] private TextMeshProUGUI playerLevelText;
    [SerializeField] private Image healthBar;
    [SerializeField] private Image manaBar;
    [SerializeField] private Image ultimateBar;
    [SerializeField] private Slider ultimateSlider;

    private bool isInitialized;

    public void Initialize()
    {
        if (isInitialized) return;

        // Hook into player stats
        PlayerManager playerManager = GameManager.Instance.GetComponent<PlayerManager>();
        if (playerManager != null)
        {
            PlayerStats stats = playerManager.GetPlayerStats();
            stats.OnHealthChanged += UpdateHealthDisplay;
            stats.OnManaChanged += UpdateManaDisplay;
            stats.OnUltimateChargeChanged += UpdateUltimateDisplay;
            stats.OnLevelUp += UpdateLevelDisplay;
        }

        isInitialized = true;
    }

    public void ShowHUD()
    {
        hudCanvas.SetActive(true);
        pauseMenuCanvas.SetActive(false);
        combatUICanvas.SetActive(false);
    }

    public void ShowCombatUI()
    {
        combatUICanvas.SetActive(true);
        hudCanvas.SetActive(true);
    }

    public void ShowPauseMenu()
    {
        pauseMenuCanvas.SetActive(true);
    }

    public void ShowDialogueUI()
    {
        dialogueUICanvas.SetActive(true);
    }

    private void UpdateHealthDisplay(float currentHealth)
    {
        PlayerStats stats = GameManager.Instance.GetComponent<PlayerManager>().GetPlayerStats();
        float healthPercent = currentHealth / stats.GetMaxHealth();
        healthBar.fillAmount = healthPercent;
        playerHealthText.text = $"{currentHealth:F0}/{stats.GetMaxHealth():F0}";
    }

    private void UpdateManaDisplay(float currentMana)
    {
        PlayerStats stats = GameManager.Instance.GetComponent<PlayerManager>().GetPlayerStats();
        float manaPercent = currentMana / stats.GetMaxMana();
        manaBar.fillAmount = manaPercent;
        playerManaText.text = $"{currentMana:F0}/{stats.GetMaxMana():F0}";
    }

    private void UpdateUltimateDisplay(float charge)
    {
        ultimateSlider.value = charge / 100f;
    }

    private void UpdateLevelDisplay()
    {
        PlayerStats stats = GameManager.Instance.GetComponent<PlayerManager>().GetPlayerStats();
        playerLevelText.text = $"Lv. {stats.GetPlayerLevel()}";
    }
}
