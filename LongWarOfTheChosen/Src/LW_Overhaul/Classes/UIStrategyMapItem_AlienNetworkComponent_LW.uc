//---------------------------------------------------------------------------------------
//  FILE:    UIStrategyMapItem_AlienNetworkComponent_LW
//  AUTHOR:  Joey Martinez -- 05/06/2019
//  PURPOSE: This file represents an alien network spot on the StrategyMap for Long War of the Chosen.
//           The base game class is being overridden because the infiltration label was not showing
//           up when you sent a squad to infiltrate an alien facility with the base implentation of
//           the parent class.
// 
//           This class' code is a literal copy paste of the UIStrategyMapItem_Mission_LW class so
//           that the alien facility strategy item has the same infiltration mechanics as other missions
//           do. All of the code in this class is unique to this class and does not override any of the
//           parent class behavior.
//
//	KDM : The same controller code found in UIStrategyMapItem_Mission_LW has been implemented here so
//	that alien facilities are 'clickable'. 
//--------------------------------------------------------------------------------------- 

class UIStrategyMapItem_AlienNetworkComponent_LW extends UIStrategyMapItem_AlienNetworkComponent;

var UIScanButton ScanButton;  // used for missions being infiltrated
var UIText InfilPct;
var UIText InfilLabel;

var UIImage SquadImage; // for cases where there is an infiltrating squad
var string CachedImageName;

var UIProgressBar ProgressBar; // used to show remaining time for missions not yet infiltrated

var int InDepth; // tracks depth of mouse in and outs, since it's recording from two possibly overlapping elements (2D and 3D icons)

var localized string strRecon;

var transient bool bScanButtonResized;
var transient float CachedScanButtonWidth;

simulated function UIStrategyMapItem InitMapItem(out XComGameState_GeoscapeEntity Entity)
{
	// override the super so we can always use MI_alienfacility to allow displaying of doom pips
	//super.InitMapItem(Entity);

	local string PinImage;
	// Initialize static data
	InitPanel(Name(Entity.GetUIWidgetName()), 'MI_alienFacility');

	PinImage = Entity.GetUIPinImagePath();
	if (PinImage != "")
	{
		SetImage(PinImage);
	}

	InitFromGeoscapeEntity(Entity);

	ScanButton = Spawn(class'UIScanButton', self).InitScanButton();
	ScanButton.SetButtonIcon("");
	ScanButton.SetDefaultDelegate(OpenInfiltrationMissionScreen);
	ScanButton.SetButtonType(eUIScanButtonType_Default);

	SquadImage = Spawn(class'UIImage', self);
	SquadImage.bAnimateOnInit = false;
	SquadImage.InitImage().SetSize(48, 48);

	InfilPct = Spawn(class'UIText', ScanButton).InitText('InfilPct_LW', "");
	InfilPct.SetWidth(60); 
	InfilPct.SetPosition(154, 3);

	InfilLabel = Spawn(class'UIText', ScanButton).InitText('InfilLabel_LW', "");
	InfilLabel.SetWidth(60); 
	InfilLabel.SetPosition(154 - 5, 23);

	ProgressBar = Spawn(class'UIProgressBar', self).InitProgressBar('MissionInfiltrationProgress', -32, 5, 64, 8, 0.5, eUIState_Normal);

	bScanButtonResized = false;

	InstanceMapItem3DMaterial();

	// KDM : The mission map item's help icon gets in the way of the infiltrating squad icon; the best way to deal with it is to null it.
	// For more information on a similar topic please see the comments in UIStrategyMapItem_Region_LW --> InitMapItem().
	if (`ISCONTROLLERACTIVE)
	{
		ScanButton.mc.SetNull("consoleHint");
	}

	return self;
}

function InstanceMapItem3DMaterial()
{
	local int i;
	local MaterialInterface Mat;
	local MaterialInstanceConstant MIC, NewMIC;

	if (MapItem3D == none)
		return;

	

	for (i = 0; i < MapItem3D.OverworldMeshs[MapItem3D.ROOT_TILE].GetNumElements(); ++i)
	{
		Mat = MapItem3D.GetMeshMaterial(i);
		MIC = MaterialInstanceConstant(Mat);

		// It is possible for there to be MITVs in these slots, so check
		if (MIC != none)
		{
			// If this is not a child MIC, make it one. This is done so that the material updates below don't stomp
			// on each other between units.
			if (InStr(MIC.Name, "MaterialInstanceConstant") == INDEX_NONE)
			{
				NewMIC = new (self) class'MaterialInstanceConstant';
				NewMIC.SetParent(MIC);
				MapItem3D.SetMeshMaterial(i, NewMIC);
				MIC = NewMIC;
			}
		}
	}

}

function UpdateFromGeoscapeEntity(const out XComGameState_GeoscapeEntity GeoscapeEntity)
{
	local int InfiltrationPct, InfiltrationTextColour;
	local float ScanWidth;
	local string InfiltrationPctValue, MissionInfo, MissionTitle;
	local X2MissionTemplate MissionTemplate;
	local XComGameState_LWPersistentSquad InfiltratingSquad;
	local XComGameState_MissionSite MissionState;

	if (!bIsInited)
	{
		return; 
	}

	super(UIStrategyMapItem).UpdateFromGeoscapeEntity(GeoscapeEntity);

	InfiltratingSquad = GetInfiltratingSquad();
	 
	MissionState = GetMission();
	if (InfiltratingSquad != none)
	{
		InfiltrationTextColour = (bIsFocused) ? -1 : eUIState_Normal;

		InfiltrationPct = int(InfiltratingSquad.CurrentInfiltration * 100.0);
		InfiltrationPctValue = string(InfiltrationPct) $ "%";
		
		// KDM : When using a controller, there are 2 general colour states :
		// 1.] This mission map item is selected, so its background is highlighted, and its text should be black.
		// 2.] This mission map item is not selected, so its background is not highlighted, and its text should be normal blue.
		if (`ISCONTROLLERACTIVE)
		{
			// KDM : When using a controller, the infiltration label needs to be continually refreshed according to the map item's selection status.
			// When using a mouse & keyboard, the infiltration label doesn't need to change, so it can be called a single time down below.
			InfilLabel.SetHTMLText(CenterText(class'UIUtilities_Text_LW'.static.AddFontInfoWithColor(strRecon, false, false, , 16, InfiltrationTextColour)));
			InfilPct.SetHTMLText(CenterText(class'UIUtilities_Text_LW'.static.AddFontInfoWithColor(InfiltrationPctValue, false, true, , 20, InfiltrationTextColour)));
		}
		else
		{
			InfilPct.SetHTMLText(CenterText(class'UIUtilities_Text'.static.AddFontInfo(InfiltrationPctValue, false, true, , 20)));
		}
		
		if (!bScanButtonResized)
		{
			MissionTitle = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(InfiltratingSquad.sSquadName);
			MissionTemplate = class'X2MissionTemplateManager'.static.GetMissionTemplateManager().FindMissionTemplate(MissionState.GeneratedMission.Mission.MissionName);
			MissionInfo = class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(MissionTemplate.PostMissionType); 

			ScanButton.SetText(MissionTitle, MissionInfo, " ", " "); // have to leave blank spaces so that Flash will size BG big enough 
			SetLevel(0); // show 0 doom pips

			// KDM : Infiltration label handling for controllers is dealt with up above.
			if (!`ISCONTROLLERACTIVE)
			{
				InfilLabel.SetHTMLText(CenterText(class'UIUtilities_Text'.static.GetSizedText(strRecon, 16)));
			}
			
			bScanButtonResized = true;

			CachedImageName = InfiltratingSquad.GetSquadImagePath();
			SquadImage.LoadImage(CachedImageName);
		}
		ScanButton.DefaultState();
		ScanButton.PulseScanner(false);
		ScanButton.ShowScanIcon(false);
		ScanButton.Realize();

		// but the MC queuing system means that the width isn't set here the first time it's been invoked
		ScanWidth = ScanButton.MC.GetNum("bg._width"); 

		if (ScanWidth != CachedScanButtonWidth)
		{
			InfilPct.SetX(ScanWidth - 60);
			InfilLabel.SetX(ScanWidth - 65);
			ScanButton.SetX(- (ScanWidth/2));
			
			CachedScanButtonWidth = ScanWidth;

			SquadImage.SetPosition(-(ScanWidth/2 + 48), 0);
		}
		if (CachedImageName != InfiltratingSquad.GetSquadImagePath())
		{
			CachedImageName = InfiltratingSquad.GetSquadImagePath();
			SquadImage.LoadImage(CachedImageName);
		}

		ProgressBar.Hide();
	}
	else if (MissionState.MakesDoom())
	{
		SetLevel(MissionState.Doom);
		ProgressBar.Hide();
		ScanButton.Hide();
		bScanButtonResized = false;
	}
	else
	{
		ProgressBar.Show();
		UpdateProgressBar(MissionState);

		ScanButton.Hide();
		SquadImage.Hide();
		bScanButtonResized = false;
	}

	// KDM : Our custom, mission map item, tooltip contains information, like mission expiration and infiltration percentage, which changes over 
	// time; therefore, we need to continously update it. However, there are a few caveats :
	//
	// 1.] Tooltips are not created under normal circumstances for mission map items; therefore, we only need to worry about updating when
	// a controller is being used, and SHOW_MISSION_TOOLTIPS_CTRL is true.
	// 2.] UIStrategyMap stores a single active tooltip, ActiveTooltip, which it associates with the currently selected map item; unfortunately, 
	// UpdateFromGeoscapeEntity() is called regardless of whether this map item is selected or not. Consequently, we don't want this mission
	// map item polluting the tool tip when it is not selected.
	if (GetStrategyMap().SelectedMapItem == self && `ISCONTROLLERACTIVE && class'UIStrategyMapItem_Mission_LW'.default.SHOW_MISSION_TOOLTIPS_CTRL)
	{
		UpdateTooltip();
	}
}

simulated function string CenterText(string Text)
{
	return class'UIUtilities_Text'.static.AlignCenter(Text);
}

simulated function XComGameState_LWPersistentSquad GetInfiltratingSquad()
{
	return `LWSQUADMGR.GetSquadOnMission(GeoscapeEntityRef);
}

simulated function XComGameState_MissionSite GetMission()
{
	return XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(GeoscapeEntityRef.ObjectID));
}

function OpenInfiltrationMissionScreen()
{
	local UIMission_LWLaunchDelayedMission MissionScreen;
	local XComHQPresentationLayer HQPres;
	
	HQPres = `HQPRES;
	MissionScreen = HQPres.Spawn(class'UIMission_LWLaunchDelayedMission', HQPres);
	MissionScreen.MissionRef = GeoscapeEntityRef;
	MissionScreen.bInstantInterp = false;
	MissionScreen = UIMission_LWLaunchDelayedMission(HQPres.ScreenStack.Push(MissionScreen));
}

simulated function OnMouseEvent(int cmd, array<string> args)
{
	if (GetStrategyMap().m_eUIState == eSMS_Flight)
	{
		return;
	}

	switch(cmd) 
	{ 
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
			OnMouseIn();
			break;
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OUT:
			OnMouseOut();
			break;
		// KDM : A mouse click opens a mission's infiltration screen if it is currently being infiltrated.
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_UP:
			MapItemMissionClicked();
			break;
	}
}

// KDM : This code was stripped out of OnMouseEvent() --> FXS_L_MOUSE_UP and placed within a function so that it could be called from both
// 1.] OnMouseEvent() for mouse & keyboard users 2.] OnUnrealCommand() for controller users.
simulated function MapItemMissionClicked()
{
	local XComGameState_GeoscapeEntity GeoscapeEntity;
	local XComGameState_LWPersistentSquad InfiltratingSquad;
	local XComGameStateHistory History;
	
	History = `XCOMHISTORY;
	InfiltratingSquad = GetInfiltratingSquad();
	
	if (InfiltratingSquad == none)
	{
		GeoscapeEntity = XComGameState_GeoscapeEntity(History.GetGameStateForObjectID(GeoscapeEntityRef.ObjectID));
		GeoscapeEntity.AttemptSelectionCheckInterruption();
	}
	else
	{
		OpenInfiltrationMissionScreen();
	}
}

simulated function UpdateProgressBar(XComGameState_MissionSite MissionState)
{
	local int RemainingSeconds;

	if(ProgressBar == none)
		return;

	if(MissionState.ExpirationDateTime.m_iYear < 2100)
	{
		RemainingSeconds = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInSeconds(MissionState.ExpirationDateTime, class'XComGameState_GeoscapeEntity'.static.GetCurrentTime());
		ProgressBar.SetPercent(1.0);
		SetProgressBarColor(RemainingSeconds);
		ProgressBar.Show();
	}
	else
	{
		ProgressBar.SetPercent(0.0);
		ProgressBar.Hide();
	}
}

simulated function SetProgressBarColor(float RemainingSeconds)
{
	local float PercentIdealInfiltration;

	PercentIdealInfiltration = (RemainingSeconds / 3600.0) / class'XComGameState_LWPersistentSquad'.static.GetBaselineHoursToInfiltration(GeoscapeEntityRef);

	if (PercentIdealInfiltration >= 1.0)
	{
		ProgressBar.SetColor(class'UIUtilities_Colors'.const.GOOD_HTML_COLOR);
	} 
	else if(PercentIdealInfiltration >= 0.5)
	{
		ProgressBar.SetColor(class'UIUtilities_Colors'.const.WARNING_HTML_COLOR);
	}
	else if(RemainingSeconds >= 86400.0)
	{
		ProgressBar.SetColor(class'UIUtilities_Colors'.const.WARNING2_HTML_COLOR);
	}
	else
	{
		ProgressBar.SetColor(class'UIUtilities_Colors'.const.BAD_HTML_COLOR);
	}

}

//---------------- 3D Map Icon Handling -------------------
simulated function OnMouseIn()
{
	if (InDepth == 0)
	{ 
		super(UIStrategyMapItem).OnMouseIn();

		if(MapItem3D != none)
			MapItem3D.SetHoverMaterialValue(1);
		if(AnimMapItem3D != none)
			AnimMapItem3D.SetHoverMaterialValue(1);
	}
	InDepth++;
}

// Clear mouse hover special behavior
simulated function OnMouseOut()
{
	InDepth--;

	if (InDepth <= 0)
	{
		super(UIStrategyMapItem).OnMouseOut();

		if(MapItem3D != none)
			MapItem3D.SetHoverMaterialValue(0);
		if(AnimMapItem3D != none)
			AnimMapItem3D.SetHoverMaterialValue(0);
	}
}

simulated function Show()
{
	// override to always allow showing items
	super(UIPanel).Show();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
}

function string GetToolTipText()
{
	local int InfiltrationPct;
	local string BodyStr, TitleStr, InfiltrationPctStr, TooltipHTML;
	local XComGameState_LWPersistentSquad InfiltratingSquad;
	local XComGameState_MissionSite Mission;

	InfiltratingSquad = GetInfiltratingSquad();
	Mission = GetMission();

	TooltipHTML = "";

	if (Mission != none)
	{	
		class'X2EventListener_StrategyMap'.static.GetMissionSiteUIButtonToolTip(TitleStr, BodyStr, none, Mission);
		TitleStr = class'UIUtilities_Text'.static.GetColoredText(TitleStr, eUIState_Header);
			
		// KDM : The title includes the amount of time left before the mission expires; this is very useful information. 
		TooltipHTML $= TitleStr;
		TooltipHTML $= "\n";
		TooltipHTML $= "--------------------------------";
		// KDM : If a squad is infiltrating, show the infiltration percentage.
		if (InfiltratingSquad != none)
		{
			TooltipHTML $= "\n";
			TooltipHTML $= class'UIStrategyMapItem_Mission_LW'.default.InfiltrationTooltipString $ " : ";

			InfiltrationPct = int(InfiltratingSquad.CurrentInfiltration * 100.0);
			InfiltrationPctStr = class'UIUtilities_Text'.static.GetColoredText(string(InfiltrationPct), eUIState_Good);
				
			TooltipHTML $= InfiltrationPctStr @ "%";
			TooltipHTML $= "\n";
			TooltipHTML $= "--------------------------------";
		}
		TooltipHTML $= "\n";
		TooltipHTML $= BodyStr;
	}
	return TooltipHTML;
}

function UpdateTooltip()
{
	local string TooltipHTML;
	local UIStrategyMap StrategyMap;

	StrategyMap = GetStrategyMap();

	// KDM : If the strategy map has no active tooltip, then there is nothing to update.
	if (StrategyMap.ActiveTooltip != none)
	{
		// KDM : Get the new tooltip text and update the active tooltip.
		TooltipHTML = GetToolTipText();
		StrategyMap.ActiveTooltip.SetText(TooltipHTML);
		StrategyMap.ActiveTooltip.UpdateData();

		// KDM : The tooltip data has been updated; however, this information is not pushed to the flash UI element, so we don't see
		// any changes. There are 2 ways around this :
		//
		// 1.] The flash element, TooltipBox, has a function, Show(), which updates the tooltip's : Style, Text, Size, BG, and Location.
		// Furthermore, it animates the tooltip in. This is a nice 'complete' method, but it involves us having to constantly hide and show the
		// tooltip within UnrealScript. Additionally, it requires us to kill the tooltip's animation since we can't have it contantly fading in
		// and fading out.
		// 2.] Update the flash element's : Style, Text, Size, and BG, via Actionscript calls. This is a better solution because it updates
		// the tooltip text and size, without having to resort to hiding and showing the tooltip; furthermore, it doesn't mess with any 
		// tooltip animations.
		StrategyMap.ActiveTooltip.MC.FunctionVoid("RealizeStyle");
		StrategyMap.ActiveTooltip.MC.FunctionVoid("RealizeText");	
		StrategyMap.ActiveTooltip.MC.FunctionVoid("RealizeSize");
		StrategyMap.ActiveTooltip.MC.FunctionVoid("RealizeBG");
	}
}

// KDM : Long War provides useful mission tooltips; however, they only appear over the mission icons on the bottom icon bar, and are only
// accessible to mouse & keyboard users. Consequently, we want to give controller users the opportunity to display this information as a normal tooltip
// next to the mission map item.
function GenerateTooltip(string tooltipHTML)
{	
	// KDM : Normally, for mission map items, tooltipHTML will be an empty string; consequently, no tooltip will be created. 
	// Only show mission tooltips if the controller is active, and SHOW_MISSION_TOOLTIPS_CTRL is true.
	if (`ISCONTROLLERACTIVE && class'UIStrategyMapItem_Mission_LW'.default.SHOW_MISSION_TOOLTIPS_CTRL)
	{
		tooltipHTML = GetToolTipText();
	}
	
	super.GenerateTooltip(tooltipHTML);
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return true;
	}

	bHandled = true;

	switch(cmd)
	{
		// KDM : The A button opens a mission's infiltration screen if it is currently being infiltrated.
		// OnMouseEvent() checks if the Avenger is in flight before executing any of its code; consequently, the same is done here for consistency.
		case class'UIUtilities_Input'.static.GetAdvanceButtonInputCode():
			if (GetStrategyMap().m_eUIState != eSMS_Flight)
			{
				MapItemMissionClicked();
			}
			break;

		default :
			bHandled = false;
			break;
	}

	return bHandled || super.OnUnrealCommand(cmd, arg);
}

DefaultProperties
{
	bDisableHitTestWhenZoomedOut = false;
	bFadeWhenZoomedOut = false;
}
