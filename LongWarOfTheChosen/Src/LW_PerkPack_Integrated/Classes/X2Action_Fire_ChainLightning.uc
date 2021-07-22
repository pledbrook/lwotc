// the first shot is a standard projectile shot
// everything after that is a cosmetic projectile
class X2Action_Fire_ChainLightning extends X2Action_Fire config(Animation);

struct TargetNode
{
	var StateObjectReference TargetID;
	var X2VisualizerInterface TargetActor;
	// when a projectile is hit, the closest currently started but unnotified target is chosen as a hit
	var vector vCoarseLocation;
	// misses will not chain, EXCEPT for the primary target. this is always the first node, and the target of the shot
	var bool isHit;
	var float bHit;
	// populated later
	var float fTentativeCost;
	var int iPrevNode;
	// runtime data
	var bool bHasStarted;
	var bool bHasNotified;

	structdefaultproperties
	{
		// 100,000 tiles, should be close enough to infinity
		fTentativeCost=1000000.0
		iPrevNode=INDEX_NONE
	}
};

var array<TargetNode> Targets;
// dijkstra's algorithm
var array<int> OpenSet;


var int notifiedTargets;
var int hitTargets;


// STOP MAKING SHIT PRIVATE
// (I have to make it private to prevent the compiler from complaining)
var protected XComPresentationLayer PresentationLayer;
var protected array<XComPerkContentInst> Perks;
var protected array<name> PerkAdditiveAnimNames;
var protected int x;

function Init()
{
	local int i;
	local TargetNode EmptyTarget, BuildTarget;
	local X2VisualizerInterface Target;
	local Actor TargetActor;

	super.Init();

	PresentationLayer = `PRES;

	// primary target
	BuildTarget = EmptyTarget;
	BuildTarget.TargetID = AbilityContext.InputContext.PrimaryTarget;
	TargetActor = `XCOMHISTORY.GetVisualizer(BuildTarget.TargetID.ObjectID);
	Target = X2VisualizerInterface(TargetActor);
	BuildTarget.vCoarseLocation = TargetActor.Location;
	if (Target != none)
	{
		BuildTarget.TargetActor = Target;
		BuildTarget.vCoarseLocation = Target.GetShootAtLocation(eHit_Success, AbilityContext.InputContext.SourceObject);
	}
	BuildTarget.bHit = AbilityContext.IsResultContextHit() ? 0.01 : 1.0;
	BuildTarget.isHit = AbilityContext.IsResultContextHit();
	Targets.AddItem(BuildTarget);

	// multitargets
	for (i = 0; i < AbilityContext.InputContext.MultiTargets.Length; i++)
	{
		BuildTarget = EmptyTarget;
		BuildTarget.TargetID = AbilityContext.InputContext.MultiTargets[i];
		TargetActor = `XCOMHISTORY.GetVisualizer(BuildTarget.TargetID.ObjectID);
		Target = X2VisualizerInterface(TargetActor);
		BuildTarget.vCoarseLocation = TargetActor.Location;
		if (Target != none)
		{
			BuildTarget.TargetActor = Target;
			BuildTarget.vCoarseLocation = Target.GetShootAtLocation(eHit_Success, AbilityContext.InputContext.SourceObject);
		}
		BuildTarget.bHit = AbilityContext.IsResultContextMultiHit(i) ? 0.01 : 1.0;
		BuildTarget.isHit = AbilityContext.IsResultContextMultiHit(i);
		Targets.AddItem(BuildTarget);
	}

	BuildTargetPath();
	notifiedTargets = 0;
}

function bool ChainHasStarted()
{
	return notifiedTargets > 0;
}

// dijkstra's algorithm
// first entry = primary target = source location
// all others will be filled. jumping from a missed location is expensive, so hit paths are encouraged
// assumption: all targets can be reached
// todo: traces? i.e. distance is much longer if there is an obstacle?
function BuildTargetPath()
{
	local int i;
	local int iCurrentNode;
	local int iMinIdx;
	local float fNewCost;

	// 1: all nodes have a tentative cost of infinity, except for our initial node
	Targets[0].fTentativeCost = 0.0;
	hitTargets = 1;

	// 2. mark all other nodes as unvisited ("open set")
	// unless we never want to visit them anyway
	for (i = 1; i < Targets.Length; i++)
	{
		if (Targets[i].isHit)
		{
			OpenSet.AddItem(i);
			hitTargets++;
		}
	}

	iCurrentNode = 0;
	while (OpenSet.Length > 0)
	{
		iMinIdx = INDEX_NONE;
		// 3. for all unvisited neighbors of the current node (everything is a neighbor!)
		for (i = 0; i < OpenSet.Length; i++)
		{
			// update the tentative cost
			fNewCost = Targets[iCurrentNode].fTentativeCost
											+ VSizeSq(Targets[OpenSet[i]].vCoarseLocation - Targets[iCurrentNode].vCoarseLocation) * Targets[iCurrentNode].bHit;
			if (fNewCost < Targets[OpenSet[i]].fTentativeCost)
			{
				Targets[OpenSet[i]].fTentativeCost = fNewCost;
				// remember the path
				Targets[OpenSet[i]].iPrevNode = iCurrentNode;
			}
										
										
			// find the nearest node
			if (iMinIdx == INDEX_NONE || Targets[OpenSet[i]].fTentativeCost < Targets[iMinIdx].fTentativeCost)
			{
				iMinIdx = OpenSet[i];
			}
		}
		// 4. mark as visited and set a new node
		iCurrentNode = iMinIdx;
		OpenSet.RemoveItem(iCurrentNode);
	}
	// 5. OpenSet is empty. all nodes have been visited
}

// override
function SetFireParameters(bool bHit, optional int OverrideTargetID, optional bool NotifyMultiTargetsAtOnce=true)
{
	super.SetFireParameters(bHit, OverrideTargetID, false);
}


function ProjectileNotifyHit(bool bMainImpactNotify, Vector HitLocation)
{
	super.ProjectileNotifyHit(bMainImpactNotify, HitLocation);
	OnProjectileHit(HitLocation);
}

function OnProjectileHit(vector vLocation)
{
	local int i;
	local bool bShouldNotify;
	bShouldNotify = true;
	// the main projectile has hit! it gets notified automatically
	if (!ChainHasStarted())
	{
		Targets[0].bHasNotified = true;
		notifiedTargets++;
		i = 0;
		bShouldNotify = false;
	}
	else
	{
		i = FindNearestTarget(vLocation);
	}
	if (i != INDEX_NONE)
	{
		AdvanceChain(i, bShouldNotify, i == 0 ? vLocation : Targets[i].vCoarseLocation);
	}
}

function int FindNearestTarget(vector vLocation)
{
	local int i;
	local int iLowestDist;
	local float fLowestDistSq;
	local float distSq;
	iLowestDist = INDEX_NONE;
	fLowestDistSq = 100000000.0;
	for (i = 0; i < Targets.Length; i++)
	{	
		distSq = VSizeSq(Targets[i].vCoarseLocation - vLocation);
		if (iLowestDist == INDEX_NONE || distSq < fLowestDistSq)
		{
			iLowestDist = i;
			fLowestDistSq = distSq;
		}
	}
	if (!Targets[iLowestDist].bHasStarted || Targets[iLowestDist].bHasNotified)
	{
		return INDEX_NONE;
	}
	return iLowestDist;
}

// this function notifies iHitIdx, marks it as notified, and initiates the next chain segments
// it marks the next ones as started and spawns cosmetic projectiles
function AdvanceChain(int iHitIdx, bool bDoNotifyTarget, vector vSourceLocation)
{
	local int i;
	local StateObjectReference Target;
	if (bDoNotifyTarget)
	{
		Targets[iHitIdx].bHasNotified = true;
		notifiedTargets++;
		// out parameter, unrealscript dumb
		Target = Targets[iHitIdx].TargetID;
		//VisualizationMgr.SendInterTrackMessage(Target, CurrentHistoryIndex);
	}
	for (i = 1; i < Targets.Length; i++)
	{
		// find all nodes that originate from the current
		if (Targets[i].iPrevNode == iHitIdx)
		{
			Targets[i].bHasStarted = true;
			SendProjectile(vSourceLocation, Targets[i].vCoarseLocation);
		}
	}
}

function SendProjectile(vector Source, vector Target)
{
	local XComWeapon WeaponEntity;
	local X2UnifiedProjectile NewProjectile;
	local AnimNotify_FireWeaponVolley FireVolleyNotify;
	
	WeaponEntity = XComWeapon(UnitPawn.Weapon);

	FireVolleyNotify = new class'AnimNotify_FireWeaponVolley';
	FireVolleyNotify.NumShots = 1;
	FireVolleyNotify.ShotInterval = 0.3f;
	FireVolleyNotify.bCosmeticVolley = true;

	NewProjectile = class'WorldInfo'.static.GetWorldInfo().Spawn(class'X2UnifiedProjectile', , , , , WeaponEntity.DefaultProjectileTemplate);
	NewProjectile.ConfigureNewProjectileCosmetic(FireVolleyNotify, AbilityContext, , , self, Source, Target, true);
	NewProjectile.GotoState('Executing');

}


simulated state Executing
{

Begin:


	if (XGUnit(PrimaryTarget).GetTeam() == eTeam_Neutral)
	{
		HideFOW();

		// Sleep long enough for the fog to be revealed
		Sleep(1.0f * GetDelayModifier());
	}

	
	UnitPawn.EnableRMA(true, true);
	UnitPawn.EnableRMAInteractPhysics(true);

	class'XComPerkContent'.static.GetAssociatedPerkInstances(Perks, UnitPawn, AbilityContext.InputContext.AbilityTemplateName);
	for( x = 0; x < Perks.Length; ++x )
	{
		kPerkContent = Perks[x];

		if( (kPerkContent.IsInState('ActionActive') || kPerkContent.IsInState('DurationAction')) &&
			kPerkContent.m_PerkData.CasterActivationAnim.PlayAnimation &&
			kPerkContent.m_PerkData.CasterActivationAnim.AdditiveAnim )
		{
			PerkAdditiveAnimNames.AddItem(class'XComPerkContent'.static.ChooseAnimationForCover(Unit, kPerkContent.m_PerkData.CasterActivationAnim));
		}
	}

	for( x =0; x < PerkAdditiveAnimNames.Length; ++x )
	{
		AdditiveAnimParams.AnimName = PerkAdditiveAnimNames[x];
		UnitPawn.GetAnimTreeController().PlayAdditiveDynamicAnim(AdditiveAnimParams);
	}
	for (x = 0; x < ShooterAdditiveAnims.Length; ++x)
	{
		AdditiveAnimParams.AnimName = ShooterAdditiveAnims[x];
		UnitPawn.GetAnimTreeController().PlayAdditiveDynamicAnim(AdditiveAnimParams);
	}
	
	// chain lightning -- the first shot will be taken
	Targets[0].bHasStarted = true;

	FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams));

	for( x =0; x < PerkAdditiveAnimNames.Length; ++x )
	{
		AdditiveAnimParams.AnimName = PerkAdditiveAnimNames[x];
		UnitPawn.GetAnimTreeController().RemoveAdditiveDynamicAnim(AdditiveAnimParams);
	}
	for (x = 0; x < ShooterAdditiveAnims.Length; ++x)
	{
		AdditiveAnimParams.AnimName = ShooterAdditiveAnims[x];
		UnitPawn.GetAnimTreeController().RemoveAdditiveDynamicAnim(AdditiveAnimParams);
	}

	// Taking a shot causes overwatch to be removed
	PresentationLayer.m_kUnitFlagManager.RealizeOverwatch(Unit.ObjectID, History.GetCurrentHistoryIndex());

	//Failure case handling! We failed to notify our targets that damage was done. Notify them now.
	SetTargetUnitDiscState();

	if( FOWViewer != none )
	{
		`XWORLD.DestroyFOWViewer(FOWViewer);

		if( XGUnit(PrimaryTarget).IsAlive() )
		{
			XGUnit(PrimaryTarget).SetForceVisibility(eForceNone);
			XGUnit(PrimaryTarget).GetPawn().UpdatePawnVisibility();
		}
	}

	if( SourceFOWViewer != none )
	{
		`XWORLD.DestroyFOWViewer(SourceFOWViewer);

		Unit.SetForceVisibility(eForceNone);
		Unit.GetPawn().UpdatePawnVisibility();
	}
	while (notifiedTargets < hitTargets)
	{
		Sleep(0.0);
	}
	CompleteAction();
	//reset to false, only during firing would the projectile be able to overwrite aim
	UnitPawn.ProjectileOverwriteAim = false;
}

defaultproperties
{
	bNotifyMultiTargetsAtOnce=false
}