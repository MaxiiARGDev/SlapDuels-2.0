--!nonstrict
-- Editable Studio UI; Build is also a fallback for fresh Rojo installs.
local View={}
local C=Color3.fromRGB
local icons={Slaps='rbxassetid://134866490325088',DeathEffects='rbxassetid://84058950298471',PointEffects='rbxassetid://123068502871010',Crates='rbxassetid://88695662177399'}
local function make(class,name,parent,props)
 local x=Instance.new(class);x.Name=name;for k,v in pairs(props or {})do x[k]=v end;x.Parent=parent;return x
end
local function round(p,r)make('UICorner','Corner',p,{CornerRadius=UDim.new(0,r or 12)})end
local function stroke(p,c,w,a)return make('UIStroke','Stroke',p,{Color=c,Thickness=w or 1,Transparency=a or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})end
local function frame(name,p,pos,size,color,alpha)
 return make('Frame',name,p,{Position=pos,Size=size,BackgroundColor3=color or C(17,26,32),BackgroundTransparency=alpha or 0,BorderSizePixel=0})
end
local function label(name,p,t,pos,size,sz,col)
 return make('TextLabel',name,p,{Text=t,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=col or C(238,246,244),TextSize=sz or 16,Font=Enum.Font.GothamBold,TextWrapped=true})
end
local function button(name,p,t,pos,size)
 local b=make('TextButton',name,p,{Text=t,Position=pos,Size=size,BackgroundColor3=C(41,217,82),TextColor3=C(255,255,255),TextSize=18,Font=Enum.Font.GothamBold,BorderSizePixel=0,AutoButtonColor=false})
 round(b,10);stroke(b,C(114,255,146),1,.25)
 make('UIGradient','Gloss',b,{Color=ColorSequence.new(C(255,255,255),C(185,222,195)),Rotation=90})
 return b
end
local function image(name,p,id,pos,size)
 return make('ImageLabel',name,p,{Image=id,Position=pos,Size=size,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit})
end
local function preview(name,p,pos,size)
 return make('ViewportFrame',name,p,{Position=pos,Size=size,BackgroundTransparency=1,Ambient=C(210,215,230),LightColor=C(255,247,228),LightDirection=Vector3.new(-1,-1,-1)})
end
function View.Build(parent)
 if parent:FindFirstChild('InventoryHUD')then return parent.InventoryHUD end
 local hud=make('ScreenGui','InventoryHUD',parent,{Enabled=false,ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=65,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 frame('Dim',hud,UDim2.fromScale(0,0),UDim2.fromScale(1,1),C(1,8,13),.38)
 local m=frame('MainFrame',hud,UDim2.fromScale(.5,.51),UDim2.fromScale(.91,.88),C(22,29,39),.04);m.AnchorPoint=Vector2.new(.5,.5)
 round(m,16);stroke(m,C(124,150,160),1,.25)
 make('UISizeConstraint','Bounds',m,{MaxSize=Vector2.new(1280,860),MinSize=Vector2.zero})
 make('UIScale','OpenScale',m,{Scale=1})
 make('UIGradient','Atmosphere',m,{Color=ColorSequence.new(C(209,225,241),C(74,89,103)),Rotation=35})
 local tabs=frame('Tabs',m,UDim2.fromOffset(0,0),UDim2.new(0,112,1,0),C(15,24,33),.08);round(tabs,14)
 local names={Slaps='SLAPS',DeathEffects='KILL EFFECT',PointEffects='POINT EFFECT',Crates='CAJAS'}
 for i,key in ipairs({'Slaps','DeathEffects','PointEffects','Crates'})do
  local b=button(key,tabs,'',UDim2.new(0,8,0,16+(i-1)*112),UDim2.new(1,-16,0,100));b.BackgroundColor3=C(28,43,53)
  image('Icon',b,icons[key],UDim2.fromScale(.2,.07),UDim2.fromScale(.6,.57))
  label('Label',b,names[key],UDim2.fromScale(.03,.68),UDim2.fromScale(.94,.26),12)
 end
 local head=frame('Header',m,UDim2.fromOffset(130,12),UDim2.new(1,-146,0,54),nil,1)
 local title=label('Title',head,'INVENTARIO',UDim2.fromOffset(0,0),UDim2.fromOffset(185,24),20);title.TextXAlignment=Enum.TextXAlignment.Left
 local sub=label('Subtitle',head,'TUS OBJETOS · TU ESTILO',UDim2.fromOffset(0,28),UDim2.fromOffset(185,18),10,C(152,177,183));sub.TextXAlignment=Enum.TextXAlignment.Left
 local search=make('TextBox','Search',head,{Position=UDim2.fromOffset(196,3),Size=UDim2.new(1,-254,0,44),BackgroundColor3=C(9,17,21),BackgroundTransparency=.1,BorderSizePixel=0,Text='',PlaceholderText='Buscar en tu inventario…',TextColor3=C(244,250,247),PlaceholderColor3=C(150,170,173),TextSize=16,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false})
 round(search,22);stroke(search,C(91,117,122),1,.3);make('UIPadding','Padding',search,{PaddingLeft=UDim.new(0,18),PaddingRight=UDim.new(0,18)})
 local close=button('Close',head,'×',UDim2.new(1,-44,0,3),UDim2.fromOffset(44,44));close.BackgroundColor3=C(249,65,91);close.TextSize=32
 local content=frame('Content',m,UDim2.fromOffset(130,80),UDim2.new(1,-146,1,-96),nil,1)
 local grid=make('ScrollingFrame','Grid',content,{Size=UDim2.new(.67,-14,1,-108),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C(82,214,125),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y})
 make('UIGridLayout','Layout',grid,{CellSize=UDim2.new(1/3,-9,0,180),CellPadding=UDim2.fromOffset(10,12),SortOrder=Enum.SortOrder.LayoutOrder})
 make('UIPadding','Padding',grid,{PaddingLeft=UDim.new(0,3),PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,5)})
 local empty=label('Empty',content,'Cargando inventario…',UDim2.fromScale(.03,.18),UDim2.fromScale(.6,.32),20,C(208,223,224))
 local footer=frame('Footer',content,UDim2.new(0,0,1,-100),UDim2.new(.67,-14,0,100),nil,1)
 local prev=button('Previous',footer,'‹',UDim2.fromOffset(0,0),UDim2.fromOffset(34,30));prev.BackgroundColor3=C(47,65,71)
 label('Page',footer,'1 / 1',UDim2.new(.5,-55,0,0),UDim2.fromOffset(110,30),12,C(178,200,203))
 local nextButton=button('Next',footer,'›',UDim2.new(1,-34,0,0),UDim2.fromOffset(34,30));nextButton.BackgroundColor3=C(47,65,71)
 local more=button('More',footer,'VER MIS CAJAS',UDim2.new(.5,-100,0,40),UDim2.fromOffset(200,38));more.TextSize=14
 label('Status',footer,'',UDim2.new(0,0,0,80),UDim2.new(1,0,0,20),11,C(180,207,204))
 local detail=frame('Detail',content,UDim2.fromScale(.67,0),UDim2.fromScale(.33,1),C(6,15,19),.12);round(detail,14);stroke(detail,C(66,91,94),1,.5)
 label('Title',detail,'Seleccioná un objeto',UDim2.fromScale(.06,.025),UDim2.fromScale(.88,.1),22)
 local aura=frame('Aura',detail,UDim2.fromScale(.05,.15),UDim2.fromScale(.9,.39),C(25,124,61),.55);round(aura,28)
 make('UIGradient','Fade',aura,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.8),NumberSequenceKeypoint.new(.5,.15),NumberSequenceKeypoint.new(1,.95)})})
 preview('Preview',detail,UDim2.fromScale(.05,.13),UDim2.fromScale(.9,.43))
 image('Icon',detail,'',UDim2.fromScale(.2,.2),UDim2.fromScale(.6,.3))
 label('Rarity',detail,'',UDim2.fromScale(.06,.57),UDim2.fromScale(.88,.07),22,C(78,244,101))
 label('Quantity',detail,'',UDim2.fromScale(.06,.65),UDim2.fromScale(.88,.05),14,C(209,223,223))
 label('Description',detail,'Elegí una categoría para ver lo que tenés.',UDim2.fromScale(.07,.72),UDim2.fromScale(.86,.1),13,C(163,190,191))
 local action=button('Action',detail,'EQUIPAR',UDim2.fromScale(.065,.86),UDim2.fromScale(.87,.1));action.Active=false
 local card=button('CardTemplate',hud,'',UDim2.new(),UDim2.fromOffset(170,180));card.Visible=false;card.BackgroundColor3=C(15,22,28);card.Stroke.Color=C(64,85,89);card.Gloss:Destroy()
 local ca=frame('Aura',card,UDim2.fromScale(.03,.03),UDim2.fromScale(.94,.78),C(24,122,57),.4);round(ca,13)
 make('UIGradient','Fade',ca,{Rotation=90,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.9),NumberSequenceKeypoint.new(.5,.1),NumberSequenceKeypoint.new(1,1)})})
 preview('Preview',card,UDim2.fromScale(.03,.02),UDim2.fromScale(.94,.74))
 image('Icon',card,'',UDim2.fromScale(.23,.15),UDim2.fromScale(.54,.48))
 label('ItemName',card,'Objeto',UDim2.fromScale(.04,.76),UDim2.fromScale(.92,.2),14,C(86,246,113))
 local check=label('Equipped',card,'✓',UDim2.fromOffset(7,7),UDim2.fromOffset(25,25),21);check.BackgroundTransparency=0;check.BackgroundColor3=C(24,216,70);round(check,20);check.Visible=false
 local count=label('Count',card,'',UDim2.new(1,-53,0,9),UDim2.fromOffset(45,20),12);count.TextXAlignment=Enum.TextXAlignment.Right
 return hud
end
function View.Button(parent)
 if parent:FindFirstChild('InventoryButton')then return parent.InventoryButton end
 local b=button('InventoryButton',parent,'',UDim2.fromScale(.041,.67),UDim2.fromScale(.062,.104));b.AnchorPoint=Vector2.new(.5,.5);b.BackgroundColor3=C(32,73,69)
 image('IconImage',b,icons.Crates,UDim2.fromScale(.12,.02),UDim2.fromScale(.76,.68))
 local t=label('TextLabel',b,'INVENTARIO',UDim2.fromScale(.01,.64),UDim2.fromScale(.98,.32),11);t.TextScaled=true
 make('UITextSizeConstraint','Bounds',t,{MaxTextSize=12,MinTextSize=8})
 make('UISizeConstraint','Bounds',b,{MinSize=Vector2.new(54,58),MaxSize=Vector2.new(100,104)})
 return b
end
View.Icons=icons
return View
