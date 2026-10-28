--!nonstrict
-- Displays receipts only. Never modifies Coins or the authoritative PlayerHUD counter.
local Config=require(game.ReplicatedStorage.Shared.DeathFeedbackConfig).CoinRewardAnimation
local Scope=require(script.Parent.Parent.DeathFeedback.Scope)
local RunService=game:GetService("RunService")
local Controller={Name="KillRewardController"}
function Controller:Init() self._active={};self._seen={} end
function Controller:Cleanup()
 for _,scope in ipairs(self._active or {}) do scope:Destroy() end
 self._active={}
end
function Controller:ResetSession() self:Cleanup();self._seen={} end
function Controller:PlayReceipt(payload)
 local player=game.Players.LocalPlayer
 if not Config.Enabled or payload.KillerUserId~=player.UserId or payload.RewardCoins<=0
  or payload.Kind~="CreditedKill" or player:GetAttribute("MatchId")~=payload.SessionId then return end
 local key=payload.SessionId..":"..payload.EliminationId
 if self._seen[key] then return end
 self._seen[key]=true
 local hud=player.PlayerGui:FindFirstChild("KillRewardHUD")
 if not hud then warn("[KillReward] Physical HUD missing");return end
 local target=hud:FindFirstChild("CoinTarget")
 local template=hud:FindFirstChild("CoinTemplate")
 local effects=hud:FindFirstChild("EffectsContainer")
 if not target or not template or not effects then warn("[KillReward] Incomplete physical HUD");return end
 for i=#self._active,1,-1 do if self._active[i].Dead then table.remove(self._active,i) end end
 while #self._active>=4 do table.remove(self._active,1):Destroy() end
 local scope=Scope.new();table.insert(self._active,scope)
 local rewardTemplate=hud:FindFirstChild("RewardAmountTemplate")
 if rewardTemplate then
  local label=scope:Add(rewardTemplate:Clone())
  label.Name="Reward_"..payload.EliminationId;label.RichText=false
  label.Text="+"..tostring(payload.RewardCoins).." Coins";label.Visible=true;label.Parent=effects
 end
 local sound=hud:FindFirstChild("RewardSound")
 if sound then
  sound=scope:Add(sound:Clone())
  if Config.SoundId~="" then sound.SoundId=Config.SoundId end
  sound.Volume=Config.SoundVolume;sound.Parent=hud
  if sound.SoundId~="" then sound:Play() end
 end
 local flights={}
 local count=math.clamp(math.floor(Config.CoinCount),1,16)
 for i=1,count do
  scope:Delay((i-1)*Config.Stagger,function()
   local coin=scope:Add(template:Clone())
   coin.Visible=true;coin.Name="Coin_"..i;coin.Parent=effects
   local start=template.AbsolutePosition+template.AbsoluteSize*.5-effects.AbsolutePosition
   local coinScale=coin:FindFirstChildOfClass("UIScale")
   if coinScale then coinScale.Scale*=.8+(i%3)*.15 end
   coin.AnchorPoint=Vector2.new(.5,.5)
   table.insert(flights,{Coin=coin,Start=start,At=os.clock(),Side=(i%2==0 and 1 or -1)*(15+i*5)})
  end)
 end
 local connection
 connection=RunService.RenderStepped:Connect(function()
  if scope.Dead then return end
  -- Read actual screen geometry each frame; never overwrite CoinTarget.Position.
  local finish=target.AbsolutePosition+target.AbsoluteSize*.5-effects.AbsolutePosition
  for i=#flights,1,-1 do
   local flight=flights[i]
   local progress=math.clamp((os.clock()-flight.At)/math.max(.001,Config.FlightDuration),0,1)
   local t=progress*progress*(3-2*progress)
   local control=(flight.Start+finish)*.5+Vector2.new(flight.Side,-Config.ArcHeight)
   local point=(1-t)^2*flight.Start+2*(1-t)*t*control+t^2*finish
   flight.Coin.Position=UDim2.fromOffset(point.X,point.Y)
   flight.Coin.Rotation=t*240
   if t>=1 then flight.Coin:Destroy();table.remove(flights,i) end
  end
 end)
 -- Scope also owns the single per-animation render connection.
 scope:Add({Destroy=function()connection:Disconnect()end})
 local arrivalTemplate=target:FindFirstChild("ArrivalTemplate")
 local endTime=(count-1)*Config.Stagger+Config.FlightDuration
 scope:Delay(endTime,function()
  if arrivalTemplate then
   local pulse=scope:Add(arrivalTemplate:Clone());pulse.Visible=true;pulse.Parent=target
   local scale=pulse:FindFirstChildOfClass("UIScale")
   if scale then scope:Tween(scale,.2,{Scale=scale.Scale*Config.ArrivalPulse}) end
   scope:Tween(pulse,.25,{BackgroundTransparency=1})
  end
 end)
 scope:Delay(endTime+.5,function()scope:Destroy()end)
end
return Controller
