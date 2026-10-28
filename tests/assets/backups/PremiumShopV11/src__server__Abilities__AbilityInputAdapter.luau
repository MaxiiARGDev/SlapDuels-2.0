--!nonstrict
-- Reusable input capabilities, not ability identifiers.
local Adapter={}
function Adapter.Validate(profile,payload)
 if profile=="None" then return true,Vector3.zero end
 if profile~="Direction" then return false end
 local v=payload.Direction
 if typeof(v)~="Vector3" then return false end
 for _,number in {v.X,v.Y,v.Z} do
  if number~=number or math.abs(number)==math.huge then return false end
 end
 if v.Magnitude>1.1 then return false end
 return true,v
end
return table.freeze(Adapter)
