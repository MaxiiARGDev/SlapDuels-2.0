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
 if record.Humanoid.Parent and math.abs(record.Humanoid.WalkSpeed-record.AppliedSpeed)<0.001 then
  record.Humanoid.WalkSpeed=record.BaseSpeed
 end
end
return Speed
