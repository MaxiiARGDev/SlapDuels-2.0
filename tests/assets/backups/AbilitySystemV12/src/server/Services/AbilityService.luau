--!nonstrict
-- One authority for selection, ownership, activation, life identity and timers.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local Definitions=require(RS.Shared.AbilityDefinitions)
local folder=script.Parent.Parent.Abilities
local Modules={Dash=require(folder.DashAbility),StrongSlap=require(folder.StrongSlapAbility),
 AirJumps=require(folder.AirJumpsAbility),DevilSpeed=require(folder.DevilSpeedAbility),Invisible=require(folder.InvisibilityAbility)}
local Service={Name="AbilityService"}
local function generation(character) return character:GetAttribute("ArenaPhysicsGeneration") or 0 end
local function now() return workspace:GetServerTimeNow() end
function Service:Init(context)
 self._context=context;self._sessions={};self._rate={};self._revisions={};self._connections={};self._elapsed=0
 local combat=RS.Remotes.Combat
 local function remote(name)
  local v=combat:FindFirstChild(name)
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
  self._rate[player]=nil;self._revisions[player]=nil
 end))
end
function Service:_round() return self._context:GetService("RoundService") end
function Service:_players() return self._context:GetService("PlayerService") end
function Service:Owns(player,id)
 local d=Definitions.Items[id]
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
  local ok,err=pcall(Modules[active.AbilityId].Cancel,active)
  if not ok then warn("[AbilityService] Cleanup failed: "..tostring(err)) end
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
function Service:IsStrongArmed(player,session)
 local actual,record,state=self:_get(player)
 local active=state and state.Active
 return actual==session and record and record.Playing and active and active.AbilityId=="StrongSlap"
  and active.State=="Armed" and active.ActiveUntil>os.clock() and player.Character==active.Character
  and generation(active.Character)==active.CharacterGeneration and self:_live(player,session)~=nil
end
function Service:GetStrongHitToken(player,session)
 if not self:IsStrongArmed(player,session) then return nil end
 local _,_,state=self:_get(player)
 return state.Active.ActivationId
end
function Service:ConsumeStrongHit(player,session,opponent,acceptedToken)
 local actual,record,state=self:_get(player)
 if acceptedToken then
  -- Token captured by SlapService at the validated contact. No yield between
  -- tag registration and consumption; do not lose a combo hit at window expiry.
  if actual~=session or not record or not record.Playing or not state or not state.Active
   or state.Active.ActivationId~=acceptedToken or state.Active.AbilityId~="StrongSlap"
   or state.Active.Character~=player.Character or generation(player.Character)~=state.Active.CharacterGeneration then return false end
 elseif not self:IsStrongArmed(player,session) then return false end
 local active=state.Active
 active.State="Consumed"
 -- A purely visual upward launch, never a force on the competitive Character.
 local char=opponent.Character
 local impact=char and {Kind="StrongImpact",SessionId=session.Id,ActivationId=active.ActivationId,
  Position=char:GetPivot().Position,Lift=active.Definition.PresentationLift}
 self:CancelPlayer(player,"Consumed")
 self:PublishSession(record)
 return true,impact
end
function Service:PresentStrongImpact(session,impact)
 local record=self._sessions[session.Id]
 if not record or not record.Playing or not impact then return end
 for viewer in pairs(record.Players) do
  if viewer.Parent==Players then self._state:FireClient(viewer,impact) end
 end
end
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
function Service:HandleRequest(player,payload)
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players then return end
 local t=os.clock()
 if t<(self._rate[player] or 0) then return end
 self._rate[player]=t+Definitions.RequestInterval
 if type(payload)~="table" or type(payload.Action)~="string" then return end
 local session,record,state=self:_get(player)
 if payload.Action=="Sync" then self:Publish(player,record);return end
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
 if payload.Action=="AirJump" then
  local active=state.Active
  if active and active.AbilityId=="AirJumps" and payload.ActivationId==active.ActivationId
   and active.ActiveUntil>t and active.Character==char then Modules.AirJumps.Jump(active,t) end
  return
 end
 if payload.Action~="Activate" or state.Active or t<state.CooldownUntil then return end
 local direction=payload.Direction
 if state.AbilityId=="Dash" then
  if typeof(direction)~="Vector3" or not finite(direction.X) or not finite(direction.Y) or not finite(direction.Z)
   or direction.Magnitude>1.1 then return end
 else direction=Vector3.zero end
 local definition=Definitions.Items[state.AbilityId]
 local active={AbilityId=state.AbilityId,Definition=definition,SessionId=session.Id,Session=session,
  UserId=player.UserId,Player=player,Character=char,CharacterGeneration=generation(char),Humanoid=hum,Root=root,
  ActivationId=HttpService:GenerateGUID(false),ActivatedAt=t,ActiveUntil=t+definition.Duration,
  CooldownUntil=t+definition.Cooldown,NetworkActiveUntil=now()+definition.Duration,State="Active"}
 -- Reserve before invoking a module. All activation implementations are non-yielding.
 state.Active=active
 local ok,started=pcall(Modules[state.AbilityId].Start,active,direction)
 if not ok or not started then self:CancelPlayer(player,"ActivationRejected");return end
 state.CooldownUntil=active.CooldownUntil;state.State=active.State
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
 for _,id in ipairs(Definitions.Order) do payload.Owned[id]=self:Owns(player,id) end
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
     local ok,keep=pcall(Modules[a.AbilityId].Step,a,dt)
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
