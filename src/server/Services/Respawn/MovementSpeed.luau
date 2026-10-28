--!nonstrict
-- SpawnService owns lifecycle; this helper composes base speed and temporary modifiers.
local Config = require(game.ReplicatedStorage.Shared.Config)
local Movement = {}
local modifiers = setmetatable({}, {__mode = "k"})
function Movement.ResolveBase(session, matchId)
 local state = session and session.State
 if not session or session.Closed or matchId ~= session.Id
  or state == "Waiting" or state == "MatchReady" or state == "MatchCountdown" then
  return Config.Character.LobbyWalkSpeed
 end
 return Config.Character.MatchWalkSpeed
end
function Movement.Base(humanoid)
 return humanoid:GetAttribute("BaseWalkSpeed") or Config.Character.MatchWalkSpeed
end
function Movement.Apply(humanoid, release)
 if not humanoid.Parent or humanoid.Health <= 0 then return false end
 if humanoid:GetAttribute("MovementLocked") or humanoid.PlatformStand
  or humanoid.Parent:GetAttribute("ArenaRespawnPending") then return false end
 -- An unowned zero can belong to another freeze. Only its explicit unlock may release it.
 if humanoid.WalkSpeed <= 0 and not release and not humanoid:GetAttribute("MovementSpeedUnlockPending") then return false end
 local modifier = modifiers[humanoid]
 humanoid.WalkSpeed = Movement.Base(humanoid) + (modifier and modifier.Extra or 0)
 humanoid:SetAttribute("MovementSpeedUnlockPending", nil)
 return true
end
function Movement.SetBase(humanoid, base)
 humanoid:SetAttribute("BaseWalkSpeed", base)
 return Movement.Apply(humanoid)
end
function Movement.SetModifier(humanoid, owner, extra)
 if not humanoid.Parent or humanoid:GetAttribute("MovementLocked") or humanoid.PlatformStand
  or humanoid.Parent:GetAttribute("ArenaRespawnPending") or humanoid.WalkSpeed <= 0 then return false end
 local current = modifiers[humanoid]
 if current and current.Owner ~= owner then return false end
 modifiers[humanoid] = {Owner = owner, Extra = extra}
 return Movement.Apply(humanoid)
end
function Movement.RemoveModifier(humanoid, owner)
 local current = modifiers[humanoid]
 if current and current.Owner == owner then
  local owned = math.abs(humanoid.WalkSpeed - (Movement.Base(humanoid) + current.Extra)) < 0.001
  modifiers[humanoid] = nil
  if owned then Movement.Apply(humanoid) end
 end
end
return Movement
