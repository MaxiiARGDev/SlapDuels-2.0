--!nonstrict
-- A presentation subscriber to the FINAL elimination decision. Never awards anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.DeathFeedbackConfig)
local Catalog = require(ReplicatedStorage.Shared.DeathEffectDefinitions)
local Contract = require(ReplicatedStorage.Shared.DeathFeedbackContract)
local GameConfig = require(ReplicatedStorage.Shared.Config)
local Service = {Name="DeathEffectService"}
function Service:Init(context)
 self._context=context
 self._seen={}
 self._connections={}
 self._remote=ReplicatedStorage.Remotes.Match:FindFirstChild("DeathFeedback")
 if not self._remote then
  self._remote=Instance.new("RemoteEvent"); self._remote.Name="DeathFeedback"
  self._remote.Parent=ReplicatedStorage.Remotes.Match
 end
 assert(self._remote:IsA("RemoteEvent"),"DeathFeedback remote class invalid")
 -- Replicate templates, never live effects. Local clones are visible only to recipients.
 local source=assert(ServerStorage:FindFirstChild("DeathEffects"),"ServerStorage.DeathEffects missing")
 local assets=ReplicatedStorage:FindFirstChild("DeathEffectAssets")
 if not assets then assets=Instance.new("Folder");assets.Name="DeathEffectAssets";assets.Parent=ReplicatedStorage end
 for _,definition in pairs(Catalog) do
  local model=source:FindFirstChild(definition.ModelName)
  assert(model and model:IsA("Model") and model:FindFirstChild("Origin"),"Death effect template missing: "..definition.ModelName)
  for _,item in ipairs(model:GetDescendants()) do
   assert(not item:IsA("LuaSourceContainer") and not item:IsA("Explosion"),"Unsafe death effect template")
   if item:IsA("BasePart") then
    assert(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery,"Unsafe death effect Part")
   end
  end
  if not assets:FindFirstChild(model.Name) then model:Clone().Parent=assets end
 end
end
function Service:HandleConfirmed(record)
 if type(record)~="table" or type(record.EliminationId)~="string" then return false end
 local function reject(reason)
  if GameConfig.Respawn.Debug then warn("[RespawnDebug] FeedbackRejectedServer",record.MatchId,record.EliminationId,record.Reason,reason) end
  return false
 end
 local snapshot=record.FeedbackSnapshot
 local killPart=record.Reason=="KillPart" or record.Reason=="KillPart_NormalFall"
 local snapshotEffect=type(snapshot)=="table" and snapshot.SessionId==record.MatchId
  and snapshot.EliminationId==record.EliminationId and typeof(snapshot.ImpactCFrame)=="CFrame"
  and Catalog[snapshot.EffectId]~=nil
 -- Compatibility for old receipts without an impact snapshot; current sensors always supply one.
 local rewardOnly=not snapshotEffect and not killPart and record.Killer~=nil and (record.RewardCoins or 0)>0
  and (record.Reason=="VoidBoundary" or record.Reason=="VoidBoundaryPolling")
 if (not snapshotEffect and not killPart and not rewardOnly) or (killPart and typeof(record.ImpactCFrame)~="CFrame") then return reject("MissingSnapshotOrImpact") end
 local rounds=self._context:GetService("RoundService")
 local session=rounds:GetSessionById(record.MatchId)
 if not session or not rounds:IsSessionActive(record.MatchId) or session.Closing or session.Closed
  or session.Cancelled or session.GameplayFrozen or not Contract.IsFeedbackState(session.State)
  or record.StateVersion~=session.StateVersion or type(record.ConfirmedAt)~="number"
  or workspace:GetServerTimeNow()-record.ConfirmedAt>Config.EventLifetime then return reject("SessionStateVersionOrAge") end
 local victim=record.Victim
 local participant=victim and rounds:GetSessionParticipant(session.Id,victim)
 if not participant or victim.Parent~=Players or victim:GetAttribute("MatchId")~=session.Id then return reject("VictimNotInSession") end
 local killer=record.Killer
 if killer then
  local attacker=rounds:GetSessionParticipant(session.Id,killer)
  if not attacker or killer==victim or killer.Parent~=Players or attacker.Team==participant.Team
   or killer:GetAttribute("MatchId")~=session.Id then return reject("AttackerNotInSession") end
 end
 local seen=self._seen[session.Id]
 if not seen then seen={};self._seen[session.Id]=seen end
 if seen[record.EliminationId] then return reject("DuplicateEliminationId") end
 seen[record.EliminationId]=true
 local effectId=if snapshotEffect then snapshot.EffectId else Contract.ResolveEffect(self._context:GetService("PlayerService"),victim,killer~=nil,Catalog,Config.DeathEffects)
 if not Catalog[effectId] then warn("[DeathEffectService] Effect not allowlisted");return false end
 local payload={
  SessionId=session.Id, StateVersion=session.StateVersion, EliminationId=record.EliminationId,
  Kind=if snapshotEffect then snapshot.Kind else (killer and "CreditedKill" or "UnattributedFall"),
  VictimUserId=if snapshotEffect then snapshot.VictimUserId else victim.UserId, VictimName=if snapshotEffect then snapshot.VictimName else victim.DisplayName,
  KillerUserId=if snapshotEffect then snapshot.KillerUserId else (killer and killer.UserId), KillerName=if snapshotEffect then snapshot.KillerName else (killer and killer.DisplayName),
  EffectId=effectId, ImpactCFrame=if snapshotEffect then snapshot.ImpactCFrame else record.ImpactCFrame,
  Debug=GameConfig.Respawn.Debug==true, Generation=if snapshotEffect then snapshot.Generation else nil, Reason=record.Reason,
  RewardOnly=rewardOnly,
  SentAt=record.ConfirmedAt,
 }
 for _,member in ipairs(session.Participants) do
  local player=member.Player
  if (not rewardOnly or player==killer) and player and player.Parent==Players and rounds:GetSessionParticipant(session.Id,player)==member
   and player:GetAttribute("MatchId")==session.Id then
   local private=table.clone(payload)
   -- Other spectators never receive a reward trigger, even inside this session.
   private.RewardCoins=player==killer and math.max(0,record.RewardCoins or 0) or 0
   self._remote:FireClient(player,private)
   if GameConfig.Respawn.Debug then print("[RespawnDebug] FeedbackSent",session.Id,record.EliminationId,"To",player.UserId,"Effect",effectId,"RewardOnly",rewardOnly,"Coins",private.RewardCoins) end
  end
 end
 print("[DeathEffectService] Confirmed",session.Id,record.EliminationId,payload.Kind,effectId)
 return true
end
function Service:Start(context)
 table.insert(self._connections,context:GetService("EliminationService").PlayerEliminated:Connect(function(record)
  local ok,failure=pcall(self.HandleConfirmed,self,record)
  if not ok then warn("[DeathEffectService] "..tostring(failure)) end
 end))
 local elapsed=0
 table.insert(self._connections,RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1 then return end;elapsed=0
  local rounds=context:GetService("RoundService")
  for id in pairs(self._seen) do if not rounds:IsSessionActive(id) then self._seen[id]=nil end end
 end))
end
return Service
