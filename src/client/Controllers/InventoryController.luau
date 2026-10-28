--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Tween=game:GetService('TweenService')
local View=require(script.Parent.Parent.UI.InventoryView)
local Pool=require(script.Parent.Parent.Social.ViewportPool)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local player=Players.LocalPlayer
local Controller={Name='InventoryController'}
local C=Color3.fromRGB
local errors={RateLimited='Esperá un momento y reintentá.',NotOwned='Este objeto ya no está en tu inventario.',PlayerUnavailable='El inventario está disponible en el lobby.',PlayerBusy='Terminá el intercambio antes de equipar.',ProductUnavailable='Este recurso no está disponible.',DataNotLoaded='Tus datos todavía están cargando.',PersistencePending='La selección sigue pendiente de confirmación.',NoResponse='No se pudo confirmar la operación. Actualizá antes de reintentar.'}
local function reason(r)return errors[r]or 'No se pudo completar la solicitud. Reintentá en un momento.'end
local function color(item)
 local v=Catalog.Variations.ById[item.Rarity or item.VariationId]
 return v and v.Color or ({Rare=C(76,169,255),Epic=C(183,116,255),Legendary=C(255,198,69)})[item.Rarity]or C(89,240,123)
end
function Controller:Blocked()
 if player:GetAttribute('MatchId')or player:GetAttribute('ResultsSessionId')then return true end
 local gui=player.PlayerGui
 for _,name in ipairs({'TradeHUD','TradeRequestHUD','CrateOpeningHUD'})do local h=gui:FindFirstChild(name);if h and h.Enabled then return true end end
 local cinematic=self.Context:GetController('CrateStandCinematicController')
 return cinematic and cinematic.IsPlaying and cinematic:IsPlaying()or false
end
function Controller:Status(t)self.Main.Content.Footer.Status.Text=t end
function Controller:Clear()
 for _,row in ipairs(self.Rows)do row.Connection:Disconnect();row.Card:Destroy()end
 self.Rows={};self.Pool:Clear()
end
function Controller:Close()
 if not self.Hud then return end
 self.Generation+=1;self.Loading=false
 local nav=self.Context:GetController('WindowNavigationController');if nav then nav:Forget('InventoryHUD')end
 self.Hud.Enabled=false;self.Pool:Clear()
end
function Controller:Open(category)
 if not self.Hud or self:Blocked()then return end
 if category and View.Icons[category]then self.Category=category end
 self.Hud.Enabled=true;self.Main.OpenScale.Scale=.96
 Tween:Create(self.Main.OpenScale,TweenInfo.new(.18,Enum.EasingStyle.Quad),{Scale=1}):Play()
 self:Load(1)
end
function Controller:Preview(view,icon,item)
 local success=false
 if item.Category=='Slaps'then success=self.Pool:Slap(view,item)
 elseif item.Category=='Crates'then
  local root=RS:FindFirstChild('CrateEffects');local definition=Catalog.Crates.ById[item.ProductId]
  success=self.Pool:Add(view,root and root:FindFirstChild(definition and definition.Model or item.ProductId),false)
 end
 view.Visible=success;icon.Visible=not success
 icon.Image=type(item.Icon)=='string'and item.Icon~=''and item.Icon or View.Icons[item.Category]
end
function Controller:Select(item)
 self.Selected=item;local d=self.Main.Content.Detail
 self.Pool:Remove(d.Preview)
 d.Title.Text=item and item.DisplayName or 'Seleccioná un objeto'
 d.Rarity.Text=item and (item.VariationName or item.Rarity or (item.Category=='Crates'and 'CAJA CERRADA')or '')or ''
 d.Quantity.Text=item and (item.Category=='Crates'and ('Tenés '..item.Quantity..' caja'..(item.Quantity==1 and ''or 's'))or item.Quantity and item.Quantity>1 and ('Tenés '..item.Quantity..' unidades')or 'EN TU INVENTARIO')or ''
 d.Description.Text=item and (item.Category=='Crates'and 'Consultá sus premios y abrila con el sistema de cajas.'or item.Equipped and 'Lo estás usando actualmente.'or 'Equipalo para tu próxima partida.')or 'Acá aparecerán los detalles de tu selección.'
 d.Preview.Visible=false;d.Icon.Visible=false
 if item then local tint=color(item);d.Rarity.TextColor3=tint;d.Aura.BackgroundColor3=tint;self:Preview(d.Preview,d.Icon,item)end
 local allowed=item~=nil and not self.PendingEquip and not self.Loading and not item.Equipped and item.Available~=false
 if item and item.Category=='Crates'then allowed=not self.Loading and not self.PendingEquip end
 d.Action.Active=allowed;d.Action.Selectable=allowed
 d.Action.Text=not item and 'SELECCIONÁ UN OBJETO'or self.PendingEquip and 'GUARDANDO…'or item.Category=='Crates'and 'VER CAJA / ABRIR'or item.Equipped and '✓ EQUIPADO'or item.Available==false and 'NO DISPONIBLE'or 'EQUIPAR'
 d.Action.BackgroundColor3=allowed and C(35,220,79)or C(53,78,70)
 for _,row in ipairs(self.Rows)do row.Card.Stroke.Color=row.Item==item and C(222,255,233)or C(63,89,88);row.Card.Stroke.Thickness=row.Item==item and 2 or 1 end
end
function Controller:Render(data)
 local selected=self.Selected and self.Selected.ProductId;self:Clear();self.Data=data
 local content=self.Main.Content
 for i,item in ipairs(data.Items)do
  local card=self.Hud.CardTemplate:Clone();card.Name='Item_'..i;card.Visible=true;card.LayoutOrder=i
  card.ItemName.Text=item.DisplayName;card.ItemName.TextColor3=color(item);card.Aura.BackgroundColor3=color(item)
  card.Equipped.Visible=item.Equipped==true;card.Count.Text=item.Quantity and item.Quantity>1 and 'x'..item.Quantity or ''
  card.Parent=content.Grid
  local connection=card.Activated:Connect(function()if not self.Loading then self:Select(item)end end)
  table.insert(self.Rows,{Card=card,Item=item,Connection=connection})
 end
 self.Page=data.Page;content.Footer.Page.Text=data.Page..' / '..data.Pages
 content.Footer.Previous.Active=data.Page>1;content.Footer.Next.Active=data.HasNext
 content.Footer.Previous.TextTransparency=data.Page>1 and 0 or .6;content.Footer.Next.TextTransparency=data.HasNext and 0 or .6
 content.Empty.Visible=#data.Items==0
 content.Empty.Text=data.FilteredTotal==0 and data.Total>0 and 'No encontramos objetos con ese nombre.'or self.Category=='Crates'and 'Todavía no tenés cajas.\nCompralas en la tienda de cajas del lobby.'or 'Todavía no tenés objetos en esta categoría.'
 content.Footer.More.Text=self.Category=='Crates'and '¿DÓNDE COMPRAR?'or 'VER MIS CAJAS'
 local pick=data.Items[1];for _,item in ipairs(data.Items)do if item.ProductId==selected then pick=item;break end end
 self:Select(pick);self:Layout();self:RefreshPreviews();self:Status(data.FilteredTotal..' tipos de objetos')
end
function Controller:Load(page)
 if not self.Hud.Enabled or self:Blocked()then return end
 self.Generation+=1;local token=self.Generation;local category=self.Category
 self.Loading=true;self.Main.Content.Detail.Action.Active=false;self:Status('Cargando…')
 for key in pairs(View.Icons)do self.Main.Tabs[key].BackgroundColor3=key==category and C(31,105,73)or C(28,43,53)end
 local query=string.sub(self.Main.Header.Search.Text,1,80)
 task.spawn(function()
  -- Shares the Social request budget with the profile; wait before following its link.
  task.wait(.3)
  if token~=self.Generation or not self.Hud.Enabled then return end
  local ok,response=pcall(self.Remote.InvokeServer,self.Remote,category,page or 1,query)
  if ok and type(response)=='table'and response.Reason=='RateLimited'then
   task.wait(.35);if token~=self.Generation or not self.Hud.Enabled then return end
   ok,response=pcall(self.Remote.InvokeServer,self.Remote,category,page or 1,query)
  end
  if token~=self.Generation or not self.Hud.Enabled then return end
  self.Loading=false;self.LastRefresh=os.clock()
  if not ok or type(response)~='table'or not response.Ok then
   self:Clear();self:Select(nil);self.Main.Content.Empty.Visible=true
   self.Main.Content.Empty.Text=reason(type(response)=='table'and response.Reason or 'NoResponse');self:Status('Usá Actualizar para reintentar.');self.Main.Content.Footer.More.Text='ACTUALIZAR';self.Failed=true;return
  end
  local data=response.Inventory
  if type(data)~='table'or data.UserId~=player.UserId or data.Category~=category then self:Close();return end
  self.Failed=false;self:Render(data)
 end)
end
function Controller:EquipSelected()
 local item=self.Selected
 if not item or self.Loading or self.PendingEquip or self:Blocked()then return end
 if item.Category=='Crates'then
  local crates=self.Context:GetController('CrateController')
  if crates and item.Product then crates:SetCatalog({item.Product});crates:ShowCrate(item.ProductId)end
  return
 end
 if item.Equipped or item.Available==false then return end
 self.PendingEquip=true;local token=self.Generation;self:Select(item);self:Status('Guardando selección…')
 task.spawn(function()
  task.wait(.3)
  local ok,response=pcall(self.Equip.InvokeServer,self.Equip,item.Category,item.ProductId,1)
  self.PendingEquip=false
  if not self.Hud.Enabled then return end
  if ok and type(response)=='table'and response.Ok then self:Load(self.Page)
  elseif token==self.Generation then self:Select(self.Selected);self:Status(reason(type(response)=='table'and response.Reason or 'NoResponse'))end
 end)
end
function Controller:RefreshPreviews()
 if not self.Hud.Enabled then return end
 local grid=self.Main.Content.Grid;local active=0
 for _,row in ipairs(self.Rows)do
  local p=row.Card.AbsolutePosition;local s=row.Card.AbsoluteSize
  if p.Y+s.Y>grid.AbsolutePosition.Y and p.Y<grid.AbsolutePosition.Y+grid.AbsoluteSize.Y and active<8 then
   self:Preview(row.Card.Preview,row.Card.Icon,row.Item);active+=1
  else self.Pool:Remove(row.Card.Preview)end
 end
end
function Controller:Layout()
 local m=self.Main;local narrow=m.AbsoluteSize.X<760;local side=narrow and 82 or 112
 m.Tabs.Size=UDim2.new(0,side,1,0)
 m.Header.Position=UDim2.fromOffset(side+18,12);m.Header.Size=UDim2.new(1,-side-34,0,54)
 m.Header.Title.Visible=not narrow;m.Header.Subtitle.Visible=not narrow
 m.Header.Search.Position=UDim2.fromOffset(narrow and 0 or 196,3);m.Header.Search.Size=UDim2.new(1,narrow and -58 or -254,0,44)
 m.Content.Position=UDim2.fromOffset(side+18,80);m.Content.Size=UDim2.new(1,-side-34,1,-96)
 local height=math.min(112,(m.AbsoluteSize.Y-24)/4)
 for i,key in ipairs({'Slaps','DeathEffects','PointEffects','Crates'})do m.Tabs[key].Position=UDim2.fromOffset(8,12+(i-1)*height);m.Tabs[key].Size=UDim2.new(1,-16,0,height-8)end
 local width=m.Content.Grid.AbsoluteSize.X;local columns=width>=520 and 3 or width>=305 and 2 or 1
 m.Content.Grid.Layout.CellSize=UDim2.new(1/columns,-9,0,math.clamp(m.AbsoluteSize.Y*.32,150,195))
 for _,label in ipairs({m.Content.Detail.Title,m.Content.Detail.Rarity,m.Content.Detail.Action})do label.TextScaled=true end
end
function Controller:Init(context)
 self.Context=context;self.Connections={};self.Rows={};self.Generation=0;self.Category='Slaps';self.Page=1;self.Pool=Pool.new(10)
 local gui=player:WaitForChild('PlayerGui');self.Hud=View.Build(gui);self.Main=self.Hud.MainFrame;self.Hud.Enabled=false
 self.Button=View.Button(gui:WaitForChild('PlayerHUD'));self:Select(nil)
end
function Controller:Start()
 local remotes=RS:WaitForChild('Remotes');local social=remotes:WaitForChild('Social')
 self.Remote=social:WaitForChild('Inventory',20);self.Equip=social:WaitForChild('Equip',20)
 if not self.Remote or not self.Equip then warn('[Inventory] Remotes unavailable');return end
 local function connect(signal,fn)table.insert(self.Connections,signal:Connect(fn))end
 local nav=self.Context:GetController('WindowNavigationController');if nav then nav:Watch('InventoryHUD',self.Hud,'Enabled')end
 connect(self.Button.Activated,function()if self.Hud.Enabled then self:Close()else self:Open()end end)
 connect(self.Main.Header.Close.Activated,function()self:Close()end)
 for key in pairs(View.Icons)do connect(self.Main.Tabs[key].Activated,function()self.Category=key;self.Selected=nil;self:Clear();self.Main.Header.Search.Text='';self:Load(1)end)end
 connect(self.Main.Header.Search:GetPropertyChangedSignal('Text'),function()self:Load(1)end)
 connect(self.Main.Content.Footer.Previous.Activated,function()if not self.Loading and self.Page>1 then self:Load(self.Page-1)end end)
 connect(self.Main.Content.Footer.Next.Activated,function()if not self.Loading and self.Data and self.Data.HasNext then self:Load(self.Page+1)end end)
 connect(self.Main.Content.Footer.More.Activated,function()
  if self.Failed then self:Load(1)
  elseif self.Category~='Crates'then self.Category='Crates';self.Selected=nil;self.Main.Header.Search.Text='';self:Load(1)
  else self:Status('Comprá cajas en la tienda de cajas del lobby.')end
 end)
 connect(self.Main.Content.Detail.Action.Activated,function()self:EquipSelected()end)
 connect(self.Main:GetPropertyChangedSignal('AbsoluteSize'),function()self:Layout()end)
 connect(self.Hud:GetPropertyChangedSignal('Enabled'),function()
  if not self.Hud.Enabled then self.Pool:Clear();self.Generation+=1;self.Loading=false
  elseif os.clock()-(self.LastRefresh or 0)>1 then self:Load(self.Page)end
 end)
 connect(remotes.Player.DataUpdated.OnClientEvent,function()
  self.LastRefresh=0
  if self.Hud.Enabled and not self.PendingEquip then self:Load(self.Page)end
 end)
 for _,key in ipairs({'MatchId','ResultsSessionId'})do connect(player:GetAttributeChangedSignal(key),function()if self:Blocked()then self:Close()end end)end
 connect(player.CharacterRemoving,function()self:Close()end)
 local elapsed=0;connect(RunService.RenderStepped,function(dt)
  if not self.Hud.Enabled then return end
  self.Pool:Step(dt);elapsed+=dt
  if elapsed>.2 then elapsed=0;self:RefreshPreviews()end
 end)
 for _,b in ipairs(self.Main:GetDescendants())do if b:IsA('GuiButton')then
  connect(b.MouseEnter,function()if b.Active then local st=b:FindFirstChild('Stroke');if st then Tween:Create(st,TweenInfo.new(.12),{Thickness=2}):Play()end end end)
  connect(b.MouseLeave,function()local st=b:FindFirstChild('Stroke');if st then Tween:Create(st,TweenInfo.new(.12),{Thickness=1}):Play()end end)
 end end
 self:Layout()
end
function Controller:Destroy()
 self:Close();self:Clear();for _,c in ipairs(self.Connections)do c:Disconnect()end;self.Connections={}
end
return Controller
