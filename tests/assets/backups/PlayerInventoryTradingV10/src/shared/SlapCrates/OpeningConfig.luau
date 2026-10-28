--!nonstrict
-- Server selects the mode. No client request can override it.
return {
 Mode="StandCinematic",
 AllowedOpenQuantities={1,5,10},
 BatchRevealDurations={[5]=4,[10]=5},
 RewardSpin={SpinDuration=3.6,InitialSpeed=16,DecelerationDuration=2.6,VisiblePreviewCount=5,
  ItemSpacing=2.5,WinningItemScale=1.1,FinalPauseDuration=2.4,MaxPreviewExtent=1.8},
 Stand={Enabled=true,ExclusiveOpening=false,ReopenCooldown=0,SpectatorRadius=80,
  MaxSequenceDuration=25,MaxActivationDistance=10,MaxIdleCrates=3},
 Cinematic={IntroTransitionDuration=.7,CameraRevealDuration=.6,ChestAppearDuration=1,
  ChestRiseDuration=2,ChestGrowthDuration=1,ChestShakeDuration=1,FlashDuration=.5,
  RewardRevealDuration=3,OutroTransitionDuration=.7},
}
