--!nonstrict
-- Binds permanent Edit templates. Never grants currency/items or acknowledges receipts.
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService");local Marketplace=game:GetService("MarketplaceService")
local Player=Players.LocalPlayer
local PurchaseFlow=require(script.Parent.Parent.PremiumShop.PremiumPurchaseFlow)
local Reserved=require(RS.Shared.PremiumShop.PlaceholderProductIds)
local Controller={}
local messages={PurchasesDisabled="Compras con Robux deshabilitadas.",ContentsPending="Contenido pendiente de aprobación.",ProductIdPending="Producto Roblox sin configurar.",
 DuplicatePolicyPending="Política de duplicados pendiente.",ApprovalPending="Venta pendiente de aprobación.",ProductDisabled="Producto deshabilitado.",DurableBackendPending="Persistencia durable pendiente.",
 PaidRandomItemsRestricted="Artículos aleatorios pagados restringidos por Roblox.",PolicyUnavailable="No se pudo verificar elegibilidad.",CommercialApprovalPending="Probabilidades y venta pendientes.",RateLimited="Esperá un momento y reintentá.",
 PlaceholderProduct="No configurado: ProductId provisional.",TestingEnvironment="Entorno de prueba: sin cobros.",TestingOrUnapprovedEnvironment="Entorno sin compras productivas.",
 ProfileLifecycleIntegrationPending="Integración durable de perfiles pendiente.",PriceUnavailable="Precio de Roblox no disponible.",PriceChanged="Cambió el precio: revisalo antes de volver a comprar.",
 ViewOddsFirst="Consultá las probabilidades actuales antes de comprar.",OddsChanged="Cambió el stock o la probabilidad. Volvé a consultar.",PersistenceTemporaryError="Error temporal de persistencia; la compra sigue pendiente."}
local categories={{"Coins","COINS","C"},{"Combos","COMBOS","★"},{"PremiumCrates","CAJAS PREMIUM","▣"}}
function Controller:Init(context)self.Context=context;self.Connections={};self.Cards={};self.CardConnections={};self.Opened=false;self.Generation=0;self.Category="Coins"end
function Controller:IsBlocked()
 local ending=self.Context:GetController("EndCinematicController");local opening=self.Context:GetController("CrateStandCinematicController")
 return Player:GetAttribute("MatchId")~=nil or Player:GetAttribute("ResultsSessionId")~=nil
  or ending and ending:IsPlaying()or opening and opening:IsPlaying()
end
function Controller:_call(action,args)
 if not self.Request then return {Ok=false,Code="NoResponse"}end
 local ok,result=pcall(self.Request.InvokeServer,self.Request,action,args or {})
 return if ok and type(result)=="table"then result else {Ok=false,Code="NoResponse"}
end
function Controller:_preview(viewport,product)
 local world=viewport:FindFirstChildWhichIsA("WorldModel");local camera=viewport:FindFirstChildWhichIsA("Camera")
 if not world or not camera then return end
 for _,obj in ipairs(world:GetChildren())do obj:Destroy()end
 local folder=RS:FindFirstChild("PremiumShopPreviews")
 local modelName=product.PreviewModel or(if product.Category=="Coins"then "CoinsDisplay"else "ComboDisplay")
 local source=(folder and folder:FindFirstChild(modelName))or RS.CrateEffects:FindFirstChild(modelName)
 if not source then return end
 local model=source:Clone()
 for _,obj in ipairs(model:GetDescendants())do
  if obj:IsA("BasePart")then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false
  elseif obj:IsA("LuaSourceContainer")then obj:Destroy()end
 end
 model.Parent=world;model:PivotTo(CFrame.new())
 local extent=model:GetExtentsSize();local size=math.max(extent.X,extent.Y,extent.Z)
 local aspect=math.max(.5,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
 camera.FieldOfView=35;camera.CFrame=CFrame.lookAt(Vector3.new(size*.8,size*.55,size*2.1/math.min(1,aspect)),Vector3.zero)
 viewport.CurrentCamera=camera
end
function Controller:_clear()
 for _,c in ipairs(self.CardConnections)do c:Disconnect()end;table.clear(self.CardConnections)
 for _,c in ipairs(self.Cards)do c:Destroy()end;table.clear(self.Cards)
end
function Controller:_layout()
 if not self.Main then return end
 local width=self.Main.AbsoluteSize.X
 local grid=self.Main.Catalog.UIGridLayout
 grid.CellSize=UDim2.new(if width<620 then 1 else .49,if width<620 then -4 else -6,0,224)
 for _,tab in ipairs(self.Main.Tabs:GetChildren())do if tab:IsA("TextButton")then tab.TextSize=if width<480 then 11 else 14 end end
end
function Controller:_render()
 if not self.Main then return end;self:_clear()
 local count=0
 for _,product in ipairs(self.Products or {})do if product.Category==self.Category then
  count+=1;local card=self.Main.Catalog.ProductCardTemplate:Clone();card.Name="Product_"..product.Id;card.LayoutOrder=count;card.Visible=true
  card.Title.Text=product.DisplayName;card.Description.Text=product.Description
  card.Content.Text=if product.Category=="Coins"then(if product.Rewards.Coins>0 then tostring(product.Rewards.Coins).." COINS"else "CANTIDAD PENDIENTE")else(if product.Category=="Combos"then "VER CONTENIDO GARANTIZADO"else "MODELO PROVISIONAL · ODDS PENDIENTES")
  card.Price.Text=if product.PriceRobux~=nil then tostring(product.PriceRobux).." ROBUX"else "ROBUX · SIN CONFIGURAR"
  card.Status.Text=messages[product.ConfigurationStatus]or messages[product.Status]or "Venta no habilitada"
  card.Buy.Active=product.PurchaseAllowed==true and product.PriceRobux~=nil;card.Buy.AutoButtonColor=card.Buy.Active
  card.Buy.Text=if card.Buy.Active then "COMPRAR"else "COMPRAR · BLOQUEADO"
  card.Buy.BackgroundTransparency=if card.Buy.Active then 0 else .5
  card.Parent=self.Main.Catalog;table.insert(self.Cards,card);self:_preview(card.Preview,product)
  table.insert(self.CardConnections,card.Activated:Connect(function()self:Details(product)end))
  table.insert(self.CardConnections,card.Buy.Activated:Connect(function()self:Details(product)end))
 end end
 self.Main.Empty.Visible=count==0
 for _,row in ipairs(categories)do local tab=self.Main.Tabs[row[1]];tab.BackgroundColor3=if self.Category==row[1]then Color3.fromRGB(94,54,176)else Color3.fromRGB(20,28,58)end
 self:_layout()
end
local function contents(product)
 local r=product.Rewards;local lines={}
 if r.Coins>0 then table.insert(lines,tostring(r.Coins).." Coins garantizadas")end
 for _,item in ipairs(r.Crates)do table.insert(lines,tostring(item.Quantity).." × caja "..item.CrateId.." cerrada (contenido aleatorio)")end
 for _,item in ipairs(r.Slaps)do table.insert(lines,"Slap garantizado: "..item.SlapId.." ["..item.VariationId.."]")end
 for _,id in ipairs(r.KillEffects)do table.insert(lines,"Kill Effect garantizado: "..id)end
 if #lines==0 then table.insert(lines,"Contenidos sin configurar. Este borrador no se puede comprar.")end
 table.insert(lines,"\nDuplicados: "..(({OncePerPlayer="compra única por jugador",RestrictOwned="bloqueado si ya poseés un premio permanente",RepeatableNoCompensation="repetible; sin compensación por duplicados",Unspecified="política pendiente"})[product.DuplicatePolicy]or "política pendiente"))
 if product.HasRandomContents then table.insert(lines,"\n"..product.OddsNotice)end
 if product.SuggestedRobux then table.insert(lines,"\nPrecio sugerido para Creator Hub: "..product.SuggestedRobux.." Robux. NO es el precio de compra; Roblox determina el precio real.")end
 return table.concat(lines,"\n")
end
function Controller:Details(product)
 if product.HasRandomContents then product.QuoteTokens=nil end
 self.Selected=product;local details=self.Main.Details;details.Visible=true
 details.Title.Text=product.DisplayName;details.Scroll.Content.Text=contents(product)
 details.Status.Text=messages[product.ConfigurationStatus]or messages[product.Status]or "Venta no habilitada"
 details.Buy.Text=if product.PriceRobux then "COMPRAR · "..product.PriceRobux.." ROBUX"else "COMPRAR · PRODUCTO SIN CONFIGURAR"
 details.Buy.Active=product.PurchaseAllowed==true and product.PriceRobux~=nil and(not product.HasRandomContents or product.QuoteTokens~=nil)and not(self.Flow and(self.Flow.Pending or self.Flow.Busy));details.Buy.AutoButtonColor=details.Buy.Active;details.Buy.BackgroundTransparency=if details.Buy.Active then 0 else .55
 details.ViewCrate.Visible=product.CrateId~=nil;details.ViewCrate.Text="VER INVENTARIO / APERTURA"
 local token=self.Generation
 if product.HasRandomContents then task.spawn(function()
  task.wait(.55);if token~=self.Generation or self.Selected~=product or not self.Opened then return end
  local result=self:_call("Odds",{Id=product.Id})
  if token~=self.Generation or self.Selected~=product or not self.Opened then return end
  local lines={contents(product),"\nPROBABILIDADES ACTUALES POR RECOMPENSA"}
  if result.Ok then
   local tokens={};local valid=true
   for crateId,quote in pairs(result.Quotes)do
    table.insert(lines,"\n"..crateId)
    if quote.Ok then
     tokens[crateId]=quote.Token
     for _,outcome in ipairs(quote.Outcomes)do table.insert(lines,string.format("%s: %.8g %%",outcome.DisplayName,outcome.Percent))end
     for _,excluded in ipairs(quote.ExcludedOutcomes or {})do table.insert(lines,excluded.DisplayName..": excluido ("..excluded.Reason..")")end
    else valid=false;table.insert(lines,messages[quote.Code]or quote.Code)end
   end
   product.QuoteTokens=if valid and next(tokens)then tokens else nil
   details.Buy.Active=product.PurchaseAllowed==true and product.PriceRobux~=nil and product.QuoteTokens~=nil and not self.Flow.Pending
  else table.insert(lines,messages[result.Code]or "No se pudo consultar. Reabrí el detalle para reintentar.")end
  details.Scroll.Content.Text=table.concat(lines,"\n")
 end)end
end
function Controller:Open()
 if not self.Main or self:IsBlocked()then return end
 self.Generation+=1;local token=self.Generation;self.Opened=true
 local navigation=self.Context:GetController('WindowNavigationController')
 local shop=self.Context:GetController("ShopController");if shop and not navigation then shop:Close()end
 local crate=self.Context:GetController("CrateController");if crate and crate._panel and not navigation then crate._panel.Visible=false end
 self.Hud.Enabled=true;self.Main.Visible=true;self.Main.Details.Visible=false;self.Main.OpenScale.Scale=.94
 Tween:Create(self.Main.OpenScale,TweenInfo.new(.18,Enum.EasingStyle.Quad),{Scale=1}):Play()
 self.Main.Banner.Text="Cargando catálogo…"
 task.spawn(function()
  local result=self:_call("Catalog")
  if token~=self.Generation or not self.Opened then return end
  if not result.Ok then self.Main.Banner.Text=messages[result.Code]or "Catálogo no disponible. Cerrá y reintentá.";return end
  self.Products=result.Products;self.CrateProducts=result.CrateProducts;self.Category=result.DefaultCategory or "Coins"
  self.Main.Banner.Text=if result.PurchasesEnabled then "TIENDA PREMIUM · PRECIOS DE ROBLOX"else "VISTA PREVIA · COMPRAS ROBUX DESHABILITADAS"
  if not result.Policy.RandomAllowed then self.Main.Banner.Text..=" · Aleatorios restringidos o sin verificar"end
  self:_render()
  for _,p in ipairs(self.Products)do
   if p.CommercialVerified and p.IsPlaceholder==false then
    local price,why=self.Flow:Price(p);p.PriceRobux=price
    if not price then p.PurchaseAllowed=false;p.Status=why;warn("[PremiumShop] Precio no disponible: "..p.Id)end
   end
  end
  if token~=self.Generation or not self.Opened then return end
  self:_render();task.wait(.55)
  local status=self:_call("Status");if status.Ok then self.Flow:Status(status.Receipts or {})end
 end)
end
function Controller:Close()
 local navigation=self.Context and self.Context:GetController('WindowNavigationController');if navigation then navigation:Forget('Premium')end
 if self.Flow then self.Flow:CancelAuthorization()end
 self.Generation+=1;self.Opened=false;self.Selected=nil;self:_clear()
 if self.Hud then self.Hud.Enabled=false;self.Main.Visible=false;self.Main.Details.Visible=false end
end
function Controller:_purchaseState(state,extra)
 local labels={Processing="Consultando compra…",Purchasing="Comprando…",AwaitingConfirmation="Esperando confirmación del servidor…",Credited="Compra acreditada por el servidor.",TemporaryError="Error temporal.",Restricted="Producto restringido.",Available="Disponible.",Unavailable="No disponible."}
 if not self.Main then return end
 local text=labels[state]or state
 if type(extra)=="string"and messages[extra]then text..=" "..messages[extra]end
 self.Main.Banner.Text=text
 if self.Selected and(self.Selected.Id==self.BuyingKey or state=="Credited"and self.Selected.Id==extra)then
  self.Main.Details.Status.Text=text
  if state=="Purchasing"and type(extra)=="number"then self.Main.Details.Buy.Text="COMPRAR · "..extra.." ROBUX"end
  if state=="Credited"and self.Selected.DuplicatePolicy~="RepeatableNoCompensation"then self.Selected.PurchaseAllowed=false end
  if extra=="PriceChanged"and self.Selected.PriceRobux then self.Main.Details.Buy.Text="COMPRAR · "..self.Selected.PriceRobux.." ROBUX"end
  self.Main.Details.Buy.Active=(state=="Available"or state=="Credited"or state=="TemporaryError")and self.Selected.PurchaseAllowed==true and self.Selected.PriceRobux~=nil and not(self.Flow.Pending or self.Flow.Busy)
 end
end
function Controller:_pollReceipt()
 if self.Polling then return end;self.Polling=true
 task.spawn(function()
  for _=1,20 do
   task.wait(2);if self.Destroyed or not self.Flow.Pending then break end
   local status=self:_call("Status");if status.Ok then self.Flow:Status(status.Receipts or {})end
  end
  self.Polling=false
 end)
end
function Controller:Start()
 task.spawn(function()
  local pg=Player:WaitForChild("PlayerGui");self.Hud=pg:WaitForChild("PremiumShopHUD",15)
  local mainHUD=pg:WaitForChild("PlayerHUD",15);local remote=RS:WaitForChild("Remotes"):WaitForChild("PremiumShop",15)
  if not self.Hud or not mainHUD or not remote then warn("[PremiumShop] Missing Edit resources");return end
  self.Request=remote:WaitForChild("Request",15);self.Main=self.Hud.MainFrame
  self.Flow=PurchaseFlow.new(Marketplace,Player,function(action,args)return self:_call(action,args)end,function(state,extra)self:_purchaseState(state,extra)end,nil,Reserved)
  local delivery=remote:WaitForChild("Delivery",15)
  if delivery then table.insert(self.Connections,delivery.OnClientEvent:Connect(function(receipt)self.Flow:Delivery(receipt)end))end
  table.insert(self.Connections,Marketplace.PromptProductPurchaseFinished:Connect(function(uid,pid,bought)self.Flow:PromptClosed(uid,pid,bought)end))
  self:Close()
  local button=mainHUD:WaitForChild("PremiumShopButton",15);if not button then return end
  table.insert(self.Connections,button.Activated:Connect(function()if self.Opened and self.Main.Visible then self:Close()else self:Open()end end))
  table.insert(self.Connections,self.Main.Close.Activated:Connect(function()self:Close()end))
  table.insert(self.Connections,self.Main.Details.Close.Activated:Connect(function()self.Main.Details.Visible=false;self.Selected=nil end))
  for _,row in ipairs(categories)do table.insert(self.Connections,self.Main.Tabs[row[1]].Activated:Connect(function()self.Category=row[1];self.Main.Details.Visible=false;self:_render()end))end
  table.insert(self.Connections,self.Main.Details.Buy.Activated:Connect(function()
   local p=self.Selected;if not p or not p.PurchaseAllowed or self:IsBlocked()or self.Purchasing then return end
   self.Purchasing=true;self.BuyingKey=p.Id
   task.spawn(function()
    self.Flow:Begin(p);self.Purchasing=false
    if self.Flow.Pending then self:_pollReceipt()end
   end)
  end))
  table.insert(self.Connections,self.Main.Details.ViewCrate.Activated:Connect(function()
   local p=self.Selected;local crate=self.Context:GetController("CrateController");if not p or not p.CrateId or not crate or self:IsBlocked()then return end
   crate:SetCatalog(self.CrateProducts or {});if not self.Context:GetController('WindowNavigationController')then self:Close()end;crate:ShowCrate(p.CrateId)
  end))
  table.insert(self.Connections,self.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:_layout()end))
  for _,attribute in ipairs({"MatchId","ResultsSessionId"})do table.insert(self.Connections,Player:GetAttributeChangedSignal(attribute):Connect(function()if self:IsBlocked()then self:Close()end end))end
 end)
end
function Controller:Destroy()self.Destroyed=true;self:Close();for _,c in ipairs(self.Connections)do c:Disconnect()end;table.clear(self.Connections)end
return Controller
