--!nonstrict
-- Shared Edit/runtime layout. No commerce, networking or gameplay side effects.
local Layout = {}
local function rect(o,x,y,w,h)
 if not o then return end
 o.AnchorPoint=Vector2.zero;o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h)
end
local function text(o,size)
 if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
  o.TextScaled=false;o.TextSize=size;o.TextWrapped=true
 end
end
function Layout.Card(card)
 local preview=card:FindFirstChild("Preview")
 if preview then preview.Position=UDim2.fromOffset(8,8);preview.Size=UDim2.new(1,-16,0,112);preview.ClipsDescendants=true end
 local name=card:FindFirstChild("NameLabel")
 if name then name.Position=UDim2.fromOffset(10,126);name.Size=UDim2.new(1,-20,0,30);text(name,18) end
 local rarity=card:FindFirstChild("RarityLabel")
 if rarity then rarity.Position=UDim2.fromOffset(10,158);rarity.Size=UDim2.new(1,-20,0,20);text(rarity,13) end
 local price=card:FindFirstChild("PriceLabel")
 if price then price.AnchorPoint=Vector2.zero;price.Position=UDim2.new(0,10,1,-40);price.Size=UDim2.new(1,-20,0,30);text(price,18) end
 if card:IsA("TextButton") then card.Text="" end
 for _,o in card:GetChildren() do
  if o:IsA("GuiObject") and (o.Name=="CrateActions" or o.Name=="CoinIcon") then o.Visible=false end
 end
end
function Layout.Prepare(hud)
 local main=hud.MainFrame;local body=main.Body
 local host=body:FindFirstChild("DetailHost")
 if not host then
  host=Instance.new("ScrollingFrame");host.Name="DetailHost";host.BackgroundTransparency=1;host.BorderSizePixel=0
  host.ScrollBarThickness=4;host.ScrollingDirection=Enum.ScrollingDirection.Y;host.CanvasSize=UDim2.new();host.Parent=body
 end
 local detail=body:FindFirstChild("DetailPanel") or host:FindFirstChild("DetailPanel")
 if detail then detail.Parent=host end
 local panel=hud:FindFirstChild("CratePanel") or host:FindFirstChild("CratePanel")
 if panel then
  panel.Parent=host;panel:SetAttribute("EmbeddedShop",true)
  if not panel:FindFirstChild("CrateThumbnail") and detail and detail:FindFirstChild("Preview") then
   local preview=detail.Preview:Clone();preview.Name="CrateThumbnail";preview.Parent=panel
  end
  for _,c in panel:GetChildren() do
   if c:IsA("UIScale") then c.Scale=1 end
   if c:IsA("UIAspectRatioConstraint") or c:IsA("UISizeConstraint") then c:Destroy() end
  end
 end
 local back=body:FindFirstChild("BackToCollection")
 if not back then
  back=Instance.new("TextButton");back.Name="BackToCollection";back.Text="‹ VOLVER A LA COLECCIÓN"
  back.Font=Enum.Font.GothamBold;back.TextSize=14;back.TextColor3=Color3.new(1,1,1)
  back.BackgroundColor3=Color3.fromRGB(38,57,101);back.BorderSizePixel=0;back.Parent=body
  local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,10);corner.Parent=back
 end
 -- ScrollingEnabled alone leaves wheel/touch input disabled when Active is false.
 -- Keep native scrolling so the deepest hovered/touched scroll owns its gesture.
 for _,scroll in {body.Catalog,host,main.Tabs,panel and panel:FindFirstChild("RewardScroll")} do
  if scroll and scroll:IsA("ScrollingFrame")then
   scroll.Active=true
   scroll.ScrollingEnabled=true
  end
 end
 Layout.Card(body.Catalog.ProductCardTemplate)
 return host,detail,panel,back
end
function Layout.Apply(hud,focused)
 local main=hud.MainFrame;local body=main.Body
 local host,detail,panel,back=Layout.Prepare(hud)
 local w,h=main.AbsoluteSize.X,main.AbsoluteSize.Y
 if w<1 or h<1 then return end
 local compact=w<850
 local rail=if compact then 0 else 112
 local top=if compact then 170 else 104
 rect(main.Header,0,0,w,72)
 local header=main.Header
 rect(header.CloseButton,w-54,12,42,42)
 rect(header.CoinsContainer,w-(compact and 166 or 218),16,compact and 100 or 150,36)
 if header:FindFirstChild("TitlePlate")then
  local plate=header.TitlePlate
  rect(plate,12,10,compact and math.max(100,w-190)or 260,54)
  rect(plate.PlateIcon,0,4,compact and 32 or 48,compact and 32 or 48)
  rect(plate.TitleLabel,compact and 38 or 60,2,compact and math.max(62,w-228)or 200,36)
  text(plate.TitleLabel,compact and 20 or 30)
  plate.TitleLabel.TextScaled=compact
  plate.V2Subtitle.Visible=not compact
 end
 for _,o in header:GetChildren() do
  if o:IsA("TextLabel") then
   text(o,if o.Name:lower():find("title") then (compact and 22 or 30) else 11)
   if compact and o.Name:lower():find("subtitle") then o.Visible=false end
  end
 end
 local tabs=main.Tabs;local list=tabs:FindFirstChildOfClass("UIListLayout")
 rect(tabs,12,82,if compact then w-24 else 100,if compact then 76 else h-110)
 if tabs:IsA("ScrollingFrame") then
  tabs.AutomaticCanvasSize=if compact then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
  tabs.ScrollingDirection=if compact then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
  tabs.CanvasSize=UDim2.new()
 end
 if list then
  list.FillDirection=if compact then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
  list.HorizontalAlignment=Enum.HorizontalAlignment.Left;list.VerticalAlignment=Enum.VerticalAlignment.Top
  list.Padding=UDim.new(0,8)
 end
 for _,tab in tabs:GetChildren() do if tab:IsA("GuiButton") then tab.Size=UDim2.fromOffset(88,64) end end
 rect(body,12+rail,top,w-24-rail,math.max(80,h-top-34))
 local bw,bh=w-24-rail,math.max(80,h-top-34)
 if main:FindFirstChild("V2CollectionTitle") then main.V2CollectionTitle.Visible=not compact;rect(main.V2CollectionTitle,12+rail,80,180,20) end
 rect(main.MessageLabel,12,h-28,w-24,24);text(main.MessageLabel,13)
 local detailWidth=if compact then bw else math.max(340,math.floor(bw*.43))
 local catalogWidth=if compact then bw else bw-detailWidth-12
 rect(body.Catalog,0,0,catalogWidth,bh)
 rect(host,if compact then 0 else catalogWidth+12,if compact then 42 else 0,detailWidth,if compact then bh-42 else bh)
 host.Visible=body.Catalog:GetAttribute("HasProducts")==true and (not compact or focused==true)
 body.Catalog.Visible=body.Catalog:GetAttribute("HasProducts")==true and (not compact or not focused)
 back.Visible=compact and focused==true;rect(back,0,0,bw,36)
 for _,name in {"EmptyState","LoadingLabel"} do rect(body:FindFirstChild(name),0,0,catalogWidth,bh) end
 local grid=body.Catalog:FindFirstChildOfClass("UIGridLayout")
 if grid then
  local columns=math.max(1,math.floor(catalogWidth/210))
  grid.CellSize=UDim2.fromOffset(math.floor((catalogWidth-12*(columns-1)-8)/columns),226)
  grid.CellPadding=UDim2.fromOffset(12,12)
 end
 body.Catalog.AutomaticCanvasSize=Enum.AutomaticSize.Y;body.Catalog.CanvasSize=UDim2.new()
 local contentHeight=math.max(500,if compact then bh-42 else bh)
 host.CanvasSize=UDim2.fromOffset(0,contentHeight)
 if detail then rect(detail,0,0,detailWidth-6,contentHeight) end
 if panel then
  local pw=detailWidth-6;rect(panel,0,0,pw,contentHeight)
  for _,name in {"Close","Header","Footer","LeftMask","RightMask","ProbabilityNote"} do local o=panel:FindFirstChild(name);if o then o.Visible=false end end
  rect(panel.CrateThumbnail,12,12,80,88)
  rect(panel.Title,104,12,pw-116,34);text(panel.Title,22)
  rect(panel.Count,104,49,pw-116,22);text(panel.Count,12)
  rect(panel.Price,104,75,pw-116,26);text(panel.Price,18)
  rect(panel.Hint,14,108,pw-28,20);text(panel.Hint,11)
  rect(panel.RewardScroll,12,136,pw-24,contentHeight-300)
  panel.RewardScroll.ClipsDescendants=true
  panel.RewardCard.Size=UDim2.new(0,158,1,-10)
  for _,card in panel.RewardScroll:GetChildren()do if card:IsA("Frame")then card.Size=panel.RewardCard.Size end end
  rect(panel.Status,14,contentHeight-155,pw-28,42);text(panel.Status,13)
  local half=math.floor((pw-36)/2)
  rect(panel.Buy,12,contentHeight-104,half,44);text(panel.Buy,17)
  rect(panel.OpenActions,12,contentHeight-104,pw-24,94)
  panel.OpenActions.BackgroundTransparency=1;panel.OpenActions.Active=false
  for _,o in panel.OpenActions:GetChildren()do if o:IsA("UIListLayout")or o:IsA("UIGridLayout")then o:Destroy()end end
  rect(panel.OpenActions.X1,half+12,0,half,44)
  rect(panel.OpenActions.X5,0,50,half,44)
  rect(panel.OpenActions.X10,half+12,50,half,44)
  for _,b in panel.OpenActions:GetChildren()do text(b,17)end
 end
 return compact
end
return Layout
