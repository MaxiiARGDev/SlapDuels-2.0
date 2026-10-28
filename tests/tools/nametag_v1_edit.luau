assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local scriptObject=workspace.NametagService
local old=scriptObject:FindFirstChild('Nametag')
local tag=Instance.new('BillboardGui');tag.Name='Nametag';tag.Size=UDim2.fromOffset(220,94);tag.StudsOffsetWorldSpace=Vector3.new(0,2.3,0);tag.AlwaysOnTop=false;tag.LightInfluence=0;tag.MaxDistance=75;tag.Enabled=true
local function color(r,g,b)return Color3.fromRGB(r,g,b)end
local function frame(parent,name,x,y,w,h,tint,radius,trans)
 local o=Instance.new('Frame');o.Name=name;o.Position=UDim2.fromScale(x,y);o.Size=UDim2.fromScale(w,h);o.BackgroundColor3=tint or color(255,255,255);o.BackgroundTransparency=trans or 0;o.BorderSizePixel=0;o.Parent=parent
 if radius then local c=Instance.new('UICorner');c.CornerRadius=UDim.new(radius,0);c.Parent=o end
 return o
end
local function text(parent,name,value,x,y,w,h,size,tint)
 local t=Instance.new('TextLabel');t.Name=name;t.Text=value;t.Position=UDim2.fromScale(x,y);t.Size=UDim2.fromScale(w,h);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextColor3=tint or color(247,255,251);t.TextScaled=true;t.TextWrapped=false;t.RichText=false;t.ZIndex=5;t.Parent=parent
 local bound=Instance.new('UITextSizeConstraint');bound.MinTextSize=9;bound.MaxTextSize=size;bound.Parent=t
 local s=Instance.new('UIStroke');s.Name='Outline';s.Color=color(25,52,72);s.Thickness=1.2;s.Transparency=.5;s.Parent=t
 t.TextSize=size;t.TextScaled=true
 return t
end
text(tag,'Level','0',.30,0,.40,.39,34,color(235,255,246))
local identity=frame(tag,'Identity',.29,.43,.50,.50,nil,nil,1)
local name=text(identity,'DisplayName','MaxDev',0,0,1,.54,21);name.TextXAlignment=Enum.TextXAlignment.Left
local user=text(identity,'Username','@MaxiiDJ4K',0,.54,1,.34,13,color(189,217,255));user.TextXAlignment=Enum.TextXAlignment.Left
local trophy=frame(tag,'Trophy',.105,.43,.155,.43,nil,nil,1)
local gold=color(255,213,40)
-- Editable geometric cup: no external image dependencies.
for i=1,3 do local glow=frame(trophy,'Glow'..i,-.2-(i*.12),-.05-(i*.1),1.4+i*.24,1.1+i*.2,color(255,226,79),.5,.94);glow.ZIndex=1 end
local left=frame(trophy,'HandleLeft',.06,.14,.34,.40,gold,.45);local right=frame(trophy,'HandleRight',.60,.14,.34,.40,gold,.45)
for _,handle in ipairs({left,right})do
 handle.BackgroundTransparency=1
 local outline=Instance.new('UIStroke');outline.Color=gold;outline.Thickness=2;outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;outline.Parent=handle
end
local cup=frame(trophy,'Cup',.23,.04,.54,.61,gold,.22)
local gradient=Instance.new('UIGradient');gradient.Color=ColorSequence.new(color(255,239,99),color(224,164,12));gradient.Rotation=90;gradient.Parent=cup
frame(trophy,'Stem',.43,.59,.14,.24,gold,.1)
frame(trophy,'Base',.25,.83,.50,.10,gold,.25)
local wins=text(trophy,'Wins','0',.16,.10,.68,.44,18,color(255,255,255));wins.Outline.Color=color(153,104,9);wins.Outline.Transparency=.15
local platform=frame(tag,'Platform',.81,.46,.11,.28,nil,nil,1)
local pc=frame(platform,'PC',0,0,1,1,nil,nil,1)
frame(pc,'Screen',.04,.05,.92,.65,color(170,156,239),.08)
frame(pc.Screen,'Glass',.10,.12,.80,.73,color(213,208,255),.03)
frame(pc,'Stand',.43,.70,.14,.18,color(147,135,222),.04)
frame(pc,'Foot',.27,.88,.46,.07,color(181,169,244),.06)
local mobile=frame(platform,'Mobile',0,0,1,1,nil,nil,1);mobile.Visible=false
frame(mobile,'Body',.23,0,.54,1,color(178,165,240),.15)
frame(mobile.Body,'Screen',.13,.10,.74,.72,color(223,216,255),.05)
frame(mobile.Body,'Home',.43,.88,.14,.05,color(244,240,255),.5)
local console=frame(platform,'Console',0,0,1,1,nil,nil,1);console.Visible=false
frame(console,'Body',.06,.21,.88,.52,color(182,166,244),.32)
frame(console,'GripLeft',0,.36,.33,.50,color(182,166,244),.4)
frame(console,'GripRight',.67,.36,.33,.50,color(182,166,244),.4)
frame(console,'CrossH',.17,.40,.25,.09,color(247,240,255),.1)
frame(console,'CrossV',.25,.31,.08,.28,color(247,240,255),.1)
frame(console,'ButtonA',.72,.44,.10,.10,color(247,240,255),.5)
frame(console,'ButtonB',.62,.34,.10,.10,color(247,240,255),.5)
if old then old:Destroy()end;tag.Parent=scriptObject
return {Template=tag:GetFullName(),Descendants=#tag:GetDescendants(),Size=tostring(tag.Size)}
