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
local categoryNames={Slaps='SLAPS',PointEffects='EFECTOS DE PUNTO',DeathEffects='EFECTOS DE MUERTE'}
local rarityColors={Basic=Color3.fromRGB(220,225,235),Common=Color3.fromRGB(190,205,220),Rare=Color3.fromRGB(69,138,255),Epic=Color3.fromRGB(145,58,225),Legendary=Color3.fromRGB(255,156,37)}
function Controller:EquipItem(item)
 if self.PendingEquip or self.PendingProfile or self.ProfileMode~='SelfProfile'or self.ProfileTarget~=player.UserId or not self.Profile.Enabled or item.Equipped then return end
 if item.Available==false then self:Message('Este recurso no está disponible.');return end
 local category=item.Category or 'Slaps';if not categoryNames[category]then return end
 self.PendingEquip=true;local generation=self.Generation;local page=self.ProfilePage
 self:Message('Guardando selección…')
 task.spawn(function()
  local ok,response=pcall(self.Equip.InvokeServer,self.Equip,category,item.ProductId or item.RewardId,page)
  self.PendingEquip=false
  if generation~=self.Generation or self.ProfileMode~='SelfProfile'or self.ProfileTarget~=player.UserId then return end
  if not ok or type(response)~='table'then self:Message('No se pudo confirmar. Actualizá el inventario para revisar tu selección.');return end
  if not response.Ok then self:Message(text(response.Reason));return end
  if response.Profile and response.Profile.UserId==player.UserId then self:ApplyProfile(response.Profile,true);self:Message('Selección equipada para tus partidas.')end
 end)
end
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
   if (entry.Item.Category==nil or entry.Item.Category=='Slaps')and self.Pool:Slap(entry.View,entry.Item)then live+=1 end
  else self.Pool:Remove(entry.View)end
 end
end
function Controller:CardsFor(gui,container,items,mode)
 self:ClearCards(container)
 local template=gui.CardTemplate
 for index,item in ipairs(items)do
  local card=template:Clone();card.Name='Item_'..index;card.LayoutOrder=index;card.Visible=true
  card:FindFirstChild('ItemName').Text=item.DisplayName;card.Variation.Text=item.VariationName
  local variation=Catalog.Variations.ById[item.VariationId];local color=variation and variation.Color or rarityColors[item.Rarity]or Color3.fromRGB(90,205,220)
  card.Accent.Color=color;card.Variation.TextColor3=color
  card.Aura.BackgroundColor3=color;card.Preview.BackgroundTransparency=1
  card.Aura.Gradient.Color=ColorSequence.new(color,Color3.fromRGB(12,20,32))
  local ownProfile=gui==self.Profile and self.ProfileMode=='SelfProfile'and self.ProfileTarget==player.UserId
  card.State.Text=ownProfile and(item.Equipped and 'EQUIPADO'or item.Available==false and 'NO DISPONIBLE'or 'EQUIPAR')or ((item.Equipped and 'EQUIPADO · 'or '')..(item.Tradable and(mode=='Add'and '+ OFRECER'or mode=='Remove'and 'RETIRAR'or 'COMERCIABLE')or 'NO COMERCIABLE'))
  card.UnitId.Text=item.Category and item.Category~='Slaps'and 'PERSONAL · NO INTERCAMBIABLE'or(item.Tradable and 'SLAP INTERCAMBIABLE'or 'SLAP NO INTERCAMBIABLE');card.UnitId.TextSize=10
  local effect=card:FindFirstChild('EffectBadge')
  if effect then effect.Visible=item.Category~=nil and item.Category~='Slaps';effect.Text=item.Category=='PointEffects'and 'PUNTO'or 'MUERTE';effect.TextColor3=color;card.Preview.Visible=not effect.Visible end
  card.Parent=container
  local connection=card.Activated:Connect(function()
   if ownProfile then self:EquipItem(item)
   elseif mode and item.UnitId and self.CurrentTrade and (mode=='Remove'or item.Tradable)then
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
 local navigation=self.Context and self.Context:GetController('WindowNavigationController');if navigation then navigation:Forget(gui.Name)end
 self.DisplayTokens[gui]=(self.DisplayTokens[gui]or 0)+1;local token=self.DisplayTokens[gui]
 if self.Fades[gui]then self.Fades[gui]:Cancel();self.Fades[gui]:Destroy();self.Fades[gui]=nil end
 if gui.Enabled then
  self:Sound(gui,'Close')
  local fade=Tween:Create(gui.MainFrame,TweenInfo.new(.15),{GroupTransparency=1});self.Fades[gui]=fade;fade:Play()
  task.delay(.16,function()if self.DisplayTokens[gui]==token then gui.Enabled=false end end)
 end
 self.Generation+=1
 for _,entry in ipairs(self.Cards)do if entry.Gui==gui then self.Pool:Remove(entry.View)end end
 if gui==self.Profile then local summary=gui.MainFrame:FindFirstChild('Summary');if summary then self.Pool:Remove(summary.Equipped.Preview)end;self.ProfileData=nil;self.Pool:Remove(gui.MainFrame.Avatar);self.ProfileTarget=nil;self.ProfileMode=nil;self.NextSelfRefresh=nil end
 if gui==self.Request then self.Pool:Remove(gui.MainFrame.Avatar)end
 if gui==self.Trade then self.Pool:Remove(gui.MainFrame.Mine.Avatar);self.Pool:Remove(gui.MainFrame.Theirs.Avatar)end
 local containers={};for _,entry in ipairs(self.Cards)do if entry.Gui==gui then containers[entry.Container]=true end end
 for container in pairs(containers)do self:ClearCards(container)end
end
-- These existing windows own their own lifecycle; this controller never changes them.
function Controller:WindowBusy()
 local gui=player:FindFirstChild('PlayerGui')
 if not gui then return true end
 for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
  local hud=gui:FindFirstChild(name)
  local main=hud and hud:FindFirstChild('MainFrame')
  local navigation=self.Context and self.Context:GetController('WindowNavigationController')
  if hud and hud.Enabled and (name=='CrateOpeningHUD'or not navigation and main and main.Visible)then return true end
 end
 return self.Request.Enabled or self.Trade.Enabled
end
function Controller:SetArticlesMode(show)
 if show and self.ProfileMode=='SelfProfile' and self.ProfileTarget==player.UserId then
  local inventory=self.Context and self.Context:GetController('InventoryController')
  if inventory then inventory:Open();return end
 end
 local m=self.Profile.MainFrame;local summary=m:FindFirstChild('Summary')
 if not summary then return end
 self.ArticlesVisible=show;summary.Visible=not show;m.Collection.Visible=show
 for _,name in ipairs({'InventoryTabs','CollectionTitle','CollectionHint'})do local o=m:FindFirstChild(name);if o then o.Visible=show end end
 local loadout=m:FindFirstChild('SelectedEffects');if loadout then loadout.Visible=not show end
 for _,name in ipairs({'Previous','Page','Next'})do m[name].Visible=show end
 m.Articles.Text=show and 'Volver al perfil'or 'Ver inventario'
 local cards=m:FindFirstChild('ProgressCards');if cards then cards.Visible=not show end
 local label=m.Articles:FindFirstChild('ActionLabel');if label then label.Text=m.Articles.Text end
 if not show then for _,entry in ipairs(self.Cards)do if entry.Gui==self.Profile then self.Pool:Remove(entry.View)end end end
end
function Controller:ProfileActions(data)
 local m=self.Profile.MainFrame;local own=data.UserId==player.UserId
 local target=Players:GetPlayerByUserId(data.UserId)
 local solo=not player:GetAttribute('SocialGroupId')and target and not target:GetAttribute('SocialGroupId')
 for _,entry in ipairs({{'Challenge',not own and solo and data.Actions and data.Actions.Challenge},{'Invite',not own and data.Actions and data.Actions.Invite}})do
  local button=m:FindFirstChild(entry[1]);if button then local enabled=entry[2]==true;button.Visible=enabled;button.Active=enabled;button.Selectable=enabled end
 end
 local articles=m:FindFirstChild('Articles')
 local badge=m:FindFirstChild('ProfileBadge');if badge and m.AbsoluteSize then badge.Visible=m.AbsoluteSize.X>=560 end
 if articles then articles.Position=UDim2.new(.02,0,.87,0);articles.Size=UDim2.new(own and .96 or .225,0,.095,0)end
end
function Controller:ApplyProfile(data,refresh)
 if type(data)~='table'or player:GetAttribute('MatchId')or self:WindowBusy()then return false end
 local owner=Players:GetPlayerByUserId(data.UserId)
 local own=data.UserId==player.UserId
 if not owner or data.ProfileMode~=(own and 'SelfProfile'or 'OtherPlayerProfile')then return false end
 self.ProfileTarget=data.UserId;self.ProfileMode=data.ProfileMode
 self.ProfilePage=data.Page;self.ProfileHasNext=data.HasNext
 self.NextSelfRefresh=workspace:GetServerTimeNow()+Config.SelfProfileRefreshSeconds
 if not refresh then self:Show(self.Profile)end
 local m=self.Profile.MainFrame
 m.Trade.Visible=not own;m.Trade.Active=not own;m.Trade.Selectable=not own
 m.Trade.AutoButtonColor=not own
 self.ProfileData=data;self:ProfileActions(data)
 if not refresh then self:SetArticlesMode(false)end
 local summary=m:FindFirstChild('Summary')
 if summary then
  summary.Streak.Value.Text=tostring(data.Stats.Streaks or 0);summary.Wins.Value.Text=tostring(data.Stats.Wins);summary.Kills.Value.Text=tostring(data.Stats.TotalKills)
 end
 local username=m:FindFirstChild('Username')
 if username then m.Identity.Text=data.DisplayName;username.Text='@'..data.Username
 else m.Identity.Text=data.DisplayName..'\n@'..data.Username end
 local badge=m:FindFirstChild('ProfileBadge');if badge then badge.Label.Text=own and 'TU PERFIL'or 'JUGADOR'end
 local collectionTitle=m:FindFirstChild('CollectionTitle');if collectionTitle then collectionTitle.Text='COLECCIÓN  /  '..tostring(data.TotalItems)..' ARTÍCULOS'end
 local hint=m:FindFirstChild('CollectionHint');if hint then hint.Text=own and 'Tocá un artículo para equiparlo. Solo los Slaps admiten intercambio.'or 'Colección de consulta. Solo los Slaps admiten intercambio.'end
 if summary then local tile=summary:FindFirstChild('Equipped');local heading=tile and tile:FindFirstChild('Eyebrow');if heading then heading.Text=own and 'TU SLAP EQUIPADO'or 'SLAP EQUIPADO'end end
 m.Stats.Text=string.format('VICTORIAS %d\nDERROTAS %d\nKILLS %d',data.Stats.Wins,data.Stats.Losses,data.Stats.TotalKills)
 m.Progression.Text='NIVEL '..tostring(owner:GetAttribute('Level')or 0)..' · Derrotas '..tostring(data.Stats.Losses);m.Page.Text=string.format('%d · %d artículos',data.Page,data.TotalItems)
 local progression=self.Context and self.Context:GetController('BattlePassController');if progression then progression:RenderProfile()end
 m.Status.Text=''
 -- Keep the same avatar and card pool on unchanged refreshes (no rotation reset).
 if not refresh then self.Pool:Remove(m.Avatar);self.Pool:Add(m.Avatar,owner,true)end
 local category=data.Category or 'Slaps';self.ProfileCategory=category
 local tabs=m:FindFirstChild('InventoryTabs');if tabs then for key in pairs(categoryNames)do tabs[key].BackgroundColor3=key==category and Color3.fromRGB(29,105,145)or Color3.fromRGB(20,30,45)end end
 local selected=m:FindFirstChild('SelectedEffects')
 if selected then for _,key in ipairs({'PointEffects','DeathEffects'})do local item=data.EquippedLoadout and data.EquippedLoadout[key];selected[key].Text=(key=='PointEffects'and 'PUNTO: 'or 'MUERTE: ')..(item and item.DisplayName or 'Sin selección disponible')end end
 local fingerprint=game:GetService('HttpService'):JSONEncode({Inventory=data.Inventory,Loadout=data.EquippedLoadout,Category=category})..':'..tostring(data.EquippedSlap and data.EquippedSlap.RewardId)
 if not refresh or self.ProfileInventoryFingerprint~=fingerprint then
  self.ProfileInventoryFingerprint=fingerprint
  self:CardsFor(self.Profile,m.Collection,data.Inventory,nil)
  if summary then
   local equipped=data.EquippedSlap
   self.Pool:Remove(summary.Equipped.Preview)
   if equipped then self.Pool:Slap(summary.Equipped.Preview,equipped);summary.Equipped.Caption.Text=string.find(string.lower(equipped.DisplayName),string.lower(equipped.VariationName),1,true)and equipped.DisplayName or equipped.DisplayName..' · '..equipped.VariationName
   else summary.Equipped.Caption.Text='Consultá Ver artículos para ver el Slap equipado'end
  end
 end
 return true
end
function Controller:OpenProfile(id,page,refresh,category)
 if self.PendingProfile or self.PendingEquip or player:GetAttribute('MatchId')or self:WindowBusy()then return end
 category=category or(refresh and self.ProfileCategory)or 'Slaps'
 local own=id==player.UserId
 self.PendingProfile=true;local generation=self.Generation
 task.spawn(function()
  local remote=own and self.SelfInspect or self.Inspect
  local ok,response
  if own then ok,response=pcall(remote.InvokeServer,remote,page,category)
  else ok,response=pcall(remote.InvokeServer,remote,id,page,category)end
  self.PendingProfile=false
  if generation~=self.Generation then return end
  if not ok or type(response)~='table'or not response.Ok then
   if refresh then
    self.NextSelfRefresh=workspace:GetServerTimeNow()+Config.RequestIntervalSeconds
    if type(response)=='table'and response.Reason~='RateLimited'then self:Close(self.Profile)end
   else self:Message(text(type(response)=='table'and response.Reason or 'Error de red'))end
   return
  end
  if response.Profile.UserId~=id then return end
  self:ApplyProfile(response.Profile,refresh)
 end)
end
function Controller:OpenSelfProfile()
 if self.Profile.Enabled and self.ProfileMode=='SelfProfile'then self:Close(self.Profile);return end
 self:OpenProfile(player.UserId,1)
end
function Controller:BindProfileButton(button)
 local base=button.BackgroundColor3
 table.insert(self.Connections,button.Activated:Connect(function()self:Sound(self.Profile,'Click');self:OpenSelfProfile()end))
 table.insert(self.Connections,button.MouseEnter:Connect(function()
  self:Sound(self.Profile,'Hover');Tween:Create(button,TweenInfo.new(.12),{BackgroundColor3=base:Lerp(Color3.fromRGB(70,160,195),.25)}):Play()
 end))
 table.insert(self.Connections,button.MouseLeave:Connect(function()Tween:Create(button,TweenInfo.new(.12),{BackgroundColor3=base}):Play()end))
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
 if not(self.Context and self.Context:GetController('WindowNavigationController'))then self:Close(self.Profile)end;self:Close(self.Request)
 local navigation=self.Context and self.Context:GetController('WindowNavigationController')
 if not self.Trade.Enabled and not(navigation and navigation:Contains('TradeHUD'))then self:Show(self.Trade)end
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
 local inventory=self.Context and self.Context:GetController('InventoryController')
 if inventory and inventory.Hud and inventory.Hud.Enabled then self:SetTarget(nil);return end
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
function Controller:Init(context)
 if self.Initialized then return end
 self.Initialized=true;self.Context=context
 self.Generation=0;self.Cards={};self.Connections={};self.DisplayTokens={};self.Fades={};self.Pool=Viewports.new(Config.MaxActivePreviews)
 local gui=player:WaitForChild('PlayerGui')
 self.Profile=gui:WaitForChild('PlayerProfileHUD',15);self.Request=gui:WaitForChild('TradeRequestHUD',15);self.Trade=gui:WaitForChild('TradeHUD',15)
 assert(self.Profile and self.Request and self.Trade,'Social HUDs missing in Edit')
 local remotes=RS:WaitForChild('Remotes'):WaitForChild('Social');self.SelfInspect=remotes:WaitForChild('SelfProfile');self.Inspect=remotes:WaitForChild('Inspect');self.Action=remotes:WaitForChild('Action');self.Update=remotes:WaitForChild('Updated')
 self.Equip=remotes:WaitForChild('Equip')
 for _,hud in ipairs({self.Profile,self.Request,self.Trade})do
  hud.Enabled=false
  for _,button in ipairs(hud:GetDescendants())do if button:IsA('TextButton')then
   local surface=hud==self.Profile and button:FindFirstChild('Surface')
   local visual=surface or button;local base=visual.BackgroundColor3
   local border=surface and button:FindFirstChild('Stroke');local thickness=border and border.Thickness
   table.insert(self.Connections,button.MouseEnter:Connect(function()
    self:Sound(hud,'Hover');Tween:Create(visual,TweenInfo.new(.12),{BackgroundColor3=base:Lerp(Color3.fromRGB(135,210,255),surface and .15 or .25)}):Play()
    if border then Tween:Create(border,TweenInfo.new(.12),{Thickness=thickness+1}):Play()end
   end))
   table.insert(self.Connections,button.MouseLeave:Connect(function()
    Tween:Create(visual,TweenInfo.new(.12),{BackgroundColor3=base}):Play()
    if border then Tween:Create(border,TweenInfo.new(.12),{Thickness=thickness}):Play()end
   end))
  end end
 end
 self:BindProfileButton(gui:WaitForChild('PlayerHUD'):WaitForChild('ProfileButton',15))
 local function connect(button,fn)table.insert(self.Connections,button.Activated:Connect(fn))end
 local articles=self.Profile.MainFrame:FindFirstChild('Articles')
 if articles then connect(articles,function()self:Sound(self.Profile,'Click');self:SetArticlesMode(not self.ArticlesVisible)end)end
 for _,entry in ipairs({{'Challenge','Duel'},{'Invite','Group'}})do
  local button=self.Profile.MainFrame:FindFirstChild(entry[1])
  if button then connect(button,function()
   if button.Active and self.ProfileMode=='OtherPlayerProfile'and self.ProfileTarget~=player.UserId then
    local play=self.Context and self.Context:GetController('SocialPlayController')
    if play then self:Sound(self.Profile,'Click');play:Invite(entry[2],self.ProfileTarget)end
   end
  end)end
 end
 connect(self.Profile.MainFrame.Close,function()self:Close(self.Profile)end)
 connect(self.Profile.MainFrame.Previous,function()if (self.ProfilePage or 1)>1 then self:OpenProfile(self.ProfileTarget,self.ProfilePage-1,true,self.ProfileCategory)end end)
 connect(self.Profile.MainFrame.Next,function()if self.ProfileHasNext then self:OpenProfile(self.ProfileTarget,self.ProfilePage+1,true,self.ProfileCategory)end end)
 local tabs=self.Profile.MainFrame:FindFirstChild('InventoryTabs')
 if tabs then for category in pairs(categoryNames)do connect(tabs[category],function()if self.ProfileTarget then self:OpenProfile(self.ProfileTarget,1,true,category)end end)end end
 connect(self.Profile.MainFrame.Trade,function()if self.ProfileMode=='OtherPlayerProfile'and self.ProfileTarget and self.ProfileTarget~=player.UserId and self.Profile.MainFrame.Trade.Active then self:RequestAction('Invite',self.ProfileTarget)end end)
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
 if self.Started then return end
 self.Started=true
 if not self.Update or not self.Profile or not self.Request or not self.Trade then warn('[Social] Init incomplete; controller disabled');return end
 table.insert(self.Connections,self.Update.OnClientEvent:Connect(function(kind,payload)
  if kind=='Trade'then self:TradePacket(payload)
  elseif kind=='ProfileUnavailable'and self.ProfileTarget==payload.UserId then self:Close(self.Profile)end
 end))
 local function closeAll()self:SetTarget(nil);for _,hud in ipairs({self.Profile,self.Request,self.Trade})do self:Close(hud)end;self.Pool:Clear()end
 table.insert(self.Connections,player:GetAttributeChangedSignal('MatchId'):Connect(function()if player:GetAttribute('MatchId')then closeAll()end end))
 table.insert(self.Connections,player.CharacterRemoving:Connect(closeAll))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)if self.ProfileTarget==p.UserId then self:Close(self.Profile)end;if self.Target==p then self:SetTarget(nil)end end))
 local dataUpdated=RS:WaitForChild('Remotes'):WaitForChild('Player'):WaitForChild('DataUpdated')
 table.insert(self.Connections,dataUpdated.OnClientEvent:Connect(function()
  -- Invalidation only; never render the client's private cached inventory.
  if self.ProfileMode=='SelfProfile'then self.NextSelfRefresh=workspace:GetServerTimeNow()+Config.RequestIntervalSeconds end
 end))
 local gui=player:WaitForChild('PlayerGui')
 for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
  local hud=gui:FindFirstChild(name);local main=hud and hud:FindFirstChild('MainFrame')
  if main then
   local function changed()if self.ProfileTarget and self:WindowBusy()and not(self.Context and self.Context:GetController('WindowNavigationController'))then self:Close(self.Profile)end end
   table.insert(self.Connections,main:GetPropertyChangedSignal('Visible'):Connect(changed))
   table.insert(self.Connections,hud:GetPropertyChangedSignal('Enabled'):Connect(changed))
  end
 end
 local elapsed=0
 table.insert(self.Connections,RunService.RenderStepped:Connect(function(dt)
  self.Pool:Step(dt);elapsed+=dt
  if elapsed<Config.AimPollSeconds then return end;elapsed=0
  self:PollTarget();self:RefreshPreviews();if self.ProfileData then self:ProfileActions(self.ProfileData)end
  if self.ProfileTarget and self:WindowBusy()and not(self.Context and self.Context:GetController('WindowNavigationController'))then self:Close(self.Profile)end
  if self.ProfileTarget and self.Profile.Enabled and workspace:GetServerTimeNow()>=(self.NextSelfRefresh or math.huge)then
   self:OpenProfile(self.ProfileTarget,self.ProfilePage,true)
  end
  local t=self.CurrentTrade
  if t and not terminal[t.State]then
   local now=workspace:GetServerTimeNow()
   if t.State=='Requested'then self.Request.MainFrame.Countdown.Text='Expira en '..math.max(0,math.ceil(t.ExpiresAt-now))..' s'
   elseif t.State=='SafetyCountdown'then self.Trade.MainFrame.Status.Text='SEGURIDAD: '..math.max(0,math.ceil(t.Deadline-now))..' s · NO TRANSFIERE OBJETOS'end
  end
 end))
end
function Controller:Destroy()
 self.Initialized=false;self.Started=false;self.Generation+=1;self:SetTarget(nil);self.Pool:Clear()
 for _,c in ipairs(self.Connections or {})do c:Disconnect()end;self.Connections={}
 for _,hud in ipairs({self.Profile,self.Request,self.Trade})do self:Close(hud)end
end
return Controller
