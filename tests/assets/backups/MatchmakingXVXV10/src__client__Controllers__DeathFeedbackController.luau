--!nonstrict
local Players=game:GetService("Players")
local Config=require(game.ReplicatedStorage.Shared.DeathFeedbackConfig)
local Catalog=require(game.ReplicatedStorage.Shared.DeathEffectDefinitions)
local Contract=require(game.ReplicatedStorage.Shared.DeathFeedbackContract)
local EffectPlayer=require(script.Parent.Parent.DeathFeedback.DeathEffectPlayer)
local Notifications=require(script.Parent.Parent.DeathFeedback.DeathNotifications)
local Controller={Name="DeathFeedbackController"}
local function trace(payload,phase,...)
 if type(payload)=="table" and payload.Debug then print("[RespawnDebug]",phase,payload.SessionId,payload.EliminationId,Players.LocalPlayer.UserId,payload.Generation,payload.Reason,payload.EffectId,...) end
end
function Controller:Init(context)
 self._context=context;self._seen={};self._effects={};self._connections={}
 self._state=nil;self._session=nil;self._version=-1
end
function Controller:Cleanup()
 self._cutoff=workspace:GetServerTimeNow()
 for _,scope in ipairs(self._effects) do scope:Destroy() end
 self._effects={}
 Notifications.Clear()
 local reward=self._context:GetController("KillRewardController")
 if reward then reward:Cleanup() end
end
function Controller:Receive(payload)
 local player=Players.LocalPlayer
 trace(payload,"FeedbackReceived",self._session,self._version,self._state)
 if type(payload)~="table" or type(payload.SessionId)~="string" or type(payload.EliminationId)~="string"
  or payload.SessionId~=player:GetAttribute("MatchId") or payload.SessionId~=self._session
  or payload.StateVersion~=self._version or not Contract.IsFeedbackState(self._state)
  or (payload.RewardOnly~=true and typeof(payload.ImpactCFrame)~="CFrame") or not Catalog[payload.EffectId]
  or (payload.Kind~="CreditedKill" and payload.Kind~="UnattributedFall")
  or type(payload.RewardCoins)~="number" or payload.RewardCoins~=payload.RewardCoins or payload.RewardCoins<0
  or type(payload.SentAt)~="number" or payload.SentAt<(self._cutoff or 0)
  or math.abs(workspace:GetServerTimeNow()-payload.SentAt)>Config.EventLifetime then
  trace(payload,"FeedbackRejectedContract","LocalVersion",self._version,"RemoteVersion",type(payload)=="table" and payload.StateVersion,"Cutoff",self._cutoff)
  return
 end
 local key=payload.SessionId..":"..payload.EliminationId
 if self._seen[key] then trace(payload,"FeedbackDuplicate");return end
 self._seen[key]=true
 for i=#self._effects,1,-1 do if self._effects[i].Dead then table.remove(self._effects,i) end end
 while #self._effects>=math.max(1,Config.DeathEffects.MaxConcurrentEffects) do table.remove(self._effects,1):Destroy() end
 if payload.RewardOnly~=true then
  local scope=EffectPlayer.Play(payload)
  table.insert(self._effects,scope)
  trace(payload,if scope.Dead then "EffectNotStarted" else "EffectStarted")
  Notifications.Play(payload)
 end
 local reward=self._context:GetController("KillRewardController")
 if reward then reward:PlayReceipt(payload) end
end
function Controller:Start()
 if self._started then return end;self._started=true
 local player=Players.LocalPlayer
 local match=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Match")
 table.insert(self._connections,match:WaitForChild("StateChanged").OnClientEvent:Connect(function(state,metadata)
  if type(metadata)~="table" or metadata.SessionId~=player:GetAttribute("MatchId")
   or type(metadata.StateVersion)~="number" then return end
  if self._session==metadata.SessionId and metadata.StateVersion<self._version then return end
  if self._session~=metadata.SessionId then self:Cleanup();self._seen={} end
  self._session=metadata.SessionId;self._version=metadata.StateVersion;self._state=state
  if not Contract.IsFeedbackState(state) then self:Cleanup() end
 end))
 table.insert(self._connections,match:WaitForChild("DeathFeedback").OnClientEvent:Connect(function(payload)
  local ok,failure=pcall(self.Receive,self,payload)
  if not ok then warn("[DeathFeedback] "..tostring(failure));self:Cleanup() end
 end))
 table.insert(self._connections,player:GetAttributeChangedSignal("MatchId"):Connect(function()
  self:Cleanup();self._seen={};self._state=nil;self._session=nil;self._version=-1
  local reward=self._context:GetController("KillRewardController")
  if reward then reward:ResetSession() end
 end))
 -- Effect scopes contain only immutable impact snapshots/local clones, not Character references.
 table.insert(self._connections,Players.PlayerRemoving:Connect(function(leaving)if leaving==player then self:Cleanup() end end))
end
function Controller:Destroy()
 self:Cleanup()
 for _,connection in ipairs(self._connections) do connection:Disconnect() end
 self._connections={}
 self._started=false
end
return Controller
