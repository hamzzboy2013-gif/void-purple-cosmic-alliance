using UnityEngine;
using System.Collections;

public class PlayerCombat : MonoBehaviour
{
    [SerializeField] private float basicAttackDamage = 10f;
    [SerializeField] private float basicAttackCooldown = 0.5f;
    [SerializeField] private float skill1Damage = 20f;
    [SerializeField] private float skill1ManaCost = 30f;
    [SerializeField] private float skill1Cooldown = 3f;
    [SerializeField] private float skill2Damage = 25f;
    [SerializeField] private float skill2ManaCost = 40f;
    [SerializeField] private float skill2Cooldown = 4f;
    [SerializeField] private float ultimateDamage = 50f;
    [SerializeField] private float ultimateChargePerHit = 15f;

    private PlayerStats playerStats;
    private Animator animator;
    private float basicAttackCooldownTimer;
    private float skill1CooldownTimer;
    private float skill2CooldownTimer;
    private bool isAttacking;

    public System.Action OnAttackHit;
    public System.Action OnSkillCast;
    public System.Action OnUltimateActivated;

    public void Initialize(PlayerStats stats)
    {
        playerStats = stats;
        animator = GetComponent<Animator>();

        InputManager.Instance.OnAttackPressed += PerformBasicAttack;
        InputManager.Instance.OnSkill1Pressed += CastSkill1;
        InputManager.Instance.OnSkill2Pressed += CastSkill2;
        InputManager.Instance.OnUltimatePressed += ActivateUltimate;
    }

    private void Update()
    {
        if (!enabled) return;

        basicAttackCooldownTimer -= Time.deltaTime;
        skill1CooldownTimer -= Time.deltaTime;
        skill2CooldownTimer -= Time.deltaTime;
    }

    private void PerformBasicAttack()
    {
        if (basicAttackCooldownTimer > 0f || isAttacking) return;

        isAttacking = true;
        animator.SetTrigger("Attack");
        basicAttackCooldownTimer = basicAttackCooldown;
        playerStats.ChargeUltimate(ultimateChargePerHit);
        OnAttackHit?.Invoke();

        StartCoroutine(DealDamageCoroutine(basicAttackDamage, 0.3f));
    }

    private void CastSkill1()
    {
        if (skill1CooldownTimer > 0f || !playerStats.CanCastSkill(skill1ManaCost) || isAttacking) return;

        isAttacking = true;
        animator.SetTrigger("Skill1");
        playerStats.UseMana(skill1ManaCost);
        skill1CooldownTimer = skill1Cooldown;
        playerStats.ChargeUltimate(ultimateChargePerHit * 2f);
        OnSkillCast?.Invoke();

        StartCoroutine(DealDamageCoroutine(skill1Damage, 0.4f));
    }

    private void CastSkill2()
    {
        if (skill2CooldownTimer > 0f || !playerStats.CanCastSkill(skill2ManaCost) || isAttacking) return;

        isAttacking = true;
        animator.SetTrigger("Skill2");
        playerStats.UseMana(skill2ManaCost);
        skill2CooldownTimer = skill2Cooldown;
        playerStats.ChargeUltimate(ultimateChargePerHit * 2.5f);
        OnSkillCast?.Invoke();

        StartCoroutine(DealDamageCoroutine(skill2Damage, 0.5f));
    }

    private void ActivateUltimate()
    {
        if (playerStats.GetUltimateCharge() < 100f || isAttacking) return;

        isAttacking = true;
        animator.SetTrigger("Ultimate");
        playerStats.ResetUltimateCharge();
        OnUltimateActivated?.Invoke();

        StartCoroutine(VoidAwakeningCoroutine());
    }

    private IEnumerator DealDamageCoroutine(float damage, float delay)
    {
        yield return new WaitForSeconds(delay);
        isAttacking = false;
    }

    private IEnumerator VoidAwakeningCoroutine()
    {
        // Apply VOID AWAKENING effects
        float originalSpeed = playerStats.GetAttackSpeed();
        
        // Temporary stat boost
        animator.SetBool("VoidAwakening", true);

        // Deal ultimate damage
        yield return new WaitForSeconds(0.6f);
        
        animator.SetBool("VoidAwakening", false);
        isAttacking = false;
    }

    public float GetBasicAttackCooldownRemaining() => Mathf.Max(0f, basicAttackCooldownTimer);
    public float GetSkill1CooldownRemaining() => Mathf.Max(0f, skill1CooldownTimer);
    public float GetSkill2CooldownRemaining() => Mathf.Max(0f, skill2CooldownTimer);
}
