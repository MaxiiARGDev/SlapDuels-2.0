--!nonstrict
local Guard=require(script.Parent.MovementGuard)
local Air={}
function Air.Start(record)
 record.AirJumps=0;record.LastJump=0;record.GroundY=record.Root.Position.Y
 return true
end
function Air.Step(record,_dt)
 if record.OwnershipUntil and os.clock()>=record.OwnershipUntil then
  Guard.Release(record.Root,record.Ownership);record.OwnershipUntil=nil;record.Ownership=nil
 end
 if record.Humanoid.FloorMaterial~=Enum.Material.Air then
  record.AirJumps=0;record.GroundY=record.Root.Position.Y
 end
 return true
end
function Air.Jump(record,now)
 local d=record.Definition
 if record.Humanoid.FloorMaterial~=Enum.Material.Air or now-record.LastJump<d.MinJumpInterval
  or record.AirJumps>=d.MaxConsecutiveAirJumps or record.Root.Position.Y-record.GroundY>=d.MaxRiseStuds then return false end
 local displacement=Vector3.new(0,3,0)
 if Guard.SafeDistance(record,displacement)<3 then return false end
 local taken,ownership=Guard.Take(record.Root)
 if not taken then return false end
 record.Ownership=ownership
 record.OwnershipUntil=now+0.15
 record.AirJumps+=1;record.LastJump=now
 local v=record.Root.AssemblyLinearVelocity
 record.Root.AssemblyLinearVelocity=Vector3.new(v.X,math.min(d.AirJumpStrength,d.MaxVerticalVelocity),v.Z)
 return true
end
function Air.Cancel(record) Guard.Release(record.Root,record.Ownership);record.Ownership=nil end
return Air
