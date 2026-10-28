--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Tween=game:GetService('TweenService')
local Config=require(RS.Shared.SocialConfig)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Targeting=require(script.Parent.Parent.Social.Targeting)
local Viewports=require(script.Parent.Parent.Social.ViewportPool)
local player=Players.LocalPlayer
local Controller={Name='SocialController'}
local terminal={Cancelled=true,Completed=true,FailedRecoverable=true}
local reasons={TradeCommitDisabled='PRUEBA FINALIZADA: no se transfirió ningún Slap.',RateLimited='Esperá un momento antes de volver a intentar.',
 OutOfRange='El jugador está fuera del alcance.',PlayerUnavailable='Jugador no disponible o en partida.',PlayerBusy='Uno de los jugadores ya tiene una solicitud o trade.',
 InviteCooldown='Esperá antes de enviar otra invitación.',ItemNotTradable='Este artículo no es comerciable.',StaleRevision='La oferta cambió. Revisala nuevamente.',
 OffersLocked='La oferta está bloqueada durante la confirmación.',InvitationDeclined='Solicitud rechazada.',Expired='La solicitud o el trade expiró.',InvitationsDisabled='El jugador no recibe solicitudes.'}
local function text(reason)return reasons[reason]or tostring(reason or '')end
function Controller:Sound(gui,name)
 local folder=gui and gui:FindFirstChild('Audio');local sound=folder and folder:FindFirstChild(name)
 if self.LastSound and self.LastSound.IsPlaying then self.LastSound:Stop()end
 if sound and sound.SoundId~=''then sound:Play();self.LastSound=sound end
end
function Controller:Message(message)
 for _,gui in ipairs({self.Profile,self.Request,self.Trade})do if gui.Enabled then gui.MainFrame.Status.Text=message end end
end
function Controller:RequestAction(action,id,revision,value,callback)
 if self.PendingAction then return end
 self.PendingAction=true
 task.spawn(function()
  local ok,response=pcall(self.Action.InvokeServer,self.Action,action,id,revision,value)
  self.PendingAction=false
  if not ok or type(response)~='table'then self:Message('No se pudo contactar al servidor.');return end
  if not response.Ok then self:Sound(self.Trade.Enabled and self.Trade or self.Profile,'Error');self:Message(text(response.Reason))end
  if callback then callback(response)end
  if self.PendingInventoryPage then local page=self.PendingInventoryPage;self.PendingInventoryPage=nil;task.delay(.3,function()self:OwnPage(page)end)end
 end)
end
function Controller:ClearCards(container)
 for i=#self.Cards,1,-1 do local record=self.Cards[i]
  if record.Container==container then
   self.Pool:Remove(record.View)
   if record.Connection then record.Connection:Disconnect()end
   record.Card:Destroy();table.remove(self.Cards,i)
  end
 end
end
function Controller:RefreshPreviews()
 local live=0
 for _,entry in ipairs(self.Cards)do
  local s=entry.Container;local visible=entry.Gui.Enabled and s.Visible
  local pos,size=entry.Card.AbsolutePosition,entry.Card.AbsoluteSize;local p,z=s.AbsolutePosition,s.AbsoluteSize
  visible=visible and pos.Y+size.Y>p.Y and pos.Y<p.Y+z.Y and pos.X+size.X>p.X and pos.X<p.X+z.X
  if visible and live<Config.MaxActivePreviews-2 then
   if self.Pool:Slap(entry.View,entry.Item)then live+=1 end
  else self.Pool:Remove(entry.View)end
 end
end
function Controller:CardsFor(gui,container,items,mode)
 self:ClearCards(container)
 local template=gui.CardTemplate
 for index,item in ipairs(items)do
  local card=template:Clone();card.Name='Item_'..index;card.LayoutOrder=index;card.Visible=true
  card:FindFirstChild('ItemName').Text=item.DisplayName;card.Variation.Text=item.VariationName
  local variation=Catalog.Variations.ById[item.VariationId];local color=variation and variation.Color or Color3.new(1,1,1)
  card.Accent.Color=color;card.Variation.TextColor3=color
  card.Aura.BackgroundColor3=color;card.Preview.BackgroundTransparency=1
  card.Aura.Gradient.Color=ColorSequence.new(color,Color3.fromRGB(12,20,32))
  card.State.Text=(item.Equipped and 'EQUIPADO · 'or '')..(item.Tradable and (mode=='Add'and '+ OFRECER'or mode=='Remove'and 'RETIRAR'or 'COMERCIABLE')or 'NO COMERCIABLE')
  card.UnitId.Text=item.UnitId or 'Propiedad base · sin unidad comerciable';card.UnitId.TextSize=10
  card.Parent=container
  local connection=card.Activated:Connect(function()
   if mode and item.UnitId and self.CurrentTrade and (mode=='Remove'or item.Tradable)then
    local t=self.CurrentTrade;self:RequestAction(mode,t.TradeId,t.Revision,item.UnitId)
   end
   self:Sound(gui,'Click')
   Tween:Create(card.Accent,TweenInfo.new(.15),{Thickness=3}):Play()
  end)
  table.insert(self.Cards,{Card=card,View=card.Preview,Item=item,Container=container,Gui=gui,Connection=connection})
 end
 local grid=container:FindFirstChildOfClass('UIGridLayout')
 if grid then
  local columns=container.AbsoluteSize.X>=300 and 3 or container.AbsoluteSize.X>=185 and 2 or 1
  grid.CellSize=UDim2.new(1/columns,-8,0,180)
 end
end
function Controller:Show(gui)
 self.DisplayTokens[gui]=(self.DisplayTokens[gui]or 0)+1
 if self.Fades[gui]then self.Fades[gui]:Cancel();self.Fades[gui]:Destroy()end
 gui.Enabled=true;gui.MainFrame.GroupTransparency=1
 local fade=Tween:Create(gui.MainFrame,TweenInfo.new(.2),{GroupTransparency=0});self.Fades[gui]=fade;fade:Play();self:Sound(gui,'Open')
end
function Controller:Close(gui)
 self.DisplayTokens[gui]=(self.DisplayTokens[gui]or 0)+1;local token=self.DisplayTokens[gui]
 if self.Fades[gui]then self.Fades[gui]:Cancel();self.Fades[gui]:Destroy();self.Fades[gui]=nil end
 if gui.Enabled then
  self:Sound(gui,'Close')
  local fade=Tween:Create(gui.MainFrame,TweenInfo.new(.15),{GroupTransparency=1});self.Fades[gui]=fade;fade:Play()
  task.delay(.16,function()if self.DisplayTokens[gui]==token then gui.Enabled=false end end)
 end
 self.Generation+=1
 for _,entry in ipairs(self.Cards)do if entry.Gui==gui then self.Pool:Remove(entry.View)end end
 if gui==self.Profile then self.Pool:Remove(gui.MainFrame.Avatar);self.ProfileTarget=nil end
 if gui==self.Request then self.Pool:Remove(gui.MainFrame.Avatar)end
 if gui==self.Trade then self.Pool:Remove(gui.MainFrame.Mine.Avatar);self.Pool:Remove(gui.MainFrame.Theirs.Avatar)end
 local containers={};for _,entry in ipairs(self.Cards)do if entry.Gui==gui then containers[entry.Container]=true end end
 for container in pairs(containers)do self:ClearCards(container)end
end
function Controller:OpenProfile(id,page)
 if self.PendingProfile then return end
 self.PendingProfile=true;local generation=self.Generation
 task.spawn(function()
  local ok,response=pcall(self.Inspect.InvokeServer,self.Inspect,id,page)
  self.PendingProfile=false
  if generation~=self.Generation then return end
  if not ok or type(response)~='table'or not response.Ok then self:Message(text(type(response)=='table'and response.Reason or 'Error de red'));return end
  local data=response.Profile
  if player:GetAttribute('MatchId')or not Players:GetPlayerByUserId(data.UserId)then return end
  self.ProfileTarget=data.UserId;self.ProfilePage=data.Page;self.ProfileHasNext=data.HasNext
  self:Show(self.Profile);local m=self.Profile.MainFrame
  m.Identity.Text=data.DisplayName..'\n@'..data.Username
  m.Stats.Text=string.format('VICTORIAS %d\nDERROTAS %d\nKILLS %d',data.Stats.Wins,data.Stats.Losses,data.Stats.TotalKills)
  m.Progression.Text=data.Progression.Status;m.Page.Text=string.format('%d · %d artículos',data.Page,data.TotalItems)
  m.Status.Text='';self.Pool:Remove(m.Avatar);self.Pool:Add(m.Avatar,Players:GetPlayerByUserId(data.UserId),true)
  self:CardsFor(self.Profile,m.Collection,data.Inventory,nil)
 end)
end
function Controller:OwnPage(page)
 local t=self.CurrentTrade;if not t or terminal[t.State]then return end
 if self.PendingAction then self.PendingInventoryPage=page;return end
 self:RequestAction('Inventory',t.TradeId,t.Revision,page,function(response)
  if not response.Ok or not self.CurrentTrade or self.CurrentTrade.TradeId~=t.TradeId or terminal[self.CurrentTrade.State]then return end
  self.OwnPageNumber=response.Profile.Page;self.OwnHasNext=response.Profile.HasNext
  self.Trade.MainFrame.Page.Text='PÁGINA '..response.Profile.Page
  self:CardsFor(self.Trade,self.Trade.MainFrame.Mine.Inventory,response.Profile.Inventory,'Add')
 end)
end
function Controller:TradePacket(t)
 local previous=self.CurrentTrade
 if previous and previous.TradeId==t.TradeId and (t.Sequence or 0)<=(previous.Sequence or 0)then return end
 self.CurrentTrade=t
 if terminal[t.State]then
  self.Request.MainFrame.Requester.Text=text(t.Reason);self:Close(self.Request)
  if self.Trade.Enabled then self.Trade.MainFrame.Status.Text=text(t.Reason);self.Trade.MainFrame.Accept.Active=false;self.Trade.MainFrame.Confirm.Active=false;self:Sound(self.Trade,'Cancel')end
  self:Message(text(t.Reason));return
 end
 local uid=player.UserId;local mine=tostring(uid);local other=tostring(t.A==uid and t.B or t.A)
 if t.State=='Requested'then
  if t.B==uid then
   self:Show(self.Request);self.Request.MainFrame.Requester.Text=t.Names[tostring(t.A)]..' quiere intercambiar Slaps.'
   self.Request.MainFrame.Status.Text='Solo negociación: transferencias reales desactivadas.'
   self.Pool:Add(self.Request.MainFrame.Avatar,Players:GetPlayerByUserId(t.A),true)
  else self:Message('Solicitud enviada. Esperando respuesta.')end
  return
 end
 self:Close(self.Profile);self:Close(self.Request)
 if not self.Trade.Enabled then self:Show(self.Trade)end
 local m=self.Trade.MainFrame
 m.Mine.Identity.Text=t.Names[mine];m.Theirs.Identity.Text=t.Names[other]
 m.Mine.Accepted.Text=t.Accepted[mine]and 'OFERTA ACEPTADA'or 'REVISANDO'
 m.Theirs.Accepted.Text=t.Accepted[other]and 'OFERTA ACEPTADA'or 'REVISANDO'
 for _,entry in ipairs({{Label=m.Mine.Accepted,Accepted=t.Accepted[mine]},{Label=m.Theirs.Accepted,Accepted=t.Accepted[other]}})do
  Tween:Create(entry.Label,TweenInfo.new(.18),{TextColor3=entry.Accepted and Color3.fromRGB(110,235,160)or Color3.fromRGB(180,205,225)}):Play()
 end
 self:CardsFor(self.Trade,m.Mine.Offers,t.Offers[mine]or {},'Remove')
 self:CardsFor(self.Trade,m.Theirs.Offers,t.Offers[other]or {},nil)
 self.Pool:Add(m.Mine.Avatar,player,true);self.Pool:Add(m.Theirs.Avatar,Players:GetPlayerByUserId(tonumber(other)),true)
 m.Accept.Active=t.State=='Negotiating';m.Confirm.Active=t.State=='FinalConfirmation'
 m.Accept.AutoButtonColor=m.Accept.Active;m.Confirm.AutoButtonColor=m.Confirm.Active
 m.Status.Text=t.State=='FinalConfirmation'and 'REVISÁ LO QUE ENTREGÁS Y RECIBÍS. Confirmación individual obligatoria.'or 'NEGOCIACIÓN DE PRUEBA · NO TRANSFIERE OBJETOS'
 if not previous or previous.TradeId~=t.TradeId or previous.State=='Requested'then task.delay(.3,function()self:OwnPage(1)end)end
end
function Controller:SetTarget(target)
 if self.Target==target and (not target or self.Prompt and self.Prompt.Parent==target.Character:FindFirstChild('HumanoidRootPart'))then return end
 if self.PromptConnection then self.PromptConnection:Disconnect();self.PromptConnection=nil end
 if self.Prompt then self.Prompt:Destroy();self.Prompt=nil end
 if self.Highlight then self.Highlight:Destroy();self.Highlight=nil end
 self.Target=target
 if not target then return end
 local root=target.Character:FindFirstChild('HumanoidRootPart')
 local prompt=Instance.new('ProximityPrompt');prompt.Name='SocialProfilePrompt';prompt.ActionText='Ver perfil';prompt.ObjectText=target.DisplayName
 prompt.HoldDuration=Config.PromptHoldSeconds;prompt.MaxActivationDistance=Config.InspectDistance;prompt.RequiresLineOfSight=true
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.ClickablePrompt=true;prompt.Parent=root
 local highlight=Instance.new('Highlight');highlight.Name='SocialTargetHighlight';highlight.Adornee=target.Character
 highlight.FillTransparency=.85;highlight.OutlineColor=Color3.fromRGB(74,210,240);highlight.FillColor=highlight.OutlineColor
 highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Parent=target.Character
 self.Prompt=prompt;self.Highlight=highlight
 self.PromptConnection=prompt.Triggered:Connect(function()self:OpenProfile(target.UserId)end)
end
function Controller:PollTarget()
 if self.Profile.Enabled or self.Request.Enabled or self.Trade.Enabled or player:GetAttribute('MatchId')then self:SetTarget(nil);return end
 local camera=workspace.CurrentCamera;if not camera then self:SetTarget(nil);return end
 local point=UIS:GetMouseLocation();local ray
 if UIS.TouchEnabled or UIS.GamepadEnabled then ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
 else ray=camera:ScreenPointToRay(point.X,point.Y)end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=player.Character and {player.Character}or {}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*200,params)
 local target=hit and Targeting.FromHit(Players,hit.Instance)
 self:SetTarget(Targeting.Valid(player,target,Config.InspectDistance)and target or nil)
end
function Controller:Init()
 self.Generation=0;self.Cards={};self.Connections={};self.DisplayTokens={};self.Fades={};self.Pool=Viewports.new(Config.MaxActivePreviews)
 local gui=player:WaitForChild('PlayerGui')
 self.Profile=gui:WaitForChild('PlayerProfileHUD',15);self.Request=gui:WaitForChild('TradeRequestHUD',15);self.Trade=gui:WaitForChild('TradeHUD',15)
 assert(self.Profile and self.Request and self.Trade,'Social HUDs missing in Edit')
 local remotes=RS:WaitForChild('Remotes'):WaitForChild('Social');self.Inspect=remotes:WaitForChild('Inspect');self.Action=remotes:WaitForChild('Action');self.Update=remotes:WaitForChild('Updated')
 for _,hud in ipairs({self.Profile,self.Request,self.Trade})do
  hud.Enabled=false
  for _,button in ipairs(hud:GetDescendants())do if button:IsA('TextButton')then
   local base=button.BackgroundColor3
   table.insert(self.Connections,button.MouseEnter:Connect(function()self:Sound(hud,'Hover');Tween:Create(button,TweenInfo.new(.12),{BackgroundColor3=base:Lerp(Color3.fromRGB(70,160,195),.25)}):Play()end))
   table.insert(self.Connections,button.MouseLeave:Connect(function()Tween:Create(button,TweenInfo.new(.12),{BackgroundColor3=base}):Play()end))
  end end
 end
 local function connect(button,fn)table.insert(self.Connections,button.Activated:Connect(fn))end
 connect(self.Profile.MainFrame.Close,function()self:Close(self.Profile)end)
 connect(self.Profile.MainFrame.Previous,function()if (self.ProfilePage or 1)>1 then self:OpenProfile(self.ProfileTarget,self.ProfilePage-1)end end)
 connect(self.Profile.MainFrame.Next,function()if self.ProfileHasNext then self:OpenProfile(self.ProfileTarget,self.ProfilePage+1)end end)
 connect(self.Profile.MainFrame.Trade,function()if self.ProfileTarget then self:RequestAction('Invite',self.ProfileTarget)end end)
 local function act(name,value)local t=self.CurrentTrade;if t then self:RequestAction(name,t.TradeId,t.Revision,value)end end
 connect(self.Request.MainFrame.Accept,function()self:Sound(self.Request,'Accept');act('Respond',true)end)
 connect(self.Request.MainFrame.Decline,function()act('Respond',false)end)
 connect(self.Request.MainFrame.Close,function()act('Respond',false)end)
 connect(self.Trade.MainFrame.Close,function()if self.CurrentTrade and terminal[self.CurrentTrade.State]then self:Close(self.Trade)else act('Cancel')end end)
 connect(self.Trade.MainFrame.Cancel,function()if self.CurrentTrade and terminal[self.CurrentTrade.State]then self:Close(self.Trade)else act('Cancel')end end)
 connect(self.Trade.MainFrame.Accept,function()self:Sound(self.Trade,'Accept');act('Accept')end)
 connect(self.Trade.MainFrame.Confirm,function()self:Sound(self.Trade,'Confirm');act('Confirm')end)
 connect(self.Trade.MainFrame.Previous,function()if (self.OwnPageNumber or 1)>1 then self:OwnPage(self.OwnPageNumber-1)end end)
 connect(self.Trade.MainFrame.Next,function()if self.OwnHasNext then self:OwnPage(self.OwnPageNumber+1)end end)
end
function Controller:Start()
 if not self.Update or not self.Profile or not self.Request or not self.Trade then warn('[Social] Init incomplete; controller disabled');return end
 table.insert(self.Connections,self.Update.OnClientEvent:Connect(function(kind,payload)
  if kind=='Trade'then self:TradePacket(payload)
  elseif kind=='ProfileUnavailable'and self.ProfileTarget==payload.UserId then self:Close(self.Profile)end
 end))
 local function closeAll()self:SetTarget(nil);for _,hud in ipairs({self.Profile,self.Request,self.Trade})do self:Close(hud)end;self.Pool:Clear()end
 table.insert(self.Connections,player:GetAttributeChangedSignal('MatchId'):Connect(function()if player:GetAttribute('MatchId')then closeAll()end end))
 table.insert(self.Connections,player.CharacterRemoving:Connect(closeAll))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)if self.ProfileTarget==p.UserId then self:Close(self.Profile)end;if self.Target==p then self:SetTarget(nil)end end))
 local elapsed=0
 table.insert(self.Connections,RunService.RenderStepped:Connect(function(dt)
  self.Pool:Step(dt);elapsed+=dt
  if elapsed<Config.AimPollSeconds then return end;elapsed=0
  self:PollTarget();self:RefreshPreviews()
  local t=self.CurrentTrade
  if t and not terminal[t.State]then
   local now=workspace:GetServerTimeNow()
   if t.State=='Requested'then self.Request.MainFrame.Countdown.Text='Expira en '..math.max(0,math.ceil(t.ExpiresAt-now))..' s'
   elseif t.State=='SafetyCountdown'then self.Trade.MainFrame.Status.Text='SEGURIDAD: '..math.max(0,math.ceil(t.Deadline-now))..' s · NO TRANSFIERE OBJETOS'end
  end
 end))
end
function Controller:Destroy()
 self.Generation+=1;self:SetTarget(nil);self.Pool:Clear()
 for _,c in ipairs(self.Connections or {})do c:Disconnect()end;self.Connections={}
 for _,hud in ipairs({self.Profile,self.Request,self.Trade})do self:Close(hud)end
end
return Controller
