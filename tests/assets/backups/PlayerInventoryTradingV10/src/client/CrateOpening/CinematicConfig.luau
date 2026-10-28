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
 Gallery={Columns=5,PortraitColumns=3,Spacing=3.2,RowSpacing=3.3,MaxModelExtent=1.7,
  Stagger=.08,EnterDuration=.24,FrameMargin=1.2,MaxRevealParticles=40},
}
