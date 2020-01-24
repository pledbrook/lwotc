//---------------------------------------------------------------------------------------
//  FILE:    X2Ability_TemplarAbilitySet_LW.uc
//  AUTHOR:  martox
//  PURPOSE: Additional Templar abilities for use in LWOTC.
//---------------------------------------------------------------------------------------
class X2Ability_TemplarAbilitySet_LW extends X2Ability_TemplarAbilitySet config(LW_FactionBalance);

var config int SOLACE_ACTION_POINTS;
var config int SOLACE_COOLDOWN;
var config int GRAZE_MIN_FOCUS, GRAZE_PER_FOCUS_CHANCE;
var config int MEDITATION_FOCUS_RECOVERY;
var config int MEDITATION_COOLDOWN;
var config float BONUS_REND_DAMAGE_PER_TILE;
var config int MAX_REND_FLECHE_DAMAGE;

var config int FOCUS1AIM;
var config int FOCUS1DEFENSE;
var config int FOCUS2AIM;
var config int FOCUS2DEFENSE;
var config int FOCUS3AIM;
var config int FOCUS3DEFENSE;
var config int FOCUS4AIM;
var config int FOCUS4DEFENSE;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	//from Udaya
	Templates.AddItem(AddSupremeFocus());
	Templates.AddItem(AddTemplarSolace());
	Templates.AddItem(AddTemplarFleche());
	Templates.AddItem(AddTemplarGrazingFireAbility());
	Templates.AddItem(AddMeditation());
	Templates.AddItem(AddOvercharge_LW());
	Templates.AddItem(AddVoltDangerZoneAbility());

	return Templates;
}

static function X2AbilityTemplate AddSupremeFocus()
{
	local X2AbilityTemplate Template;

	Template = PurePassive('SupremeFocus', "img:///UILibrary_XPACK_Common.PerkIcons.UIPerk_SupremeFocus", false, 'eAbilitySource_Psionic', false);
	Template.PrerequisiteAbilities.AddItem('DeepFocus');

	return Template;
}

static function X2AbilityTemplate AddTemplarSolace()
{
	local X2AbilityTemplate						Template;
	local X2AbilityCooldown						Cooldown;
	local X2AbilityCost_ActionPoints			ActionPointCost;
	local X2Effect_RemoveEffects                MentalEffectRemovalEffect;
	local X2Effect_RemoveEffects                MindControlRemovalEffect;
	local X2Condition_UnitProperty              EnemyCondition;
	local X2Condition_UnitProperty              FriendCondition;
	local X2Condition_Solace_LW					SolaceCondition;
	local X2Effect_StunRecover StunRecoverEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'TemplarSolace');

	Template.IconImage = "img:///UILibrary_PerkIcons.UIPerk_solace";
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
	Template.Hostility = eHostility_Neutral;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SimpleSingleTarget;
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.bCrossClassEligible = false;
	Template.bDisplayInUITooltip = true;
	Template.bDisplayInUITacticalText = true;
	Template.DisplayTargetHitChance = false;
	Template.bLimitTargetIcons = true;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = default.SOLACE_ACTION_POINTS;
	ActionPointCost.bConsumeAllPoints = false;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.SOLACE_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	Template.AbilityTargetConditions.AddItem(default.GameplayVisibilityCondition);

	SolaceCondition = new class'X2Condition_Solace_LW';
	Template.AbilityTargetConditions.AddItem(SolaceCondition);

	//Naming confusion: CreateMindControlRemoveEffects removes everything _except_ mind control, and is used when mind-controlling an enemy.
	//We want to remove all those other status effects on friendly units; we want to remove mind-control itself from enemy units.
	//(Enemy units with mind-control will be back on our team once it's removed.)

	StunRecoverEffect = class'X2StatusEffects'.static.CreateStunRecoverEffect();
	Template.AddTargetEffect(StunRecoverEffect);

	MentalEffectRemovalEffect = class'X2StatusEffects'.static.CreateMindControlRemoveEffects();
	FriendCondition = new class'X2Condition_UnitProperty';
	FriendCondition.ExcludeFriendlyToSource = false;
	FriendCondition.ExcludeHostileToSource = true;
	MentalEffectRemovalEffect.TargetConditions.AddItem(FriendCondition);
	Template.AddTargetEffect(MentalEffectRemovalEffect);

	MindControlRemovalEffect = new class'X2Effect_RemoveEffects';
	MindControlRemovalEffect.EffectNamesToRemove.AddItem(class'X2Effect_MindControl'.default.EffectName);
	EnemyCondition = new class'X2Condition_UnitProperty';
	EnemyCondition.ExcludeFriendlyToSource = true;
	EnemyCondition.ExcludeHostileToSource = false;
	MindControlRemovalEffect.TargetConditions.AddItem(EnemyCondition);
	Template.AddTargetEffect(MindControlRemovalEffect);

	// Solace recovers action points like Revival Protocol
	Template.AddTargetEffect(new class'X2Effect_RestoreActionPoints');

	Template.ActivationSpeech = 'StunStrike';
	Template.bShowActivation = true;
	Template.CustomFireAnim = 'HL_Volt';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.CinescriptCameraType = "Psionic_FireAtUnit";

	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;

	return Template;
}

static function X2AbilityTemplate AddTemplarFleche()
{
	local X2AbilityTemplate				Template;
	local X2Effect_FlecheBonusDamage	FlecheBonusDamageEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'TemplarFleche');
	Template.IconImage = "img:///UILibrary_LW_PerkPack.LW_AbilityFleche";
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	Template.bIsPassive = true;
	Template.bHideOnClassUnlock = true;
	Template.bCrossClassEligible = false;
	FlecheBonusDamageEffect = new class 'X2Effect_FlecheBonusDamage';
	FlecheBonusDamageEffect.BonusDmgPerTile = default.BONUS_REND_DAMAGE_PER_TILE;
	FlecheBonusDamageEffect.MaxBonusDamage = default.MAX_REND_FLECHE_DAMAGE;
	FlecheBonusDamageEffect.AbilityNames.AddItem('Rend');
	FlecheBonusDamageEffect.AbilityNames.AddItem('ArcWave');
	//FlecheBonusDamageEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,,Template.AbilitySourceName);
	FlecheBonusDamageEffect.BuildPersistentEffect (1, true, false);
	Template.AddTargetEffect (FlecheBonusDamageEffect);
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

static function X2AbilityTemplate AddTemplarGrazingFireAbility()
{
	local X2AbilityTemplate					Template;
	local X2Effect_TemplarGrazingFire		GrazingEffect;

	`CREATE_X2ABILITY_TEMPLATE (Template, 'TemplarGrazingFire');

	Template.IconImage = "img:///UILibrary_LW_PerkPack.LW_AbilityGrazingFire";
	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.Hostility = eHostility_Neutral;
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	Template.bDisplayInUITooltip = true;
	Template.bDisplayInUITacticalText = true;
	Template.bShowActivation = false;
	Template.bSkipFireAction = true;
	Template.bCrossClassEligible = true;
	GrazingEffect = new class'X2Effect_TemplarGrazingFire';
	GrazingEffect.GrazeMinFocus = default.GRAZE_MIN_FOCUS;
	GrazingEffect.SuccessChance = class'X2Ability_PerkPackAbilitySet'.default.GRAZING_FIRE_SUCCESS_CHANCE;
	GrazingEffect.GrazePerFocusChance = default.GRAZE_PER_FOCUS_CHANCE;
	GrazingEffect.BuildPersistentEffect (1, true, false);
	GrazingEffect.SetDisplayInfo (ePerkBuff_Passive,Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage,,, Template.AbilitySourceName); 
	Template.AddTargetEffect(GrazingEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	//Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	return Template;
}

static function X2AbilityTemplate AddMeditation()
{
	local X2AbilityTemplate						Template;
	local X2Effect_ModifyTemplarFocus			FocusEffect;
	local X2AbilityCost_ActionPoints        	ActionPointCost;
	local X2AbilityCooldown						Cooldown;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Meditation');

//BEGIN AUTOGENERATED CODE: Template Overrides 'MeditationPreparation'
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
//END AUTOGENERATED CODE: Template Overrides 'MeditationPreparation'
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.IconImage = "img:///UILibrary_XPACK_Common.PerkIcons.UIPerk_meditation";

	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bConsumeAllPoints = true;
	Template.AbilityCosts.AddItem(ActionPointCost);

	Cooldown = new class'X2AbilityCooldown';
	Cooldown.iNumTurns = default.MEDITATION_COOLDOWN;
	Template.AbilityCooldown = Cooldown;

	FocusEffect = new class'X2Effect_ModifyTemplarFocus';
	FocusEffect.ModifyFocus = default.MEDITATION_FOCUS_RECOVERY;
	Template.AddShooterEffect(FocusEffect);

	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;

	// Template.AdditionalAbilities.AddItem('MeditationPreparationPassive');

	return Template;
}

static function X2AbilityTemplate AddOvercharge_LW()
{
	local X2AbilityTemplate					Template;
	local X2Effect_TemplarFocusStatBonuses	FocusEffect;
	local array<StatChange>					StatChanges;
	local StatChange						NewStatChange;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'Overcharge_LW');
	Template.IconImage = "img:///UILibrary_XPACK_Common.PerkIcons.UIPerk_Overcharge";
	Template.Hostility = eHostility_Neutral;
//BEGIN AUTOGENERATED CODE: Template Overrides 'Overcharge'
	Template.AbilitySourceName = 'eAbilitySource_Psionic';
//END AUTOGENERATED CODE: Template Overrides 'Overcharge'
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	FocusEffect = new class'X2Effect_TemplarFocusStatBonuses';
	FocusEffect.BuildPersistentEffect(1, true, false);
	FocusEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.LocLongDescription, Template.IconImage, false, , Template.AbilitySourceName);

	//	focus 0
	StatChanges.Length = 0;
	FocusEffect.AddNextFocusLevel(StatChanges, 0, 0);
	//	focus 1
	StatChanges.Length = 0;
	NewStatChange.StatType = eStat_Offense;
	NewStatChange.StatAmount = default.FOCUS1AIM;
	StatChanges.AddItem(NewStatChange);
	NewStatChange.StatType = eStat_Defense;
	NewStatChange.StatAmount = default.FOCUS1DEFENSE;
	StatChanges.AddItem(NewStatChange);
	FocusEffect.AddNextFocusLevel(StatChanges, 0, 0);
	//	focus 2
	StatChanges.Length = 0;
	NewStatChange.StatType = eStat_Offense;
	NewStatChange.StatAmount = default.FOCUS2AIM;
	StatChanges.AddItem(NewStatChange);
	NewStatChange.StatType = eStat_Defense;
	NewStatChange.StatAmount = default.FOCUS2DEFENSE;
	StatChanges.AddItem(NewStatChange);
	FocusEffect.AddNextFocusLevel(StatChanges, 0, 0);
	//	focus 3
	StatChanges.Length = 0;
	NewStatChange.StatType = eStat_Offense;
	NewStatChange.StatAmount = default.FOCUS3AIM;
	StatChanges.AddItem(NewStatChange);
	NewStatChange.StatType = eStat_Defense;
	NewStatChange.StatAmount = default.FOCUS3DEFENSE;
	StatChanges.AddItem(NewStatChange);
	FocusEffect.AddNextFocusLevel(StatChanges, 0, 0);
	//	focus 3
	StatChanges.Length = 0;
	NewStatChange.StatType = eStat_Offense;
	NewStatChange.StatAmount = default.FOCUS4AIM;
	StatChanges.AddItem(NewStatChange);
	NewStatChange.StatType = eStat_Defense;
	NewStatChange.StatAmount = default.FOCUS4DEFENSE;
	StatChanges.AddItem(NewStatChange);
	FocusEffect.AddNextFocusLevel(StatChanges, 0, 0);

	Template.AddTargetEffect(FocusEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	//  NOTE: No visualization on purpose!

	Template.bShowPostActivation = true;
	Template.bSkipFireAction = true;

	return Template;
}

static function X2AbilityTemplate AddVoltDangerZoneAbility()
{
	local X2AbilityTemplate Template;	

	Template = PurePassive('VoltDangerZone', "img:///UILibrary_LW_PerkPack.LW_AbilityDangerZone", false, 'eAbilitySource_Perk');
	Template.bCrossClassEligible = false;
	Template.PrerequisiteAbilities.AddItem('Volt');
	return Template;
}
