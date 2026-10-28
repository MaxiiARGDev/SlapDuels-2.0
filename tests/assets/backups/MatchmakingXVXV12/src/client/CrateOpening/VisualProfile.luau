--!nonstrict
-- Presentation only. Every color comes from the registered variation, never an economy tier.
local Profiles={}
local tiers={Basic=1,Common=1,Uncommon=2,Rare=2,Gold=3,Arcoiris=3,Emote=4,Wings=4,Epic=5,Legendary=5,Blood=6,Galaxy=6}
local stageMap={FlashSparks="Flash",SoftGlow="Appear,Growth,Reward",RiseStreaks="Rise",Soft="Appear"}
function Profiles.For(variation)
 local tier=tiers[variation.Id]or 1
 return {Tier=tier,Color=variation.Color,Particles=.65+tier*.15,Light=.65+tier*.18,
  Bob=.1+tier*.012,Spin=.35+tier*.035,Zoom=3+tier*.35,Special=tier>=5}
end
function Profiles.Count(emitter,stage,profile)
 local stages=emitter:GetAttribute("OpeningStages")or stageMap[emitter.Name]or "Flash"
 if not (","..stages..","):find(","..stage..",",1,true)then return 0 end
 local count=emitter:GetAttribute("BurstCount")or 5
 if type(count)~="number"or count~=count or count==math.huge then return 0 end
 return math.clamp(math.floor(count*(profile and profile.Particles or 1)),0,32)
end
function Profiles.Emit(effects,stage,profile)
 local remaining=64
 for _,item in ipairs(effects:GetDescendants())do if item:IsA("ParticleEmitter")then
  local count=math.min(remaining,Profiles.Count(item,stage,profile))
  if count>0 then item:Emit(count);remaining-=count end
 end end
end
function Profiles.Pose(stage,p)
 local eased=p*p*(3-2*p)
 if stage=="Appear"then return eased*.5,.15+eased*.65
 elseif stage=="Rise"then return .5+eased*2,.8
 elseif stage=="Growth"then return 2.5,.8+eased*.45
 elseif stage=="Shake"or stage=="Flash"then return 2.5,1.25 end
 return 0,.15
end
function Profiles.Rotation(plan,elapsed)
 local speeds={Intro=.15,CameraReveal=.15,Appear=.4,Rise=1,Growth=2,Shake=3,Flash=3,Reward=.4,Outro=.2}
 local angle,prior=0,.15
 for _,stage in ipairs(plan.Stages)do
  local t=math.clamp(elapsed-stage.Start,0,stage.Duration);local target=speeds[stage.Name]
  angle+=prior*t+(target-prior)*t*t/(2*stage.Duration)
  if t<stage.Duration then break end;prior=target
 end
 return angle
end
return Profiles
