--!nonstrict
local Motion={}
-- Integral of constant velocity followed by a cubic velocity decay: continuous speed, zero at end.
function Motion.Remaining(age,config)
 local duration=config.SpinDuration;local decel=math.min(config.DecelerationDuration,duration)
 local steady=duration-decel;local t=math.clamp(age,0,duration)
 local total=config.InitialSpeed*(steady+decel/4)
 local travelled
 if t<=steady then travelled=config.InitialSpeed*t else
  local q=(t-steady)/decel;travelled=config.InitialSpeed*steady+config.InitialSpeed*decel*(1-(1-q)^4)/4
 end
 return math.max(0,total-travelled)
end
function Motion.Slots(remaining,count)
 local rows={};local center=math.floor(remaining+.5);local half=math.floor(count/2)
 for offset=-half,half do local logical=center+offset
  table.insert(rows,{Logical=logical,Pool=(logical%count)+1,X=logical-remaining,Winner=logical==0})
 end
 return rows
end
return Motion
