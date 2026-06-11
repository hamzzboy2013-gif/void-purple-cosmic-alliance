using UnityEngine;
using UnityEngine.InputSystem;

public class InputManager : MonoBehaviour
{
    public static InputManager Instance { get; private set; }

    private PlayerInput playerInput;
    private Vector2 movementInput;
    private Vector2 aimInput;

    public System.Action OnAttackPressed;
    public System.Action OnSkill1Pressed;
    public System.Action OnSkill2Pressed;
    public System.Action OnDashPressed;
    public System.Action OnUltimatePressed;
    public System.Action OnPausePressed;
    public System.Action OnInteractPressed;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        playerInput = GetComponent<PlayerInput>();
        SetupInputCallbacks();
    }

    private void SetupInputCallbacks()
    {
        var actions = playerInput.actions;

        actions["Move"].performed += ctx => movementInput = ctx.ReadValue<Vector2>();
        actions["Move"].canceled += ctx => movementInput = Vector2.zero;

        actions["Aim"].performed += ctx => aimInput = ctx.ReadValue<Vector2>();
        actions["Aim"].canceled += ctx => aimInput = Vector2.zero;

        actions["Attack"].started += ctx => OnAttackPressed?.Invoke();
        actions["Skill1"].started += ctx => OnSkill1Pressed?.Invoke();
        actions["Skill2"].started += ctx => OnSkill2Pressed?.Invoke();
        actions["Dash"].started += ctx => OnDashPressed?.Invoke();
        actions["Ultimate"].started += ctx => OnUltimatePressed?.Invoke();
        actions["Pause"].started += ctx => OnPausePressed?.Invoke();
        actions["Interact"].started += ctx => OnInteractPressed?.Invoke();
    }

    public Vector2 GetMovementInput() => movementInput;
    public Vector2 GetAimInput() => aimInput;

    public void EnableInput() => playerInput.enabled = true;
    public void DisableInput() => playerInput.enabled = false;
}
