--!nonstrict
-- Binds permanent Edit templates. Never grants currency/items or acknowledges receipts.
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService");local Marketplace=game:GetService("MarketplaceService")
local Player=Players.LocalPlayer
local Controller={}
local messages={PurchasesDisabled="Compras con Robux deshabilitadas.",ContentsPending="Contenido pendiente de aprobación.",ProductIdPending="Producto Roblox sin configurar.",
 DuplicatePolicyPending="Política de duplicados pendiente.",ApprovalPending="Venta pendiente de aprobación.",ProductDisabled="Producto deshabilitado.",DurableBackendPending="Persistencia durable pendiente.",
 PaidRandomItemsRestricted="Artículos aleatorios pagados restringidos por Roblox.",PolicyUnavailable="No se pudo verificar elegibilidad.",CommercialApprovalPending="Probabilidades y venta pendientes.",RateLimited="Esperá un momento y reintentá."}
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
  card.Buy.Active=product.PurchaseAllowed==true;card.Buy.AutoButtonColor=card.Buy.Active
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
 return table.concat(lines,"\n")
end
function Controller:Details(product)
 self.Selected=product;local details=self.Main.Details;details.Visible=true
 details.Title.Text=product.DisplayName;details.Scroll.Content.Text=contents(product)
 details.Status.Text=messages[product.ConfigurationStatus]or messages[product.Status]or "Venta no habilitada"
 details.Buy.Text=if product.PriceRobux then "COMPRAR · "..product.PriceRobux.." ROBUX"else "COMPRAR · PRODUCTO SIN CONFIGURAR"
 details.Buy.Active=product.PurchaseAllowed==true;details.Buy.AutoButtonColor=details.Buy.Active;details.Buy.BackgroundTransparency=if details.Buy.Active then 0 else .55
 details.ViewCrate.Visible=product.CrateId~=nil;details.ViewCrate.Text="VER INVENTARIO / APERTURA"
 local token=self.Generation
 if product.HasRandomContents then task.spawn(function()
  task.wait(.55);if token~=self.Generation or self.Selected~=product or not self.Opened then return end
  local result=self:_call("Odds",{Id=product.Id})
  if token~=self.Generation or self.Selected~=product or not self.Opened then return end
  local lines={contents(product),"\nPROBABILIDADES ACTUALES POR RECOMPENSA"}
  if result.Ok then
   for crateId,quote in pairs(result.Quotes)do
    table.insert(lines,"\n"..crateId)
    if quote.Ok then
     for _,outcome in ipairs(quote.Outcomes)do table.insert(lines,string.format("%s: %.8g %%",outcome.DisplayName,outcome.Percent))end
     for _,excluded in ipairs(quote.ExcludedOutcomes or {})do table.insert(lines,excluded.DisplayName..": excluido ("..excluded.Reason..")")end
    else table.insert(lines,messages[quote.Code]or quote.Code)end
   end
  else table.insert(lines,messages[result.Code]or "No se pudo consultar. Reabrí el detalle para reintentar.")end
  details.Scroll.Content.Text=table.concat(lines,"\n")
 end)end
end
function Controller:Open()
 if not self.Main or self:IsBlocked()then return end
 self.Generation+=1;local token=self.Generation;self.Opened=true
 local shop=self.Context:GetController("ShopController");if shop then shop:Close()end
 local crate=self.Context:GetController("CrateController");if crate and crate._panel then crate._panel.Visible=false end
 self.Hud.Enabled=true;self.Main.Visible=true;self.Main.Details.Visible=false;self.Main.OpenScale.Scale=.94
 Tween:Create(self.Main.OpenScale,TweenInfo.new(.18,Enum.EasingStyle.Quad),{Scale=1}):Play()
 self.Main.Banner.Text="Cargando catálogo…"
 task.spawn(function()
  local result=self:_call("Catalog")
  if token~=self.Generation or not self.Opened then return end
  if not result.Ok then self.Main.Banner.Text=messages[result.Code]or "Catálogo no disponible. Cerrá y reintentá.";return end
  self.Products=result.Products;self.CrateProducts=result.CrateProducts;self.Category=result.DefaultCategory or "Coins"
  self.Main.Banner.Text="VISTA PREVIA · COMPRAS ROBUX DESHABILITADAS"
  if not result.Policy.RandomAllowed then self.Main.Banner.Text..=" · Aleatorios restringidos o sin verificar"end
  self:_render()
 end)
end
function Controller:Close()
 self.Generation+=1;self.Opened=false;self.Selected=nil;self:_clear()
 if self.Hud then self.Hud.Enabled=false;self.Main.Visible=false;self.Main.Details.Visible=false end
end
function Controller:Start()
 task.spawn(function()
  local pg=Player:WaitForChild("PlayerGui");self.Hud=pg:WaitForChild("PremiumShopHUD",15)
  local mainHUD=pg:WaitForChild("PlayerHUD",15);local remote=RS:WaitForChild("Remotes"):WaitForChild("PremiumShop",15)
  if not self.Hud or not mainHUD or not remote then warn("[PremiumShop] Missing Edit resources");return end
  self.Request=remote:WaitForChild("Request",15);self.Main=self.Hud.MainFrame;self:Close()
  local button=mainHUD:WaitForChild("PremiumShopButton",15);if not button then return end
  table.insert(self.Connections,button.Activated:Connect(function()if self.Opened then self:Close()else self:Open()end end))
  table.insert(self.Connections,self.Main.Close.Activated:Connect(function()self:Close()end))
  table.insert(self.Connections,self.Main.Details.Close.Activated:Connect(function()self.Main.Details.Visible=false;self.Selected=nil end))
  for _,row in ipairs(categories)do table.insert(self.Connections,self.Main.Tabs[row[1]].Activated:Connect(function()self.Category=row[1];self.Main.Details.Visible=false;self:_render()end))end
  table.insert(self.Connections,self.Main.Details.Buy.Activated:Connect(function()
   local p=self.Selected;if not p or not p.PurchaseAllowed or self:IsBlocked()or self.Purchasing then return end
   self.Purchasing=true;local token=self.Generation
   task.spawn(function()
    local result=self:_call("Purchase",{Id=p.Id});self.Purchasing=false
    if token~=self.Generation or self:IsBlocked()then return end
    -- Only an explicit server authorization may open the official Roblox prompt. V1.0 never issues one.
    if result.Ok and result.PromptAllowed==true and type(result.ProductId)=="number"and result.ProductId>0 then Marketplace:PromptProductPurchase(Player,result.ProductId)
    else self.Main.Details.Status.Text=messages[result.Code]or "Compra no autorizada."end
   end)
  end))
  table.insert(self.Connections,self.Main.Details.ViewCrate.Activated:Connect(function()
   local p=self.Selected;local crate=self.Context:GetController("CrateController");if not p or not p.CrateId or not crate or self:IsBlocked()then return end
   crate:SetCatalog(self.CrateProducts or {});self:Close();crate:ShowCrate(p.CrateId)
  end))
  table.insert(self.Connections,self.Main:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:_layout()end))
  for _,attribute in ipairs({"MatchId","ResultsSessionId"})do table.insert(self.Connections,Player:GetAttributeChangedSignal(attribute):Connect(function()if self:IsBlocked()then self:Close()end end))end
 end)
end
function Controller:Destroy()self:Close();for _,c in ipairs(self.Connections)do c:Disconnect()end;table.clear(self.Connections)end
return Controller
