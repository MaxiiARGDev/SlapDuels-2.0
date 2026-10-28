--!nonstrict
-- Deterministic scalar choreography; no ownership, economy or gameplay writes.
local Motion={}
local function ease(p)return p*p*(3-2*p)end
function Motion.Cover(stage,p,c)
 p=math.clamp(p,0,1)
 if stage=="Intro"then return .5*(1-(1-p)^c.ClosePower)end
 if stage=="CameraReveal"then return c.Letterbox+(.5-c.Letterbox)*(1-p)^c.OpenPower end
 if stage=="Outro"then
  if p<c.OutroHandoff then return c.Letterbox+(.5-c.Letterbox)*(1-(1-p/c.OutroHandoff)^c.ClosePower)end
  return .5*(1-(p-c.OutroHandoff)/(1-c.OutroHandoff))^c.OpenPower
 end
 if stage=="Done"then return 0 end
 return c.Letterbox
end
function Motion.Sample(plan,elapsed,stage,p,c)
 local entry=plan.Stages[2].Start
 local q=math.clamp((elapsed-entry)/c.IntroDuration,0,1)
 local drop=(1-q)^3-c.Bounce*math.sin(q*math.pi)^2
 local tension=if stage=="Growth"then ease(p)*.35 elseif stage=="Shake"then .35+.65*ease(p)else 0
 local flash=plan.Stages[7].Start
 local impactAge=elapsed-flash
 local impact=if impactAge>=0 and impactAge<c.ImpactDuration then (1-impactAge/c.ImpactDuration)^3 else 0
 local position=math.min(c.MaxPositionShake,c.TensionPosition*tension+c.ImpactPosition*impact)
 local degrees=math.min(c.MaxDegreesShake,c.TensionDegrees*tension+c.ImpactDegrees*impact)
 local frequency=c.ImpactFrequency
 return {Drop=drop,Fov=c.IntroFov*(1-q)^2,
  X=math.sin(elapsed*frequency)*position,Y=math.sin(elapsed*frequency*.79+1)*position*.65,
  Pitch=math.rad(math.sin(elapsed*frequency*.87)*degrees),
  Roll=math.rad(math.sin(elapsed*frequency*.61)*degrees*.5),Impact=impact}
end
return Motion
