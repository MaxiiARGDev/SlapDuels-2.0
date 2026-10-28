--!nonstrict
-- Server selects the mode. No client request can override it.
return {
 Mode="StandCinematic",
 Stand={Enabled=true,ExclusiveOpening=true,ReopenCooldown=5,SpectatorRadius=80,
  MaxSequenceDuration=25,MaxActivationDistance=10,MaxIdleCrates=3},
 Cinematic={IntroTransitionDuration=.7,CameraRevealDuration=.6,ChestAppearDuration=1,
  ChestRiseDuration=2,ChestGrowthDuration=1,ChestShakeDuration=1,FlashDuration=.5,
  RewardRevealDuration=3,OutroTransitionDuration=.7},
}
