using UnityEngine;
using System.Collections;

public class EnemyAI : MonoBehaviour
{
    [SerializeField] private float detectionRange = 15f;
    [SerializeField] private float attackRange = 2f;
    [SerializeField] private float attackCooldown = 2f;
    [SerializeField] private float patrolSpeed = 2f;
    [SerializeField] private float chaseSpeed = 5f;

    private EnemyManager enemyManager;
    private Transform playerTransform;
    private float attackCooldownTimer;
    private bool isChasing;
    private Rigidbody rb;
    private Animator animator;

    public enum AIState
    {
        Idle,
        Patrol,
        Chase,
        Attack
    }
    private AIState currentState = AIState.Idle;

    public void Initialize(EnemyManager manager)
    {
        enemyManager = manager;
        rb = GetComponent<Rigidbody>();
        animator = GetComponent<Animator>();
        playerTransform = GameObject.FindGameObjectWithTag("Player")?.transform;
    }

    private void Update()
    {
        if (playerTransform == null) return;

        float distanceToPlayer = Vector3.Distance(transform.position, playerTransform.position);
        attackCooldownTimer -= Time.deltaTime;

        if (distanceToPlayer <= detectionRange)
        {
            currentState = AIState.Chase;
            isChasing = true;
        }
        else if (isChasing && distanceToPlayer > detectionRange * 1.5f)
        {
            currentState = AIState.Patrol;
            isChasing = false;
        }

        switch (currentState)
        {
            case AIState.Chase:
                ChasePlayer(distanceToPlayer);
                break;
            case AIState.Attack:
                AttackPlayer();
                break;
            default:
                Patrol();
                break;
        }
    }

    private void ChasePlayer(float distance)
    {
        if (distance <= attackRange)
        {
            currentState = AIState.Attack;
            return;
        }

        Vector3 direction = (playerTransform.position - transform.position).normalized;
        transform.rotation = Quaternion.LookRotation(direction);
        rb.velocity = new Vector3(direction.x * chaseSpeed, rb.velocity.y, direction.z * chaseSpeed);
        animator.SetBool("IsMoving", true);
    }

    private void AttackPlayer()
    {
        animator.SetBool("IsMoving", false);

        if (attackCooldownTimer <= 0f)
        {
            animator.SetTrigger("Attack");
            attackCooldownTimer = attackCooldown;
        }
    }

    private void Patrol()
    {
        animator.SetBool("IsMoving", false);
        rb.velocity = Vector3.zero;
    }
}
