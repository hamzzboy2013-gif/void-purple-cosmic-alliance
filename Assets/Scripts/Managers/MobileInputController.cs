using UnityEngine;
using UnityEngine.UI;

public class MobileInputController : MonoBehaviour
{
    [SerializeField] private Joystick movementJoystick;
    [SerializeField] private Button attackButton;
    [SerializeField] private Button skill1Button;
    [SerializeField] private Button skill2Button;
    [SerializeField] private Button dashButton;
    [SerializeField] private Button ultimateButton;
    [SerializeField] private Button pauseButton;

    private void Start()
    {
        SetupButtonListeners();
    }

    private void SetupButtonListeners()
    {
        attackButton.onClick.AddListener(() => InputManager.Instance.OnAttackPressed?.Invoke());
        skill1Button.onClick.AddListener(() => InputManager.Instance.OnSkill1Pressed?.Invoke());
        skill2Button.onClick.AddListener(() => InputManager.Instance.OnSkill2Pressed?.Invoke());
        dashButton.onClick.AddListener(() => InputManager.Instance.OnDashPressed?.Invoke());
        ultimateButton.onClick.AddListener(() => InputManager.Instance.OnUltimatePressed?.Invoke());
        pauseButton.onClick.AddListener(() => InputManager.Instance.OnPausePressed?.Invoke());
    }
}
