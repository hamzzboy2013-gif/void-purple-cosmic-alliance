using UnityEngine;
using System.Collections.Generic;

public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    [SerializeField] private PlayerManager playerManager;
    [SerializeField] private AllyManager allyManager;
    [SerializeField] private CombatManager combatManager;
    [SerializeField] private ProgressionManager progressionManager;
    [SerializeField] private UIManager uiManager;

    private GameState currentGameState;

    public enum GameState
    {
        MainMenu,
        Exploration,
        Combat,
        Pause,
        DialogueEvent,
        RaidPrep,
        Loading
    }

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        DontDestroyOnLoad(gameObject);
        Initialize();
    }

    private void Initialize()
    {
        playerManager.Initialize();
        allyManager.Initialize();
        combatManager.Initialize();
        progressionManager.Initialize();
        uiManager.Initialize();

        SetGameState(GameState.Exploration);
        Debug.Log("Game Manager Initialized");
    }

    public void SetGameState(GameState newState)
    {
        if (currentGameState == newState) return;

        currentGameState = newState;
        Time.timeScale = (newState == GameState.Pause) ? 0f : 1f;

        switch (newState)
        {
            case GameState.Exploration:
                playerManager.EnableControls();
                uiManager.ShowHUD();
                break;
            case GameState.Combat:
                playerManager.DisableControls();
                combatManager.StartCombat();
                break;
            case GameState.Pause:
                uiManager.ShowPauseMenu();
                break;
            case GameState.DialogueEvent:
                playerManager.DisableControls();
                uiManager.ShowDialogueUI();
                break;
        }
    }

    public GameState GetGameState() => currentGameState;

    public void TriggerBossBattle(BossData bossData)
    {
        SetGameState(GameState.Combat);
        combatManager.InitializeBossBattle(bossData);
    }

    public void CompleteLevel()
    {
        progressionManager.CompleteCurrentLevel();
        SetGameState(GameState.Exploration);
    }
}
