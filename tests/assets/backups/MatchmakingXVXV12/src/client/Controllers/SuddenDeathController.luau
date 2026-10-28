--!nonstrict
-- Local-only additive colour correction; never edits the server or base Lighting.
local Players=game:GetService("Players")
local Lighting=game:GetService("Lighting")
local TweenService=game:GetService("TweenService")
local Config=require(game.ReplicatedStorage.Shared.Config)
local Controller={Name="SuddenDeathController"}
function Controller:Init(context)
 self._context=context;self._roundIndex=0;self._active=false;self._epoch=0
 self._connections={}
end
function Controller:_set(active,restoreArena)
 if self._active==active then return end
 self._active=active;self._epoch+=1
 local epoch=self._epoch
 local settings=Config.SuddenDeathPresentation
 local hud=Players.LocalPlayer.PlayerGui:FindFirstChild("SuddenDeathHUD")
 if hud then local label=hud:FindFirstChild("Notice");if label then label.Visible=active end end
 local music=self._context:GetController("MusicController")
 local match=self._context:GetController("MatchController")
 if music then music:SetSuddenDeath(active,match and match:GetCurrentSelectedMap(),restoreArena) end
 if self._tween then self._tween:Cancel();self._tween:Destroy();self._tween=nil end
 if active then
  if not self._effect then
   local assets=game.ReplicatedStorage:FindFirstChild("UIAssets")
   local folder=assets and assets:FindFirstChild("SuddenDeathAssets")
   local source=folder and folder:FindFirstChild("RedCorrection")
   if not source then warn("[SuddenDeath] Physical RedCorrection missing");return end
   self._effect=source:Clone()
   self._effect.Name="LocalSuddenDeathCorrection"
   self._effect.Enabled=true;self._effect.Brightness=0;self._effect.Contrast=0
   self._effect.Saturation=0;self._effect.TintColor=Color3.new(1,1,1)
   self._effect.Parent=Lighting
  end
  self._tween=TweenService:Create(self._effect,TweenInfo.new(settings.TransitionDuration),
   {Brightness=settings.Brightness,Contrast=settings.Contrast,Saturation=settings.Saturation,TintColor=settings.TintColor})
  self._tween:Play()
 elseif self._effect then
  local effect=self._effect
  local tween=TweenService:Create(effect,TweenInfo.new(settings.TransitionDuration),
   {Brightness=0,Contrast=0,Saturation=0,TintColor=Color3.new(1,1,1)})
  self._tween=tween
  tween.Completed:Connect(function()
   if self._epoch==epoch and not self._active and self._effect==effect then effect:Destroy();self._effect=nil end
  end)
  tween:Play()
 end
end
function Controller:Start(context)
 local player=Players.LocalPlayer
 local match=context:GetController("MatchController")
 local remotes=game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Match")
 table.insert(self._connections,remotes.Countdown.OnClientEvent:Connect(function(_,label,data)
  if label~="PLAYING" or type(data)~="table" or data.SessionId~=match:GetCurrentMatchId()
   or player:GetAttribute("MatchId")~=data.SessionId or not match:IsParticipant()
   or data.StateVersion~=match:GetCurrentStateVersion() then return end
  if self._sessionId~=data.SessionId then self._sessionId=data.SessionId;self._roundIndex=0 end
  if type(data.RoundIndex)~="number" or data.RoundIndex<self._roundIndex then return end
  self._roundIndex=data.RoundIndex
  self:_set(data.SuddenDeath==true and not data.Resolved,true)
 end))
 table.insert(self._connections,remotes.StateChanged.OnClientEvent:Connect(function(state,data)
  if type(data)=="table" and data.SessionId==self._sessionId and state~="Playing"
   and type(data.StateVersion)=="number" and data.StateVersion>=match:GetCurrentStateVersion() then
   self:_set(false,state=="PointRestartCountdown")
  end
 end))
 table.insert(self._connections,player:GetAttributeChangedSignal("MatchId"):Connect(function()
  if player:GetAttribute("MatchId")~=self._sessionId then self:_set(false,false);self._sessionId=nil;self._roundIndex=0 end
 end))
end
return Controller
