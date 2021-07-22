// X2EventListener_Tactical.uc
// 
// A listener template that allows LW2 to override game behaviour related to
// tactical missions. It's a dumping ground for tactical stuff that doesn't
// fit with more specific listener classes.
//
class X2EventListener_Tactical extends X2EventListener config(LW_Overhaul);

var config int LISTENER_PRIORITY;
var config array<float> SOUND_RANGE_DIFFICULTY_MODIFIER;
var config array<int> RED_ALERT_DETECTION_DIFFICULTY_MODIFIER;
var config array<int> YELLOW_ALERT_DETECTION_DIFFICULTY_MODIFIER;

var config int NUM_TURNS_FOR_WILL_LOSS;
var config int NUM_TURNS_FOR_TIRED_WILL_LOSS;

// Camel case for consistency with base game's will roll data config vars
var const config WillEventRollData PerTurnWillRollData;

var config array<int> MISSION_DIFFICULTY_THRESHOLDS;

var localized string HIT_CHANCE_MSG;
var localized string CRIT_CHANCE_MSG;
var localized string DODGE_CHANCE_MSG;
var localized string MISS_CHANCE_MSG;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateYellowAlertListeners());
	Templates.AddItem(CreateMiscellaneousListeners());
	Templates.AddItem(CreateDifficultMissionAPListener());
	Templates.AddItem(CreateVeryDifficultMissionAPListener());
	Templates.AddItem(CreateUIFocusOverride());

	return Templates;
}

static function CHEventListenerTemplate CreateYellowAlertListeners()
{
	local CHEventListenerTemplate Template;

	`LWTrace("Registering evac event listeners");

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'YellowAlertListeners');
	Template.AddCHEvent('OverrideSoundRange', OnOverrideSoundRange, ELD_Immediate, GetListenerPriority());
	Template.AddCHEvent('OverrideSeesAlertedAllies', DisableSeesAlertedAlliesAlert, ELD_Immediate, GetListenerPriority());
	Template.AddCHEvent('ProcessReflexMove', OnScamperBegin, ELD_Immediate);
	Template.AddCHEvent('UnitTakeEffectDamage', OnUnitTookDamage, ELD_OnStateSubmitted);
	Template.AddCHEvent('OverrideAllowedAlertCause', OnOverrideAllowedAlertCause, ELD_Immediate);
	Template.AddCHEvent('ShouldCivilianRun', ShouldCivilianRunFromOtherUnit, ELD_Immediate);

	Template.RegisterInTactical = true;

	return Template;
}

static function CHEventListenerTemplate CreateMiscellaneousListeners()
{
	local CHEventListenerTemplate Template;

	`LWTrace("Registering miscellaneous tactical event listeners");

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'MiscellaneousTacticalListeners');
	Template.AddCHEvent('GetEvacPlacementDelay', OnPlacedDelayedEvacZone, ELD_Immediate, GetListenerPriority());
	Template.AddCHEvent('KilledbyExplosion', OnKilledbyExplosion, ELD_Immediate, GetListenerPriority());
	Template.AddCHEvent('CleanupTacticalMission', OnCleanupTacticalMission, ELD_Immediate, GetListenerPriority());
	Template.AddCHEvent('OverrideBodyRecovery', OnOverrideBodyAndLootRecovery, ELD_Immediate);
	Template.AddCHEvent('OverrideLootRecovery', OnOverrideBodyAndLootRecovery, ELD_Immediate);
	Template.AddCHEvent('AbilityActivated', OnAbilityActivated, ELD_OnStateSubmitted, GetListenerPriority());
	Template.AddCHEvent('UnitChangedTeam', ClearUnitStateValues, ELD_Immediate, GetListenerPriority());
	Template.AddCHEvent('PlayerTurnEnded', RollForPerTurnWillLoss, ELD_OnStateSubmitted, GetListenerPriority());
	Template.AddCHEvent('OverrideR3Button', BindR3ToPlaceDelayedEvacZone, ELD_Immediate, GetListenerPriority());

	// This seems to be causing stutter in the game, so commenting out for now.
	// if (XCom_Perfect_Information_UIScreenListener.default.ENABLE_PERFECT_INFORMATION)
	// {
	// 	Template.AddCHEvent('AbilityActivated', AddPerfectInfoFlyover, ELD_OnStateSubmitted, GetListenerPriority());
	// }

	Template.RegisterInTactical = true;

	return Template;
}

static function X2AbilityPointTemplate CreateDifficultMissionAPListener()
{
	local X2AbilityPointTemplate Template;

	`CREATE_X2TEMPLATE(class'X2AbilityPointTemplate', Template, 'DifficultMissionCompleted');
	Template.AddEvent('EndBattle', CheckForDifficultMissionCompleted);

	return Template;
}

static function X2AbilityPointTemplate CreateVeryDifficultMissionAPListener()
{
	local X2AbilityPointTemplate Template;

	`CREATE_X2TEMPLATE(class'X2AbilityPointTemplate', Template, 'VeryDifficultMissionCompleted');
	Template.AddEvent('EndBattle', CheckForVeryDifficultMissionCompleted);

	return Template;
}

static protected function int GetListenerPriority()
{
	return default.LISTENER_PRIORITY != -1 ? default.LISTENER_PRIORITY : class'XComGameState_LWListenerManager'.default.DEFAULT_LISTENER_PRIORITY;
}

// Handles modification of the evac timer based on various conditions, such as
// infiltration percentage, squad size, etc.
static function EventListenerReturn OnPlacedDelayedEvacZone(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple EvacDelayTuple;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_LWSquadManager SquadMgr;
	local XComGameState_LWPersistentSquad Squad;
	local XComGameState_MissionSite MissionState;
	local XComGameState_LWAlienActivity CurrentActivity;

	EvacDelayTuple = XComLWTuple(EventData);
	if(EvacDelayTuple == none)
		return ELR_NoInterrupt;

	if(EvacDelayTuple.Id != 'DelayedEvacTurns')
		return ELR_NoInterrupt;

	if(EvacDelayTuple.Data[0].Kind != XComLWTVInt)
		return ELR_NoInterrupt;

	XComHQ = `XCOMHQ;
	SquadMgr = class'XComGameState_LWSquadManager'.static.GetSquadManager();
	if(SquadMgr == none)
		return ELR_NoInterrupt;

	Squad = SquadMgr.GetSquadOnMission(XComHQ.MissionRef);

	`LWTRACE("**** Evac Delay Calculations ****");
	`LWTRACE("Base Delay : " $ EvacDelayTuple.Data[0].i);

	// adjustments based on squad size
	EvacDelayTuple.Data[0].i += Squad.EvacDelayModifier_SquadSize();
	`LWTRACE("After Squadsize Adjustment : " $ EvacDelayTuple.Data[0].i);

	// adjustments based on infiltration
	EvacDelayTuple.Data[0].i += Squad.EvacDelayModifier_Infiltration();
	`LWTRACE("After Infiltration Adjustment : " $ EvacDelayTuple.Data[0].i);

	// adjustments based on number of active missions engaged with
	EvacDelayTuple.Data[0].i += Squad.EvacDelayModifier_Missions();
	`LWTRACE("After NumMissions Adjustment : " $ EvacDelayTuple.Data[0].i);

	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(`XCOMHQ.MissionRef.ObjectID));
	CurrentActivity = class'XComGameState_LWAlienActivityManager'.static.FindAlienActivityByMission(MissionState);

	EvacDelayTuple.Data[0].i += CurrentActivity.GetMyTemplate().MissionTree[CurrentActivity.CurrentMissionLevel].EvacModifier;

	`LWTRACE("After Activity Adjustment : " $ EvacDelayTuple.Data[0].i);
	
	return ELR_NoInterrupt;

}

static function EventListenerReturn OnOverrideSoundRange(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Item WeaponState;
	local XComGameState_Ability ActivatedAbilityState;
	local int SoundRange;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	if (Tuple.Id != 'OverrideSoundRange')
		return ELR_NoInterrupt;

	WeaponState = XComGameState_Item(Tuple.Data[1].o);
	if (WeaponState == None)
	{
		`REDSCREEN("Invalid item state passed to OnOverrideSoundRange");
		return ELR_NoInterrupt;
	}

	ActivatedAbilityState = XComGameState_Ability(Tuple.Data[2].o);
	if (ActivatedAbilityState == None)
	{
		`REDSCREEN("Invalid ability state passed to OnOverrideSoundRange");
		return ELR_NoInterrupt;
	}

	SoundRange = Tuple.Data[3].i;

	// If the sound comes from ammo, like a grenade fired from a grenade launcher, use
	// the ammo's sound range instead of the weapon's.
	if (!WeaponState.SoundOriginatesFromOwnerLocation() && ActivatedAbilityState.GetSourceAmmo() != None)
	{
		SoundRange = ActivatedAbilityState.GetSourceAmmo().GetItemSoundRange();
	}
	
	// Apply any sound range modifiers, like those provided by suppressors.
	SoundRange += ModifySoundRange(WeaponState, ActivatedAbilityState);
	Tuple.Data[3].i = SoundRange;

	return ELR_NoInterrupt;
}
	
static function EventListenerReturn DisableSeesAlertedAlliesAlert(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	if (Tuple.Id != 'OverrideSeesAlertedAllies')
		return ELR_NoInterrupt;

	// Copying original LW2 behaviour for now, which is to disable this alert
	// when yellow alert is enabled.
	Tuple.Data[2].i = eAC_None;
	return ELR_NoInterrupt;
}

// Add extra actions to eligible green- and yellow-alert units.
static function EventListenerReturn OnScamperBegin(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local array<int> AlivePodMembers;
	local XComGameState_Unit PodLeaderUnit;
	local XComGameState_Unit PodMember;
	local XComGameStateHistory History;
	local XComGameState_AIGroup Group;
	local bool IsYellow;
	local float Chance;
	local UnitValue Value;
	local XComGameState_MissionSite			MissionSite;
	local XComGameState_LWPersistentSquad	SquadState;
	local XComGameState_BattleData			BattleData;
	local int i, NumSuccessfulReflexActions;

	History = `XCOMHISTORY;
	Group = XComGameState_AIGroup(EventSource);
	if (Group == none)
	{
		`REDSCREEN("Event source for 'ScamperBegin' is not an XCGS_AIGroup");
	}

	// Start by getting hold of the members of the pod that are currently
	// alive + the leader.
	Group.GetLivingMembers(AlivePodMembers);
	PodLeaderUnit = XComGameState_Unit(History.GetGameStateForObjectID(AlivePodMembers[0]));

	`LWTrace(GetFuncName() $ ": Processing reflex move for pod leader " $ PodLeaderUnit.GetMyTemplateName());

	// LWOTC: This note is from original LW2. I don't know if the assumptions and reasoning
	// still hold with WOTC.
	//
	// Note: We don't currently support reflex actions on XCOM's turn. Doing so requires
	// adjustments to how scampers are processed so the units would use their extra action
	// point. Also note that giving units a reflex action point while it's not their turn
	// can break stun animations unless those action points are used: see X2Effect_Stunned
	// where action points are only removed if it's the units turn, and the effect actions
	// (including the stunned idle anim override) are only visualized if the unit has no
	// action points left. If the unit has stray reflex actions they haven't used they
	// will stand back up and perform the normal idle animation (although they are still
	// stunned and won't act).
	if (PodLeaderUnit.ControllingPlayer != `TACTICALRULES.GetCachedUnitActionPlayerRef())
	{
		`LWTrace(GetFuncName() $ ": Not the alien turn: aborting");
		return ELR_NoInterrupt;
	}

	if (PodLeaderUnit.GetCurrentStat(eStat_AlertLevel) <= 1)
	{
		// This unit isn't in red alert. If a scampering unit is not in red, this generally means they're a reinforcement
		// pod. Skip them.
		`LWTrace(GetFuncName() $ ": Reinforcement unit: aborting");
		return ELR_NoInterrupt;
	}

	// Look for the special 'NoReflexAction' unit value. If present, this unit isn't allowed to take an action.
	// This is typically set on reinforcements on the turn they spawn. But if they spawn out of LoS they are
	// eligible, just like any other yellow unit, on subsequent turns. Both this check and the one above are needed.
	PodLeaderUnit.GetUnitValue(class'Utilities_LW'.const.NoReflexActionUnitValue, Value);
 	if (Value.fValue == 1)
	{
		`LWTrace(GetFuncName() $ ": Unit with no reflex action value: aborting");
		return ELR_NoInterrupt;
	}

	// Walk backwards through history for this unit until we find a state in which this unit wasn't in red
	// alert to see if we entered from yellow or from green.
	IsYellow = class'Utilities_LW'.static.GetPreviousAlertLevel(PodLeaderUnit) == `ALERT_LEVEL_YELLOW;
	Chance = IsYellow ? class'Utilities_LW'.default.REFLEX_ACTION_CHANCE_YELLOW[`TACTICALDIFFICULTYSETTING]
			 : class'Utilities_LW'.default.REFLEX_ACTION_CHANCE_GREEN[`TACTICALDIFFICULTYSETTING];

	// if is infiltration mission, get infiltration % and modify yellow and green alert chances by how much you missed 100%, diff modifier, positive boolean
	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	MissionSite = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(BattleData.m_iMissionID));

	// Infiltration modifier
	if (`LWSQUADMGR.IsValidInfiltrationMission(MissionSite.GetReference()))
	{
		SquadState = `LWSQUADMGR.GetSquadOnMission(MissionSite.GetReference());
		if (SquadState.CurrentInfiltration <= 1)
		{
			Chance += (1.0 - SquadState.CurrentInfiltration) * class'Utilities_LW'.default.LOW_INFILTRATION_MODIFIER_ON_REFLEX_ACTIONS[`TACTICALDIFFICULTYSETTING];
		}
		else
		{
			Chance -= (SquadState.CurrentInfiltration - 1.0) * class'Utilities_LW'.default.HIGH_INFILTRATION_MODIFIER_ON_REFLEX_ACTIONS[`TACTICALDIFFICULTYSETTING];
		}
	}

	NumSuccessfulReflexActions = 0;
	for (i = 0; i < AlivePodMembers.Length; ++i)
	{
		PodMember = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', AlivePodMembers[i]));
		NumSuccessfulReflexActions += ProcessReflexActionsForUnit(
			PodMember,
			IsYellow,
			Chance,
			NumSuccessfulReflexActions);
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnUnitTookDamage(
	Object EventData,
	Object EventSource,
	XComGameState GameState,
	Name InEventID,
	Object CallbackData)
{
	local XComGameState_Unit Unit;
	local XComGameState NewGameState;

	Unit = XComGameState_Unit(EventSource);
	if (Unit.ControllingPlayerIsAI() &&
		Unit.IsInjured() &&
		`BEHAVIORTREEMGR.IsScampering() &&
		Unit.ActionPoints.Find(class'Utilities_LW'.const.OffensiveReflexAction) >= 0)
	{
		// This unit has taken damage, is scampering, and has an 'offensive' reflex action point. Replace it with
		// a defensive action point.
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Replacing reflex action for injured unit");
		Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
		Unit.ActionPoints.RemoveItem(class'Utilities_LW'.const.OffensiveReflexAction);
		Unit.ActionPoints.AddItem(class'Utilities_LW'.const.DefensiveReflexAction);
		`TACTICALRULES.SubmitGameState(NewGameState);
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn OnOverrideAllowedAlertCause(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local EAlertCause AlertCause;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Sanity check. This should not happen.
	if (Tuple.Id != 'OverrideAllowedAlertCause')
	{
		`REDSCREEN("Received unexpected event ID in OnOverrideAllowedAlertCause() event handler");
		return ELR_NoInterrupt;
	}

	if (class'Helpers_LW'.static.YellowAlertEnabled())
	{
		AlertCause = EAlertCause(Tuple.Data[0].i);
		switch (AlertCause)
		{
			case eAC_DetectedSound:
			case eAC_DetectedAllyTakingDamage:
			case eAC_DetectedNewCorpse:
			case eAC_SeesExplosion:
			case eAC_SeesSmoke:
			case eAC_SeesFire:
			case eAC_AlertedByYell:
				Tuple.Data[1].b = true;
				break;

			default:
				break;
		}
	}

	return ELR_NoInterrupt;
}

static function EventListenerReturn ShouldCivilianRunFromOtherUnit(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit OtherUnitState;
	local bool DoesAIAttackCivilians;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Sanity check. This should not happen.
	if (Tuple.Id != 'ShouldCivilianRun')
	{
		`REDSCREEN("Received unexpected event ID in ShouldCivilianRunFromOtherUnit() event handler");
		return ELR_NoInterrupt;
	}

	OtherUnitState = XComGameState_Unit(Tuple.Data[0].o);
	DoesAIAttackCivilians = Tuple.Data[1].b;

	// Civilians shouldn't run from the aliens/ADVENT unless Team Alien
	// is attacking neutrals.
	Tuple.Data[2].b = !(!DoesAIAttackCivilians && OtherUnitState.GetTeam() == eTeam_Alien); 

	return ELR_NoInterrupt;
}

// Returns a modifier that should be applied to the sound range for a weapon/ability combo
//
// Implementation copied from X2DLCInfo_LW_Overhaul in the original LW2.
static function int ModifySoundRange(XComGameState_Item Weapon, XComGameState_Ability Ability)
{
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local float SoundRangeModifier;
	local int k;
	local X2WeaponTemplate WeaponTemplate;
	local X2MultiWeaponTemplate MultiWeaponTemplate;
	local X2AbilityTemplate AbilityTemplate;
	local X2Effect AbilityEffect;
	local bool UseAltWeaponSoundRange;
	local XComGameState_HeadquartersXCom 	XComHQ;

	SoundRangeModifier = 0.0;
	WeaponTemplate = X2WeaponTemplate(Weapon.GetMyTemplate());

	// Is it a multiweapon?
	MultiWeaponTemplate = X2MultiWeaponTemplate(WeaponTemplate);

	if (MultiWeaponTemplate != none)
	{
		AbilityTemplate = Ability.GetMyTemplate();
		foreach AbilityTemplate.AbilityTargetEffects(AbilityEffect)
		{
			if (AbilityEffect.IsA('X2Effect_ApplyAltWeaponDamage'))
			{
				UseAltWeaponSoundRange = true;
				break;
			}
		}

		foreach AbilityTemplate.AbilityMultiTargetEffects(AbilityEffect)
		{
			if (AbilityEffect.IsA('X2Effect_ApplyAltWeaponDamage'))
			{
				UseAltWeaponSoundRange = true;
				break;
			}
		}

		if (UseAltWeaponSoundRange)
		{
			// This ability is using the secondary effect of a multi-weapon. We need to apply a mod to use the alt sound
			// range in place of the primary range.
			SoundRangeModifier += (MultiWeaponTemplate.iAltSoundRange - MultiWeaponTemplate.iSoundRange);
		}
	}

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	if (WeaponTemplate != none)
	{
		WeaponUpgrades = Weapon.GetMyWeaponUpgradeTemplates();
		for (k = 0; k < WeaponUpgrades.Length; k++)
		{
			switch (WeaponUpgrades[k].DataName)
			{
				case 'FreeKillUpgrade_Bsc':
					SoundRangeModifier = -(class'X2Item_DefaultWeaponMods_LW'.default.BASIC_SUPPRESSOR_SOUND_REDUCTION_METERS 
						+ (XComHQ.bEmpoweredUpgrades ? class'X2Item_DefaultWeaponMods_LW'.default.SUPPRESSOR_SOUND_REDUCTION_EMPOWER_BONUS : 0));
					break;
				case 'FreeKillUpgrade_Adv':
					SoundRangeModifier = -(class'X2Item_DefaultWeaponMods_LW'.default.ADVANCED_SUPPRESSOR_SOUND_REDUCTION_METERS
						+ (XComHQ.bEmpoweredUpgrades ? class'X2Item_DefaultWeaponMods_LW'.default.SUPPRESSOR_SOUND_REDUCTION_EMPOWER_BONUS : 0));
					break;
				case 'FreeKillUpgrade_Sup':
					SoundRangeModifier = -(class'X2Item_DefaultWeaponMods_LW'.default.ELITE_SUPPRESSOR_SOUND_REDUCTION_METERS
						+ (XComHQ.bEmpoweredUpgrades ? class'X2Item_DefaultWeaponMods_LW'.default.SUPPRESSOR_SOUND_REDUCTION_EMPOWER_BONUS : 0));
					break;
				default: break;
			}
		}
	}

	SoundRangeModifier += default.SOUND_RANGE_DIFFICULTY_MODIFIER[`TACTICALDIFFICULTYSETTING];

	return int (FMax (SoundRangeModifier, 0.0));
}

static function int ProcessReflexActionsForUnit(
	XComGameState_Unit Unit,
	bool IsYellowAlert,
	float Chance,
	int NumSuccessfulReflexActions)
{
	if (class'Utilities_LW'.default.REFLEX_ACTION_CHANCE_REDUCTION > 0 && NumSuccessfulReflexActions > 0)
	{
		`LWTrace(GetFuncName() $ ": Reducing reflex chance due to " $ NumSuccessfulReflexActions $ " successes");
		Chance -= NumSuccessfulReflexActions * class'Utilities_LW'.default.REFLEX_ACTION_CHANCE_REDUCTION;
	}

	if (`SYNC_FRAND_STATIC() < Chance)
	{
		// Award the unit a special kind of action point. These are more restricted than standard action points.
		// See the 'OffensiveReflexAbilities' and 'DefensiveReflexAbilities' arrays in LW_Overhaul.ini for the list
		// of abilities that have been modified to allow these action points.
		//
		// Damaged units, and units in green (if enabled) get 'defensive' action points. Others get 'offensive' action points.
		if (Unit.IsInjured() || !IsYellowAlert)
		{
			`LWTrace(GetFuncName() $ ": Awarding an extra defensive action point to unit " $ Unit.GetMyTemplateName());
			Unit.ActionPoints.AddItem(class'Utilities_LW'.const.DefensiveReflexAction);
		}
		else
		{
			`LWTrace(GetFuncName() $ ": Awarding an extra offensive action point to unit " $ Unit.GetMyTemplateName());
			Unit.ActionPoints.AddItem(class'Utilities_LW'.const.OffensiveReflexAction);
		}

		return 1;
	}
	else
	{
		return 0;
	}
}

// Prevent Needle grenades from blowing up the corpse.
static function EventListenerReturn OnKilledByExplosion(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComLWTuple				OverrideTuple;
	local XComGameState_Unit		Killer, Target;

	OverrideTuple = XComLWTuple(EventData);
	`assert(OverrideTuple != none);

	Target = XComGameState_Unit(EventSource);
	`assert(Target != none);
	`assert(OverrideTuple.Id == 'OverrideKilledbyExplosion');

	Killer = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(OverrideTuple.Data[1].i));

	if (OverrideTuple.Data[0].b && Killer.HasSoldierAbility('NeedleGrenades', true))
	{
		OverrideTuple.Data[0].b = false;
	}

	return ELR_NoInterrupt;
}

// Additional tactical mission cleanup, including Field Surgeon, turret wreck
// recovery and transferring Full Override MECs to havens.
static function EventListenerReturn OnCleanupTacticalMission(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
    local XComGameState_BattleData BattleData;
    local XComGameState_Unit Unit;
    local XComGameStateHistory History;
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;
	local bool AwardWrecks;

    History = `XCOMHISTORY;
    BattleData = XComGameState_BattleData(EventData);
    BattleData = XComGameState_BattleData(NewGameState.GetGameStateForObjectID(BattleData.ObjectID));

	// If we completed this mission with corpse recovery, you get the wreck/loot from any turret
	// left on the map as well as any Mastered unit that survived but is not eligible to be
	// transferred to a haven.
	AwardWrecks = BattleData.AllTacticalObjectivesCompleted();

    if (AwardWrecks)
    {
        // If we have completed the tactical objectives (e.g. sweep) we are collecting corpses.
        // Generate wrecks for each of the turrets left on the map that XCOM didn't kill before
        // ending the mission.
        foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
        {
            if (Unit.IsTurret() && !Unit.IsDead())
            {
                // We can't call the RollForAutoLoot() function here because we have a pending
                // gamestate with a modified BattleData already. Just add a corpse to the list
                // of pending auto loot.
                BattleData.AutoLootBucket.AddItem('CorpseAdventTurret');
            }
        }
    }

	// Handle effects that can only be performed at mission end:
	//
	// Handle full override mecs. Look for units with a full override effect that are not dead
	// or captured. This is done here instead of in an OnEffectRemoved hook, because effect removal
	// isn't fired when the mission ends on a sweep, just when they evac. Other effect cleanup
	// typically happens in UnitEndedTacticalPlay, but since we need to update the haven gamestate
	// we can't use that: we don't get a reference to the current XComGameState being submitted.
	// This works because the X2Effect_TransferMecToOutpost code sets up its own UnitRemovedFromPlay
	// event listener, overriding the standard one in XComGameState_Effect, so the effect won't get
	// removed when the unit is removed from play and we'll see it here.
	//
	// Handle Field Surgeon. We can't let the effect get stripped on evac via OnEffectRemoved because
	// the surgeon themself may die later in the mission. We need to wait til mission end and figure out
	// which effects to apply.
	//
	// Also handle units that are still living but are affected by mind-control - if this is a corpse
	// recovering mission, roll their auto-loot so that corpses etc. are granted despite them not actually
	// being killed.

	foreach History.IterateByClassType(class'XComGameState_Unit', Unit)
	{
		// LWOTC: Manual cleanup for haven advisers and any other soldiers that are
		// "spawned from the Avenger". Bit of a hack to avoid further changes to the
		// highlander. This just duplicates code that's in
		// X2TacticalGameRuleSet.CleanupTacticalMission().
		if (Unit.bSpawnedFromAvenger)
		{
			if (BattleData.AllTacticalObjectivesCompleted() || (HasAnyTriadObjective(BattleData) && BattleData.AllTriadObjectivesCompleted()))
			{
				Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
				Unit.RemoveUnitFromPlay();
				Unit.bBleedingOut = false;
				Unit.bUnconscious = false;

				if (Unit.IsDead())
				{
					Unit.bBodyRecovered = true;
				}
			}
			else if (!BattleData.AllTacticalObjectivesCompleted() && !(HasAnyTriadObjective(BattleData) && BattleData.AllTriadObjectivesCompleted()))
			{
				// Missions that don't result in recovery of XCOM bodies should ensure that
				// mind controlled soldiers are captured.
				if (Unit.IsMindControlled())
				{
					Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', Unit.ObjectID));
					Unit.bCaptured = true;
				}
			}
		}

		if(Unit.IsAlive() && !Unit.bCaptured)
		{
			foreach Unit.AffectedByEffects(EffectRef)
			{
				EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
				if (EffectState.GetX2Effect().EffectName == class'X2Effect_TransferMecToOutpost'.default.EffectName)
				{
					X2Effect_TransferMecToOutpost(EffectState.GetX2Effect()).AddMECToOutpostIfValid(EffectState, Unit, NewGameState, AwardWrecks);
				}
				else if (EffectState.GetX2Effect().EffectName == class'X2Effect_FieldSurgeon'.default.EffectName)
				{
					X2Effect_FieldSurgeon(EffectState.GetX2Effect()).ApplyFieldSurgeon(EffectState, Unit, NewGameState);
				}
				else if (EffectState.GetX2Effect().EffectName == class'X2Effect_GreaterPadding'.default.EffectName)
				{
					X2Effect_GreaterPadding(EffectState.GetX2Effect()).ApplyGreaterPadding(EffectState, Unit, NewGameState);
				}
					
				else if (EffectState.GetX2Effect().EffectName == class'X2Effect_MindControl'.default.EffectName && AwardWrecks)
				{
					Unit.RollForAutoLoot(NewGameState);

					// Super hacks for andromedon, since only the robot drops a corpse.
					if (Unit.GetMyTemplateName() == 'Andromedon')
					{
						BattleData.AutoLootBucket.AddItem('CorpseAndromedon');
					}
				}
			}
		}
	}

    return ELR_NoInterrupt;
}

// Mark a mission as having body and loot recovery if it has triad objectives
// and all its triad objectives have been completed.
static function EventListenerReturn OnOverrideBodyAndLootRecovery(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_BattleData BattleData;
	
	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	BattleData = XComGameState_BattleData(EventSource);
	if (BattleData == none)
	{
		`REDSCREEN("BattleData not provided with 'OverrideBodyAndLootRecovery' event");
		return ELR_NoInterrupt;
	}

	Tuple.Data[0].b = (HasAnyTriadObjective(BattleData) && BattleData.AllTriadObjectivesCompleted()) || Tuple.Data[0].b;

	return ELR_NoInterrupt;
}

static function bool HasAnyTriadObjective(XComGameState_BattleData Battle)
{
	local int ObjectiveIndex;

	for( ObjectiveIndex = 0; ObjectiveIndex < Battle.MapData.ActiveMission.MissionObjectives.Length; ++ObjectiveIndex )
	{
		if( Battle.MapData.ActiveMission.MissionObjectives[ObjectiveIndex].bIsTriadObjective )
		{
			return true;
		}
	}

	return false;
}

// Make sure reinforcements arrive in red alert if any aliens on the map are
// already in red alert.
static function EventListenerReturn AddPerfectInfoFlyover(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
	local XComGameState NewGameState;
	local AvailableTarget Target;
	local XComGameState_Unit UnitState;
	local XComGameState_Ability AbilityState;
	local XComGameStateContext_Ability Context;
	local X2AbilityToHitCalc_StandardAim ToHitCalc;
	local XComGameState_LastShotBreakdown LastShotBreakdown;

	//ActivatedAbilityStateContext = XComGameStateContext_Ability(GameState.GetContext());
	AbilityState = XComGameState_Ability(EventData);
	UnitState = XComGameState_Unit(EventSource);
	ToHitCalc = X2AbilityToHitCalc_StandardAim(AbilityState.GetMyTemplate().AbilityToHitCalc);
	if (ToHitCalc == None)
	{
		// Ignore any abilities that don't use StandardAim
		return ELR_NoInterrupt;
	}

	Context = XComGameStateContext_Ability(GameState.GetContext());

	if (Context.InterruptionStatus != eInterruptionStatus_Interrupt)
	{
		// We want to use the shot breakdown from the last interrupt state
		// (because Steady Weapon loses its buff just before the resume state)
		// but we only want one flyover. If we add the flyover to the interrupt
		// state, it will be copied to the resume state and *both* will execute
		// and you'll see the flyover twice.
		//
		// However, we do want to add the visualization for eInterruptionStatus_None.
		GameState.GetContext().PostBuildVisualizationFn.AddItem(PIFlyover_BuildVisualization);
	}

	if (Context.InterruptionStatus == eInterruptionStatus_Resume)
	{
		// Don't build the shot breakdown info for resumed contexts, primarily because
		// Steady Weapon loses its buff by this point.
		return ELR_NoInterrupt;
	}

	// Add the ID of the last shotbreakdown to the unit state so that the
	// flyover visualisation actually has a reference it can use to get the
	// shot breakdown info it needs.
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Record Last Shot Breakdown");
	LastShotBreakdown = XComGameState_LastShotBreakdown(NewGameState.CreateNewStateObject(class'XComGameState_LastShotBreakdown'));
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
	UnitState.SetUnitFloatValue('LW_LastShotBreakdownId', LastShotBreakdown.ObjectID, eCleanup_BeginTactical);
	
	// Calculate the shotbreakdown from this interrupt state and save it
	// to game state, from where the flyover visualisation can pick it up.
	Target.PrimaryTarget = Context.InputContext.PrimaryTarget;
	ToHitCalc.GetShotBreakdown(AbilityState, Target, LastShotBreakdown.ShotBreakdown);
	
	`TACTICALRULES.SubmitGameState(NewGameState);
	return ELR_NoInterrupt;
}

static function PIFlyover_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory				History;
	local XComGameStateContext_Ability		Context;
	local VisualizationActionMetadata		EmptyTrack, BuildTrack;
	local XComGameState_Unit				UnitState, ShooterState;
	local X2Action_PlaySoundAndFlyOver		MessageAction;
	local ShotBreakdown						TargetBreakdown;
	local XComGameState_LastShotBreakdown	LastShotBreakdown;
	local UnitValue							ShotBreakdownValue;

	History = `XCOMHISTORY;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	ShooterState = XComGameState_Unit(History.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID));
	if (!ShooterState.GetUnitValue('LW_LastShotBreakdownId', ShotBreakdownValue))
	{
		return;
	}
	LastShotBreakdown = XComGameState_LastShotBreakdown(History.GetGameStateForObjectID(int(ShotBreakdownValue.fValue)));
	TargetBreakdown = LastShotBreakdown.ShotBreakdown;

	BuildTrack = EmptyTrack;
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(Context.InputContext.PrimaryTarget.ObjectID));
	BuildTrack.StateObject_NewState = UnitState;
	BuildTrack.StateObject_OldState = UnitState;
	BuildTrack.VisualizeActor = UnitState.GetVisualizer();
	MessageAction = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyOver'.static.AddToVisualizationTree(BuildTrack, Context, false, BuildTrack.LastActionAdded));
	MessageAction.SetSoundAndFlyOverParameters(None, GetHitChanceText(TargetBreakdown), '', eColor_Gray,, 5.0f);
}

// Return with chance string
static function string GetHitChanceText(ShotBreakdown TargetBreakdown)
{
	local string HitText;
	local string GrazeText;
	local string CritText;
	local string ReturnText;
	local int SomeDamageHitChance;

	HitText = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'XLocalizedData'.default.HitLabel);
	CritText = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(class'XLocalizedData'.default.CritLabel);
	GrazeText = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(
		class'X2TacticalGameRulesetDataStructures'.default.m_aAbilityHitResultStrings[eHit_Graze]);

	SomeDamageHitChance = TargetBreakdown.ResultTable[eHit_Success] + TargetBreakdown.ResultTable[eHit_Crit] + TargetBreakdown.ResultTable[eHit_Graze];

	ReturnText = (ReturnText @ HitText @ SomeDamageHitChance $ "% ");

	//Add Dodge Chance to ReturnText
	ReturnText = (ReturnText @ GrazeText @ TargetBreakdown.ResultTable[eHit_Graze] $ "% ");

	//Add Crit Chance to ReturnText
	ReturnText = (ReturnText @ CritText @ TargetBreakdown.ResultTable[eHit_Crit] $ "% ");

	return ReturnText;
}

// Make sure reinforcements arrive in red alert if any aliens on the map are
// already in red alert.
//
// This listener also increases the detection radius for enemy units when they
// enter yellow or red alert and clears the effect that restores their sight
// radius (since that effect breaks the Low Visibility sit rep).
//
// Note that the implementation is based on the Compound Rescure mission's
// security levels, but it could probably also be implemented by adding a
// persistent stat change to the units.
static function EventListenerReturn OnAbilityActivated(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
    local XComGameState_Ability ActivatedAbilityState;
	local XComGameState_LWReinforcements Reinforcements;
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	local float DetectionRadius;
	local int Modifier;

	//ActivatedAbilityStateContext = XComGameStateContext_Ability(GameState.GetContext());
	ActivatedAbilityState = XComGameState_Ability(EventData);
	UnitState = XComGameState_Unit(EventSource);
	if (ActivatedAbilityState.GetMyTemplate().DataName == 'RedAlert')
	{
		`LWTrace("Max detection radius for " $ UnitState.GetMyTemplateName() $ " = " $UnitState.GetMaxStat(eStat_DetectionRadius));
		`LWTrace("Current detection radius for " $ UnitState.GetMyTemplateName() $ " = " $UnitState.GetCurrentStat(eStat_DetectionRadius));
		DetectionRadius = UnitState.GetBaseStat(eStat_DetectionRadius);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("On Red Alert Activated");
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

		Modifier = default.RED_ALERT_DETECTION_DIFFICULTY_MODIFIER[`TACTICALDIFFICULTYSETTING];
		if (class'Utilities_LW'.static.GetPreviousAlertLevel(UnitState) == `ALERT_LEVEL_YELLOW)
		{
			// If the unit was previously in yellow alert, then its detection radius
			// already has that modifier applied, so don't apply it twice!
			Modifier -= default.YELLOW_ALERT_DETECTION_DIFFICULTY_MODIFIER[`TACTICALDIFFICULTYSETTING];
		}

		`LWTrace("[Red Alert] Modifying detection radius for " $ UnitState.GetMyTemplateName() $ " to " $ int(DetectionRadius + Modifier));
		UnitState.SetBaseMaxStat(eStat_DetectionRadius, int(DetectionRadius + Modifier));

		Reinforcements = XComGameState_LWReinforcements(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_LWReinforcements', true));
		if (Reinforcements != none && !Reinforcements.RedAlertTriggered)
		{
			Reinforcements = XComGameState_LWReinforcements(NewGameState.ModifyStateObject(class'XComGameState_LWReinforcements', Reinforcements.ObjectID));
			Reinforcements.RedAlertTriggered = true;
		}

		// Clear the stat restoration effect that gets applied when units enter
		// red or yellow alert, since it overrides the sight radius changes applied
		// by the Low Visibility sit rep.
		RemoveSightRadiusRestorationEffect(UnitState, NewGameState);

		`TACTICALRULES.SubmitGameState(NewGameState);
	}
	else if (ActivatedAbilityState.GetMyTemplate().DataName == 'YellowAlert')
	{
		DetectionRadius = UnitState.GetBaseStat(eStat_DetectionRadius);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("On Yellow Alert Activated");
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

		`LWTrace("[Yellow Alert] Modifying detection radius for " $ UnitState.GetMyTemplateName() $
			" to " $ int(DetectionRadius + default.YELLOW_ALERT_DETECTION_DIFFICULTY_MODIFIER[`TACTICALDIFFICULTYSETTING]));
		UnitState.SetBaseMaxStat(eStat_DetectionRadius, int(DetectionRadius + default.YELLOW_ALERT_DETECTION_DIFFICULTY_MODIFIER[`TACTICALDIFFICULTYSETTING]));

		// Clear the stat restoration effect that gets applied when units enter
		// red or yellow alert, since it overrides the sight radius changes applied
		// by the Low Visibility sit rep.
		RemoveSightRadiusRestorationEffect(UnitState, NewGameState);

		`TACTICALRULES.SubmitGameState(NewGameState);
	}
	return ELR_NoInterrupt;
}

private static function RemoveSightRadiusRestorationEffect(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local X2Effect_PersistentStatChangeRestoreDefault CurrentEffect;
	local XComGameStateHistory History;
	local XComGameState_Effect EffectState;
	local StateObjectReference EffectRef;

	History = `XCOMHISTORY;
	foreach UnitState.AffectedByEffects(EffectRef)
	{
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(EffectRef.ObjectID));
		CurrentEffect = X2Effect_PersistentStatChangeRestoreDefault(EffectState.GetX2Effect());
		if (CurrentEffect != none && CurrentEffect.StatTypesToRestore.Find(eStat_SightRadius) != INDEX_NONE)
		{
			EffectState.RemoveEffect(NewGameState, NewGameState, true);
			break;
		}
	}
}

// This listener clears the `eCleanup_BeginTurn` unit values on units that
// swap teams. This fixes a problem where those unit values don't get cleared
// when team swapping happens after the turn begins.
static protected function EventListenerReturn ClearUnitStateValues(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none) return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	UnitState.CleanupUnitValues(eCleanup_BeginTurn);

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn RollForPerTurnWillLoss(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComGameStateHistory History;
	local XComGameState_Player PlayerState;
	local XComGameStateContext_WillRoll WillRollContext;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference SquadRef;
	local XComGameState_Unit SquadUnit;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class' XComGameState_HeadquartersXCom'));
	PlayerState = XComGameState_Player(EventData);

	// We only want to lose Will every n turns, so skip other turns
	if (PlayerState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;

	// Remove Will from all squad members
	foreach XComHQ.Squad(SquadRef)
	{
		SquadUnit = XComGameState_Unit(History.GetGameStateForObjectID(SquadRef.ObjectID));

		// Check whether this unit should lose Will this turn (depends on whether
		// they are Tired or not)
		if ((SquadUnit.GetMentalState() != eMentalState_Tired && PlayerState.PlayerTurnCount % default.NUM_TURNS_FOR_WILL_LOSS != 0) ||
			(SquadUnit.GetMentalState() == eMentalState_Tired && PlayerState.PlayerTurnCount % default.NUM_TURNS_FOR_TIRED_WILL_LOSS != 0))
		{
			continue;
		}

		// Unit should lose Will this turn, so do it
		if (class'XComGameStateContext_WillRoll'.static.ShouldPerformWillRoll(default.PerTurnWillRollData, SquadUnit))
		{
			`LWTrace("Performing Will roll at end of turn");
			WillRollContext = class'XComGameStateContext_WillRoll'.static.CreateWillRollContext(SquadUnit, 'PlayerTurnEnd',, false);
			WillRollContext.DoWillRoll(default.PerTurnWillRollData);
			WillRollContext.Submit();
		}
	}

	return ELR_NoInterrupt;
}

static protected function EventListenerReturn CheckForDifficultMissionCompleted(
	Object EventData,
	Object EventSource,
	XComGameState GameState,
	Name Event,
	Object CallbackData)
{
	return CheckForMissionCompleted(
		'DifficultMissionCompleted',
		default.MISSION_DIFFICULTY_THRESHOLDS[0],
		default.MISSION_DIFFICULTY_THRESHOLDS[1] - 1,
		GameState);
}

static protected function EventListenerReturn CheckForVeryDifficultMissionCompleted(
	Object EventData,
	Object EventSource,
	XComGameState GameState,
	Name Event,
	Object CallbackData)
{
	return CheckForMissionCompleted(
		'VeryDifficultMissionCompleted',
		default.MISSION_DIFFICULTY_THRESHOLDS[1],
		999,
		GameState);
}

static protected function EventListenerReturn CheckForMissionCompleted(
	name APTemplateName,
	int MinDifficulty,
	int MaxDifficulty,
	XComGameState GameState)
{
	local XComGameStateContext_AbilityPointEvent EventContext;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_BattleData BattleData;
	local X2AbilityPointTemplate APTemplate;
	local X2SitRepEffectTemplate SitRepEffectTemplate;
	local int Difficulty, Roll;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	APTemplate = class'X2EventListener_AbilityPoints'.static.GetAbilityPointTemplate(APTemplateName);

	if (APTemplate == none || BattleData == none)
		return ELR_NoInterrupt;

	// Only trigger an AP award if the tactical game has ended with a player win
	if (!`TACTICALRULES.HasTacticalGameEnded() && BattleData.bLocalPlayerWon && !BattleData.bMissionAborted)
		return ELR_NoInterrupt;

	// Is the mission difficulty right for this AP award?
	Difficulty = 0;
	foreach class'X2SitRepTemplateManager'.static.IterateEffects(class'X2SitRepEffectTemplate', SitRepEffectTemplate, BattleData.ActiveSitReps)
	{
		Difficulty += SitRepEffectTemplate.DifficultyModifier;
	}

	if (Difficulty < MinDifficulty || Difficulty > MaxDifficulty)
		return ELR_NoInterrupt;

	Roll = class'Engine'.static.GetEngine().SyncRand(100, "RollForAbilityPoint");
	if (Roll < APTemplate.Chance)
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

		EventContext = XComGameStateContext_AbilityPointEvent(class'XComGameStateContext_AbilityPointEvent'.static.CreateXComGameStateContext());
		EventContext.AbilityPointTemplateName = APTemplate.DataName;

		// The AP event system requires a unit, so just given it the first member
		// of the squad. TODO: Could feasibly make this the officer or highest-ranked
		// soldier to make it look a little less weird. Alternatively, could make
		// a highlander change to eliminate this requirement.
		EventContext.AssociatedUnitRef = XComHQ.Squad[0];
		EventContext.TriggerHistoryIndex = GameState.GetContext().GetFirstStateInEventChain().HistoryIndex;

		`TACTICALRULES.SubmitGameStateContext(EventContext);
	}
}

static protected function EventListenerReturn BindR3ToPlaceDelayedEvacZone(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;

	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	// Bind R3 controller button to this LW2/LWOTC ability
	Tuple.Data[1].n = 'PlaceDelayedEvacZone';

	return ELR_NoInterrupt;
}

static function CHEventListenerTemplate CreateUIFocusOverride()
{
	local CHEventListenerTemplate Template;

	`LWTrace("Registering evac event listeners");

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'YellowAlertListeners');
	//Needed because chain lightning uses focus for its targeting now
	Template.AddCHEvent('OverrideUnitFocusUI', HideFocusOnAssaults, ELD_Immediate, GetListenerPriority());

	Template.RegisterInTactical = true;

	return Template;
}


static protected function EventListenerReturn HideFocusOnAssaults(
	Object EventData,
	Object EventSource,
	XComGameState NewGameState,
	Name InEventID,
	Object CallbackData)
{
	local XComLWTuple Tuple;
	local XComGameState_Unit Unit;


	Unit = XComGameState_Unit(EventSource);
	Tuple = XComLWTuple(EventData);
	if (Tuple == none)
		return ELR_NoInterrupt;

	if(Unit.GetSoldierClassTemplate() != none && Unit.GetSoldierClassTemplate().DataName == 'LWS_Assault')
	{
		// Hide focus on assaults
		Tuple.Data[0].b = false;
	}

	return ELR_NoInterrupt;
}