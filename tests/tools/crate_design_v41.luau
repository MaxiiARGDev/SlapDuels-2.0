assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local hud=game.StarterGui.ShopHUD
local p=hud.CratePanel
local main=hud.MainFrame
local function color(r,g,b)return Color3.fromRGB(r,g,b)end
local function corner(o,r)
 local c=o:FindFirstChildWhichIsA('UICorner')or Instance.new('UICorner');c.CornerRadius=UDim.new(0,r);c.Parent=o
end
local function gradient(o,name,a,b)
 local g=o:FindFirstChild(name)or Instance.new('UIGradient');g.Name=name;g.Color=ColorSequence.new(a,b);g.Rotation=90;g.Parent=o
end
local function stroke(o,name,c,t)
 local s=o:FindFirstChild(name)or Instance.new('UIStroke');s.Name=name;s.Color=c;s.Thickness=t;s.Transparency=0;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=o;return s
end
local function fit(o,max)
 o.TextScaled=true;local c=o:FindFirstChildWhichIsA('UITextSizeConstraint')or Instance.new('UITextSizeConstraint');c.MinTextSize=10;c.MaxTextSize=max;c.Parent=o
end
local function box(o,x,y,w,h)o.Position=UDim2.fromScale(x,y);o.Size=UDim2.fromScale(w,h)end
local title=main.Header.TitlePlate.TitleLabel
local action=main.Body.DetailPanel.ActionButton
-- Keep the real 3D viewing band transparent; opaque header/footer mask the world.
corner(p,18)
local border=stroke(p,'DesignBorder',color(34,211,238),3)
local original=main.UIStroke:FindFirstChildWhichIsA('UIGradient')
if not border:FindFirstChildWhichIsA('UIGradient')then original:Clone().Parent=border end
for _,name in {'Header','Footer','LeftMask','RightMask'}do
 local o=p[name];o.BackgroundColor3=Color3.new(1,1,1)
 gradient(o,'DesignGradient',color(30,36,86),color(10,13,35))
end
corner(p.Header,18);corner(p.Footer,18)
box(p.Title,.035,.025,.71,.085);p.Title.FontFace=title.FontFace;p.Title.TextColor3=color(242,250,255);fit(p.Title,34)
local ts=stroke(p.Title,'TitleOutline',color(8,10,26),2.5);ts.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
gradient(p.Title,'TitleTint',Color3.new(1,1,1),color(120,230,255))
box(p.Count,.04,.125,.61,.047);fit(p.Count,17);p.Count.TextColor3=color(255,211,85)
box(p.Price,.69,.125,.27,.047);fit(p.Price,17)
box(p.Hint,.04,.181,.90,.025);p.Hint.Text='DESLIZÁ Y DESCUBRÍ TU PRÓXIMO SLAP';fit(p.Hint,11)
box(p.Close,.908,.028,.055,.087);p.Close.FontFace=title.FontFace;fit(p.Close,30)
gradient(p.Close,'Gloss',color(255,100,125),color(173,23,61));stroke(p.Close,'Stroke',color(255,166,184),1.5)
local divider=p.Header:FindFirstChild('DesignDivider')or Instance.new('Frame');divider.Name='DesignDivider';divider.BorderSizePixel=0;divider.BackgroundColor3=Color3.new(1,1,1);divider.Position=UDim2.new(.025,0,1,-3);divider.Size=UDim2.new(.95,0,0,3);divider.ZIndex=62;divider.Parent=p.Header
gradient(divider,'Tint',color(34,211,238),color(140,90,255))
p.RewardScroll.ScrollBarThickness=5;p.RewardScroll.ScrollBarImageColor3=color(110,175,255)
p.RewardScroll.Layout.Padding=UDim.new(0,16)
local card=p.RewardCard;corner(card,12);card.Stroke.Thickness=2
card.Info.BackgroundColor3=Color3.new(1,1,1);gradient(card.Info,'InfoGradient',color(29,38,79),color(10,14,34));corner(card.Info,10)
for _,name in {'ItemName','Rarity','Chance','Detail'}do
 local label=card[name];label.FontFace=if name=='ItemName'then title.FontFace else Font.fromEnum(Enum.Font.GothamBold)
 fit(label,if name=='ItemName'then 20 elseif name=='Chance'then 12 else 14)
end
box(card.ItemName,.04,.69,.92,.085);box(card.Rarity,.08,.79,.84,.055);box(card.Chance,.035,.875,.93,.068)
card.Detail.BackgroundColor3=color(14,21,48);corner(card.Detail,8);stroke(card.Detail,'DetailBorder',color(110,175,255),1)
local accent=card:FindFirstChild('DesignAccent')or Instance.new('Frame');accent.Name='DesignAccent';accent.BorderSizePixel=0;accent.BackgroundColor3=color(120,155,255);accent.Position=UDim2.fromScale(.12,.66);accent.Size=UDim2.new(.76,0,0,3);accent.ZIndex=65;accent.Parent=card;corner(accent,3)
box(p.ProbabilityNote,.04,.75,.92,.043);p.ProbabilityNote.Text='Probabilidades aproximadas · Todos los premios posibles';fit(p.ProbabilityNote,13)
box(p.Status,.04,.811,.92,.034);fit(p.Status,14)
for _,b in {p.Buy,p.OpenActions.X1,p.OpenActions.X5,p.OpenActions.X10}do
 b.FontFace=action.FontFace;fit(b,25);corner(b,10);b.TextStrokeTransparency=1
 stroke(b,'Stroke',color(190,220,255),1.5)
 gradient(b,'ButtonGloss',Color3.new(1,1,1),color(170,180,190))
 local s=stroke(b,'TextOutline',color(8,15,30),2);s.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
end
p.Buy.BackgroundColor3=color(20,190,97)
for _,b in {p.OpenActions.X1,p.OpenActions.X5,p.OpenActions.X10}do b.BackgroundColor3=color(228,166,35)end
return {Panel=p:GetFullName(),Descendants=#p:GetDescendants(),Mode='Edit'}
