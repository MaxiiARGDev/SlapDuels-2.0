--!nonstrict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Http=game:GetService("HttpService")
local Chat=game:GetService("TextChatService")
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local Controller={}
local ERRORS={CommercialApprovalPending="Precio y probabilidades pendientes de aprobación.",ProductionBackendBlocked="Ventas bloqueadas: backend productivo pendiente.",
 PaidRandomItemsRestricted="Esta apertura no está habilitada por las políticas de Roblox o no se pudo verificar elegibilidad.",
 OddsChanged="Cambió el stock o la probabilidad. Volvé a consultar antes de continuar.",ViewOddsFirst="Consultá las probabilidades actuales primero.",
 LobbyOnly="Solo podés abrir cajas en el lobby.",InsufficientFunds="Coins insuficientes.",NoCrate="No tenés cajas cerradas.",
 NoEligibleResults="No quedan premios elegibles para vos.",RateLimited="Esperá un momento y reintentá.",DataNotLoaded="Esperá a que cargue tu perfil."}
function Controller:Init(context)
 self._context=context;self._connections={};self._seen={};self._worldSeen={};self._chatSeen={};self._worldModels={};self._pending={};self._busy=false
end
function Controller:_call(action,args)
 local ok,result=pcall(self._request.InvokeServer,self._request,action,args or {})
 return if ok and type(result)=="table" then result else {Ok=false,Code="NoResponse"}
end
function Controller:_status(result)
 self._panel.Status.Text=if result.Ok then "Operación confirmada." else (ERRORS[result.Code] or tostring(result.Code))
end
function Controller:ShowCrate(id)
 if self._busy or not self._panel or not self._request then return end
 self._crateId=id;self._quote=nil;self._panel.Visible=true
 self._panel.Title.Text=(Catalog.Crates.ById[id] or {}).DisplayName or id
 self._panel.Buy.Active=false;self._panel.Open.Active=false
 self._panel.Outcomes.Text="Consultando resultados y elegibilidad…"
 task.spawn(function()
  local inventory=self:_call("Inventory",{})
  if inventory.Ok then self._inventory=inventory.Inventory end
  if self._crateId~=id then return end
  self._panel.Count.Text="Cajas cerradas: "..tostring(self._inventory and self._inventory.Crates[id] or 0)
  task.wait(.3)
  self:_quoteCurrent(id)
 end)
end
function Controller:_quoteCurrent(id)
 local result=self:_call("Quote",{CrateId=id})
 if id~=self._crateId then return end
 self:_status(result);self._quote=if result.Ok then result else nil
 if result.Ok then
  local lines={"Probabilidades finales por recompensa — "..result.Scope,"Precio: "..result.PriceCoins.." Coins"}
  for _,row in ipairs(result.Outcomes)do
   table.insert(lines,row.DisplayName.." — "..string.format("%.10g",row.Percent).." % | "..(row.Stock.UnlimitedStock and "Ilimitado" or tostring(row.Stock.RemainingStock).." disponibles"))
  end
  self._panel.Outcomes.Text=table.concat(lines,"\n")
 else self._panel.Outcomes.Text=ERRORS[result.Code] or tostring(result.Code)end
 self._panel.Buy.Active=result.Ok;self._panel.Open.Active=result.Ok
end
function Controller:_mutate(action)
 if self._busy or not self._quote or not self._crateId then return end
 self._busy=true;local id=self._crateId
 -- Keep the same OperationId after transport failure; no second charge on retry.
 local key=id..":"..action
 self._pending[key]=self._pending[key] or Http:GenerateGUID(false)
 task.spawn(function()
  local result=self:_call(action,{CrateId=id,QuoteToken=self._quote.Token,OperationId=self._pending[key]})
  self._busy=false;self:_status(result)
  if result.Ok then
   self._pending[key]=nil
   self._panel.Count.Text="Cajas cerradas: "..tostring(result.Crates[id] or 0)
   if action=="Open"then
    self:_spin({OpeningId=result.Operation.UnitId,Operation=result.Operation,Duration=Catalog.Crates.ById[id].RollDuration})
   end
  elseif result.Code~="NoResponse" and result.Code~="InternalError"then
   self._pending[key]=nil;self._quote=nil;self._panel.Buy.Active=false;self._panel.Open.Active=false
  end
 end)
end
function Controller:_spin(packet)
 if type(packet)~="table" or not packet.OpeningId or self._seen[packet.OpeningId]then return end
 local reward=packet.Operation and Catalog.Rewards[packet.Operation.RewardId]
 if not reward then return end
 self._seen[packet.OpeningId]=true
 if self._tween then self._tween:Cancel()end
 if self._tickConnection then self._tickConnection:Disconnect()end
 local spin=self._spinPanel;spin.Visible=true;spin.Close.Visible=false
 spin.Result.Text="Abriendo…";local strip=spin.Window.RollingStrip
 for _,c in ipairs(strip:GetChildren())do if c:IsA("GuiObject") and c.Name~="RewardTemplate" then c:Destroy()end end
 local ids={}for id in pairs(Catalog.Rewards)do table.insert(ids,id)end;table.sort(ids)
 local winnerIndex=41;local stride=140
 for i=1,45 do
  local r=if i==winnerIndex then reward else Catalog.Rewards[ids[((i*7)%#ids)+1]]
  local card=strip.RewardTemplate:Clone();card.Name="Reward_"..i;card.Visible=true
  card.Position=UDim2.fromOffset((i-1)*stride,0);card.Title.Text=r.DisplayName
  card.BackgroundColor3=Catalog.Variations.ById[r.VariationId].Color;card.Parent=strip
 end
 strip.Position=UDim2.fromOffset(0,0)
 local target=spin.Window.AbsoluteSize.X/2-((winnerIndex-1)*stride+66)
 local lastIndex=0
 self._tickConnection=strip:GetPropertyChangedSignal("Position"):Connect(function()
  local index=math.floor(-strip.Position.X.Offset/stride)
  if index~=lastIndex then lastIndex=index;if spin.Tick.SoundId~="" then spin.Tick:Play()end end
 end)
 local duration=math.clamp(tonumber(packet.Duration) or 5,1,30)
 self._tween=TweenService:Create(strip,TweenInfo.new(duration,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=UDim2.fromOffset(target,0)})
 local openingId=packet.OpeningId;self._currentSpin=openingId
 self._tween.Completed:Once(function(state)
  if self._currentSpin~=openingId or state~=Enum.PlaybackState.Completed then return end
  if self._tickConnection then self._tickConnection:Disconnect();self._tickConnection=nil end
  spin.Result.Text="Obtuviste "..reward.DisplayName;spin.Close.Visible=true
  if spin.Reveal.SoundId~=""then spin.Reveal:Play()end
 end)
 self._tween:Play()
end
function Controller:_world(packet)
 if not packet.OpeningId or self._worldSeen[packet.OpeningId] or typeof(packet.Position)~="Vector3"then return end
 if Players.LocalPlayer:GetAttribute("MatchId") or Players.LocalPlayer:GetAttribute("ResultsSessionId")then return end
 local root=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
 if not root or (root.Position-packet.Position).Magnitude>80 then return end
 local age=workspace:GetServerTimeNow()-(packet.StartedAt or 0)
 local duration=math.clamp(packet.Duration or 5,1,30);if age>duration+2 then return end
 local model=RS.CrateEffects:FindFirstChild(packet.Model)
 if not model then return end
 self._worldSeen[packet.OpeningId]=true
 local clone=model:Clone();clone.Name="CrateOpening_"..packet.OpeningId
 local vfxTemplate=RS.CrateEffects:FindFirstChild(packet.VFX or packet.Model)
 if vfxTemplate and vfxTemplate~=model then
  local emitter=vfxTemplate:FindFirstChildWhichIsA("ParticleEmitter",true)
  local body=clone:FindFirstChild("Body")
  if emitter and body then emitter:Clone().Parent=body end
 end
 clone:PivotTo(CFrame.new(packet.Position));clone.Parent=workspace;self._worldModels[clone]=true
 local reward=Catalog.Rewards[packet.Operation.RewardId]
 local previews=RS:FindFirstChild("SlapVariationPreviews")
 local slapPreviews=previews and previews:FindFirstChild(reward.SlapId)
 local rewardModel=(slapPreviews and slapPreviews:FindFirstChild(reward.VariationId)) or RS.CrateRewardPreviews:FindFirstChild(reward.SlapId)
 local visual=rewardModel and rewardModel:Clone()
 local stopped=false;local pulse=clone:FindFirstChild("Body")
 if pulse then TweenService:Create(pulse,TweenInfo.new(math.max(.1,duration-age),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Orientation=Vector3.new(0,540,0)}):Play()end
 task.delay(math.max(0,duration-age-.7),function()
  if not clone.Parent then return end
  local lid=clone:FindFirstChild("Lid")
  if lid then TweenService:Create(lid,TweenInfo.new(.5),{Position=packet.Position+Vector3.new(0,3,0),Transparency=1}):Play()end
  if visual then
   visual:PivotTo(CFrame.new(packet.Position+Vector3.new(0,1,0)));visual.Parent=clone
   local v=Catalog.Variations.ById[reward.VariationId]
   local effect=RS.SlapVariationEffects:FindFirstChild(v.VisualProfile)
   local part=visual:FindFirstChildWhichIsA("BasePart",true)
   if part and effect then
    Appearance.Apply(part,effect)
    for _,child in ipairs(effect:GetChildren())do
     if child:IsA("Sound") and child.Name==v.SFX and child.SoundId~=""then local sound=child:Clone();sound.Name="VariationReveal";sound.Parent=part;sound:Play()end
    end
   end
  end
  for _,item in ipairs(clone:GetDescendants())do
   if item:IsA("ParticleEmitter")then
    local burst=item:GetAttribute("RevealBurstCount")
    if type(burst)=="number"then item:Emit(math.clamp(math.floor(burst),0,12))
    elseif item:GetAttribute("SlapVariationEmitter")~=true then item:Emit(18)end
   elseif item:IsA("Sound") and item.Name==packet.SFX and item.SoundId~=""then item:Play()end
  end
 end)
 task.delay(math.max(0,duration-age)+2,function()if not stopped then stopped=true;clone:Destroy();self._worldModels[clone]=nil end end)
end
function Controller:Start()
 task.spawn(function()
  local hud=Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ShopHUD",15)
  local remotes=RS:WaitForChild("Remotes"):WaitForChild("Crates",15)
  if not hud or not remotes then return end
  self._request=remotes:WaitForChild("Request",10);self._panel=hud:WaitForChild("CratePanel",10);self._spinPanel=hud:WaitForChild("CrateSpinPanel",10)
  if not self._panel or not self._spinPanel or not self._request then warn("[Crates] Missing editable UI");return end
  self._panel.Visible=false;self._spinPanel.Visible=false
  local function on(signal,fn)table.insert(self._connections,signal:Connect(fn))end
  on(self._panel.Close.Activated,function()self._panel.Visible=false end)
  on(self._panel.Buy.Activated,function()self:_mutate("Purchase")end)
  on(self._panel.Open.Activated,function()self:_mutate("Open")end)
  on(self._panel.ViewOdds.Activated,function()if not self._busy then self:_quoteCurrent(self._crateId)end end)
  on(self._panel.Receipt.Activated,function()
   task.spawn(function()
    local result=self:_call("Inventory",{});if not result.Ok then self:_status(result);return end
    local last
    for _,op in pairs(result.Inventory.CrateOperations)do
     if op.Kind=="Open" and (not last or (op.CreatedAt or 0)>(last.CreatedAt or 0))then last=op end
    end
    if last then self._panel.Status.Text="Premio conservado: "..(Catalog.Rewards[last.RewardId] and Catalog.Rewards[last.RewardId].DisplayName or last.RewardId)
    else self._panel.Status.Text="Todavía no abriste cajas."end
   end)
  end)
  on(self._spinPanel.Close.Activated,function()self._spinPanel.Visible=false end)
  on(remotes.Reveal.OnClientEvent,function(p)self:_spin(p)end)
  on(remotes.World.OnClientEvent,function(p)self:_world(p)end)
  on(remotes.Announce.OnClientEvent,function(p)
   if self._chatSeen[p.OpeningId]then return end
   local reward=Catalog.Rewards[p.RewardId];local crate=Catalog.Crates.ById[p.CrateId]
   if not reward or not crate then return end
   self._chatSeen[p.OpeningId]=true
   local channels=Chat:FindFirstChild("TextChannels");local channel=channels and channels:FindFirstChild("RBXGeneral")
   local name=if type(p.PlayerName)=="string" and p.PlayerName:match("^[%w_]+$")then p.PlayerName else "Jugador "..tostring(p.UserId)
   if channel then channel:DisplaySystemMessage("¡"..name.." obtuvo "..reward.DisplayName.." al abrir "..crate.DisplayName.."!")end
  end)
  on(Players.LocalPlayer:GetAttributeChangedSignal("MatchId"),function()
   if Players.LocalPlayer:GetAttribute("MatchId")then
    self._panel.Visible=false;self._spinPanel.Visible=false
    if self._tween then self._tween:Cancel()end
    for model in pairs(self._worldModels)do model:Destroy()end;table.clear(self._worldModels)
   end
  end)
 end)
end
function Controller:Destroy()
 for _,c in ipairs(self._connections)do c:Disconnect()end
 if self._tickConnection then self._tickConnection:Disconnect()end
 if self._tween then self._tween:Cancel()end
 for model in pairs(self._worldModels)do model:Destroy()end
end
return Controller
