-- Run through MCP in Edit ONLY. Creates only new roots / the authorized HUD button.
assert(game:GetService("RunService"):IsStudio()and not game:GetService("RunService"):IsRunning())
local RS=game.ReplicatedStorage
assert(not game.StarterGui:FindFirstChild("PremiumShopHUD"),"Premium HUD already installed; inspect before replacing")
assert(not game.StarterGui.PlayerHUD:FindFirstChild("PremiumShopButton"))
assert(not RS:FindFirstChild("PremiumShopPreviews"))
local navy=Color3.fromRGB(10,16,38);local panel=Color3.fromRGB(20,28,58);local violet=Color3.fromRGB(134,78,232)
local gold=Color3.fromRGB(255,208,92);local cyan=Color3.fromRGB(65,216,241);local white=Color3.fromRGB(238,243,255)
local function make(class,name,parent,props)local n=Instance.new(class);n.Name=name;for k,v in pairs(props or {})do n[k]=v end;n.Parent=parent;return n end
local function corner(n,r)make("UICorner","UICorner",n,{CornerRadius=UDim.new(0,r or 12)})end
local function stroke(n,c,t)make("UIStroke","UIStroke",n,{Color=c or violet,Thickness=t or 1.5,Transparency=.18,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})end
local function label(name,parent,text,pos,size,color,fontSize)
 return make("TextLabel",name,parent,{Text=text,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=color or white,TextSize=fontSize or 16,Font=Enum.Font.GothamMedium,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center})
end
local function button(name,parent,text,pos,size,color)
 local n=make("TextButton",name,parent,{Text=text,Position=pos,Size=size,BackgroundColor3=color or panel,TextColor3=white,TextSize=14,Font=Enum.Font.GothamBold,AutoButtonColor=true});corner(n,10);stroke(n,color or violet);return n
end
local hud=make("ScreenGui","PremiumShopHUD",nil,{Enabled=false,ResetOnSpawn=false,DisplayOrder=32,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=false})
make("Frame","Dim",hud,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(),BackgroundTransparency=.3,BorderSizePixel=0})
local main=make("Frame","MainFrame",hud,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.93,.88),BackgroundColor3=navy,BorderSizePixel=0,ClipsDescendants=true,Visible=false})
corner(main,18);stroke(main,violet,2);make("UISizeConstraint","Bounds",main,{MaxSize=Vector2.new(1050,730)})
make("UIScale","OpenScale",main,{Scale=1})
make("UIGradient","Backdrop",main,{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(25,23,66)),ColorSequenceKeypoint.new(1,navy)}),Rotation=70})
label("Eyebrow",main,"SLAPDUELS · PREMIUM COLLECTION",UDim2.new(0,18,0,10),UDim2.new(1,-80,0,18),gold,11)
label("Title",main,"TIENDA PREMIUM",UDim2.new(0,18,0,30),UDim2.new(1,-80,0,38),white,26)
button("Close",main,"×",UDim2.new(1,-52,0,16),UDim2.fromOffset(36,36),panel)
label("Banner",main,"VISTA PREVIA · COMPRAS ROBUX DESHABILITADAS",UDim2.new(0,18,0,72),UDim2.new(1,-36,0,40),cyan,12)
local tabs=make("Frame","Tabs",main,{Position=UDim2.new(0,18,0,118),Size=UDim2.new(1,-36,0,40),BackgroundTransparency=1})
for i,row in ipairs({{"Coins","C  COINS"},{"Combos","★  COMBOS"},{"PremiumCrates","▣  CAJAS PREMIUM"}})do
 button(row[1],tabs,row[2],UDim2.new((i-1)/3,2,0,0),UDim2.new(1/3,-6,1,0))
end
local catalog=make("ScrollingFrame","Catalog",main,{Position=UDim2.new(0,16,0,174),Size=UDim2.new(1,-32,1,-190),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=violet,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
make("UIGridLayout","UIGridLayout",catalog,{CellSize=UDim2.new(.49,-6,0,224),CellPadding=UDim2.fromOffset(10,12),SortOrder=Enum.SortOrder.LayoutOrder})
make("UIPadding","Padding",catalog,{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,2),PaddingRight=UDim.new(0,2),PaddingBottom=UDim.new(0,8)})
local card=button("ProductCardTemplate",catalog,"",UDim2.new(),UDim2.new(.49,0,0,224),panel);card.Visible=false;card.ClipsDescendants=true
make("UIGradient","Accent",card,{Color=ColorSequence.new(Color3.fromRGB(46,34,88),panel),Rotation=30})
local view=make("ViewportFrame","Preview",card,{Position=UDim2.new(0,8,0,8),Size=UDim2.new(.34,-8,0,130),BackgroundTransparency=1,Ambient=Color3.fromRGB(180,180,210),LightColor=white,LightDirection=Vector3.new(-1,-1,-1)})
make("WorldModel","WorldModel",view);local cam=make("Camera","PreviewCamera",view,{FieldOfView=35});view.CurrentCamera=cam
label("Title",card,"Producto Premium",UDim2.new(.34,8,0,16),UDim2.new(.66,-24,0,38),gold,18)
label("Description",card,"Descripción editable del producto.",UDim2.new(.34,8,0,58),UDim2.new(.66,-24,0,66),white,13)
label("Content",card,"CONTENIDO PENDIENTE",UDim2.new(0,14,0,138),UDim2.new(1,-28,0,22),cyan,12)
label("Price",card,"ROBUX · SIN CONFIGURAR",UDim2.new(0,14,0,166),UDim2.new(1,-28,0,22),gold,14)
label("Status",card,"Venta no habilitada",UDim2.new(0,14,0,192),UDim2.new(1,-28,0,24),Color3.fromRGB(177,185,212),11)
card.Status.Position=UDim2.new(0,14,1,-38);card.Status.Size=UDim2.new(1,-166,0,28)
local cardBuy=button("Buy",card,"COMPRAR · BLOQUEADO",UDim2.new(1,-146,1,-38),UDim2.fromOffset(132,28),Color3.fromRGB(91,58,157));cardBuy.Active=false;cardBuy.AutoButtonColor=false;cardBuy.TextSize=10
label("Empty",main,"No hay productos configurados en esta categoría.",UDim2.new(.1,0,.48,0),UDim2.new(.8,0,0,60),white,16).Visible=false
local detail=make("Frame","Details",main,{Position=UDim2.new(0,10,0,112),Size=UDim2.new(1,-20,1,-122),BackgroundColor3=navy,BorderSizePixel=0,Visible=false,ZIndex=5});corner(detail,14);stroke(detail,gold)
label("Title",detail,"DETALLES",UDim2.new(0,18,0,12),UDim2.new(1,-80,0,44),gold,22)
button("Close",detail,"×",UDim2.new(1,-50,0,12),UDim2.fromOffset(34,34))
local scroll=make("ScrollingFrame","Scroll",detail,{Position=UDim2.new(0,18,0,64),Size=UDim2.new(1,-36,1,-212),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()})
local text=label("Content",scroll,"Contenidos pendientes",UDim2.new(),UDim2.new(1,-10,0,0),white,15);text.AutomaticSize=Enum.AutomaticSize.Y;text.TextYAlignment=Enum.TextYAlignment.Top
label("Status",detail,"Compra no habilitada",UDim2.new(0,18,1,-142),UDim2.new(1,-36,0,34),cyan,12)
button("ViewCrate",detail,"VER INVENTARIO / APERTURA",UDim2.new(0,18,1,-102),UDim2.new(1,-36,0,36),panel)
local buy=button("Buy",detail,"COMPRAR · SIN CONFIGURAR",UDim2.new(0,18,1,-58),UDim2.new(1,-36,0,42),Color3.fromRGB(91,58,157));buy.Active=false;buy.AutoButtonColor=false
for _,n in ipairs(detail:GetDescendants())do if n:IsA("GuiObject")then n.ZIndex=if n:IsA("GuiButton")then 7 else 6 end end
main.BackgroundColor3=Color3.new(1,1,1);card.BackgroundColor3=Color3.new(1,1,1)
hud.Parent=game.StarterGui
local open=button("PremiumShopButton",game.StarterGui.PlayerHUD,"TIENDA PREMIUM",UDim2.new(1,-18,.5,0),UDim2.fromOffset(154,48),Color3.fromRGB(69,39,128));open.AnchorPoint=Vector2.new(1,.5);open.TextColor3=gold;open.ZIndex=10
make("UIGradient","Glow",open,{Color=ColorSequence.new(Color3.fromRGB(146,76,238),Color3.fromRGB(62,38,112)),Rotation=30})
open.BackgroundColor3=Color3.new(1,1,1)
-- Provisional native models, no scripts, IDs, physics or commercial odds.
local previews=make("Folder","PremiumShopPreviews",RS)
local function part(name,model,size,pose,color,material)
 local n=make("Part",name,model,{Size=size,CFrame=pose,Color=color,Material=material or Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false});return n
end
local function crate(id,color)
 assert(not RS.CrateEffects:FindFirstChild(id),"Model already exists")
 local model=make("Model",id,nil);local body=part("Body",model,Vector3.new(2.2,1.7,1.8),CFrame.new(),color)
 model.PrimaryPart=body;part("Lid",model,Vector3.new(2.35,.3,1.95),CFrame.new(0,1,0),gold,Enum.Material.Metal)
 for _,x in ipairs({-.8,.8})do part("Band_"..tostring(x),model,Vector3.new(.12,2,1.85),CFrame.new(x,.1,0),gold,Enum.Material.Metal)end
 part("Seal",model,Vector3.new(.5,.5,.12),CFrame.new(0,.3,-.96),cyan,Enum.Material.Neon)
 local attachment=make("Attachment","PremiumFX",body)
 local emitter=RS.UIAssets.CrateRevealV25.RewardEffects.Anchor.RewardGlowParticles:Clone()
 emitter.Name="PremiumSparkles";emitter.Color=ColorSequence.new(color);emitter.Enabled=false;emitter.Rate=0
 emitter:SetAttribute("OpeningStages","Appear,Growth,Flash");emitter:SetAttribute("BurstCount",4);emitter.Parent=attachment
 model:SetAttribute("ArtStatus","Provisional");model.Parent=RS.CrateEffects
 local preview=model:Clone();preview.Parent=previews
end
crate("PremiumI",Color3.fromRGB(100,55,170));crate("PremiumII",Color3.fromRGB(35,88,160));crate("PremiumIII",Color3.fromRGB(154,48,113))
local combo=previews.PremiumIII:Clone();combo.Name="ComboDisplay";combo.Parent=previews
local coins=make("Model","CoinsDisplay",previews)
for i=1,5 do local p=part("Coin_"..i,coins,Vector3.new(.18,1.5,1.5),CFrame.new(0,i*.22,0)*CFrame.Angles(0,0,math.pi/2),gold,Enum.Material.Metal);p.Shape=Enum.PartType.Cylinder;if i==1 then coins.PrimaryPart=p end end
local shops=workspace:FindFirstChild("Shops")or make("Folder","Shops",workspace);assert(not shops:FindFirstChild("CoinShop"))
local shop=make("Model","CoinShop",nil);local stand=workspace.CrateStands.MainCrateStand
local origin=stand.InteractionPart.CFrame*CFrame.new(-14,0,0)
shop.PrimaryPart=part("Base",shop,Vector3.new(7,.5,5),origin*CFrame.new(0,-3,0),navy)
part("Counter",shop,Vector3.new(6,2,2.4),origin*CFrame.new(0,-1.8,0),panel)
local interaction=part("InteractionPart",shop,Vector3.new(1,1,1),origin,gold);interaction.Transparency=1
make("ProximityPrompt","ProximityPrompt",interaction,{ActionText="Abrir tienda Coins",ObjectText="COIN SHOP",MaxActivationDistance=12,HoldDuration=0,RequiresLineOfSight=false})
local sign=part("Sign",shop,Vector3.new(6,1.6,.3),origin*CFrame.new(0,2,0),violet)
local bill=make("BillboardGui","BillboardGui",sign,{Size=UDim2.fromOffset(240,64),StudsOffset=Vector3.new(0,.3,0),Adornee=sign,AlwaysOnTop=false,MaxDistance=70})
local title=label("Title",bill,"TIENDA COINS",UDim2.new(),UDim2.fromScale(1,1),gold,24);title.TextXAlignment=Enum.TextXAlignment.Center
shop:SetAttribute("ArtStatus","Provisional");shop.Parent=shops
-- Hide only the superseded normal-HUD entry; keep its art and descendants.
local old=game.StarterGui.ShopHUD:FindFirstChild("ShopButton");if old then old.Visible=false end
return {HUDDescendants=#hud:GetDescendants(),Shop=shop:GetFullName(),PreviewModels=#previews:GetChildren(),Button=open:GetFullName()}
