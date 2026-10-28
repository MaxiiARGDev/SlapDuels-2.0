--!nonstrict
local Targeting={}
function Targeting.Valid(localPlayer,target,maxDistance)
 if not target or target==localPlayer or not target.Parent or target.Parent~=localPlayer.Parent or localPlayer:GetAttribute('MatchId')or target:GetAttribute('MatchId')then return false end
 local a=localPlayer.Character;local b=target.Character
 local x=a and a:FindFirstChild('HumanoidRootPart');local y=b and b:FindFirstChild('HumanoidRootPart')
 local h=b and b:FindFirstChildOfClass('Humanoid')
 local ownHumanoid=a and a:FindFirstChildOfClass('Humanoid')
 return x~=nil and y~=nil and h~=nil and h.Health>0 and ownHumanoid~=nil and ownHumanoid.Health>0 and (x.Position-y.Position).Magnitude<=maxDistance
end
-- Exclude whole avatars: a torso/back Slap must not hide its own profile prompt.
-- Both the viewer's body and camera must have an unobstructed path to the target.
function Targeting.Visible(world,localPlayer,target,cameraPosition)
 local a,b=localPlayer.Character,target and target.Character
 local origin=a and a:FindFirstChild('HumanoidRootPart')
 local root=b and b:FindFirstChild('HumanoidRootPart')
 if not origin or not root or not cameraPosition then return false end
 local head=b:FindFirstChild('Head') or root
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={a,b};params.RespectCanCollide=true
 local function clear(from,to)
  local delta=to-from
  return delta.Magnitude<0.001 or world:Raycast(from,delta,params)==nil
 end
 return clear(origin.Position,root.Position) and clear(cameraPosition,head.Position)
end
function Targeting.Select(localPlayer,players,aimed,maxDistance,visible)
 if Targeting.Valid(localPlayer,aimed,maxDistance) and visible(aimed) then return aimed end
 local candidates={}
 local root=localPlayer.Character and localPlayer.Character:FindFirstChild('HumanoidRootPart')
 if not root then return nil end
 for _,target in ipairs(players) do
  if Targeting.Valid(localPlayer,target,maxDistance) then
   table.insert(candidates,{Player=target,Distance=(root.Position-target.Character:FindFirstChild('HumanoidRootPart').Position).Magnitude})
  end
 end
 table.sort(candidates,function(a,b)
  if a.Distance==b.Distance then return a.Player.UserId<b.Player.UserId end
  return a.Distance<b.Distance
 end)
 for _,candidate in ipairs(candidates) do if visible(candidate.Player) then return candidate.Player end end
 return nil
end
function Targeting.FromHit(players,hit)
 local current=hit
 while current and current~=workspace do
  if current:IsA('Model')then local player=players:GetPlayerFromCharacter(current);if player then return player end end
  current=current.Parent
 end
 return nil
end
return Targeting
