--!nonstrict
-- Spawn-owned physical contract, captured before competitive mutations, per exact Character.
local PhysicsService=game:GetService("PhysicsService")
local Config=require(game.ReplicatedStorage.Shared.Config)
local Physics={Group="SlapDuelsCharacters",Records=setmetatable({},{__mode="k"})}
function Physics.Configure()
 if not PhysicsService:IsCollisionGroupRegistered(Physics.Group) then PhysicsService:RegisterCollisionGroup(Physics.Group) end
 -- Preserve the authored Default/Default matrix; player exclusion belongs to a separate group.
 PhysicsService:CollisionGroupSetCollidable(Physics.Group,Physics.Group,false)
 PhysicsService:CollisionGroupSetCollidable(Physics.Group,"Default",true)
end
function Physics.Track(character)
 if Physics.Records[character] then return end
 local record={Parts={}}
 Physics.Records[character]=record
 local function capture(part)
  if not part:IsA("BasePart") then return end
  part.CollisionGroup=Physics.Group
  -- These are owned temporary R6 colliders, not a normal avatar collision baseline.
  if part.Name=="Collider" or character:GetAttribute("ArenaRespawnPending") then return end
  record.Parts[part]={CanCollide=part.CanCollide,CanTouch=part.CanTouch,CanQuery=part.CanQuery}
 end
 for _,part in ipairs(character:GetDescendants()) do capture(part) end
 record.Connection=character.DescendantAdded:Connect(capture)
end
function Physics.Forget(character)
 local record=Physics.Records[character]
 if record and record.Connection then record.Connection:Disconnect() end
 Physics.Records[character]=nil
end
function Physics.Restore(character)
 local record=Physics.Records[character]
 if not record then return false end
 for part,properties in pairs(record.Parts) do
  if part:IsDescendantOf(character) then
   part.CollisionGroup=Physics.Group
   part.CanCollide=properties.CanCollide
   part.CanTouch=properties.CanTouch
   part.CanQuery=properties.CanQuery
  end
 end
 return true
end
function Physics.Trace(player,phase,spawn,roundState)
 if not Config.Respawn.Debug then return end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local hum=character and character:FindFirstChildOfClass("Humanoid")
 if not root or not hum then return end
 local support=character:FindFirstChild("Torso") or character:FindFirstChild("LowerTorso") or root
 print("[RespawnDebug]",phase,"UserId",player.UserId,"Session",player:GetAttribute("MatchId"),
  "EliminationId",character:GetAttribute("ArenaEliminationId"),"Generation",character:GetAttribute("ArenaPhysicsGeneration"),
  "RoundState",roundState,"State",hum:GetState().Name,"Jump",hum.Jump,"PlatformStand",hum.PlatformStand,"Anchored",root.Anchored,
  "Linear",root.AssemblyLinearVelocity,"Angular",root.AssemblyAngularVelocity,
  "BodyGroup",support.CollisionGroup,"BodyCanCollide",support.CanCollide,"RootCanCollide",root.CanCollide,
  "SpawnGroup",spawn and spawn.CollisionGroup,"GroupPair",spawn and PhysicsService:CollisionGroupsAreCollidable(support.CollisionGroup,spawn.CollisionGroup))
end
return Physics
