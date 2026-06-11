using UnityEngine;

public class PlayerMovement : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 5f;
    [SerializeField] private float dashSpeed = 15f;
    [SerializeField] private float dashDuration = 0.3f;
    [SerializeField] private float dashCooldown = 1f;

    private Rigidbody rb;
    private PlayerStats playerStats;
    private Vector3 moveDirection;
    private bool isDashing;
    private float dashCooldownTimer;
    private Animator animator;

    public void Initialize(PlayerStats stats)
    {
        playerStats = stats;
        rb = GetComponent<Rigidbody>();
        animator = GetComponent<Animator>();

        InputManager.Instance.OnDashPressed += PerformDash;
    }

    private void Update()
    {
        if (!enabled) return;

        Vector2 input = InputManager.Instance.GetMovementInput();
        moveDirection = new Vector3(input.x, 0f, input.y).normalized;

        if (moveDirection != Vector3.zero)
        {
            animator.SetBool("IsMoving", true);
            transform.rotation = Quaternion.LookRotation(moveDirection);
        }
        else
        {
            animator.SetBool("IsMoving", false);
        }

        dashCooldownTimer -= Time.deltaTime;
    }

    private void FixedUpdate()
    {
        if (!enabled || isDashing) return;

        Vector3 velocity = moveDirection * moveSpeed;
        rb.velocity = new Vector3(velocity.x, rb.velocity.y, velocity.z);
    }

    private void PerformDash()
    {
        if (isDashing || dashCooldownTimer > 0f) return;

        StartCoroutine(DashCoroutine());
    }

    private System.Collections.IEnumerator DashCoroutine()
    {
        isDashing = true;
        animator.SetTrigger("Dash");
        float elapsedTime = 0f;

        Vector3 dashDirection = moveDirection != Vector3.zero ? moveDirection : transform.forward;

        while (elapsedTime < dashDuration)
        {
            rb.velocity = new Vector3(
                dashDirection.x * dashSpeed,
                rb.velocity.y,
                dashDirection.z * dashSpeed
            );
            elapsedTime += Time.fixedDeltaTime;
            yield return new WaitForFixedUpdate();
        }

        isDashing = false;
        dashCooldownTimer = dashCooldown;
    }
}
