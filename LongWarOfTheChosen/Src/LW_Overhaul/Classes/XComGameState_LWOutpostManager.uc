//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_LWOutpostManager.uc
//  AUTHOR:  tracktwo / Pavonis Interactive
//  PURPOSE: This singleton object manages rebel outposts for the mod
//---------------------------------------------------------------------------------------

class XComGameState_LWOutpostManager extends XComGameState_BaseObject config(LW_Outposts);

var array<StateObjectReference> Outposts;
var bool bNeedsAttention;

// The name of the resistance comms tech that triggers availability of the
// resistance outpost management interfaces.
const nmResistanceCommunicationsTech = 'ResistanceCommunications';

// The name of the sub-menu for resistance management
const nmResistanceManagementSubMenu = 'LW_ResistanceManagementMenu';

var localized string LabelCQ_ResistanceManagement;
var localized string TooltipCQ_ResistanceManagement;

static function XComGameState_LWOutpostManager GetOutpostManager(optional bool AllowNULL = false)
{
	return XComGameState_LWOutpostManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_LWOutpostManager', AllowNULL));
}

function bool NeedsAttention()
{
	return bNeedsAttention;
}

function SetNeedsAttention()
{
	bNeedsAttention = true;
}

function ClearNeedsAttention()
{
	bNeedsAttention = false;
}

static function CreateOutpostManager(optional XComGameState StartState)
{
	local XComGameState_LWOutpostManager OutpostMgr;
	local XComGameState NewGameState;

	if (GetOutpostManager(true) != none)
		return;

	if(StartState != none)
	{
		NewGameState = StartState;
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating LW Rebel Outpost Manager Singleton");
	}

	OutpostMgr = XComGameState_LWOutpostManager(NewGameState.CreateStateObject(class'XComGameState_LWOutpostManager'));
	NewGameState.AddStateObject(OutpostMgr);
	OutpostMgr.CreateOutposts(NewGameState);

	if (StartState == none)
	{
		`XCOMHISTORY.AddGameStateToHistory(NewGameState);
	}
}

protected function CreateOutposts(XComGameState NewState)
{
	local XComGameState_WorldRegion Region;
	local XComGameStateHistory History;
	local XComGameState_LWOutpost Outpost;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_WorldRegion', Region)
	{
		Outpost = class'XComGameState_LWOutpost'.static.CreateOutpost(NewState, Region);
		Outposts.AddItem(Outpost.GetReference());
	}
}

function XComGameState_LWOutpost GetOutpostForRegion(XComGameState_WorldRegion Region)
{
	local StateObjectReference Ref;
	local XComGameState_LWOutpost Outpost;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	foreach Outposts(Ref)
	{
		Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(Ref.ObjectID));
		if (Outpost.Region.ObjectID == Region.ObjectID)
		{
			return Outpost;
		}
	}

	return none;
}

function XComGameState_WorldRegion GetRegionForOutpost(XComGameState_LWOutpost Outpost)
{
	local XComGameState_WorldRegion Region;

	Region = XComGameState_WorldRegion(`XCOMHISTORY.GetGameStateForObjectID(Outpost.Region.ObjectID));
	return Region;
}

function XComGameState_LWOutpost GetOutpostForStaffSlot(StateObjectReference StaffSlotRef)
{
	local StateObjectReference Ref;
	local XComGameState_LWOutpost Outpost;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	foreach Outposts(Ref)
	{
		Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(Ref.ObjectID));
		if (Outpost.StaffSlot.ObjectID == StaffSlotRef.ObjectID)
		{
			return Outpost;
		}
	}

	return none;
}


////
// On game load setup
////

// After beginning a game, set up the rebel outpost management interface.
function SetupOutpostInterface()
{
	EnableResistanceManagementMenu();
}

function SetOutpostNeedsAttention(bool Enable)
{
	local XComGameState NewGameState;
	local XComGameState_FacilityXCom CICFacility;
	local XComGameState_LWOutpostManager NewManager;
	
	if (Enable != NeedsAttention())
	{
		// Set the rebel outpost manager as needing attention (or not)
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set rebel outpost needs attention");
		NewManager = XComGameState_LWOutpostManager(NewGameState.CreateStateObject(class'XComGameState_LWOutpostManager', self.ObjectID));
		NewGameState.AddStateObject(NewManager);
		if (Enable)
		{
			NewManager.SetNeedsAttention();
		}
		else
		{
			NewManager.ClearNeedsAttention();
		}

		// And update the CIC state to also require attention if necessary.
		// We don't need to clear it as clearing happens automatically when the 
		// facility is selected.
		CICFacility = `XCOMHQ.GetFacilityByName('CommandersQuarters');
		if (Enable && !CICFacility.NeedsAttention())
		{
			CICFacility = XComGameState_FacilityXCom(NewGameState.CreateStateObject(class'XComGameState_FacilityXCom', CICFacility.ObjectID));
			CICFacility.TriggerNeedsAttention();
			NewGameState.AddStateObject(CICFacility);
		}

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
}

// Enable the outpost menu
function EnableResistanceManagementMenu(optional bool forceAlert = false)
{
	local string AlertIcon;
	local UIAvengerShortcutSubMenuItem SubMenu;
	local UIAvengerShortcuts Shortcuts;

	if (NeedsAttention() || forceAlert)
	{
		AlertIcon = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.HTML_AttentionIcon, 20, 20, 0) $" ";
	}

	ShortCuts = `HQPRES.m_kAvengerHUD.Shortcuts;

	if (ShortCuts.FindSubMenu(eUIAvengerShortcutCat_CommandersQuarters, nmResistanceManagementSubMenu, SubMenu))
	{
		// It already exists: just update the label to adjust the alert state (if necessary).
		SubMenu.Message.Label = AlertIcon $ LabelCQ_ResistanceManagement;
		Shortcuts.UpdateSubMenu(eUIAvengerShortcutCat_CommandersQuarters, SubMenu);
	}
	else
	{
		SubMenu.Id = nmResistanceManagementSubMenu;
		SubMenu.Message.Label = AlertIcon $ LabelCQ_ResistanceManagement;
		SubMenu.Message.Description = TooltipCQ_ResistanceManagement;
		SubMenu.Message.Urgency = eUIAvengerShortcutMsgUrgency_Low;
		SubMenu.Message.OnItemClicked = GoToResistanceManagement;
		Shortcuts.AddSubMenu(eUIAvengerShortcutCat_CommandersQuarters, SubMenu);
	}
}

simulated function GoToResistanceManagement(optional StateObjectReference Facility)
{
	local UIResistanceManagement_LW TempScreen;
	local XComHQPresentationLayer HQPres;
	local UIAvengerShortcutSubMenuItem SubMenu;
	local UIAvengerShortcuts Shortcuts;

	HQPres = `HQPRES;

	// Set the rebel outpost game state as not needing attention.
	SetOutpostNeedsAttention(false);

	// Clear the attention label from the submenu item.
	ShortCuts = HQPres.m_kAvengerHUD.Shortcuts;
	Shortcuts.FindSubMenu(eUIAvengerShortcutCat_CommandersQuarters, nmResistanceManagementSubMenu, SubMenu);
	SubMenu.Message.Label = LabelCQ_ResistanceManagement;
	Shortcuts.UpdateSubMenu(eUIAvengerShortcutCat_CommandersQuarters, SubMenu);

	if(HQPres.ScreenStack.IsNotInStack(class'UIResistanceManagement_LW'))
	{
		TempScreen = HQPres.Spawn(class'UIResistanceManagement_LW', HQPres);
		HQPres.ScreenStack.Push(TempScreen, HQPres.Get3DMovie());
	}
}

// Rai - Added function to enable entering the haven management screen from geoscape directly
static function OpenResistanceManagementScreen(optional StateObjectReference ActionToFocus)
{
	local UIResistanceManagement_LW TempScreen;
	local XComHQPresentationLayer HQPres;

	HQPres = `HQPRES;
	if (HQPres.ScreenStack.GetFirstInstanceOf(class'UIResistanceManagement_LW') != none) return;

	TempScreen = HQPres.Spawn(class'UIResistanceManagement_LW', HQPres);
	//TempScreen.ActionToShowOnInitRef = ActionToFocus;
	HQPres.ScreenStack.Push(TempScreen);

}

function bool IsUnitAHavenLiaison(StateObjectReference UnitRef)
{
	local XComGameState_LWOutpost Outpost;
	local StateObjectReference OutpostRef;

	foreach Outposts(OutpostRef)
	{
		Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));
		if (Outpost.GetLiaison().ObjectID == UnitRef.ObjectID)
			return true;
	}

	return false;
}

function bool IsUnitALockedHavenLiaison(StateObjectReference UnitRef)
{
	local XComGameState_LWOutpost Outpost;
	local StateObjectReference OutpostRef;

	foreach Outposts(OutpostRef)
	{
		Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));
		if (Outpost.GetLiaison().ObjectID == UnitRef.ObjectID && !Outpost.CanLiaisonBeMoved())
			return true;
	}

	return false;
}

function XComGameState_WorldRegion GetRegionForLiaison(StateObjectReference UnitRef)
{
	local XComGameState_LWOutpost Outpost;
	local StateObjectReference OutpostRef;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	foreach Outposts(OutpostRef)
	{
		Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));
		if (Outpost.GetLiaison().ObjectID == UnitRef.ObjectID)
			return GetRegionForOutpost(Outpost);
	}

	return none;
}

function XComGameState_WorldRegion GetRegionForRebel(StateObjectReference Rebel)
{
	local XComGameState_LWOutpost Outpost;
	local StateObjectReference OutpostRef;
	local XComGameStateHistory History;
	local int i;

	History = `XCOMHISTORY;

	foreach Outposts(OutpostRef)
	{
		Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));
		i = Outpost.Rebels.Find('Unit', Rebel);
		if (i != -1)
			return GetRegionForOutpost(Outpost);
	}

	return none;
}


function UpdateOutpostsPostMission()
{
	local XComGameState_MissionSite Mission;
	local XComGameState_WorldRegion Region;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_LWOutpost Outpost;
	local XComGameStateHistory History;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
	XComHQ = `XCOMHQ;

	Mission = XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));
	Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(Mission.Region.ObjectID));

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Outpost post-mission");
	Outpost = GetOutpostForRegion(Region);
	if (Outpost == none)
		return;
	Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));
	NewGameState.AddStateObject(Outpost);
	
	if (!Outpost.UpdatePostMission(Mission, NewGameState))
		 NewGameState.PurgeGameStateForObjectID(Outpost.ObjectID);

	if (NewGameState.GetNumGameStateObjects() > 0)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);

}
