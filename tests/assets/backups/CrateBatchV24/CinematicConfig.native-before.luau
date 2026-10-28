--!nonstrict
-- Presentation only. Stage durations remain in Shared.SlapCrates.OpeningConfig.
return {
 HideStandPrompt=true,
 RewardOverlayByMode={StandCinematic=false,Spin=true},
 Transition={Letterbox=.075,ClosePower=3,OpenPower=4,OutroHandoff=.5},
 Camera={IntroDuration=1.8,IntroHeight=7,IntroBack=2,IntroLookHeight=12,
  IntroFov=9,Bounce=.045,TensionPosition=.035,TensionDegrees=.18,
  ImpactPosition=.16,ImpactDegrees=.65,ImpactDuration=.85,ImpactFrequency=19,
  FocusResponse=8,PushIn=.035,MaxPositionShake=.2,MaxDegreesShake=.8},
 Audio={Close="WhooshClose",Open="WhooshOpen",Volume=.65},
}
