--!nonstrict
-- Percent thresholds are visual only; no weights, purchases or outcomes live here.
return {
 Thresholds={NormalAbove=5,FeaturedAtLeast=1,RareAtLeast=.1,UltraAtLeast=.01},
 Profiles={
  {Name="Normal",Burst=2,Fill=.94,Outline=.35,Reaction=0,Duration=.4},
  {Name="Destacado",Burst=5,Fill=.91,Outline=.27,Reaction=0,Duration=.6},
  {Name="Raro",Burst=9,Fill=.88,Outline=.2,Reaction=.025,Duration=.7},
  {Name="Ultra raro",Burst=16,Fill=.85,Outline=.14,Reaction=.06,Duration=1},
  {Name="Jackpot",Burst=28,Fill=.81,Outline=.08,Reaction=.1,Duration=1.3},
 },
 Chest={ColorSpeed=1.8,LockFraction=.65,Fill=.93,Outline=.25},
 MaxParticles=64,MobileParticleScale=.4,MaxMobileParticles=24,
 RingSegments=12,ReactionDuration=.65,MaxReactionDegrees=.35,
 HighlightPulse=.06,WinnerEnterDuration=.35,
}
