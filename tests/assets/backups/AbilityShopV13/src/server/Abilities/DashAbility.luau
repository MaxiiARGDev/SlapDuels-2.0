--!nonstrict
local Guard=require(script.Parent.MovementGuard)
local Dash={}
function Dash.Start(record,direction)
 local horizontal=Vector3.new(direction.X,0,direction.Z)
 if horizontal.Magnitude<0.05 then horizontal=Vector3.new(record.Root.CFrame.LookVector.X,0,record.Root.CFrame.LookVector.Z) end
 if horizontal.Magnitude<0.05 then return false end
 local taken,ownership=Guard.Take(record.Root)
 if not taken then return false end
 record.Ownership=ownership
 record.Direction=horizontal.Unit;record.Travelled=0
 record.DashOrigin=record.Root.Position
 return true
end
function Dash.Step(record,dt)
 if dt>0.1 then return false end -- no long-frame tunnelling impulse
 local speed=record.Definition.DistanceStuds/record.Definition.Duration
 local remaining=record.Definition.DistanceStuds-(record.Root.Position-record.DashOrigin).Magnitude
 local requested=math.min(speed*dt,remaining)
 if requested<=0 then return false end
 local safe=Guard.SafeDistance(record,record.Direction*requested)
 if safe<requested then return false end
 local v=record.Root.AssemblyLinearVelocity
 record.Root.AssemblyLinearVelocity=record.Direction*math.min(speed,safe/math.max(dt,0.001))+Vector3.new(0,v.Y,0)
 return true
end
function Dash.Cancel(record)
 local hum=record.Humanoid
 if record.Root.Parent and not hum.PlatformStand and not record.Character:GetAttribute("ArenaRespawnPending") then
  local v=record.Root.AssemblyLinearVelocity
  record.Root.AssemblyLinearVelocity=Vector3.new(0,v.Y,0)
 end
 Guard.Release(record.Root,record.Ownership);record.Ownership=nil
end
Dash.Descriptor={Id="Dash",DisplayName="Dash",Description="Impulso horizontal dirigido. E o botón táctil.",Type="Movimiento",
 Duration=0.2,Cooldown=11,Icon="",SortOrder=10,DurationKind="Instant"}
Dash.Enabled=true
Dash.Config={DistanceStuds=24}
Dash.ConfigSchema={DistanceStuds={Type="number",Min=1,Max=100}}
Dash.Shop={Price=0,PriceApproved=false,PurchaseEnabled=false}
Dash.Dependencies={"MovementGuard"}
Dash.Input={Primary="Direction"}
Dash.Assets={Key="Dash",Profile="AttachmentEffect"}
return Dash
