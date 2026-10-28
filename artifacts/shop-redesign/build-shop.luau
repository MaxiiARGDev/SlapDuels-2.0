
local hud=game.StarterGui.ShopHUD
assert(not hud.MainFrame:GetAttribute("NeonShopV2"),"Already redesigned")
local old=hud.MainFrame
local backupFolder=game.ServerStorage:FindFirstChild("UIBackups") or Instance.new("Folder",game.ServerStorage)
backupFolder.Name="UIBackups"
local backup=old:Clone();backup.Name="ShopHUD_MainFrame_Backup_"..os.date("%Y%m%d_%H%M%S");backup.Parent=backupFolder
local m=old:Clone();m.Name="MainFrame"
local C=Color3.fromRGB
local function make(class,name,parent,p)
 local x=Instance.new(class);x.Name=name;for k,v in pairs(p or {}) do x[k]=v end;x.Parent=parent;return x
end
local function corner(x,r)
 local q=x:FindFirstChildOfClass("UICorner") or make("UICorner","UICorner",x);q.CornerRadius=UDim.new(0,r)
end
local function gradient(x,a,b)
 for _,v in x:GetChildren() do if v:IsA("UIGradient") then v:Destroy() end end
 return make("UIGradient","V2Gradient",x,{Color=ColorSequence.new(a,b),Rotation=90})
end
local function border(x,c,w)
 local st=x:FindFirstChildOfClass("UIStroke") or make("UIStroke","V2Border",x)
 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Color=c;st.Thickness=w or 1.5;st.Transparency=0
 for _,v in st:GetChildren() do if v:IsA("UIGradient") then v:Destroy() end end
 return st
end
local function rect(n,p,pos,size,col,z,alpha)
 return make("Frame",n,p,{Position=pos,Size=size,BackgroundColor3=col,BackgroundTransparency=alpha or 0,BorderSizePixel=0,ZIndex=z or p.ZIndex,Active=false})
end
local function text(n,p,t,pos,size,color,sz)
 return make("TextLabel",n,p,{Text=t,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=color,Font=Enum.Font.GothamBold,TextSize=sz,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=p.ZIndex+3})
end
-- Editable procedural halftone: no external asset dependency.
local function dots(p,cols,rows,z)
 local f=rect("V2Halftone",p,UDim2.fromScale(0,0),UDim2.fromScale(1,1),C(255,255,255),z,1)
 f.ClipsDescendants=true
 for y=1,rows do for x=1,cols do
 local d=rect("Dot",f,UDim2.fromScale((x-.5)/cols,(y-.5)/rows),UDim2.fromOffset(3,3),C(170,220,255),z,.86+(y/rows)*.1)
 corner(d,9)
 end end
end
local function panel(p,a,b,stroke)
 p.BorderSizePixel=0;p.BackgroundTransparency=0;p.BackgroundColor3=C(255,255,255)
 gradient(p,a,b);corner(p,12);border(p,stroke or C(74,102,170),1.5)
end
for _,v in m:GetDescendants() do
 if v:IsA("GuiObject") then v.BorderSizePixel=0 end
 if v:IsA("TextLabel") or v:IsA("TextButton") then v.Font=Enum.Font.GothamBold end
end
if m:FindFirstChild("DecorLayer") then m.DecorLayer:Destroy() end
m:SetAttribute("NeonShopV2",true)
m:SetAttribute("SelectedStrokeColor",C(104,244,255))
m.AnchorPoint=Vector2.new(.5,.5);m.Position=UDim2.fromScale(.5,.52);m.Size=UDim2.fromScale(.86,.85)
m.ClipsDescendants=false
panel(m,C(25,35,75),C(12,17,39),C(100,128,229))
local bounds=m:FindFirstChildOfClass("UISizeConstraint");if bounds then bounds.MinSize=Vector2.new(0,0);bounds.MaxSize=Vector2.new(1250,820) end
local shadow=rect("V2Depth",m,UDim2.fromOffset(0,9),UDim2.fromScale(1,1),C(4,8,22),m.ZIndex-2,.15);corner(shadow,14)
local glow=border(shadow,C(67,82,185),5);glow.Transparency=.6
local h=m.Header;h.Size=UDim2.new(1,0,0,78);panel(h,C(52,135,244),C(47,55,157),C(111,200,255))
dots(h,42,4,h.ZIndex+1)
h.Divider.BackgroundColor3=C(99,234,255);h.Divider.Size=UDim2.new(1,-24,0,2);h.Divider.Position=UDim2.new(0,12,1,-2)
h.DividerGlow.Visible=false
local plate=h.TitlePlate;plate.BackgroundTransparency=1;plate.Position=UDim2.fromOffset(18,10);plate.Size=UDim2.fromOffset(260,58)
for _,v in plate:GetChildren() do if v:IsA("UIStroke") or v:IsA("UIGradient") or v.Name=="Shine" then v:Destroy() end end
plate.PlateIcon.Size=UDim2.fromOffset(51,51);plate.PlateIcon.Position=UDim2.fromOffset(0,0)
local title=plate.TitleLabel;title.Text="TIENDA";title.Position=UDim2.fromOffset(60,0);title.Size=UDim2.new(1,-60,0,35);title.TextSize=30;title.TextScaled=false;title.TextXAlignment=Enum.TextXAlignment.Left;title.TextColor3=C(255,255,255)
for _,v in title:GetChildren() do if v:IsA("UIGradient") then v:Destroy() end end
text("V2Subtitle",plate,"TU ESTILO. TU VICTORIA.",UDim2.fromOffset(62,36),UDim2.fromOffset(200,16),C(189,227,255),10)
local coins=h.CoinsContainer;coins.AnchorPoint=Vector2.new(1,.5);coins.Position=UDim2.new(1,-78,.5,0);coins.Size=UDim2.fromOffset(158,38)
panel(coins,C(67,49,35),C(36,27,40),C(255,195,71));coins.CoinsLabel.TextColor3=C(255,222,118)
local close=h.CloseButton;close.AnchorPoint=Vector2.new(1,.5);close.Position=UDim2.new(1,-16,.5,0);close.Size=UDim2.fromOffset(44,44);close.Image="";close.ZIndex=26
panel(close,C(255,112,151),C(195,43,91),C(255,164,187))
local cross=text("V2CloseGlyph",close,"×",UDim2.fromScale(0,0),UDim2.fromScale(1,1),C(255,255,255),34);cross.TextXAlignment=Enum.TextXAlignment.Center
local tabs=m.Tabs;tabs.Position=UDim2.fromOffset(14,94);tabs.Size=UDim2.new(0,112,1,-130);panel(tabs,C(18,26,59),C(16,21,48),C(44,60,106))
tabs:SetAttribute("ActiveColor",C(52,132,233));tabs.ScrollBarThickness=2;tabs.AutomaticCanvasSize=Enum.AutomaticSize.Y
local tl=tabs:FindFirstChildOfClass("UIListLayout");tl.Padding=UDim.new(0,9)
local tp=tabs:FindFirstChildOfClass("UIPadding");tp.PaddingTop=UDim.new(0,8);tp.PaddingBottom=UDim.new(0,8);tp.PaddingLeft=UDim.new(0,8);tp.PaddingRight=UDim.new(0,8)
local accents={PointEffectsTab=C(57,195,255),SlapsTab=C(255,192,76),TrailsTab=C(157,114,255),DeathEffectsTab=C(255,107,157),AbilitiesTab=C(70,232,184),CratesTab=C(255,171,62)}
for _,b in tabs:GetChildren() do if b:IsA("GuiButton") then
 b.Size=UDim2.new(1,0,0,68);b.BackgroundColor3=C(39,49,91);b.BackgroundTransparency=0;b.ZIndex=23
 gradient(b,C(255,255,255),C(165,177,219));corner(b,9);border(b,accents[b.Name] or C(120,160,240),1)
 local sc=b:FindFirstChildOfClass("UISizeConstraint");if sc then sc.MinSize=Vector2.zero;sc.MaxSize=Vector2.new(9999,9999) end
 for _,v in b:GetChildren() do
 if v:IsA("ImageLabel") then v.AnchorPoint=Vector2.new(.5,0);v.Position=UDim2.new(.5,0,0,3);v.Size=UDim2.fromOffset(36,36);v.ZIndex=25
 elseif v:IsA("TextLabel") and v.Name~="SoonBadge" then v.Position=UDim2.new(0,2,0,42);v.Size=UDim2.new(1,-4,0,21);v.TextScaled=true;v.TextColor3=C(240,246,255);v.ZIndex=26 end
 end
end end
local body=m.Body;body.Position=UDim2.fromOffset(142,110);body.Size=UDim2.new(1,-160,1,-148);body.BackgroundTransparency=1
local bp=body:FindFirstChildOfClass("UIPadding");if bp then bp:Destroy() end
text("V2CollectionTitle",m,"COLECCIÓN",UDim2.fromOffset(146,87),UDim2.fromOffset(180,20),C(163,185,237),11)
local cat=body.Catalog;cat.Position=UDim2.fromOffset(0,0);cat.Size=UDim2.new(.64,-10,1,0);cat.BackgroundTransparency=1;cat.ScrollBarThickness=4;cat.ScrollBarImageColor3=C(102,164,255)
cat.AutomaticCanvasSize=Enum.AutomaticSize.Y;cat.CanvasSize=UDim2.new()
local grid=cat:FindFirstChildOfClass("UIGridLayout");grid.CellSize=UDim2.new(.5,-10,0,214);grid.CellPadding=UDim2.fromOffset(12,12)
local cp=cat:FindFirstChildOfClass("UIPadding");cp.PaddingTop=UDim.new(0,3);cp.PaddingLeft=UDim.new(0,3);cp.PaddingRight=UDim.new(0,5);cp.PaddingBottom=UDim.new(0,8)
local card=cat.ProductCardTemplate;panel(card,C(42,61,111),C(26,32,68),C(84,105,166))
card.ClipsDescendants=true
card.Preview.Position=UDim2.fromOffset(8,10);card.Preview.Size=UDim2.new(1,-16,0,108);card.Preview.ClipsDescendants=true
panel(card.Preview,C(47,71,140),C(25,30,73),C(80,114,178));dots(card.Preview,10,6,card.Preview.ZIndex)
card.NameLabel.Position=UDim2.fromOffset(10,122);card.NameLabel.Size=UDim2.new(1,-20,0,23);card.NameLabel.TextColor3=C(245,248,255)
card.RarityLabel.Position=UDim2.fromOffset(10,148);card.RarityLabel.Size=UDim2.new(1,-20,0,16)
card.PriceLabel.Position=UDim2.new(0,10,1,-39);card.PriceLabel.Size=UDim2.new(1,-20,0,29);panel(card.PriceLabel,C(64,53,32),C(38,33,37),C(154,119,58));card.PriceLabel.TextColor3=C(255,221,114)
card.CoinIcon.Position=UDim2.new(0,17,1,-34);card.CoinIcon.ZIndex=card.PriceLabel.ZIndex+1
card.CardAccent.BackgroundColor3=C(97,219,255);card.CardAccent.Size=UDim2.new(1,-28,0,3)
local d=body.DetailPanel;d.AnchorPoint=Vector2.new(1,0);d.Position=UDim2.fromScale(1,0);d.Size=UDim2.new(.36,-4,1,0)
panel(d,C(43,42,96),C(22,24,54),C(129,105,219))
for _,v in d:GetChildren() do if v:IsA("UIListLayout") or v:IsA("UIPadding") then v:Destroy() end end
local function place(x,y,ht) x.Position=UDim2.new(0,12,y,0);x.Size=UDim2.new(1,-24,ht,0) end
place(d.Preview,.025,.31);d.Preview.ClipsDescendants=true;panel(d.Preview,C(80,61,148),C(32,35,81),C(131,108,210));dots(d.Preview,13,7,d.Preview.ZIndex)
place(d.NameLabel,.36,.085);d.NameLabel.TextScaled=true;d.NameLabel.TextWrapped=true;d.NameLabel.TextColor3=C(247,242,255)
place(d.RarityLabel,.445,.045)
place(d.DescriptionLabel,.51,.13);d.DescriptionLabel.TextWrapped=true;d.DescriptionLabel.TextScaled=true;d.DescriptionLabel.TextColor3=C(190,203,233)
place(d.PriceRow,.66,.075);panel(d.PriceRow,C(53,44,40),C(31,29,43),C(130,102,62));d.PriceRow.PriceLabel.TextColor3=C(255,223,123)
place(d.StatusLabel,.745,.045);d.StatusLabel.TextScaled=true
place(d.ActionButton,.805,.095);panel(d.ActionButton,C(255,255,255),C(172,210,201),C(136,255,211));d.ActionButton.BackgroundColor3=C(54,222,154);d.ActionButton.TextColor3=C(255,255,255);d.ActionButton.TextScaled=true
d.ActionButton:SetAttribute("Color_Buy",C(40,213,154));d.ActionButton:SetAttribute("Color_Equip",C(41,164,246));d.ActionButton:SetAttribute("Color_Disabled",C(82,91,120));d.ActionButton:SetAttribute("UIEffectsBound",true)
place(d.SecondaryButton,.92,.055);panel(d.SecondaryButton,C(66,64,110),C(37,37,74),C(103,101,155));d.SecondaryButton.TextScaled=true
for _,v in {body.EmptyState,body.LoadingLabel} do v.Size=cat.Size;v.Position=cat.Position end
m.MessageLabel.Position=UDim2.new(0,145,1,-28);m.MessageLabel.Size=UDim2.new(1,-164,0,20);m.MessageLabel.TextSize=12
for _,p in {card.Preview,d.Preview} do for _,v in p:GetChildren() do if v:IsA("Frame") and v.Name:match("^Spot") then v.BackgroundTransparency=.94;v.ZIndex=p.ZIndex end end end
m.Parent=hud;old:Destroy()
game:GetService("Selection"):Set({m})
print("Created active MainFrame; original backup: "..backup:GetFullName())


local m=game.StarterGui.ShopHUD.MainFrame
local price=m.Body.Catalog.ProductCardTemplate.PriceLabel
price.BackgroundColor3=Color3.fromRGB(54,43,32)
price.V2Gradient.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(222,224,230))
price.TextStroke.Thickness=1;price.TextStroke.Transparency=.4
local d=m.Body.DetailPanel
for _,v in {d.NameLabel,d.DescriptionLabel,d.StatusLabel,d.ActionButton,d.SecondaryButton} do
 local c=v:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint",v)
 c.MinTextSize=9;c.MaxTextSize=(v==d.NameLabel and 24) or (v==d.ActionButton and 21) or (v==d.DescriptionLabel and 15) or 14
end
m.OpenScale.Scale=1;m.Visible=true

local motion=Instance.new("LocalScript");motion.Name="NeonShopMotion";motion.Source=[====[
-- Cosmetic behavior only: purchasing remains owned by ShopController.
local Tween=game:GetService("TweenService")
local main=script.Parent
local catalog=main.Body.Catalog
local connections={}
local bound=setmetatable({},{__mode="k"})
local function connect(signal,fn) local c=signal:Connect(fn);table.insert(connections,c);return c end
local function tween(x,time,properties)
 local t=Tween:Create(x,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties);t:Play();return t
end
local function bind(button)
 if not button:IsA("GuiButton") or bound[button] then return end
 if button.Name~="ActionButton" and button.Name~="Action" and button.Name~="Buy" then return end
 bound[button]=true
 local owned={}
 local function connect(signal,fn) local c=signal:Connect(fn);table.insert(owned,c);return c end
 button.Destroying:Once(function() for _,c in owned do c:Disconnect() end end)
 local shine=Instance.new("Frame");shine.Name="V2Shine";shine.Size=UDim2.fromScale(1,1);shine.BackgroundColor3=Color3.new(1,1,1);shine.BackgroundTransparency=.67;shine.BorderSizePixel=0;shine.ZIndex=button.ZIndex+1;shine.Active=false
 local c=Instance.new("UICorner",shine);c.CornerRadius=UDim.new(0,10)
 local g=Instance.new("UIGradient",shine);g.Rotation=25;g.Offset=Vector2.new(-1.5,0);g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.38,1),NumberSequenceKeypoint.new(.5,.15),NumberSequenceKeypoint.new(.62,1),NumberSequenceKeypoint.new(1,1)})
 shine.Parent=button
 local stroke=button:FindFirstChildOfClass("UIStroke")
 local base=stroke and stroke.Thickness or 1.5
 local sweep
 local function glint()
  if not button.Active or not main.Visible then return end
  if sweep then sweep:Cancel() end
  g.Offset=Vector2.new(-1.5,0)
  sweep=tween(g,.65,{Offset=Vector2.new(1.5,0)})
 end
 connect(button.MouseEnter,function() glint();if stroke and button.Active then tween(stroke,.15,{Thickness=base+1}) end end)
 connect(button.MouseLeave,function() if stroke then tween(stroke,.15,{Thickness=base}) end end)
 local scale=Instance.new("UIScale");scale.Name="V2PressScale";scale.Parent=button
 local motion
 local function press(value) if motion then motion:Cancel() end;motion=tween(scale,.1,{Scale=value}) end
 connect(button.InputBegan,function(input) if button.Active and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA) then press(.975) end end)
 connect(button.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA then press(1) end end)
 connect(button.MouseLeave,function() press(1) end)
 connect(button:GetPropertyChangedSignal("Active"),function() if not button.Active then press(1);if stroke then stroke.Thickness=base end end end)
 connect(button.Activated,glint)
end
for _,v in main:GetDescendants() do bind(v) end
connect(main.DescendantAdded,bind)
local function layout()
 local narrow=main.AbsoluteSize.X<760
 local side=narrow and 82 or 112
 main.Tabs.Size=UDim2.new(0,side,1,-130)
 main.Body.Position=UDim2.fromOffset(side+30,110)
 main.Body.Size=UDim2.new(1,-side-48,1,-148)
 main.V2CollectionTitle.Position=UDim2.fromOffset(side+34,87)
 local grid=catalog.UIGridLayout
 grid.CellSize=UDim2.new(narrow and 1 or .5,narrow and -12 or -10,0,214)
 main.Header.TitlePlate.Size=UDim2.fromOffset(narrow and 180 or 260,58)
 main.Header.TitlePlate.TitleLabel.TextSize=narrow and 24 or 30
 main.Header.TitlePlate.V2Subtitle.Visible=not narrow
 main.Header.CoinsContainer.Size=UDim2.fromOffset(narrow and 112 or 158,38)
end
connect(main:GetPropertyChangedSignal("AbsoluteSize"),layout);layout()
connect(script.Destroying,function() for _,c in connections do c:Disconnect() end end)

-- A category illustration is shown only when the catalog has no product artwork.
local function decoratePreview(preview)
 if not preview:IsA("Frame") or preview.Name~="Preview" or preview:FindFirstChild("V2CategoryArt") then return end
 if preview.Parent.Name=="ProductCardTemplate" then return end
 local label=preview:FindFirstChild("PreviewLabel")
 local original=preview:FindFirstChild("PreviewIcon")
 if not label or not original then return end
 local art=Instance.new("ImageLabel");art.Name="V2CategoryArt";art.BackgroundTransparency=1;art.AnchorPoint=Vector2.new(.5,.5);art.Position=UDim2.fromScale(.5,.5);art.Size=UDim2.fromScale(.68,.68);art.ScaleType=Enum.ScaleType.Fit;art.ZIndex=preview.ZIndex+1;art.Parent=preview
 local function refresh()
  art.Visible=not(original.Visible and original.Image~="") and not(label.Visible and label.Text~="")
  for _,v in preview:GetChildren() do if v:IsA("ViewportFrame") and v.Visible then art.Visible=false end end
  for _,tab in main.Tabs:GetChildren() do
   if tab:IsA("GuiButton") and tab.BackgroundColor3==main.Tabs:GetAttribute("ActiveColor") then
    local icon=tab:FindFirstChild("IconImage");if icon then art.Image=icon.Image end
   end
  end
 end
 local owned={}
 table.insert(owned,preview.ChildAdded:Connect(refresh))
 table.insert(owned,preview.ChildRemoved:Connect(refresh))
 for _,sig in {original:GetPropertyChangedSignal("Visible"),original:GetPropertyChangedSignal("Image"),label:GetPropertyChangedSignal("Visible"),label:GetPropertyChangedSignal("Text")} do table.insert(owned,sig:Connect(refresh)) end
 for _,tab in main.Tabs:GetChildren() do if tab:IsA("GuiButton") then table.insert(owned,tab:GetPropertyChangedSignal("BackgroundColor3"):Connect(refresh)) end end
 preview.Destroying:Once(function() for _,c in owned do c:Disconnect() end end)
 refresh()
end
for _,v in main:GetDescendants() do decoratePreview(v) end
connect(main.DescendantAdded,decoratePreview)
]====];motion.Parent=game.StarterGui.ShopHUD.MainFrame

