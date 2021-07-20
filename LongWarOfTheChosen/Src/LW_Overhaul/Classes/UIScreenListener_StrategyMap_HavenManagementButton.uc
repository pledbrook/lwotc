//---------------------------------------------------------------------------------------
//  AUTHOR:  Rai 
//  PURPOSE: This class adds the corresponding screen listener to access the haven management 
//           screen from the geoscape directly
//---------------------------------------------------------------------------------------
//  Credits: Adapted from WOTCStrategyOverhaul Team's code for CI
//---------------------------------------------------------------------------------------

class UIScreenListener_StrategyMap_HavenManagementButton extends UIScreenListener;

/////////////////////
/// Adding button ///
/////////////////////

event OnInit(UIScreen Screen)
{
	local UIStrategyMap_HavenManagementButton HavenManagementButton;
	local UIStrategyMap StrategyMap;

	StrategyMap = UIStrategyMap(Screen);
	if (StrategyMap == none) return;

	if (!`ISCONTROLLERACTIVE)
	{
		HavenManagementButton = Screen.Spawn(class 'UIStrategyMap_HavenManagementButton', StrategyMap.StrategyMapHUD);
		HavenManagementButton.InitHMButton();
	}

}

public function OnHavenManagementNewButton(UIButton HavenManagementNewButton)
{
	class'XComGameState_LWOutpostManager'.static.OpenResistanceManagementScreen();
}

///////////////////////////////////////////
/// Handling input (controller support) ///
///////////////////////////////////////////
/*
event OnReceiveFocus(UIScreen screen)
{
	if (UIStrategyMap(Screen) == none) return;

	HandleInput(true);
}

event OnLoseFocus(UIScreen screen)
{
	if (UIStrategyMap(Screen) == none) return;

	HandleInput(false);
}

event OnRemoved(UIScreen screen)
{
	if (UIStrategyMap(Screen) == none) return;

	HandleInput(false);
}

function HandleInput(bool isSubscribing)
{
	local delegate<UIScreenStack.CHOnInputDelegate> inputDelegate;
	inputDelegate = OnUnrealCommand;

	if(isSubscribing)
	{
		`SCREENSTACK.SubscribeToOnInput(inputDelegate);
	}
	else
	{
		`SCREENSTACK.UnsubscribeFromOnInput(inputDelegate);
	}
}

static protected function bool OnUnrealCommand(int cmd, int arg)
{
	if (cmd == class'UIUtilities_Input'.const.FXS_BUTTON_X && arg == class'UIUtilities_Input'.const.FXS_ACTION_RELEASE)
	{
		if (class'XComEngine'.static.GetHQPres().StrategyMap2D.m_eUIState != eSMS_Flight)
		{
			// Cannot open screen during flight
			class'XComGameState_LWOutpostManager'.static.ResistanceManagementScreen();
		}

		return true;
	}

	return false;
}
*/
