//---------------------------------------------------------------------------------------
//	FILE:    UIOutpostManagement
//	AUTHOR:  tracktwo / Pavonis Interactive
//	PURPOSE: UI for managing a single outpost
//---------------------------------------------------------------------------------------

class UIOutpostManagement extends UIScreen
	config(LW_UI) dependson(XComGameState_LWOutpost);

var config bool FONT_SIZE_2D_3D_SAME_MK, USE_FANCY_VERSION;
var config int ADVISOR_FONT_SIZE_MK, HEADER_BUTTON_HEIGHT_MK, HEADER_FONT_SIZE_MK;
var config int ADVISOR_FONT_SIZE_CTRL, HEADER_BUTTON_HEIGHT_CTRL, HEADER_FONT_SIZE_CTRL;

var name DisplayTag;
var name CameraTag;

var localized string ChangeJobStr, ChangeAllJobsStr, PerksStr;
var localized string m_strTitle;
var localized string m_strLabel;
var localized string m_strName;
var localized string m_strMission;
var localized string m_strBuildRadioRelay;
var localized string m_strLiaisonTitle;
var localized string m_strRegionalInfo;
var localized string m_strResistanceMecs;
var localized string m_strProhibited;
var localized string m_strCannotChangeLiaisonTitle;
var localized string m_strCannotChangeLiaison;

var UIButton RadioTowerUpgradeButton;

var UIList List;
var UIBGBox ListBG;
var UIPanel MainPanel;
var UIX2PanelHeader ListTitle;
var UIPanel DividerLine;
var UIPanel HeaderPanel;
var UIButton NameHeaderButton;
var UIButton JobHeaderButton;
var UIButton PerksHeaderButton;
var UIText LiaisonTitle;
var UIButton LiaisonButton;
var UIButton LiaisonLoadoutButton;
var UIImage LiaisonImage;
var UIText LiaisonName;

var UIScrollingText RegionalInfo;
var UIScrollingText ResistanceMecs;
var UIScrollingText JobDetail;

var UIPersonnel_Liaison LiaisonScreen;

var StateObjectReference OutpostRef;
var array<RebelUnit> CachedRebels;
var array<Name> CachedJobNames;
var StateObjectReference CachedLiaison;

var bool IsDirty;

var int panelY;
var int panelH;
var int panelW;

var int TheAdviserFontSize;
var float NameHeaderPct, JobHeaderPct, PerksHeaderPct;

// Debug options
var bool ShowFaceless;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local bool IntelProhibited, SupplyProhibited, RecruitProhibited;
	local int AdviserBorderPadding, AdviserIconSize, AvailableSpace, BorderPadding, i, TheHeaderButtonHeight, TheHeaderFontSize, ScrollbarPadding;

	local int NextX, NextY;
	local XComGameState_LWOutpost Outpost;
	local XComGameState_WorldRegion Region;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));
	Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(Outpost.Region.ObjectID));

	// KDM : The normal UI has 2 columns : rebel name, and rebel job; the fancy UI has a rebel perks column in the middle.
	if (USE_FANCY_VERSION)
	{
		NameHeaderPct = 0.45f;
		PerksHeaderPct = 0.25f;
		JobHeaderPct = 0.3f;
	}
	else
	{
		NameHeaderPct = 0.7f;
		JobHeaderPct = 0.3f;
	}

	NextX = 0;
	NextY = 0;

	AdviserBorderPadding = 4;
	AdviserIconSize = 64;
	BorderPadding = 15;
	ScrollbarPadding = 10;

	if (`ISCONTROLLERACTIVE)
	{
		TheAdviserFontSize = ADVISOR_FONT_SIZE_CTRL;
		TheHeaderButtonHeight = HEADER_BUTTON_HEIGHT_CTRL;
		TheHeaderFontSize = HEADER_FONT_SIZE_CTRL;
	}
	else
	{
		// KDM : The font size for the adviser title and adviser name is larger if viewed on a 3D screen like the Avenger.
		// This is ignored, however, if FONT_SIZE_2D_3D_SAME_MK is true.
		if (class'Utilities_LW'.static.IsOnStrategyMap())
		{
			TheAdviserFontSize = ADVISOR_FONT_SIZE_MK;
		}
		else
		{
			TheAdviserFontSize = (FONT_SIZE_2D_3D_SAME_MK) ? ADVISOR_FONT_SIZE_MK : ADVISOR_FONT_SIZE_MK + 4;
		}

		TheHeaderButtonHeight = HEADER_BUTTON_HEIGHT_MK;
		TheHeaderFontSize = HEADER_FONT_SIZE_MK;
	}

	super.InitScreen(InitController, InitMovie, InitName);

	// KDM : The Haven screen is centered horizontally and vertically when viewed via the strategy map.
	// When viewed via the Avenger; however, its vertical position must be set manually in order to fit a fancy 3D background.
	panelW = 1000;
	panelH = 830;
	if (class'Utilities_LW'.static.IsOnStrategyMap())
	{
		panelY = (Movie.UI_RES_Y / 2) - (panelH / 2);
	}
	else
	{
		panelY = 80;
	}

	// KDM : Container which will hold our UI components : it's invisible
	MainPanel = Spawn(class 'UIPanel', self);
	MainPanel.bAnimateOnInit = false;
	MainPanel.bIsNavigable = false;
	MainPanel.InitPanel('ListContainer');
	MainPanel.SetPosition((Movie.UI_RES_X / 2) - (panelW / 2), panelY);

	// KDM : Background rectangle
	ListBG = Spawn(class'UIBGBox', MainPanel);
	ListBG.bAnimateOnInit = false;
	ListBG.LibID = class'UIUtilities_Controls'.const.MC_X2Background;
	ListBG.InitBG('ListBG', 0, 0, panelW, panelH);

	// KDM : Header (includes title, and region sub-title)
	ListTitle = Spawn(class'UIX2PanelHeader', MainPanel);
	ListTitle.bAnimateOnInit = false;
	ListTitle.bIsNavigable = false;
	ListTitle.InitPanelHeader('TitleHeader', m_strTitle, Region.GetDisplayName());
	ListTitle.SetPosition(BorderPadding, BorderPadding);
	ListTitle.SetHeaderWidth(panelW - BorderPadding * 2);

	NextY = ListTitle.Y + ListTitle.Height;

	// KDM : Advent strength in the region
	RegionalInfo = Spawn(class'UIScrollingText', MainPanel);
	RegionalInfo.bAnimateOnInit = false;
	RegionalInfo.InitScrollingText('Outpost_RegionalInfo_LW', "", panelW - BorderPadding * 2, BorderPadding, ListBG.Y + 46.75 + 6);
	RegionalInfo.SetHTMLText("<p align=\'RIGHT\'><font size=\'24\' color=\'#fef4cb\'>" $ GetAdventStrengthString(Region) $ "</font></p>");
	RegionalInfo.SetAlpha(67.1875);

	// Resistance MECs
	if (Outpost.GetResistanceMecCount() > 0)
	{
		ResistanceMecs = Spawn(class'UIScrollingText', MainPanel);
		ResistanceMecs.bAnimateOnInit = false;
		ResistanceMecs.InitScrollingText('Outpost_ResistanceMecs_LW', "", panelW - BorderPadding * 2, BorderPadding, RegionalInfo.Y + RegionalInfo.Height);
		ResistanceMecs.SetHTMLText("<p align=\'RIGHT\'><font size=\'24\' color=\'#fef4cb\'>" $ GetResistanceMecString(Outpost) $ "</font></p>");
		ResistanceMecs.SetAlpha(67.1875);
	}

	for (i = 0; i < Outpost.prohibitedjobs.length; i++)
	{
		if (OutPost.ProhibitedJobs[i].Job == 'Intel' && Outpost.ProhibitedJobs[i].DaysLeft > 0)
		{
			IntelProhibited = true;
		}
		if (OutPost.ProhibitedJobs[i].Job == 'Resupply' && OutPost.ProhibitedJobs[i].DaysLeft > 0)
		{
			SupplyProhibited = true;
		}
		if (OutPost.ProhibitedJobs[i].Job == 'Recruit' && Outpost.ProhibitedJobs[i].DaysLeft > 0)
		{
			RecruitProhibited = true;
		}
	}

	// KDM : Job prohibitions for the region
	if (IntelProhibited || SupplyProhibited || RecruitProhibited)
	{
		JobDetail = Spawn(class'UIScrollingText', MainPanel);
		JobDetail.bAnimateOnInit = false;
		JobDetail.InitScrollingText('OutPost_JobDetail_LW', "", panelW - BorderPadding * 2, BorderPadding,
			RegionalInfo.Y + RegionalInfo.Height + (OutPost.GetResistanceMecCount() > 0) ? ResistanceMECs.Height : 0.0f);
		JobDetail.SetHTMLText("<p align=\'RIGHT\'><font size=\'24\' color=\'#fef4cb\'>" $
			GetJobProhibitedString(Outpost, IntelProhibited, SupplyProhibited, RecruitProhibited) $ "</font></p>");
		JobDetail.SetAlpha(67.1875);
	}

	// KDM : Haven adviser background
	LiaisonButton = Spawn(class'UIButton', MainPanel);
	LiaisonButton.bAnimateOnInit = false;
	LiaisonButton.bIsNavigable = false;
	LiaisonButton.InitButton(, , OnLiaisonClicked);
	LiaisonButton.SetPosition(BorderPadding, NextY);
	LiaisonButton.SetSize(AdviserIconSize + AdviserBorderPadding * 2, AdviserIconSize + AdviserBorderPadding * 2);

	// KDM : Haven adviser photo
	LiaisonImage = Spawn(class'UIImage', LiaisonButton);
	LiaisonImage.bAnimateOnInit = false;
	LiaisonImage.InitImage();
	LiaisonImage.SetPosition(AdviserBorderPadding, AdviserBorderPadding);
	LiaisonImage.SetSize(AdviserIconSize, AdviserIconSize);

	// KDM : Haven adviser label
	LiaisonTitle = Spawn(class'UIText', MainPanel);
	LiaisonTitle.bAnimateOnInit = false;
	LiaisonTitle.InitText('', "");
	LiaisonTitle.SetPosition(BorderPadding + LiaisonButton.Width + 5, NextY);
	LiaisonTitle.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(m_strLiaisonTitle, eUIState_Normal, TheAdviserFontSize));

	// KDM : Haven adviser name
	LiaisonName = Spawn(class'UIText', MainPanel);
	LiaisonName.bAnimateOnInit = false;
	LiaisonName.InitText('',"");
	LiaisonName.SetPosition(LiaisonTitle.X, NextY + LiaisonTitle.Height);

	// Rai : Haven advisor loadout button.
	LiaisonLoadoutButton = Spawn(class'UIButton', MainPanel);
	LiaisonLoadoutButton.bAnimateOnInit = false;
	LiaisonLoadoutButton.bIsNavigable = false;
	LiaisonLoadoutButton.InitButton(, , OnLiaisonLoadoutClicked);
	LiaisonLoadoutButton.SetText("Edit Loadout");
	LiaisonLoadoutButton.SetHeight(30);
	LiaisonLoadoutButton.SetPosition(811 , NextY + LiaisonTitle.Height);// As KDM mentioned below, the button does not seem to anchor to MainPanel, so have resorted to hard coding the values
	LiaisonLoadoutButton.SetFontSize(24);

	NextY += 81;

	// KDM : Dividing line
	DividerLine = Spawn(class'UIPanel', MainPanel);
	DividerLine.bAnimateOnInit = false;
	DividerLine.bIsNavigable = false;
	DividerLine.LibID = class'UIUtilities_Controls'.const.MC_GenericPixel;
	DividerLine.InitPanel('DividerLine');
	DividerLine.SetPosition(BorderPadding, NextY);
	DividerLine.SetWidth(panelW - BorderPadding * 2);
	DividerLine.SetAlpha(20);

	NextY += DividerLine.Height + 8;

	// KDM : Container for column headers : it's invisible
	HeaderPanel = Spawn(class'UIPanel', MainPanel);
	HeaderPanel.bAnimateOnInit = false;
	HeaderPanel.bIsNavigable = false;
	HeaderPanel.InitPanel('Header');
	HeaderPanel.SetPosition(BorderPadding, NextY);
	HeaderPanel.SetSize(panelW - BorderPadding * 2 - ScrollbarPadding, 32);

	// KDM : Available space = total header width - 2 pixels between each column header.
	// The normal UI has 2 column headers, while the fancy UI has 3 columns headers.
	if (USE_FANCY_VERSION)
	{
		AvailableSpace = HeaderPanel.Width - 2 * 2;
	}
	else
	{
		AvailableSpace = HeaderPanel.Width - 2;
	}

	// KDM : Rebel name column header
	NameHeaderButton = Spawn(class'UIButton', HeaderPanel);
	NameHeaderButton.bAnimateOnInit = false;
	NameHeaderButton.bIsNavigable = false;
	NameHeaderButton.ResizeToText = false;
	NameHeaderButton.InitButton(, CAPS(m_strName));
	NameHeaderButton.SetPosition(0, 0);
	NameHeaderButton.SetSize(AvailableSpace * NameHeaderPct, TheHeaderButtonHeight);
	NameHeaderButton.SetStyle(eUIButtonStyle_NONE, TheHeaderFontSize);
	NameHeaderButton.SetWarning(true);
	// KDM : Since the name column header can't be clicked, remove its hit testing so mouse events don't change its colour
	// and make users think the button is active. The same is done for the perks column header below.
	NameHeaderButton.SetHitTestDisabled(true);

	NextX = NameHeaderButton.X + NameHeaderButton.Width + 2;

	// KDM : Rebel perks column header used in the fancy UI
	if (USE_FANCY_VERSION)
	{
		PerksHeaderButton = Spawn(class'UIButton', HeaderPanel);
		PerksHeaderButton.bAnimateOnInit = false;
		PerksHeaderButton.bIsNavigable = false;
		PerksHeaderButton.bProcessesMouseEvents = false;
		PerksHeaderButton.ResizeToText = false;
		PerksHeaderButton.InitButton(, PerksStr);
		PerksHeaderButton.SetPosition(NextX, 0);
		PerksHeaderButton.SetSize(AvailableSpace * PerksHeaderPct, TheHeaderButtonHeight);
		PerksHeaderButton.SetStyle(eUIButtonStyle_NONE, TheHeaderFontSize);
		PerksHeaderButton.SetWarning(true);
		PerksHeaderButton.SetHitTestDisabled(true);

		NextX += PerksHeaderButton.Width + 2;
	}

	// KDM : Rebel job column header
	JobHeaderButton = Spawn(class'UIButton', HeaderPanel);
	JobHeaderButton.bAnimateOnInit = false;
	JobHeaderButton.bIsNavigable = false;
	JobHeaderButton.ResizeToText = false;
	JobHeaderButton.InitButton(, CAPS(m_strMission), OnJobHeaderButtonClicked);
	JobHeaderButton.SetPosition(NextX, 0);
	JobHeaderButton.SetSize(AvailableSpace * JobHeaderPct, TheHeaderButtonHeight);
	JobHeaderButton.SetStyle(eUIButtonStyle_NONE, TheHeaderFontSize);
	JobHeaderButton.SetWarning(true);
	JobHeaderButton.ProcessMouseEvents(OnJobHeaderMouseEvent);

	NextY += 32 + 5;

	// KDM : List container which will hold rows of rebels
	List = Spawn(class'UIList', MainPanel);
	List.bAnimateOnInit = false;
	List.bIsNavigable = true;
	List.bStickyHighlight = false;
	List.InitList(, BorderPadding, NextY, HeaderPanel.Width, panelH - NextY - BorderPadding);

	// KDM : As per Long War 2, radio relays can only be built via the strategy map, not via the Avenger.
	if (class'Utilities_LW'.static.IsOnStrategyMap())
	{
		RadioTowerUpgradeButton = Spawn(class'UIButton', MainPanel);
		RadioTowerUpgradeButton.bAnimateOnInit = false;
		RadioTowerUpgradeButton.bIsNavigable = false;
		RadioTowerUpgradeButton.InitButton(, m_strBuildRadioRelay, OnRadioTowerUpgradeClicked);
		// KDM : I did a lot of testing, and this button seems to anchor to the screen rather than MainPanel.
		// Therefore, to make things easier, I chose manual positioning rather than positioning through the use of an anchor and origin.
		RadioTowerUpgradeButton.SetPosition(811, 21);
		RadioTowerUpgradeButton.SetHeight(30);
		RadioTowerUpgradeButton.SetFontSize(24);
	}

	// LWS : Redirect all background mouse events to the list so mouse wheel scrolling doesn't get lost when the mouse is positioned between list items.
	ListBG.ProcessMouseEvents(List.OnChildMouseEvent);

	InitJobNameCache();
	RefreshNavHelp();
	GetData();
	RefreshData();

	// KDM : Automatically select the 1st rebel row when using a controller.
	if (`ISCONTROLLERACTIVE)
	{
		List.NavigatorSelectionChanged(0);
	}
}

simulated function string GetResistanceMecString(XComGameState_LWOutpost Outpost)
{
	local XGParamTag kTag;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.IntValue0 = Outpost.GetResistanceMecCount();
	return `XEXPAND.ExpandString(m_strResistanceMecs);
}

simulated function string GetAdventStrengthString(XComGameState_WorldRegion Region)
{
	local XComGameState_WorldRegion_LWStrategyAI RegionalAIState;
	local XGParamTag kTag;

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	RegionalAIState = class'XComGameState_WorldRegion_LWStrategyAI'.static.GetRegionalAI(Region);
	if (!RegionalAIState.bLiberated)
	{
		kTag.IntValue0 = RegionalAIState.LocalAlertLevel;
		return `XEXPAND.ExpandString(m_strRegionalInfo);
	}
	else
	{
		return class'UIResistanceManagement_LW'.default.m_strLiberated;
	}
}

simulated function string GetJobProhibitedString(XComGameState_LWOutpost Outpost, bool IntelProhibited, bool SupplyProhibited, bool RecruitProhibited)
{
	local string ProhibitedString;

	ProhibitedString = "";

	if (IntelProhibited)
	{
		ProhibitedString @= OutPost.GetJobName('Intel') $ ":";
		ProhibitedString @= m_strProhibited;
	}
	if (SupplyProhibited)
	{
		ProhibitedString @= OutPost.GetJobName('Resupply') $ ":";
		ProhibitedString @= m_strProhibited;
	}
	if (RecruitProhibited)
	{
		ProhibitedString @= OutPost.GetJobName('Recruit') $ ":";
		ProhibitedString @= m_strProhibited;
	}

	return ProhibitedString;
}

simulated function bool ControllerCanBuildRelay()
{
	// KDM : A haven's radio relay can be built if :
	// [1] You are on the strategy map. [2] The region has been contacted. [3] There is no previously built radio relay.
	if (class'Utilities_LW'.static.IsOnStrategyMap())
	{
		if (ShowRadioTowerUpgradeButton())
		{
			return true;
		}
	}

	return false;
}

simulated function bool ShowRadioTowerUpgradeButton()
{
	return class'UIUtilities_Strategy'.static.GetXComHQ().IsOutpostResearched() && GetRegion().ResistanceLevel == eResLevel_Contact && !GetRegion().bCanScanForOutpost;
}

simulated function XComGameState_WorldRegion GetRegion()
{
	local XComGameState_WorldRegion Region;
	local XComGameState_LWOutpost Outpost;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));
	Region = XComGameState_WorldRegion(History.GetGameStateForObjectID(Outpost.Region.ObjectID));
	return Region;
}

function OnRadioTowerUpgradeClicked(UIButton Button)
{
	`HQPRES.UIBuildOutpost(GetRegion());
}

function OnJobHeaderButtonClicked(UIButton Button)
{
	local int i, j, k;
	local XComGameState_LWOutpost Outpost;
	local bool GoodJobFound;
	local UIOutpostManagement_ListItem ListItem;

	Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));
	i = CachedJobNames.Find(CachedRebels[0].Job);
	GoodJobFound = false;
	While (!GoodJobFound)
	{
		GoodJobFound = true;
		i += 1;
		if (i >= CachedJobNames.Length)
			i = 0;
		for (k = 0; k < Outpost.ProhibitedJobs.length; k++)
		{
			if (Outpost.ProhibitedJobs[k].DaysLeft > 0 && CachedJobNames[i] == OutPost.ProhibitedJobs[k].Job)
			{
				GoodJobFound = false;
			}
		}
	}
	for (j = 0; j < OutPost.Rebels.Length; j++)
	{
		if (CachedJobNames[i] == class'LWRebelJob_DefaultJobSet'.const.HIDING_JOB || j < OutPost.MaxRebels)
		{
			CachedRebels[j].Job = CachedJobNames[i];
		}
		else
		{
			if (j >= OutPost.MaxRebels)
			{
				CachedRebels[j].Job = class'LWRebelJob_DefaultJobSet'.const.HIDING_JOB;
			}
		}
		IsDirty = true;
		List.SetSelectedIndex(j);
		ListItem = UIOutpostManagement_ListItem(List.GetSelectedItem());
		ListItem.SetJobName(class'XComGameState_LWOutpost'.static.GetJobName(CachedRebels[j].Job));
	}
}

simulated function InitJobNameCache()
{
	local X2StrategyElementTemplateManager StrategyTemplateMgr;
	local array<X2StrategyElementTemplate> Templates;
	local LWRebelJobTemplate JobTemplate;
	local int idx;

	StrategyTemplateMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Templates = StrategyTemplateMgr.GetAllTemplatesOfClass(class'LWRebelJobTemplate');

	for (idx = 0; idx < Templates.Length; ++idx)
	{
		JobTemplate = LWRebelJobTemplate(Templates[idx]);
		CachedJobNames.AddItem(JobTemplate.DataName);
	}
}

simulated function SetOutpost(StateObjectReference Ref)
{
	OutpostRef = Ref;
}

simulated function RefreshData()
{
	UpdateLiaison();
	UpdateList();
	if (ShowRadioTowerUpgradeButton())
		RadioTowerUpgradeButton.Show();
	else
		RadioTowerUpgradeButton.Hide();
}

simulated function GetData()
{
	local int i;
	local XComGameStateHistory History;
	local XComGameState_LWOutpost Outpost;

	History = `XCOMHISTORY;
	Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));
	CachedRebels.Length = 0;

	for (i = 0; i < Outpost.Rebels.Length; ++i)
	{
		CachedRebels.AddItem(Outpost.Rebels[i]);
	}

	CachedLiaison = Outpost.GetLiaison();
}

simulated function UpdateLiaison()
{
	local String Str;
	local Texture2D LiaisonPicture;
	local XComGameState_Unit Liaison;

	if (CachedLiaison.ObjectID == 0)
	{
		LiaisonName.SetHtmlText("");
		LiaisonImage.Hide();
	}
	else
	{
		Liaison = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(CachedLiaison.ObjectID));
		if (Liaison.IsSoldier())
		{
			Str = class'UIUtilities_Text'.static.InjectImage(Liaison.GetSoldierClassTemplate().IconImage, 40, 40, -18);
			Str $= class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.static.GetRankIcon(Liaison.GetRank(), Liaison.GetSoldierClassTemplateName()), 40, 40, -18);
			Str $= Liaison.GetName(eNameType_FullNick);
		}
		else
		{
			if (Liaison.IsEngineer())
			{
				Str = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.EventQueue_Engineer, 32, 32, -6);
			}
			else if (Liaison.IsScientist())
			{
				Str = class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Image'.const.EventQueue_Science, 32, 32, -6);
			}
			Str $= Liaison.GetFullName();
		}

		LiaisonName.SetHtmlText(class'UIUtilities_Text'.static.GetColoredText(Str, eUIState_Normal, TheAdviserFontSize));

		LiaisonPicture = class'UIUtilities_LW'.static.TakeUnitPicture(CachedLiaison, OnPictureTaken);
		if (LiaisonPicture != none)
		{
			LiaisonImage.LoadImage(PathName(LiaisonPicture));
			LiaisonImage.Show();
		}
	}
}

simulated function UpdateList()
{
	local int i;

	List.ClearItems();

	for (i = 0; i < CachedRebels.Length; ++i)
	{
		UIOutpostManagement_ListItem(List.CreateItem(class'UIOutpostManagement_ListItem')).InitListItem();
	}
}

simulated function RefreshNavHelp()
{
	local UINavigationHelp NavHelp;

	NavHelp = `HQPRES.m_kAvengerHUD.NavHelp;
	NavHelp.ClearButtonHelp();
	NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;
	NavHelp.AddBackButton(OnCancel);

	// KDM : Controller specific navigation help
	if (`ISCONTROLLERACTIVE)
	{
		// KDM : D-Pad left/right changes the selected rebels job.
		NavHelp.AddLeftHelp(ChangeJobStr, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_DPAD_HORIZONTAL);

		// KDM : Bumper left/right changes all rebel jobs.
		NavHelp.AddLeftHelp(ChangeAllJobsStr, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RB_R1);

		// KDM : X button changes the haven's adviser.
		NavHelp.AddLeftHelp(CAPS(m_strLiaisonTitle), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);

		// KDM : Y button brings up the option to build a haven relay, if certain conditions are met.
		if (ControllerCanBuildRelay())
		{
			NavHelp.AddLeftHelp(CAPS(m_strBuildRadioRelay), class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.Icon_Y_TRIANGLE);
		}
	}
	else
	{
		class'LWHelpTemplate'.static.AddHelpButton_Nav('OutpostManagement_Help');
	}
}

simulated function OnCancel()
{
	if (IsDirty)
		SaveOutpost();

	Movie.Stack.Pop(self);

	`XEVENTMGR.TriggerEvent('OnLeaveOutpost', self, self); // this is needed to advance objective LW_T2_M0_S1_ReviewOutpost
}

simulated function OnAccept()
{
	if (IsDirty)
		SaveOutpost();

	`XEVENTMGR.TriggerEvent('OnLeaveOutpost', self, self); // this is needed to advance objective LW_T2_M0_S1_ReviewOutpost
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();

	// KDM : Removed the following LWS code :
	// [1] A call to JobHeaderButton.SetWidth() which was unnecessary.
	// [2] A call to Show() since bHideOnLoseFocus causes the screen to automatically Show() upon receiving focus.
	RefreshNavHelp();
	RefreshData();

	// KDM : Automatically select the 1st rebel row when using a controller.
	if (`ISCONTROLLERACTIVE)
	{
		List.SetSelectedIndex(0, true);
	}
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();

	// KDM : Removed a LWS call to Hide() since bHideOnLoseFocus is true by default.
}

simulated function SetDirty()
{
	IsDirty = true;
}

simulated function OnJobHeaderMouseEvent(UIPanel Panel, int cmd)
{
	local UIButton JobHeader;

	JobHeader = UIButton(Panel);

	// KDM : In Long War 2, mousing over a header button results in black text over a dull yellow background. What we really
	// want, for readability and usability, is black text over a nice saturated yellow background.
	//
	// HOW THIS WAS DONE :
	// [1] Open up gfxComponents.upk with JPEXS
	// [2] Open scripts --> _Packages --> XComButton (the LibID for UIButton within UnrealScript)
	// [3] Figure out that the flash component we want to manipulate is buttonMC; this is the button's background movie clip.
	// [4] Figure out that buttonMC changes colour via state changes, using a function like : gotoAndStop.
	// [5] Figure out that gotoAndStop wants 1 parameter in the format : _STATEPHASE.
	//	   Valid values for STATE are : Bad | SelectedBad | Warning | SelectedWarning | Good | SelectedGood
	//	   Valid values for PHASE are : Up | UpToDown | Down | DownToUp | Over
	// [6] Figure out that black text on a nice saturated yellow background results from : _WarningDown.
	// [7] Look in UIMCController.uc to determine how we call Actionscript from UnrealScript.
	//	   In this case we want : simulated function ChildFunctionString(string ChildPath, string Func, string Param)
	//
	// IMPORTANT NOTE : Figure out = look through the code with a lot of trial and error.

	switch (cmd)
	{
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_IN:
		case class'UIUtilities_Input'.const.FXS_L_MOUSE_OVER:
			JobHeader.MC.ChildFunctionString("buttonMC", "gotoAndStop", "_WarningDown");
			break;
	}
}

simulated function bool OnUnrealCommand(int cmd, int arg)
{
	local bool bHandled;

	if (!CheckInputIsReleaseOrDirectionRepeat(cmd, arg))
	{
		return false;
	}

	bHandled = true;

	switch (cmd)
	{
		case class'UIUtilities_Input'.static.GetAdvanceButtonInputCode():
		case class'UIUtilities_Input'.const.FXS_KEY_ENTER:
		case class'UIUtilities_Input'.const.FXS_KEY_SPACEBAR:
			OnAccept();
			break;

		case class'UIUtilities_Input'.static.GetBackButtonInputCode():
		case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
		case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
			OnCancel();
			break;

		// KDM : X button either :
		// [1] Opens the haven adviser selection screen, if no haven adviser currently exists.
		// [2] Removes the haven adviser, if one currently exists.
		case class'UIUtilities_Input'.const.FXS_BUTTON_X:
			OnLiaisonClicked(none);
			break;

		// KDM : Y button brings up the option to build a haven relay, if certain conditions are met.
		case class'UIUtilities_Input'.const.FXS_BUTTON_Y:
			if (ControllerCanBuildRelay())
			{
				OnRadioTowerUpgradeClicked(none);
			}
			break;

		// KDM : Bumper left/right allows you to change all rebel's jobs at the same time.
		// The algorithm works as follows : [1] Give all rebels the same job as the 1st rebel. [2] Give each rebel the next job.
		// NOTE : Currently, both bumper buttons change rebel jobs in the same direction; this is not a big deal since only 4 jobs exist.
		case class'UIUtilities_Input'.const.FXS_BUTTON_LBUMPER:
		case class'UIUtilities_Input'.const.FXS_BUTTON_RBUMPER:
			OnJobHeaderButtonClicked(none);
			// KDM : Once all rebel jobs have been changed, select the 1st rebel for UI simplicity.
			// NavigatorSelectionChanged() is called, instead of SetSelectedIndex(), because it :
			// [1] Updates the scroll bar [2] Moves the list to the top if necessary.
			List.NavigatorSelectionChanged(0);
			break;

		default:
			bHandled = super.OnUnrealCommand(cmd, arg);
			// KDM : Handle D-Pad inputs via the list.
			if (`ISCONTROLLERACTIVE && !bHandled)
			{
				bHandled = List.Navigator.OnUnrealCommand(cmd, arg);
			}
			break;
	}

	if (bHandled)
	{
		return true;
	}

	return super.OnUnrealCommand(cmd, arg);
}

function int CountNonHidingRebels()
{
	local int NumNonHidingRebels;
	local int i;

	// Count the number of non-hiding rebels, and if it's at the cap we can't change this one.
	for (i = 0; i < CachedRebels.Length; ++i)
	{
		if (CachedRebels[i].Job != class'LWRebelJob_DefaultJobSet'.const.HIDING_JOB)
			++NumNonHidingRebels;
	}

	return NumNonHidingRebels;
}

function OnJobChanged(UIOutpostManagement_ListItem ListItem, int Direction)
{
	local int RebelIdx;
	local int i, k;
	local XComGameState_LWOutpost Outpost;
	local bool GoodJobFound;

	RebelIdx = List.GetItemIndex(ListItem);
	Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));
	i = CachedJobNames.Find(CachedRebels[RebelIdx].Job);

	GoodJobFound = false;
	while (!GoodJobFound)
	{
		GoodJobFound = true;
		i += Direction;
		if (i >= CachedJobNames.Length)
			i = 0;
		else if (i < 0)
			i = CachedJobNames.Length - 1;
		if (CachedJobNames[i] != class'LWRebelJob_DefaultJobSet'.const.HIDING_JOB)
		{
			for (k = 0; k < Outpost.ProhibitedJobs.length; k++)
			{
				if (Outpost.ProhibitedJobs[k].DaysLeft > 0 && CachedJobNames[i] == OutPost.ProhibitedJobs[k].Job)
				{
					GoodJobFound = false;
				}
			}
		}
	}

	// Special logic needed if this rebel is hiding - it's possible the outpost is already at max
	// and we shouldn't be able to set them to a real job. If they aren't hiding then they can always
	// be adjusted.
	if (CachedRebels[RebelIdx].Job == class'LWRebelJob_DefaultJobSet'.const.HIDING_JOB)
	{
		if (CountNonHidingRebels() >= Outpost.MaxRebels)
		{
			// Too many rebels on the job. Return without changing anything.
			`SOUNDMGR.PlaySoundEvent("Play_MenuClickNegative");
			return;
		}
	}

	CachedRebels[RebelIdx].Job = CachedJobNames[i];
	IsDirty = true;
	// Tell the list item to refresh itself.
	ListItem.SetJobName(class'XComGameState_LWOutpost'.static.GetJobName(CachedRebels[RebelIdx].Job));
}

function SaveOutpost()
{
	local XComGameState_LWOutpost Outpost;
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local int I;

	History = `XCOMHISTORY;
	Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving Outpost Changes");
	Outpost = XComGameState_LWOutpost(NewGameState.CreateStateObject(class'XComGameState_LWOutpost', Outpost.ObjectID));

	for (I = 0; I < CachedRebels.Length; ++I)
	{
		Outpost.SetRebelJob(CachedRebels[I].Unit, CachedRebels[I].Job);
	}
	Outpost.UpdateJobs(NewGameState);

	// This should be redundant because liaison changes are saved immediately.
	SaveLiaison();

	NewGameState.AddStateObject(Outpost);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	`HQPRES.m_kAvengerHUD.UpdateResources();
}

// Debug: Show or hide faceless
function ToggleShowFaceless()
{
	if (ShowFaceless)
	{
		ShowFaceless = false;
	}
	else
	{
		ShowFaceless = true;
	}

	RefreshData();
}

simulated function OnLiaisonClicked(UIButton theButton)
{
	local TDialogueBoxData DialogData;
	local XComGameState_LWOutpost Outpost;

	Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));

	if (!Outpost.CanLiaisonBeMoved())
	{
		DialogData.eType = eDialog_Normal;
		DialogData.strTitle = m_strCannotChangeLiaisonTitle;
		DialogData.strText = m_strCannotChangeLiaison;
		DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
		Movie.Pres.UIRaiseDialog(DialogData);
		return;
	}

	if (CachedLiaison.ObjectID != 0)
	{
		// Clear the existing liaison
		CachedLiaison.ObjectID = 0;
		SetDirty();
		UpdateLiaison();
		SaveLiaison();
	}
	else
	{
		//`HQPRES.UIPersonnel(eUIPersonnel_All, OnPersonnelSelected);
		LiaisonScreen = Spawn( class'UIPersonnel_Liaison', self );
		LiaisonScreen.m_eListType = eUIPersonnel_All;
		LiaisonScreen.onSelectedDelegate = OnPersonnelSelected;
		LiaisonScreen.m_bRemoveWhenUnitSelected = true;
		Movie.Stack.Push(LiaisonScreen);
	}
}

// Rai - On Edit Loadout button click
simulated function OnLiaisonLoadoutClicked(UIButton theButton)
{
	local TDialogueBoxData DialogData;
	local XComGameState_LWOutpost Outpost;
	local XComGameState_Unit	Liaison;
	local XComHQPresentationLayer HQPres;

	Outpost = XComGameState_LWOutpost(`XCOMHISTORY.GetGameStateForObjectID(OutpostRef.ObjectID));
	Liaison = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(CachedLiaison.ObjectID));

	HQPres = `HQPRES;
	if (!Outpost.CanLiaisonBeMoved())
	{
		DialogData.eType = eDialog_Normal;
		DialogData.strTitle = m_strCannotChangeLiaisonTitle;
		DialogData.strText = m_strCannotChangeLiaison;
		DialogData.strAccept = class'UIDialogueBox'.default.m_strDefaultAcceptLabel;
		Movie.Pres.UIRaiseDialog(DialogData);
		return;
	}

	if (CachedLiaison.ObjectID != 0 && Liaison.IsSoldier())
	{
		// Check if we are calling from geoscape or avenger?
		if (class'Utilities_LW'.static.IsOnStrategyMap())
		{
			// This assumes that we have a way to get to the resistance/outpost management screen, which will be handled in a separate pull request
			`HQPRES.UIArmory_MainMenu(CachedLiaison);
		}		
		else
		{
			//Apparently, for this case, the haven and resitance management screens are still in the stack but appear blank, so need to figure this out
			// For now, we just have to double right click to get dumped back to the barracks screen
			`HQPRES.UIArmory_MainMenu(CachedLiaison);
		}		
	}
}

simulated function OnPersonnelSelected(StateObjectReference SelectedUnitRef)
{
	CachedLiaison = SelectedUnitRef;
	UpdateLiaison();
	SaveLiaison();
	SetDirty();
}

// We need to update the outpost liaison state immediately in order to display the unit
// status correctly. E.g. if you have a liaison set (and saved) and you enter the screen and
// clear the liaison then click it again to choose a new one, we need to show the unit that was
// previously the liaison as available.
simulated function SaveLiaison()
{
	local XComGameState_LWOutpost Outpost;
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_Unit Unit;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference OldLiaison;

	History = `XCOMHISTORY;
	Outpost = XComGameState_LWOutpost(History.GetGameStateForObjectID(OutpostRef.ObjectID));

	// Check for a new liaison
	OldLiaison = Outpost.GetLiaison();
	if (OldLiaison.ObjectID != CachedLiaison.ObjectID)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Saving Outpost Liaison Changes");

		// Set up the new liaison in the outpost (does not require a new outpost state: it only affects the staff slot)
		Outpost.SetLiaison(CachedLiaison, NewGameState);

		// For soldiers we need to set the on-mission status.
		// Clear the "on mission" status from the old one and add it to the new.
		if (OldLiaison.ObjectID != 0)
		{
			Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', OldLiaison.ObjectID));
			Unit.SetStatus(eStatus_Active);
			class'Helpers_LW'.static.UpdateUnitWillRecoveryProject(Unit);
		}

		if (CachedLiaison.ObjectID != 0)
		{
			Unit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', CachedLiaison.ObjectID));
			class'LWDLCHelpers'.static.SetOnMissionStatus(Unit, NewGameState);
		}

		// Tell XComHQ that we have a potential staffing change to update any sci/eng jobs.
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		XComHQ.HandlePowerOrStaffingChange();
	}
}

simulated function OnPictureTaken(StateObjectReference UnitRef)
{
	local Texture2D LiaisonPicture;

	LiaisonPicture = class'UIUtilities_LW'.static.FinishUnitPicture(UnitRef);
	if (LiaisonPicture != none)
	{
		LiaisonImage.LoadImage(PathName(LiaisonPicture));
		LiaisonImage.Show();
	}
}

defaultproperties
{
	bConsumeMouseEvents = true;
	InputState    = eInputState_Consume;

	// Main panel positioning. Note X is not defined, it's set to centered
	// based on the movie width and panel width.
	panelY = 150;
	panelW = 961;
	panelH = 724;

	// KDM : See the comments in UIMouseGuard_LW for more information.
	MouseGuardClass = class'UIMouseGuard_LW';
}

