--!nonstrict
-- Zero-Death lifecycle owned by SpawnService. Keeps the same Character and independent VFX alive.
local Players=game:GetService("Players")
local Config=require(game.ReplicatedStorage.Shared.Config)
local Policy=require(game.ReplicatedStorage.Shared.ArenaRespawnPolicy)
local CharacterPhysics=require(script.Parent.CharacterPhysics)
local Lifecycle={}
Lifecycle.__index=Lifecycle
function Lifecycle.new(spawn) return setmetatable({Spawn=spawn,Pending={}},Lifecycle) end
function Lifecycle:Trace(record,phase)
 if not Config.Respawn.Debug then return end
 print("[RespawnDebug]",phase,"EliminationId",record.EliminationId,"UserId",record.Player.UserId,
  "Generation",record.Character:GetAttribute("ArenaPhysicsGeneration"),"Kind",record.Kind,
  "Session",record.Session.Id,"RoundState",record.Session.State,"State",record.Humanoid:GetState().Name,"Jump",record.Humanoid.Jump,
  "Linear",record.Root.AssemblyLinearVelocity,"Angular",record.Root.AssemblyAngularVelocity)
end
local function zero(character)
 for _,part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero end
 end
end
function Lifecycle:Take(player)
 local record=self.Pending[player]
 if not record then return nil end
 self.Pending[player]=nil
 if record.Thread and record.Thread~=coroutine.running() then pcall(task.cancel,record.Thread) end
 if record.Connection then record.Connection:Disconnect() end
 return record
end
function Lifecycle:Restore(record)
 local character=record.Character
 if not character.Parent then return end
 for object,properties in pairs(record.Properties) do
  if object.Parent then for key,value in pairs(properties) do object[key]=value end end
 end
 -- Never adopt transient Physics/ragdoll collision values as the normal avatar contract.
 CharacterPhysics.Restore(character)
 local humanoid=record.Humanoid
 if humanoid.Parent then
  humanoid.Jump=false
  humanoid.AutoRotate=not humanoid:GetAttribute("MovementLocked") and record.AutoRotate
  humanoid.PlatformStand=record.PlatformStand
  humanoid.DisplayDistanceType=record.DisplayDistanceType
  humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,record.JumpingEnabled)
 end
 zero(character)
 record.Root.Anchored=record.Anchored
 character:SetAttribute("ArenaRespawnPending",nil)
 character:SetAttribute("ArenaPhysicsPhase","Playing")
 self:Trace(record,"ServerRestored")
 if record.Root.Parent and not record.Root.Anchored then
  pcall(function()
   if record.OwnerAuto then record.Root:SetNetworkOwnershipAuto()
   else record.Root:SetNetworkOwner(record.Owner and record.Owner.Parent==Players and record.Owner or nil) end
  end)
 end
end
function Lifecycle:Cancel(player,reason,recover)
 local record=self.Pending[player]
 if not record then return end
 print("[ArenaRespawn] Cancelled",record.Session.Id,record.EliminationId,reason)
 self:Trace(record,"Cancelled:"..reason)
 if recover and player.Parent==Players and player.Character==record.Character then
  if self.Spawn:ResetCharacterInArena(player,record.Session.Id) then return end
 end
 record=self:Take(player)
 if record then self:Restore(record) end
end
function Lifecycle:CancelSession(id,reason,recover)
 local players={}
 for player,record in pairs(self.Pending) do if record.Session.Id==id then table.insert(players,player) end end
 for _,player in ipairs(players) do self:Cancel(player,reason,recover) end
end
function Lifecycle:Begin(player,session,eliminationId,kind)
 if self.Pending[player] then return false end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not character or not humanoid or not root or humanoid.Health<=0 then return false end
 local delayMs,valid=Policy.NormalizeDelayMs(Config.Respawn.KillPartDelayMs,Config.Respawn.MaxKillPartDelayMs)
 if not valid then warn("[ArenaRespawn] Invalid/out-of-range KillPartDelayMs normalized to",delayMs) end
 local ownerAuto,owner=true,nil
 pcall(function()ownerAuto=root:GetNetworkOwnershipAuto();owner=root:GetNetworkOwner();root:SetNetworkOwner(nil)end)
 local generation=(character:GetAttribute("ArenaPhysicsGeneration") or 0)+1
 local ragdoll=self.Spawn:_getRagdollService()
 local hadRagdoll=ragdoll and ragdoll:IsRagdolled(character) or false
 local record={Player=player,Character=character,Humanoid=humanoid,Root=root,Session=session,
  StateVersion=session.StateVersion,Generation=generation,EliminationId=eliminationId,Kind=kind or "KillPart",
  Anchored=root.Anchored,OwnerAuto=ownerAuto,Owner=owner,Properties={},Started=os.clock(),
  AutoRotate=humanoid.AutoRotate,PlatformStand=false,JumpingEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
  DisplayDistanceType=humanoid.DisplayDistanceType}
 self.Pending[player]=record
 character:SetAttribute("ArenaPhysicsPhase","Retired")
 character:SetAttribute("ArenaRespawnDebug",Config.Respawn.Debug==true)
 character:SetAttribute("ArenaEliminationId",eliminationId)
 character:SetAttribute("ArenaPhysicsGeneration",generation)
 character:SetAttribute("ArenaRespawnPending",true)
 character:SetAttribute("ArenaRespawnRevision",(character:GetAttribute("ArenaRespawnRevision") or 0)+1)
 root.Anchored=true
 -- Cancel old ragdoll callbacks/constraints without a GettingUp impulse or a new launch.
 if ragdoll then ragdoll:ResetRagdollImmediate(character,true) end
 record.AutoRotate=humanoid.AutoRotate
 local function hide(object)
  if record.Properties[object] then return end
  if object:IsA("BasePart") then
   record.Properties[object]={Transparency=object.Transparency,CanCollide=object.CanCollide,
    CanTouch=object.CanTouch,CanQuery=object.CanQuery,CastShadow=object.CastShadow}
   object.Transparency=1;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false;object.CastShadow=false
  elseif object:IsA("Decal") then record.Properties[object]={Transparency=object.Transparency};object.Transparency=1
  elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
   record.Properties[object]={Enabled=object.Enabled};object.Enabled=false
  elseif object:IsA("BillboardGui") then record.Properties[object]={Enabled=object.Enabled};object.Enabled=false end
 end
 for _,object in ipairs(character:GetDescendants()) do hide(object) end
 record.Connection=character.DescendantAdded:Connect(hide)
 humanoid.Jump=false;humanoid.AutoRotate=false;humanoid.PlatformStand=true
 humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 zero(character)
 self:Trace(record,if hadRagdoll then "RetiredAfterRagdoll" else "RetiredWithoutRagdoll")
 print("[ArenaRespawn] Retired",session.Id,eliminationId,"Generation",generation,"DelayMs",delayMs)
 record.Thread=task.delay(math.max(0,delayMs/1000-(os.clock()-record.Started)),function()
  record.Thread=nil
  if self.Pending[player]~=record then return end
  local rounds=self.Spawn:_getRoundService()
  local current=rounds:GetSessionForPlayer(player)
  if player.Parent~=Players or not Policy.IsCurrent(record,current,player.Character,character:GetAttribute("ArenaPhysicsGeneration"))
   or rounds:GetSessionParticipant(session.Id,player)==nil then
   -- Obsolete timers only release their own resources; never reposition any Character.
   self:Cancel(player,"StaleTimer",false)
   return
  end
  local ok,failure=pcall(self.Spawn.ResetCharacterInArena,self.Spawn,player,session.Id)
  if not ok or not failure then
   warn("[ArenaRespawn] Respawn failed",session.Id,eliminationId,tostring(failure))
   self:Cancel(player,"PlacementFailed",false)
   if rounds._cancelSession then rounds:_cancelSession("KillPartRespawnFailed",session.Id) end
   return
  end
  print("[ArenaRespawn] Restored",session.Id,eliminationId,"ElapsedMs",math.floor((os.clock()-record.Started)*1000))
 end)
 return true
end
return Lifecycle
