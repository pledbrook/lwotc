//---------------------------------------------------------------------------------------
//  FILE:    X2LWModTemplate_SkirmisherAbilities.uc
//  AUTHOR:  Peter Ledbrook
//  PURPOSE: Modifies existing ability templates related to Skirmisher soldiers.
//---------------------------------------------------------------------------------------
class X2LWModTemplate_SkirmisherAbilities extends X2LWTemplateModTemplate config(LW_FactionBalance);

var config int SKIRMISHER_INTERRUPT_COOLDOWN;
var config int JUSTICE_COOLDOWN;
var config int JUSTICE_IENVIRONMENT_DAMAGE;
var config int WRATH_COOLDOWN;	
var config int WHIPLASH_COOLDOWN;
var config int WHIPLASH_ACTION_POINT_COST;
var config int FULL_THROTTLE_DURATION;
var config int BATTLELORD_ACTION_POINT_COST;
var config int BATTLELORD_COOLDOWN;

static function UpdateAbilities(X2AbilityTemplate Template, int Difficulty)
{
	switch (Template.DataName)
	{
	case 'SkirmisherReflex':
		Template.AdditionalAbilities.AddItem('SkirmisherReflexTrigger');
		break;
	case 'JudgmentTrigger':
		ModifyJudgementPanicChanceFunction(Template);
		break;
	case 'FullThrottle':
		ModifyFullThrottleDuration(Template);
		break;
	case 'Whiplash':
		ModifyWhiplash(Template);
		break;
	case 'SkirmisherInterruptInput':
		AddCooldownToInterrupt(Template);
		break;
	case 'SkirmisherGrapple':
		AddParkourSupportToGrapple(Template);
		break;
	// Justice and Wrath cooldowns are hard coded in vanilla.
	case 'Justice':
		Template.AbilityCooldown.iNumTurns = default.JUSTICE_COOLDOWN;
		ReduceJusticeEnvironmentDamage(Template);
		break;
	case 'SkirmisherVengeance':
		Template.AbilityCooldown.iNumTurns = default.WRATH_COOLDOWN;
		break;
	case 'Battlelord':
		AddCooldownToBattlelord(Template);
		break;
	}
}

static function ModifyJudgementPanicChanceFunction(X2AbilityTemplate Template)
{
	local X2Effect CurrentEffect;

	foreach Template.AbilityTargetEffects(CurrentEffect)
	{
		if (X2Effect_Panicked(CurrentEffect) != none)
		{
			CurrentEffect.ApplyChanceFn = JudgementApplyChance;
		}
	}
}

// Copied and modified from X2Ability_SkirmisherAbilitySet
//
// Replaces the configurable JUDGMENT_APPLYCHANCEATTACKVAL bonus to panic
// chance with Skirmisher's current will and an extra bonus based on the
// current tier of armor.
static function name JudgementApplyChance(
	const out EffectAppliedData ApplyEffectParameters,
	XComGameState_BaseObject kNewTargetState,
	XComGameState NewGameState)
{
	//  this mimics the panic hit roll without actually BEING the panic hit roll
	local XComGameState_Unit TargetUnit, SourceUnit;
	local name ImmuneName;
	local int AttackVal, DefendVal, TargetRoll, RandRoll;

	TargetUnit = XComGameState_Unit(kNewTargetState);
	if( TargetUnit != none )
	{
		foreach class'X2AbilityToHitCalc_PanicCheck'.default.PanicImmunityAbilities(ImmuneName)
		{
			if( TargetUnit.FindAbility(ImmuneName).ObjectID != 0 )
			{
				return 'AA_UnitIsImmune';
			}
		}

		// LWOTC: Base the attack roll on current will.
		SourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
		AttackVal = SourceUnit.GetCurrentStat(eStat_Will) + class'X2Ability_SkirmisherAbilitySet'.default.JUDGMENT_APPLYCHANCEATTACKVAL;

		DefendVal = TargetUnit.GetCurrentStat(eStat_Will);
		TargetRoll = class'X2AbilityToHitCalc_PanicCheck'.default.BaseValue + AttackVal - DefendVal;
		TargetRoll = Clamp(TargetRoll, class'X2Ability_SkirmisherAbilitySet'.default.JUDGMENT_MINCHANCE, class'X2Ability_SkirmisherAbilitySet'.default.JUDGMENT_MAXCHANCE);
		RandRoll = `SYNC_RAND_STATIC(100);
		if( RandRoll < TargetRoll )
			return 'AA_Success';
	}

	return 'AA_EffectChanceFailed';
}

// Allow Full Throttle bonus mobility to apply for longer than the
// turn it activates.
static function ModifyFullThrottleDuration(X2AbilityTemplate Template)
{
	local X2Effect CurrentEffect;
	local X2Effect_PersistentStatChange FullThrottleEffect;

	foreach Template.AbilityTargetEffects(CurrentEffect)
	{
		FullThrottleEffect = X2Effect_PersistentStatChange(CurrentEffect);
		if (FullThrottleEffect != none && FullThrottleEffect.EffectName == 'FullThrottleStats')
		{
			FullThrottleEffect.iNumTurns = default.FULL_THROTTLE_DURATION;
		}
	}
}

// Makes Whiplash cost 1 action point and makes the damage scale
// with Ripjack tech.
static function ModifyWhiplash(X2AbilityTemplate Template)
{
	local X2AbilityToHitCalc_StandardAim	ToHitCalc;
	local X2Effect_ApplyWeaponDamage		WeaponDamageEffect;
	local X2Condition_UnitProperty			UnitPropertyCondition;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2AbilityCooldown					Cooldown;

	local int i;

	// Kill the charges and the charge cost
	Template.AbilityCosts.Length = 0;
	Template.AbilityCharges = none;

	// Killing the above results in some collateral damage so we have to re-add the action point costs
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = default.WHIPLASH_ACTION_POINT_COST;
	ActionPointCost.bFreeCost = false;
	Template.AbilityCosts.AddItem(ActionPointCost);

	// And finally we take the cooldowns from our config file and apply them here
	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.WHIPLASH_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	// Give Whiplash same aim bonus as Justice and Wrath. Also disable crit
	// like with those two abilities.
	ToHitCalc = X2AbilityToHitCalc_StandardAim(Template.AbilityToHitCalc);
	ToHitCalc.bAllowCrit = false;

	// Use weapon damage and aim bonus from secondary weapon (unless the ability
	// is explicitly bound to a different inventory slot).
	Template.DefaultSourceItemSlot = eInvSlot_SecondaryWeapon;

	// Remove the existing damage effects for Whiplash, because we're going to replace them.
	for (i = Template.AbilityTargetEffects.Length - 1; i >= 0 ; i--)
	{
		if (X2Effect_ApplyWeaponDamage(Template.AbilityTargetEffects[i]) != none)
		{
			Template.AbilityTargetEffects.Remove(i, 1);
		}
	}

	// Configure the damage for non-robotic targets.
	WeaponDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	WeaponDamageEffect.bIgnoreArmor = true;
	WeaponDamageEffect.bIgnoreBaseDamage = true;
	WeaponDamageEffect.DamageTag = 'Whiplash';
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.ExcludeOrganic = false;
	WeaponDamageEffect.TargetConditions.AddItem(UnitPropertyCondition);
	Template.AddTargetEffect(WeaponDamageEffect);

	// Configure the damage for robotic targets (higher damage than for organics).
	WeaponDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	WeaponDamageEffect.bIgnoreArmor = true;
	WeaponDamageEffect.bIgnoreBaseDamage = true;
	WeaponDamageEffect.DamageTag = 'Whiplash_Robotic';
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeRobotic = false;
	UnitPropertyCondition.ExcludeOrganic = true;
	WeaponDamageEffect.TargetConditions.AddItem(UnitPropertyCondition);
	Template.AddTargetEffect(WeaponDamageEffect);
}

static function AddCooldownToInterrupt(X2AbilityTemplate Template)
{
	local X2AbilityCost_ActionPoints	ActionPointCost;
	local X2AbilityCooldown				Cooldown;

	// Kill the charges and the charge cost
	Template.AbilityCosts.Length = 0;
	Template.AbilityCharges = none;

	// Killing the above results in some collateral damage so we have to re-add the action point costs
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 0;
	ActionPointCost.bFreeCost = true;
	ActionPointCost.DoNotConsumeAllEffects.Length = 0;
	ActionPointCost.DoNotConsumeAllSoldierAbilities.Length = 0;
	ActionPointCost.AllowedTypes.RemoveItem(class'X2CharacterTemplateManager'.default.SkirmisherInterruptActionPoint);
	Template.AbilityCosts.AddItem(ActionPointCost);

	// And finally we take the cooldowns from our config file and apply them here
	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.SKIRMISHER_INTERRUPT_COOLDOWN;
	Template.AbilityCooldown = Cooldown;
}

static function AddParkourSupportToGrapple(X2AbilityTemplate Template)
{
	local X2AbilityCooldown_Grapple Cooldown;

	// Kill the default cooldown
	Template.AbilityCooldown = none;

	// Have the ability check our custom X2AbilityCooldown_Grapple file to get its cooldown time
	Cooldown = new class'X2AbilityCooldown_Grapple';
	Template.AbilityCooldown = Cooldown;
}

// Reduces Justice's environmental damage so that it doesn't destroy
// quite so much enemy cover when it misses.
static function ReduceJusticeEnvironmentDamage(X2AbilityTemplate Template)
{
	local X2Effect_ApplyWeaponDamage WeaponDamageEffect;
	local int i;

	// Update Justice's environment damage value on the Apply Weapon Damage effect
	for (i = 0; i < Template.AbilityTargetEffects.Length; i++)
	{
		WeaponDamageEffect = X2Effect_ApplyWeaponDamage(Template.AbilityTargetEffects[i]);
		if (WeaponDamageEffect != none)
		{
			WeaponDamageEffect.EnvironmentalDamageAmount = default.JUSTICE_IENVIRONMENT_DAMAGE;
		}
	}

}

// Removes Battlelord charges, replacing them with a cooldown.
static function AddCooldownToBattlelord(X2AbilityTemplate Template)
{
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2AbilityCooldown					Cooldown;

	// Kill the charges and the charge cost
	Template.AbilityCosts.Length = 0;
	Template.AbilityCharges = none;

	// Killing the above results in some collateral damage so we have to re-add the action point costs
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = default.BATTLELORD_ACTION_POINT_COST;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.AllowedTypes.RemoveItem(class'X2CharacterTemplateManager'.default.SkirmisherInterruptActionPoint);
	Template.AbilityCosts.AddItem(ActionPointCost);

	// And finally we take the cooldowns from our config file and apply them here
	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.BATTLELORD_COOLDOWN;
	Template.AbilityCooldown = Cooldown;
}

defaultproperties
{
	AbilityTemplateModFn=UpdateAbilities
}
