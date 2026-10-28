--!nonstrict
local Timeline={}
local stages={{"Intro","IntroTransitionDuration"},{"CameraReveal","CameraRevealDuration"},
 {"Appear","ChestAppearDuration"},{"Rise","ChestRiseDuration"},{"Growth","ChestGrowthDuration"},
 {"Shake","ChestShakeDuration"},{"Flash","FlashDuration"},{"Reward","RewardRevealDuration"},
 {"Outro","OutroTransitionDuration"}}
function Timeline.Build(config)
 if type(config)~="table"or(config.Mode~="Spin"and config.Mode~="StandCinematic")then return nil,"InvalidOpeningConfig"end
 local stand,c=config.Stand,config.Cinematic
 if type(stand)~="table"or type(c)~="table"or type(stand.Enabled)~="boolean"or type(stand.ExclusiveOpening)~="boolean"then return nil,"InvalidOpeningConfig"end
 for _,key in ipairs({"ReopenCooldown","SpectatorRadius","MaxSequenceDuration","MaxActivationDistance","MaxIdleCrates"})do
  local v=stand[key];if type(v)~="number"or v~=v or v<0 or v==math.huge then return nil,"InvalidOpeningConfig"end
 end
 if stand.MaxActivationDistance<=0 or stand.MaxActivationDistance>20 or stand.SpectatorRadius>150
  or stand.MaxIdleCrates%1~=0 or stand.MaxIdleCrates>6 or stand.MaxSequenceDuration>60 then return nil,"InvalidOpeningConfig"end
 local plan={Stages={},Duration=0}
 for _,row in ipairs(stages)do
  local d=c[row[2]];if type(d)~="number"or d~=d or d<=0 or d>10 then return nil,"InvalidOpeningConfig"end
  table.insert(plan.Stages,{Name=row[1],Start=plan.Duration,Duration=d});plan.Duration+=d
 end
 if plan.Duration>stand.MaxSequenceDuration then return nil,"InvalidOpeningConfig"end
 return plan
end
function Timeline.At(plan,elapsed)
 for _,stage in ipairs(plan.Stages)do if elapsed<stage.Start+stage.Duration then
  return stage.Name,math.clamp((elapsed-stage.Start)/stage.Duration,0,1)
 end end
 return "Done",1
end
return Timeline
