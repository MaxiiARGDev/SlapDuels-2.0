--!nonstrict
local Targeting={}
function Targeting.Valid(localPlayer,target,maxDistance)
 if not target or target==localPlayer or not target.Parent or localPlayer:GetAttribute('MatchId')or target:GetAttribute('MatchId')then return false end
 local a=localPlayer.Character;local b=target.Character
 local x=a and a:FindFirstChild('HumanoidRootPart');local y=b and b:FindFirstChild('HumanoidRootPart')
 local h=b and b:FindFirstChildOfClass('Humanoid')
 return x~=nil and y~=nil and h~=nil and h.Health>0 and (x.Position-y.Position).Magnitude<=maxDistance
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
