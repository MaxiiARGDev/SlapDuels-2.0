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
Air.Descriptor={Id="AirJumps",DisplayName="Saltos de Aire",Description="Saltos aéreos moderados durante 15 s; hasta 4 antes de tocar suelo.",Type="Movilidad",
 Duration=15,Cooldown=20,Icon="",SortOrder=30}
Air.Enabled=true
Air.Config={AirJumpStrength=32,MinJumpInterval=0.8,MaxConsecutiveAirJumps=4,MaxVerticalVelocity=38,MaxRiseStuds=24}
Air.ConfigSchema={AirJumpStrength={Type="number",Min=1,Max=100},MinJumpInterval={Type="number",Min=0.1,Max=10},MaxConsecutiveAirJumps={Type="number",Min=1,Max=10,Integer=true},MaxVerticalVelocity={Type="number",Min=1,Max=100},MaxRiseStuds={Type="number",Min=1,Max=100}}
Air.Shop={Price=750,PriceApproved=true,PurchaseEnabled=true}
Air.Dependencies={"MovementGuard"}
Air.Input={Primary="None",ActivePrimaryAction="AirJump",JumpAction="AirJump"}
Air.Assets={Key="AirJumps",Profile="AttachmentEffect"}
Air.Actions={AirJump={Input="None"}}
function Air.OnAction(record,action,_input,clock)
 if action=="AirJump" then return Air.Jump(record,clock) end
 return false
end
return Air
