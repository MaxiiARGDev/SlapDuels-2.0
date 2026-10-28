--!nonstrict
-- One authority for selection, ownership, activation, life identity and timers.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local Definitions=require(RS.Shared.AbilityDefinitions)
local Registry=require(script.Parent.AbilityRegistry)
local Callbacks=require(script.Parent.Parent.Abilities.AbilityCallbacks)
local Input=require(script.Parent.Parent.Abilities.AbilityInputAdapter)
local Service={Name="AbilityService"}
local function generation(character) return character:GetAttribute("ArenaPhysicsGeneration") or 0 end
local function now() return workspace:GetServerTimeNow() end
local function invoke(entry,label,callback,...)
 local result=table.pack(Callbacks.Call(callback,...))
 if not result[1] then
  warn(string.format("[AbilityService] %s.%s: %s",entry.Id,label,tostring(result[2]):sub(1,500)))
 end
 return table.unpack(result,1,result.n)
end
function Service:Init(context)
 self._context=context;self._sessions={};self._rate={};self._revisions={};self._connections={};self._elapsed=0;self._catalogSent={}
 local combat=RS.Remotes.Combat
 local function remote(name)
  local v=combat:FindFirstChild(name)
  local count=0 for _,child in ipairs(combat:GetChildren()) do if child.Name==name then count+=1 end end
  assert(count<=1,"Duplicate ability remote: "..name)
  if not v then v=Instance.new("RemoteEvent");v.Name=name;v.Parent=combat end
  assert(v:IsA("RemoteEvent"),"Invalid ability remote: "..name);return v
 end
 self._request=remote("AbilityRequest");self._state=remote("AbilityState")
 table.insert(self._connections,self._request.OnServerEvent:Connect(function(player,payload) self:HandleRequest(player,payload) end))
end
function Service:Start(_context)
 table.insert(self._connections,RunService.Heartbeat:Connect(function(dt) self:Step(dt) end))
 table.insert(self._connections,Players.PlayerRemoving:Connect(function(player)
  for _,session in pairs(self._sessions) do
   local state=session.Players[player]
   if state then self:CancelPlayer(player,"Disconnect");session.Players[player]=nil end
  end
  self._rate[player]=nil;self._revisions[player]=nil;self._catalogSent[player]=nil
 end))
end
function Service:_round() return self._context:GetService("RoundService") end
function Service:_players() return self._context:GetService("PlayerService") end
function Service:Owns(player,id)
 local d=Registry:Get(id)
 local ps=self:_players()
 return d~=nil and d.Enabled==true and ps~=nil and ps:IsShopDataReady(player)
  and ps:HasItem(player,Definitions.Category,id)
end
function Service:SyncLife(player,state)
 local char=player.Character
 local gen=char and generation(char)
 if state.Character~=char or state.Generation~=gen then
  self:CancelPlayer(player,"LifeChanged")
  state.Character=char;state.Generation=gen;state.LifeId=HttpService:GenerateGUID(false)
 end
end
function Service:_get(player)
 local session=self:_round():GetSessionForPlayer(player)
 local record=session and self._sessions[session.Id]
 return session,record,record and record.Players[player]
end
function Service:_live(player,session)
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players then return nil end
 local round=self:_round()
 if not session or round:GetSessionById(session.Id)~=session or not round:IsSessionActive(session.Id)
  or not round:GetSessionParticipant(session.Id,player) or session.Closing or session.Closed or session.Cancelled or session.Result then return nil end
 local char=player.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local root=char and char:FindFirstChild("HumanoidRootPart")
 if not char or not char:IsDescendantOf(workspace) or char:GetAttribute("ArenaRespawnPending")
  or not hum or hum.Health<=0 or hum.WalkSpeed<=0 or hum.PlatformStand or char:GetAttribute("Ragdolled")==true
  or not root or root.Anchored then return nil end
 local spawn=self._context:GetService("SpawnService")
 local ragdoll=self._context:GetService("RagdollService")
 if ragdoll and ragdoll:IsRagdolled(char) then return nil end
 if spawn and spawn.IsKillPartRespawnPending and spawn:IsKillPartRespawnPending(player) then return nil end
 return char,hum,root
end
function Service:PrepareSelection(session,duration)
 local preparationState=session.State
 if (preparationState~="StartCountdown" and preparationState~="PointRestartCountdown")
  or type(duration)~="number" or duration~=duration or duration<=0 or duration==math.huge
  or self:_round():GetSessionById(session.Id)~=session or session.Closing or session.Closed or session.Cancelled or session.Result then return false end
 local index=if session.GameplayRound then session.GameplayRound.Index+1 else 1
 local preparationId=session.Id..":Preparation:"..tostring(index)..":"..tostring(session.StateVersion)
 local previous=self._sessions[session.Id]
 -- A repeated opener in the same preparation must never extend its deadline.
 if previous and previous.PreparationId==preparationId then return previous.WindowId end
 local choices={}
 if previous then for player,state in pairs(previous.Players) do choices[player]=state.AbilityId end end
 self:CleanupSession(session.Id,"NewSelection")
 local record={Session=session,Players={},WindowId=HttpService:GenerateGUID(false),
  PreparationId=preparationId,PreparationIndex=index,PreparationState=preparationState,PreparationVersion=session.StateVersion,
  SelectionUntil=os.clock()+duration,SelectionNetworkUntil=now()+duration,Selecting=true}
 self._sessions[session.Id]=record
 for _,member in ipairs(session.Participants) do
  local player=member.Player
  if self:_round():GetSessionParticipant(session.Id,player) then
   local preferred=self:_players():GetEquippedItem(player,Definitions.Category)
   local selected=if self:Owns(player,choices[player]) then choices[player] elseif self:Owns(player,preferred) then preferred else Definitions.DefaultId
   record.Players[player]={AbilityId=selected,
    CooldownUntil=0,State="Selecting"}
  end
 end
 self:PublishSession(record)
 return record.WindowId
end
function Service:FinishSelection(session,windowId)
 local record=self._sessions[session.Id]
 if not record or record.WindowId~=windowId or not record.Selecting then return end
 record.Selecting=false
 for _,state in pairs(record.Players) do state.State="Prepared" end
 self:PublishSession(record)
end
function Service:IsSelectionOpen(record,player)
 local session=record.Session
 return self._sessions[session.Id]==record and record.Selecting and os.clock()<record.SelectionUntil
  and session.State==record.PreparationState and session.StateVersion==record.PreparationVersion
  and (session.State=="StartCountdown" or session.State=="PointRestartCountdown")
  and not session.Closing and not session.Closed and not session.Cancelled and session.Result==nil
  and self:_round():GetSessionById(session.Id)==session and self:_round():IsSessionActive(session.Id)
  and self:_round():GetSessionParticipant(session.Id,player)~=nil
end
function Service:BeginRound(session)
 local record=self._sessions[session.Id]
 assert(record and not record.Selecting,"AbilitySelectionRequired")
 record.RoundId=session.GameplayRound.Id;record.Playing=true
 for player,state in pairs(record.Players) do
  if not self:Owns(player,state.AbilityId) then state.AbilityId=Definitions.DefaultId end
  state.CooldownUntil=0;state.State="Ready"
 end
 self:PublishSession(record)
end
function Service:CancelPlayer(player,reason)
 local _,record,state=self:_get(player)
 -- RoundService may unregister a disconnect before this service's callback.
 if not state then
  for _,candidate in pairs(self._sessions) do
   if candidate.Players[player] then record=candidate;state=candidate.Players[player];break end
  end
 end
 if not state then return end
 local active=state.Active
 state.Active=nil
 if active then
  -- Detach the active record before cleanup, so duplicate callbacks cannot cancel it twice.
  invoke(active.Entry,"Cancel",active.Entry.Module.Cancel,active.Runtime)
 end
 state.State=if record.Playing then "Cooldown" else "Prepared"
 state.Reason=reason
end
function Service:CancelSession(sessionId,reason)
 local record=self._sessions[sessionId]
 if not record then return end
 record.Playing=false;record.Selecting=false
 for player in pairs(record.Players) do self:CancelPlayer(player,reason) end
 self:PublishSession(record)
end
function Service:CleanupSession(sessionId,reason)
 self:CancelSession(sessionId,reason)
 self._sessions[sessionId]=nil
end
-- Generic, single-use contact capability. SlapService captures it after all
-- normal contact checks and consumes it only after CombatService accepts the hit.
function Service:PrepareHit(player,session)
 local actual,record,state=self:_get(player)
 local active=state and state.Active
 local hooks=active and active.Entry.Hooks
 if actual~=session or not record or not record.Playing or not hooks
  or active.ActiveUntil<=os.clock() or player.Character~=active.Character
  or generation(active.Character)~=active.CharacterGeneration or not self:_live(player,session) then return nil end
 local ok,ready=invoke(active.Entry,"BeforeHit",hooks.BeforeHit,active.Runtime)
 if not ok then self:CancelPlayer(player,"HitHookFailed");return nil end
 if ready~=true then return nil end
 local ticket=table.freeze({ActivationId=active.ActivationId,SkipComboCount=true})
 active.HitTicket=ticket
 return ticket
end
function Service:ConsumeHit(player,session,opponent,ticket)
 local actual,record,state=self:_get(player)
 local active=state and state.Active
 if actual~=session or not record or not record.Playing or not active or active.HitTicket~=ticket
  or not ticket or ticket.ActivationId~=active.ActivationId or active.Character~=player.Character
  or generation(active.Character)~=active.CharacterGeneration then return false end
 active.HitTicket=nil
 local hooks=active.Entry.Hooks
 local ok,consumed=invoke(active.Entry,"Consume",hooks.Consume,active.Runtime)
 if not ok or consumed~=true then self:CancelPlayer(player,"HitHookRejected");return false end
 local char=opponent.Character
 local cue=char and {Kind="AbilityCue",AbilityId=active.AbilityId,Cue=hooks.Cue,
  SessionId=session.Id,ActivationId=active.ActivationId,Position=char:GetPivot().Position}
 self:CancelPlayer(player,"Consumed")
 self:PublishSession(record)
 return true,cue,hooks.Reason
end
function Service:PresentCue(session,cue)
 local record=self._sessions[session.Id]
 if not record or not record.Playing or not cue then return end
 for viewer in pairs(record.Players) do
  if viewer.Parent==Players then self._state:FireClient(viewer,cue) end
 end
end
function Service:HandleRequest(player,payload)
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players then return end
 local t=os.clock()
 if t<(self._rate[player] or 0) then return end
 self._rate[player]=t+Definitions.RequestInterval
 if type(payload)~="table" or type(payload.Action)~="string" then return end
 local session,record,state=self:_get(player)
 if payload.Action=="Sync" then self._catalogSent[player]=nil;self:Publish(player,record);return end
 if not session or not record or not state or payload.SessionId~=session.Id then return end
 if payload.Action=="Select" then
  if type(payload.RequestId)~="string" or #payload.RequestId==0 or #payload.RequestId>80 then return end
  local allowed=self:IsSelectionOpen(record,player) and payload.WindowId==record.WindowId
   and payload.PreparationId==record.PreparationId and type(payload.AbilityId)=="string" and self:Owns(player,payload.AbilityId)
  if allowed then state.AbilityId=payload.AbilityId end
  state.SelectionReceipt={RequestId=payload.RequestId,WindowId=payload.WindowId,PreparationId=payload.PreparationId,
   AbilityId=state.AbilityId,Accepted=allowed==true,Reason=if allowed then "Confirmed" else "SelectionRejected"}
  self:Publish(player,record)
  return
 end
 local char,hum,root=self:_live(player,session)
 if state.Character~=player.Character or (player.Character and state.Generation~=generation(player.Character)) then
  self:SyncLife(player,state);self:Publish(player,record);return
 end
 if not char or not record.Playing or session.State~="Playing" or session.PointInProgress
  or payload.LifeId~=state.LifeId
  or payload.RoundId~=record.RoundId or payload.CharacterGeneration~=generation(char)
  or payload.AbilityId~=state.AbilityId or not self:Owns(player,state.AbilityId)
  or not self:_round():IsGameplayRoundOpen(session) then return end
 local entry=Registry:Get(state.AbilityId)
 if not entry or not entry.Enabled then return end
 if payload.Action~="Activate" then
  local action=entry.Actions[payload.Action]
  local active=state.Active
  if not action or not active or payload.ActivationId~=active.ActivationId
   or active.ActiveUntil<=t or active.Character~=char then return end
  local valid,input=Input.Validate(action.Input,payload)
  if not valid then return end
  local ok=invoke(entry,"OnAction",entry.Module.OnAction,active.Runtime,payload.Action,input,t)
  if not ok then self:CancelPlayer(player,"ActionFailed");self:PublishSession(record) end
  return
 end
 if state.Active or t<state.CooldownUntil then return end
 local valid,direction=Input.Validate(entry.Input.Primary,payload)
 if not valid then return end
 local definition=entry.Definition
 local activationId=HttpService:GenerateGUID(false)
 local info=session.InstanceInfo
 local killParts={} for _,part in ipairs(info and info.KillParts or {}) do table.insert(killParts,part) end
 local runtime=Callbacks.Runtime(table.freeze({AbilityId=state.AbilityId,Definition=definition,Config=entry.Config,
  SessionId=session.Id,RoundId=record.RoundId,UserId=player.UserId,
  Character=char,CharacterGeneration=generation(char),Humanoid=hum,Root=root,
  ActivationId=activationId,ActivatedAt=t,ActiveUntil=t+definition.Duration,
  World=table.freeze({VoidBoundaryPart=info and info.VoidBoundaryPart,KillParts=table.freeze(killParts)})}))
 local active={AbilityId=state.AbilityId,Entry=entry,Runtime=runtime,Character=char,
  CharacterGeneration=generation(char),ActivationId=activationId,ActiveUntil=t+definition.Duration,
  CooldownUntil=t+definition.Cooldown,NetworkActiveUntil=now()+definition.Duration}
 -- Reserve before callbacks. Modules receive neither the session nor economy/services.
 -- Callbacks cannot yield; cleanup runs once even after partial activation failure.
 state.Active=active
 if entry.Module.ValidateActivation then
  local ok,allowed=invoke(entry,"ValidateActivation",entry.Module.ValidateActivation,runtime,direction)
  if not ok or allowed~=true then self:CancelPlayer(player,"ValidationRejected");self:PublishSession(record);return end
 end
 local ok,started=invoke(entry,"Start",entry.Module.Start,runtime,direction)
 if not ok or started~=true then self:CancelPlayer(player,"ActivationRejected");self:PublishSession(record);return end
 state.CooldownUntil=active.CooldownUntil;state.State=runtime.State
 self:PublishSession(record)
end
function Service:Publish(player,record)
 if player.Parent~=Players then return end
 local session=record and record.Session
 local state=record and record.Players[player]
 self._revisions[player]=(self._revisions[player] or 0)+1
 local payload={Kind="State",Revision=self._revisions[player],SessionId=session and session.Id,
  RoundId=record and record.RoundId,WindowId=record and record.WindowId,Selecting=record and self:IsSelectionOpen(record,player) or false,
  PreparationId=record and record.PreparationId,PreparationIndex=record and record.PreparationIndex,
  PreparationState=record and record.PreparationState,
  Preparing=record~=nil and session.State==record.PreparationState and session.StateVersion==record.PreparationVersion
   and not session.Closing and not session.Closed and not session.Cancelled and session.Result==nil,
  SelectionUntil=record and record.SelectionNetworkUntil,Playing=record and record.Playing or false,
  AbilityId=state and state.AbilityId or Definitions.DefaultId,Owned={},Presentations={}}
 for _,id in ipairs(Registry.GetPublicCatalog().Order) do payload.Owned[id]=self:Owns(player,id) end
 if state then
  self:SyncLife(player,state)
  local a=state.Active
  payload.State=state.State;payload.CooldownUntil=now()+math.max(0,state.CooldownUntil-os.clock())
  payload.ActivationId=a and a.ActivationId;payload.ActiveUntil=a and a.NetworkActiveUntil
  payload.CharacterGeneration=player.Character and generation(player.Character)
  payload.LifeId=state.LifeId
  payload.SelectionReceipt=state.SelectionReceipt
 end
 if record and record.Playing then
  for subject,s in pairs(record.Players) do
   local a=s.Active
   if a then table.insert(payload.Presentations,{UserId=subject.UserId,AbilityId=a.AbilityId,
    ActivationId=a.ActivationId,CharacterGeneration=a.CharacterGeneration,ActiveUntil=a.NetworkActiveUntil}) end
  end
 end
 if not self._catalogSent[player] then
  payload.Catalog=Registry.GetPublicCatalog();self._catalogSent[player]=true
 end
 self._state:FireClient(player,payload)
end
function Service:PublishSession(record)
 for player in pairs(record.Players) do self:Publish(player,record) end
end
function Service:Step(dt)
 self._elapsed+=dt
 local publish=self._elapsed>=Definitions.SnapshotInterval
 if publish then self._elapsed=0 end
 for _,record in pairs(self._sessions) do
  local session=record.Session
  if record.Selecting and (os.clock()>=record.SelectionUntil or session.State~=record.PreparationState
   or session.StateVersion~=record.PreparationVersion or session.Closing or session.Closed or session.Cancelled or session.Result) then
   self:FinishSelection(session,record.WindowId)
  end
  for player,state in pairs(record.Players) do
   local a=state.Active
   if a then
    local char=self:_live(player,session)
    if not record.Playing or session.State~="Playing" or session.PointInProgress or not session.GameplayRound
     or session.GameplayRound.Resolved or session.GameplayRound.Id~=record.RoundId
     or char~=a.Character or generation(a.Character)~=a.CharacterGeneration or os.clock()>=a.ActiveUntil then
     self:CancelPlayer(player,"ExpiredOrInvalidated")
    else
     local ok,keep=true,true
     if a.Entry.Module.Step then ok,keep=invoke(a.Entry,"Step",a.Entry.Module.Step,a.Runtime,dt) end
     if not ok or not keep then self:CancelPlayer(player,"ModuleStopped") end
    end
   end
   if not state.Active and record.Playing then
    state.State=if os.clock()>=state.CooldownUntil then "Ready" else "Cooldown"
   end
  end
  if publish then self:PublishSession(record) end
 end
end
return Service
