--!nonstrict
local Speed={}
function Speed.Start(record)
 record.BaseSpeed=record.Humanoid.WalkSpeed;record.AppliedSpeed=record.BaseSpeed
 return record.BaseSpeed>0
end
function Speed.Step(record,dt)
 local hum=record.Humanoid
 -- Another owner (lock, recovery, modifier) wins. Do not overwrite its value.
 if math.abs(hum.WalkSpeed-record.AppliedSpeed)>0.001 then return false end
 local target=math.min(record.BaseSpeed*record.Definition.SpeedMultiplier,record.Definition.MaxSpeed)
 record.AppliedSpeed=math.min(target,record.AppliedSpeed+record.Definition.Acceleration*dt)
 hum.WalkSpeed=record.AppliedSpeed
 return true
end
function Speed.Cancel(record)
 if record.AppliedSpeed and record.Humanoid.Parent and math.abs(record.Humanoid.WalkSpeed-record.AppliedSpeed)<0.001 then
  record.Humanoid.WalkSpeed=record.BaseSpeed
 end
end
Speed.Descriptor={Id="DevilSpeed",DisplayName="Velocidad Diabólica",Description="Acelera durante 5 s. El derribo cancela el efecto.",Type="Movilidad",
 Duration=5,Cooldown=14,Icon="",SortOrder=40}
Speed.Enabled=true
Speed.Config={SpeedMultiplier=2.4,MaxSpeed=48,Acceleration=100}
Speed.ConfigSchema={SpeedMultiplier={Type="number",Min=1,Max=5},MaxSpeed={Type="number",Min=1,Max=100},Acceleration={Type="number",Min=1,Max=500}}
Speed.Shop={Price=1500,PriceApproved=true,PurchaseEnabled=true}
Speed.Dependencies={}
Speed.Input={Primary="None"}
Speed.Assets={Key="DevilSpeed",Profile="AttachmentEffect"}
return Speed
