//---------------------------------------------------------------------------------------
//  FILE:    X2Ability_LW_AssaultAbilitySet.uc
//  AUTHOR:  Amineri (Pavonis Interactive)
//  PURPOSE: Defines all Long War Assault-specific abilities
//---------------------------------------------------------------------------------------

class X2Ability_LW_AssaultAbilitySet extends X2Ability config(LW_SoldierSkills);

var config int EMPULSER_HACK_DEFENSE_CHANGE;
var config int STUN_COOLDOWN;

var config int STREET_SWEEPER2_MIN_ACTION_REQ;
var config int STREET_SWEEPER2_AMMO_COST;
var config int STREET_SWEEPER2_COOLDOWN;
var config int STREET_SWEEPER2_CONE_LENGTH;
var config int STREET_SWEEPER2_TILE_WIDTH;
var config float STREET_SWEEPER2_UNARMORED_DAMAGE_MULTIPLIER;
var config int STREET_SWEEPER2_UNARMORED_DAMAGE_BONUS;

var config int CHAIN_LIGHTNING_COOLDOWN;
var config int CHAIN_LIGHTNING_MIN_ACTION_REQ;
var config int CHAIN_LIGHTNING_AIM_MOD;
var config int CHAIN_LIGHTNING_TARGETS;


static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	`Log("LW_AssaultAbilitySet.CreateTemplates --------------------------------");
	
	Templates.AddItem(AddArcthrowerStun());
	Templates.AddItem(AddArcthrowerPassive());
	Templates.AddItem(AddEMPulser());
	Templates.AddItem(PurePassive('EMPulserPassive', "img:///UILibrary_LW_Overhaul.LW_AbilityEMPulser", true));  
	Templates.AddItem(StunGunner());
	Templates.AddItem(PurePassive('Electroshock', "img:///UILibrary_LW_Overhaul.LW_AbilityElectroshock", true));  
	Templates.AddItem(CreateStreetSweeper2Ability());
	Templates.AddItem(CreateStreetSweeperBonusDamageAbility());
	Templates.AddItem(CreateChainLightningAbility());
	//Focus ability for the Chain lightning ability
	Templates.AddItem(CreateCLFocus('CLFocus',default.CHAIN_LIGHTNING_TARGETS));
	
	return Templates;
}


//Basic stun attack, which increases stun duration based on tech level
static function X2AbilityTemplate AddArcthrowerStun()
{

	local X2AbilityCooldown                 Cooldown;
	local X2AbilityTemplate                 Template;	
	local X2Condition_UnitProperty			UnitPropertyCondition;
	local X2AbilityToHitCalc_StandardAim    ToHitCalc;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2Effect_ArcthrowerStunned	    StunnedEffect;
	local array<name>                       SkipExclusions;
	local X2Condition_UnitType				ImmuneUnitCondition;
	//local X2Effect_RemoveEffects			CleanUpEffect;

	// Macro to do localisation and stuffs
	`CREATE_X2ABILITY_TEMPLATE(Template, 'ArcthrowerStun');

	// Icon Properties
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityArcthrowerStun";  
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.STANDARD_PISTOL_SHOT_PRIORITY;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.DisplayTargetHitChance = true;
	Template.AbilitySourceName = 'eAbilitySource_Perk';                                       // color of the icon

	// Activated by a button press; additionally, tells the AI this is an activatable
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	// *** VALIDITY CHECKS *** //
	SkipExclusions.AddItem(class'X2AbilityTemplateManager'.default.DisorientedName);
	Template.AddShooterEffectExclusions(SkipExclusions);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.STUN_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	// Targeting Details
	// Can only shoot visible enemies
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	// Can't target dead; Can't target friendlies -- must be enemy organic
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.ExcludeOrganic = false;
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.RequireWithinRange = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	
	ImmuneUnitCondition = new class'X2Condition_UnitType';
	ImmuneUnitCondition.ExcludeTypes.AddItem('PsiZombie');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM2');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM3');
	Template.AbilityTargetConditions.AddItem(ImmuneUnitCondition);

	// Can't shoot while dead
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	// Only at single targets that are in range.
	Template.AbilityTargetStyle = default.SimpleSingleTarget;

	// Action Point
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.DoNotConsumeAllSoldierAbilities.AddItem('Unlimitedpower_LW');
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);	

	//Stun Effect
	StunnedEffect = CreateArcthrowerStunnedStatusEffect(100);
	Template.AddTargetEffect(StunnedEffect);

	//CleanUpEffect = CreateStunnedEffectsCleanUpEffect();
	//Template.AddTargetEffect(CleanUpEffect);

	Template.AssociatedPassives.AddItem('Electroshock');
	Template.AddTargetEffect(ElectroshockDisorientEffect());

	// Hit Calculation (Different weapons now have different calculations for range)
	ToHitCalc = new class'X2AbilityToHitCalc_StandardAim';
	ToHitCalc.bGuaranteedHit = false;
	ToHitCalc.bAllowCrit = false;
	Template.AbilityToHitCalc = ToHitCalc;
	Template.AbilityToHitOwnerOnMissCalc = ToHitCalc;
			
	// Targeting Method
	Template.TargetingMethod = class'X2TargetingMethod_OverTheShoulder';
	Template.bUsesFiringCamera = true;
	Template.CinescriptCameraType = "StandardGunFiring";
	Template.ActivationSpeech = 'StunTarget';

	// MAKE IT LIVE!
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;	
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	
	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	Template.AdditionalAbilities.AddItem('ArcthrowerPassive');

	return Template;	
}


static function X2Effect_RemoveEffects CreateStunnedEffectsCleanUpEffect()
{
	local X2Effect_RemoveEffects RemoveEffects;

	RemoveEffects = new class'X2Effect_RemoveEffects';
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2AbilityTemplateManager'.default.DisorientedName);
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2AbilityTemplateManager'.default.ConfusedName);
	RemoveEffects.EffectNamesToRemove.AddItem(class'X2AbilityTemplateManager'.default.PanickedName);
	RemoveEffects.EffectNamesToRemove.AddItem('MindControl');
	RemoveEffects.DamageTypes.AddItem('Mental');

	return RemoveEffects;
}


static function X2AbilityTemplate AddArcthrowerPassive()
{
	local X2AbilityTemplate			Template;	
	local X2Effect_Arcthrower		ArcthrowerEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'ArcthrowerPassive');
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityStunGunner";  
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.bDisplayInUITacticalText = false;
	
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	
	//prevents grazes and crits
	ArcthrowerEffect = new class'X2Effect_Arcthrower';
	ArcthrowerEffect.BuildPersistentEffect(1, true, false, false);
	Template.AddTargetEffect(ArcthrowerEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;	
}

static function X2Effect_Persistent ElectroshockDisorientEffect()
{
	local X2Effect_PersistentStatChange DisorientedEffect;
	local X2Condition_AbilityProperty   AbilityCondition;
	local X2Condition_UnitProperty Condition_UnitProperty;

	DisorientedEffect = class'X2StatusEffects'.static.CreateDisorientedStatusEffect();
	DisorientedEffect.bApplyOnHit = false;
	DisorientedEffect.bApplyOnMiss = true;

	AbilityCondition = new class'X2Condition_AbilityProperty';
	AbilityCondition.OwnerHasSoldierAbilities.AddItem('Electroshock');
	DisorientedEffect.TargetConditions.AddItem(AbilityCondition);

	Condition_UnitProperty = new class'X2Condition_UnitProperty';
	Condition_UnitProperty.ExcludeOrganic = false;
	Condition_UnitProperty.ExcludeRobotic = true;
	DisorientedEffect.TargetConditions.AddItem(Condition_UnitProperty);
	
	return DisorientedEffect;
}

static function X2Effect_ArcthrowerStunned CreateArcthrowerStunnedStatusEffect(int Chance)
{
	local X2Effect_ArcthrowerStunned StunnedEffect;
	local X2Condition_UnitProperty UnitPropCondition;

	StunnedEffect = new class'X2Effect_ArcthrowerStunned';
	StunnedEffect.BuildPersistentEffect(1, true, true, false, eGameRule_UnitGroupTurnBegin);
	StunnedEffect.ApplyChance = Chance;
	//StunnedEffect.StunLevel = StunLevel;
	StunnedEffect.bIsImpairing = true;
	StunnedEffect.EffectHierarchyValue = class'X2StatusEffects'.default.STUNNED_HIERARCHY_VALUE;
	StunnedEffect.EffectName = class'X2AbilityTemplateManager'.default.StunnedName;
	StunnedEffect.VisualizationFn = class'X2StatusEffects'.static.StunnedVisualization;
	StunnedEffect.EffectTickedVisualizationFn = class'X2StatusEffects'.static.StunnedVisualizationTicked;
	StunnedEffect.EffectRemovedVisualizationFn = class'X2StatusEffects'.static.StunnedVisualizationRemoved;
	StunnedEffect.EffectRemovedFn = class'X2StatusEffects'.static.StunnedEffectRemoved;
	StunnedEffect.bRemoveWhenTargetDies = true;
	StunnedEffect.bCanTickEveryAction = true;

	if (class'X2StatusEffects'.default.StunnedParticle_Name != "")
	{
		StunnedEffect.VFXTemplateName = class'X2StatusEffects'.default.StunnedParticle_Name;
		StunnedEffect.VFXSocket = class'X2StatusEffects'.default.StunnedSocket_Name;
		StunnedEffect.VFXSocketsArrayName = class'X2StatusEffects'.default.StunnedSocketsArray_Name;
	}

	UnitPropCondition = new class'X2Condition_UnitProperty';
	UnitPropCondition.ExcludeFriendlyToSource = false;
	UnitPropCondition.ExcludeRobotic = true;
	StunnedEffect.TargetConditions.AddItem(UnitPropCondition);

	return StunnedEffect;
}

static function X2AbilityTemplate StunGunner()
{
	local X2AbilityTemplate			Template;	
	local X2Effect_StunGunner		StunGunnerEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'StunGunner');
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityStunGunner";  
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.bDisplayInUITacticalText = false;
	
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	
	// Conditional Bonus to Aim
	StunGunnerEffect = new class'X2Effect_StunGunner';
	StunGunnerEffect.BuildPersistentEffect(1, true, false, false);
	StunGunnerEffect.WeaponCategory = 'arcthrower';
	StunGunnerEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage,,,Template.AbilitySourceName);
	Template.AddTargetEffect(StunGunnerEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;	
}


//EM Pulser alternative attack, which allows targeting and damaging robots
static function X2AbilityTemplate AddEMPulser()
{
	local X2AbilityCooldown                 Cooldown;
	local X2AbilityTemplate                 Template;	
	local X2Condition_UnitProperty			UnitPropertyCondition;
	local X2AbilityToHitCalc_StandardAim    ToHitCalc;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2Effect_ArcthrowerStunned	    StunnedEffect;
	local array<name>                       SkipExclusions;
	local X2Condition_UnitType				ImmuneUnitCondition;
	//local X2Effect_RemoveEffects			CleanUpEffect;
	// Macro to do localisation and stuffs
	`CREATE_X2ABILITY_TEMPLATE(Template, 'EMPulser');

	// Icon Properties
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityEMPulser"; 
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.STANDARD_PISTOL_SHOT_PRIORITY;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.DisplayTargetHitChance = true;
	Template.AbilitySourceName = 'eAbilitySource_Perk';                                       // color of the icon

	// Activated by a button press; additionally, tells the AI this is an activatable
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	// *** VALIDITY CHECKS *** //
	SkipExclusions.AddItem(class'X2AbilityTemplateManager'.default.DisorientedName);
	Template.AddShooterEffectExclusions(SkipExclusions);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.STUN_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	// Targeting Details
	// Can only shoot visible enemies
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	// Can't target dead; Can't target friendlies -- must be enemy organic
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeRobotic = false;  // change from basic stun to allow targeting robotic units
	UnitPropertyCondition.ExcludeOrganic = false;
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.RequireWithinRange = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	
	ImmuneUnitCondition = new class'X2Condition_UnitType';
	ImmuneUnitCondition.ExcludeTypes.AddItem('PsiZombie');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM2');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM3');
	Template.AbilityTargetConditions.AddItem(ImmuneUnitCondition);

	// Can't shoot while dead
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	// Only at single targets that are in range.
	Template.AbilityTargetStyle = default.SimpleSingleTarget;

	// Action Point
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	ActionPointCost.DoNotConsumeAllSoldierAbilities.AddItem('Unlimitedpower_LW');
	Template.AbilityCosts.AddItem(ActionPointCost);	

	// Hit Calculation (Different weapons now have different calculations for range)
	ToHitCalc = new class'X2AbilityToHitCalc_StandardAim';
	ToHitCalc.bGuaranteedHit = false;
	ToHitCalc.bAllowCrit = false;
	Template.AbilityToHitCalc = ToHitCalc;
	Template.AbilityToHitOwnerOnMissCalc = ToHitCalc;

	//Stun Effect
	StunnedEffect = CreateArcthrowerStunnedStatusEffect(100);
	Template.AddTargetEffect(StunnedEffect);
	
	//CleanUpEffect = CreateStunnedEffectsCleanUpEffect();
	//Template.AddTargetEffect(CleanUpEffect);

	Template.AssociatedPassives.AddItem( 'Electroshock' );
	Template.AddTargetEffect(ElectroshockDisorientEffect());

	Template.AssociatedPassives.AddItem( 'EMPulser' );
	Template.AddTargetEffect(EMPulserHackDefenseReductionEffect());
	Template.AddTargetEffect(EMPulserWeaponDamageEffect());

	// Targeting Method
	Template.TargetingMethod = class'X2TargetingMethod_OverTheShoulder';
	Template.bUsesFiringCamera = true;
	Template.CinescriptCameraType = "StandardGunFiring";
	Template.ActivationSpeech = 'TeslaCannon';

	// MAKE IT LIVE!
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;	
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	
	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	Template.AdditionalAbilities.AddItem('ArcthrowerPassive');
	Template.AdditionalAbilities.AddItem('EMPulserPassive');
	Template.OverrideAbilities.AddItem('ArcthrowerStun');

	return Template;	
}

static function X2Effect_PersistentStatChange EMPulserHackDefenseReductionEffect()
{
	local X2Condition_UnitProperty Condition_UnitProperty;

	Condition_UnitProperty = new class'X2Condition_UnitProperty';
	Condition_UnitProperty.ExcludeOrganic = true;
	Condition_UnitProperty.TreatMindControlledSquadmateAsHostile = true;

	return class'Helpers_LW'.static.CreateHackDefenseReductionStatusEffect(
		'Arc Pulser Hack Bonus',
		default.EMPULSER_HACK_DEFENSE_CHANGE,
		Condition_UnitProperty);
}

static function X2Effect EMPulserWeaponDamageEffect()
{
	local X2Effect_ApplyWeaponDamage WeaponDamageEffect;
	local X2Condition_UnitProperty Condition_UnitProperty;

	Condition_UnitProperty = new class'X2Condition_UnitProperty';
	Condition_UnitProperty.ExcludeOrganic = true;
	Condition_UnitProperty.TreatMindControlledSquadmateAsHostile = true;
	WeaponDamageEffect = new class'X2Effect_ApplyWeaponDamage';
	WeaponDamageEffect.TargetConditions.AddItem(Condition_UnitProperty);

	return WeaponDamageEffect;
}


static function X2AbilityTemplate CreateStreetSweeper2Ability()
{
	local X2AbilityTemplate					Template;	
	local X2AbilityCost_Ammo                AmmoCost;
	local X2AbilityCost_ActionPoints        ActionPointCost;
	local X2AbilityTarget_Cursor            CursorTarget;
	local X2AbilityMultiTarget_Cone         ConeMultiTarget;
	local X2Condition_UnitProperty          UnitPropertyCondition;
	local X2AbilityToHitCalc_StandardAim    StandardAim;
	local X2AbilityCooldown                 Cooldown;
	local X2Condition_UnitInventory			InventoryCondition;
	local X2Effect_Shredder					WeaponDamageEffect;
	local X2Condition_UnitEffects			SuppressedCondition;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'StreetSweeper2');

	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_COLONEL_PRIORITY;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityStreetSweeper2";
	Template.ActivationSpeech = 'Reaper';
	Template.CinescriptCameraType = "StandardGunFiring";
	Template.bCrossClassEligible = false;
	Template.Hostility = eHostility_Offensive;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.TargetingMethod = class'X2TargetingMethod_Cone';
	Template.bDisplayInUITooltip = true;
	Template.bDisplayInUITacticalText = true;

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AbilityTargetConditions.AddItem(default.LivingTargetUnitOnlyProperty);

	Template.AddTargetEffect(class'X2Ability_GrenadierAbilitySet'.static.ShredderDamageEffect());
	Template.bAllowAmmoEffects = true;

	ActionPointCost = new class 'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = default.STREET_SWEEPER2_MIN_ACTION_REQ;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	AmmoCost = new class'X2AbilityCost_Ammo';	
	AmmoCost.iAmmo = default.STREET_SWEEPER2_AMMO_COST;
	Template.AbilityCosts.AddItem(AmmoCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.STREET_SWEEPER2_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeFriendlyToSource = false;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	
	SuppressedCondition = new class'X2Condition_UnitEffects';
	SuppressedCondition.AddExcludeEffect(class'X2Effect_Suppression'.default.EffectName, 'AA_UnitIsSuppressed');
	SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
	Template.AbilityShooterConditions.AddItem(SuppressedCondition);

	InventoryCondition = new class'X2Condition_UnitInventory';
	InventoryCondition.RelevantSlot=eInvSlot_PrimaryWeapon;
	InventoryCondition.RequireWeaponCategory = 'shotgun';
	Template.AbilityShooterConditions.AddItem(InventoryCondition);

	Template.AddShooterEffectExclusions();

	StandardAim = new class'X2AbilityToHitCalc_StandardAim';
	StandardAim.bMultiTargetOnly = false; 
	StandardAim.bGuaranteedHit = false;
	StandardAim.bOnlyMultiHitWithSuccess = false;
	StandardAim.bAllowCrit = true;
	Template.AbilityToHitCalc = StandardAim;
	Template.bOverrideAim = false;

	CursorTarget = new class'X2AbilityTarget_Cursor';
	Template.AbilityTargetStyle = CursorTarget;	

	WeaponDamageEffect = new class'X2Effect_Shredder';
	Template.AddMultiTargetEffect(WeaponDamageEffect);
	Template.bFragileDamageOnly = true;
	Template.bCheckCollision = true;

	ConeMultiTarget = new class'X2AbilityMultiTarget_Cone';
	ConeMultiTarget.bExcludeSelfAsTargetIfWithinRadius = true;
	ConeMultiTarget.ConeEndDiameter = default.STREET_SWEEPER2_TILE_WIDTH * class'XComWorldData'.const.WORLD_StepSize;
	ConeMultiTarget.bUseWeaponRangeForLength = false;
	ConeMultiTarget.ConeLength=default.STREET_SWEEPER2_CONE_LENGTH;
	ConeMultiTarget.fTargetRadius = 99;     //  large number to handle weapon range - targets will get filtered according to cone constraints
	ConeMultiTarget.bIgnoreBlockingCover = false;
	Template.AbilityMultiTargetStyle = ConeMultiTarget;
	
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	
	Template.SuperConcealmentLoss = class'X2AbilityTemplateManager'.default.SuperConcealmentStandardShotLoss;
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	Template.AdditionalAbilities.AddItem('StreetSweeperBonusDamage');

	return Template;
}


static function X2AbilityTemplate CreateStreetSweeperBonusDamageAbility()
{
	local X2AbilityTemplate					Template;	
	local X2Effect_StreetSweeper			StreetSweeperEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'StreetSweeperBonusDamage');
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bIsPassive = true;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.Hostility = eHostility_Neutral;
	Template.bDisplayInUITacticalText = false;
	
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	StreetSweeperEffect = new class 'X2Effect_StreetSweeper';
	StreetSweeperEffect.Unarmored_Damage_Multiplier = default.STREET_SWEEPER2_UNARMORED_DAMAGE_MULTIPLIER;
	StreetSweeperEffect.Unarmored_Damage_Bonus = default.STREET_SWEEPER2_UNARMORED_DAMAGE_BONUS;
	StreetSweeperEffect.BuildPersistentEffect(1,true,false,false);
	Template.AddTargetEffect(StreetSweeperEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	
	return Template;
}
/*
static function X2AbilityTemplate CreateChainLightningAbility()
{
	local X2AbilityTemplate					Template;	
	local X2AbilityCost_ActionPoints		ActionPointCost;
	local X2Condition_UnitProperty			UnitPropertyCondition, UnitPropertyCondition2;
	local X2Effect_ArcthrowerStunned		StunnedEffect;
	local X2AbilityToHitCalc_StandardAim    ToHitCalc;
	local X2AbilityCooldown					Cooldown;	
	local X2Condition_UnitType				ImmuneUnitCondition;
	local X2Condition_UnitEffects			SuppressedCondition;
	//local X2Effect_RemoveEffects			CleanUpEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'ChainLightning');
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_COLONEL_PRIORITY;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityChainLightning";
	Template.bCrossClassEligible = false;
	Template.Hostility = eHostility_Offensive;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.ActivationSpeech = 'TeslaCannon';

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AbilityTargetConditions.AddItem(default.LivingTargetUnitOnlyProperty);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityMultiTargetStyle = new class'X2AbilityMultiTarget_AllAllies';
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	Template.AbilityTargetConditions.AddItem(default.LivingHostileUnitDisallowMindControlProperty);

	//Template.bAllowAmmoEffects = true;
	Template.bAllowBonusWeaponEffects = true;

	// Can't target dead; Can't target friendlies -- must be enemy organic
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.ExcludeOrganic = false;
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.RequireWithinRange = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	
	UnitPropertyCondition2=new class'X2Condition_UnitProperty';
	UnitPropertyCondition2.ExcludeConcealed = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition2);

	SuppressedCondition = new class'X2Condition_UnitEffects';
	SuppressedCondition.AddExcludeEffect(class'X2Effect_Suppression'.default.EffectName, 'AA_UnitIsSuppressed');
	SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
	Template.AbilityShooterConditions.AddItem(SuppressedCondition);

	ImmuneUnitCondition = new class'X2Condition_UnitType';
	ImmuneUnitCondition.ExcludeTypes.AddItem('PsiZombie');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM2');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM3');
	Template.AbilityTargetConditions.AddItem(ImmuneUnitCondition);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.CHAIN_LIGHTNING_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	// Action Point
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = default.CHAIN_LIGHTNING_MIN_ACTION_REQ;
	ActionPointCost.DoNotConsumeAllSoldierAbilities.AddItem('Unlimitedpower_LW');
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);	

	//Stun Effect
	StunnedEffect = CreateArcthrowerStunnedStatusEffect(100);
	Template.AddTargetEffect(StunnedEffect);
	Template.AddMultiTargetEffect(StunnedEffect);

	//CleanUpEffect = CreateStunnedEffectsCleanUpEffect();
	//Template.AddTargetEffect(CleanUpEffect);


	Template.AssociatedPassives.AddItem('Electroshock');
	Template.AddMultiTargetEffect(ElectroshockDisorientEffect());
	
	ToHitCalc = new class'X2AbilityToHitCalc_StandardAim';
	ToHitCalc.bOnlyMultiHitWithSuccess = false;
	ToHitCalc.BuiltInHitMod = default.CHAIN_LIGHTNING_AIM_MOD;
	Template.AbilityToHitCalc = ToHitCalc;
	

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = class'X2Ability_SharpshooterAbilitySet'.static.Faceoff_BuildVisualization;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	return Template;
}
*/


static function X2AbilityTemplate CreateChainLightningAbility()
{
	local X2AbilityTemplate					Template;	
	local X2AbilityCost_ActionPoints		ActionPointCost;
	local X2Condition_UnitProperty			UnitPropertyCondition, UnitPropertyCondition2;
	local X2Effect_ArcthrowerStunned		StunnedEffect;
	local X2AbilityToHitCalc_StandardAim    ToHitCalc;
	local X2AbilityCooldown					Cooldown;	
	local X2Condition_UnitType				ImmuneUnitCondition;
	local X2Condition_UnitEffects			SuppressedCondition;
	local X2Effect_ApplyWeaponDamage		DamageEffect;
	//local X2Effect_RemoveEffects			CleanUpEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'ChainLightning');
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.CLASS_COLONEL_PRIORITY;
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.IconImage = "img:///UILibrary_LW_Overhaul.LW_AbilityChainLightning";
	Template.bCrossClassEligible = false;
	Template.Hostility = eHostility_Offensive;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.ActivationSpeech = 'TeslaCannon';

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AbilityTargetConditions.AddItem(default.LivingTargetUnitOnlyProperty);
	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityMultiTargetStyle = new class'X2AbilityMultiTarget_Volt';
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.TargetingMethod = class'X2TargetingMethod_Volt';

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);
	Template.AbilityTargetConditions.AddItem(default.LivingHostileUnitDisallowMindControlProperty);


	//Template.bAllowAmmoEffects = true;
	Template.bAllowBonusWeaponEffects = true;

	// Can't target dead; Can't target friendlies -- must be enemy organic
	UnitPropertyCondition = new class'X2Condition_UnitProperty';
	UnitPropertyCondition.ExcludeRobotic = true;
	UnitPropertyCondition.ExcludeOrganic = false;
	UnitPropertyCondition.ExcludeDead = true;
	UnitPropertyCondition.ExcludeFriendlyToSource = true;
	UnitPropertyCondition.RequireWithinRange = true;
	Template.AbilityTargetConditions.AddItem(UnitPropertyCondition);
	
	UnitPropertyCondition2=new class'X2Condition_UnitProperty';
	UnitPropertyCondition2.ExcludeConcealed = true;
	Template.AbilityShooterConditions.AddItem(UnitPropertyCondition2);

	SuppressedCondition = new class'X2Condition_UnitEffects';
	SuppressedCondition.AddExcludeEffect(class'X2Effect_Suppression'.default.EffectName, 'AA_UnitIsSuppressed');
	SuppressedCondition.AddExcludeEffect(class'X2Effect_AreaSuppression'.default.EffectName, 'AA_UnitIsSuppressed');
	Template.AbilityShooterConditions.AddItem(SuppressedCondition);

	ImmuneUnitCondition = new class'X2Condition_UnitType';
	ImmuneUnitCondition.ExcludeTypes.AddItem('PsiZombie');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM2');
	ImmuneUnitCondition.ExcludeTypes.AddItem('AdvPsiWitchM3');
	Template.AbilityTargetConditions.AddItem(ImmuneUnitCondition);



	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.CHAIN_LIGHTNING_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	// Action Point
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = default.CHAIN_LIGHTNING_MIN_ACTION_REQ;
	ActionPointCost.DoNotConsumeAllSoldierAbilities.AddItem('Unlimitedpower_LW');
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);	

	//Stun Effect
	StunnedEffect = CreateArcthrowerStunnedStatusEffect(100);
	Template.AddTargetEffect(StunnedEffect);
	Template.AddMultiTargetEffect(StunnedEffect);

	//CleanUpEffect = CreateStunnedEffectsCleanUpEffect();
	//Template.AddTargetEffect(CleanUpEffect);
	DamageEffect = new class'X2Effect_ApplyWeaponDamage';
	DamageEffect.bIgnoreBaseDamage = true;
	DamageEffect.DamageTag = 'Volt';
	DamageEffect.bIgnoreArmor = true;
	DamageEffect.TargetConditions.AddItem(UnitPropertyCondition);
	Template.AddTargetEffect(DamageEffect);
	Template.AddMultiTargetEffect(DamageEffect);


	Template.AssociatedPassives.AddItem('Electroshock');
	Template.AddMultiTargetEffect(ElectroshockDisorientEffect());
	
	ToHitCalc = new class'X2AbilityToHitCalc_StandardAim';
	ToHitCalc.bOnlyMultiHitWithSuccess = false;
	ToHitCalc.BuiltInHitMod = default.CHAIN_LIGHTNING_AIM_MOD;
	Template.AbilityToHitCalc = ToHitCalc;
	Template.AdditionalAbilities.AddItem('CLFocus');
	
	Template.ActionFireClass = class'X2Action_Fire_ChainLightning';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	//Template.BuildVisualizationFn = class'X2Ability_SharpshooterAbilitySet'.static.Faceoff_BuildVisualization;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.BuildInterruptGameStateFn = TypicalAbility_BuildInterruptGameState;
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	return Template;
}


static function X2AbilityTemplate CreateCLFocus(name AbilityName, int FocusLevel)
{
	local X2AbilityTemplate Template;
	local X2Effect_ModifyTemplarFocus FocusEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, AbilityName);

	Template.IconImage = "img:///UILibrary_XPACK_Common.PerkIcons.UIPerk_templarFocus";
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.bIsPassive = true;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	Template.AdditionalAbilities.AddItem('SupremeFocus');
	Template.AdditionalAbilities.AddItem('DeepFocus');
	Template.AdditionalAbilities.AddItem('AddSuperGigaOmegaFocus');
	
	Template.AddTargetEffect(new class'X2Effect_TemplarFocus');

	FocusEffect = new class'X2Effect_ModifyTemplarFocus';
	FocusEffect.ModifyFocus = FocusLevel;
	Template.AddTargetEffect(FocusEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	// Note: no visualization on purpose!

	return Template;
}
