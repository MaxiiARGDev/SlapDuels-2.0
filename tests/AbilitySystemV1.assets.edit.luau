-- Edit-only authored resource installation. Refuses to replace existing artwork.
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning(),"Edit required")
local RS=game:GetService("ReplicatedStorage")
local SG=game:GetService("StarterGui")
assert(not SG:FindFirstChild("AbilityHUD") and not RS:FindFirstChild("AbilityEffects"),"Ability assets already exist; inspect before editing")
assert(not game.ServerStorage:FindFirstChild("_AbilityV1Backups"),"Backup already exists")
local backup=Instance.new("Folder");backup.Name="_AbilityV1Backups"
local original=SG.ShopHUD:Clone();original.Name="ShopHUD_Before";original.Parent=backup
backup.Parent=game.ServerStorage
local function make(class,name,parent,props)
 local v=Instance.new(class);v.Name=name
 for k,value in pairs(props or {}) do v[k]=value end
 v.Parent=parent;return v
end
local dark=Color3.fromRGB(20,24,38)
local accent=Color3.fromRGB(107,203,255)
local white=Color3.fromRGB(242,247,255)
local function round(parent,radius) return make("UICorner","UICorner",parent,{CornerRadius=UDim.new(0,radius or 12)}) end
local function label(name,parent,text,pos,size,fontSize)
 return make("TextLabel",name,parent,{BackgroundTransparency=1,Text=text,Position=pos,Size=size,
  TextColor3=white,Font=Enum.Font.GothamBold,TextSize=fontSize or 16,TextWrapped=true,ZIndex=3})
end
local hud=make("ScreenGui","AbilityHUD",nil,{Enabled=false,ResetOnSpawn=false,DisplayOrder=22,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
hud:SetAttribute("Version","AbilitySystemV1")
local button=make("TextButton","AbilityButton",hud,{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-28,1,-175),
 Size=UDim2.fromOffset(148,120),BackgroundColor3=dark,Text="",AutoButtonColor=true,ClipsDescendants=true})
round(button,18)
make("UIStroke","UIStroke",button,{Color=accent,Thickness=2,Transparency=0.2})
make("UISizeConstraint","UISizeConstraint",button,{MinSize=Vector2.new(112,100),MaxSize=Vector2.new(180,145)})
make("ImageLabel","Icon",button,{Image="",Visible=false,BackgroundTransparency=1,
 Position=UDim2.fromScale(0.36,0.05),Size=UDim2.fromScale(0.28,0.3),ZIndex=3})
label("AbilityName",button,"DASH",UDim2.fromScale(0.04,0.32),UDim2.fromScale(0.92,0.32),17)
label("CooldownLabel",button,"E · LISTA",UDim2.fromScale(0.04,0.68),UDim2.fromScale(0.92,0.24),15)
make("Frame","CooldownOverlay",button,{Visible=false,BackgroundColor3=Color3.fromRGB(0,0,0),
 BackgroundTransparency=0.4,Size=UDim2.fromScale(1,1),ZIndex=2,BorderSizePixel=0})
local selection=make("Frame","AbilitySelectionFrame",hud,{Visible=false,AnchorPoint=Vector2.new(0.5,0.5),
 Position=UDim2.fromScale(0.5,0.55),Size=UDim2.new(0.92,0,0,270),BackgroundColor3=dark})
round(selection,16)
make("UISizeConstraint","UISizeConstraint",selection,{MaxSize=Vector2.new(1060,290),MinSize=Vector2.new(280,250)})
make("UIStroke","UIStroke",selection,{Color=accent,Thickness=2})
label("Title",selection,"ELEGÍ TU HABILIDAD",UDim2.new(0,10,0,8),UDim2.new(1,-20,0,30),21)
label("Hint",selection,"Una habilidad por ronda · elección confirmada por el servidor",UDim2.new(0,10,0,40),UDim2.new(1,-20,0,30),13)
local cards=make("ScrollingFrame","Cards",selection,{Position=UDim2.new(0,12,0,80),Size=UDim2.new(1,-24,1,-92),
 BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,
 ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=6})
make("UIListLayout","UIListLayout",cards,{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder})
local card=make("TextButton","AbilityCardTemplate",cards,{Visible=false,Size=UDim2.fromOffset(190,162),Text="",
 BackgroundColor3=Color3.fromRGB(34,43,65),AutoButtonColor=true})
round(card,10)
make("ImageLabel","Icon",card,{Image="",Visible=false,BackgroundTransparency=1,Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(24,24)})
label("AbilityName",card,"HABILIDAD",UDim2.new(0,8,0,8),UDim2.new(1,-16,0,28),15)
label("Description",card,"Descripción",UDim2.new(0,8,0,38),UDim2.new(1,-16,0,58),12)
label("Cooldown",card,"CD",UDim2.new(0,8,0,100),UDim2.new(1,-16,0,24),11)
local status=label("Status",card,"SELECCIONAR",UDim2.new(0,8,0,132),UDim2.new(1,-16,0,22),12)
status.TextColor3=accent
hud.Parent=SG

local effects=make("Folder","AbilityEffects",nil)
local colors={Dash=Color3.fromRGB(120,215,255),StrongSlap=Color3.fromRGB(255,195,60),
 AirJumps=Color3.fromRGB(165,240,255),DevilSpeed=Color3.fromRGB(255,65,95),Invisible=Color3.fromRGB(170,145,240)}
for id,color in pairs(colors) do
 local f=make("Folder",id,effects)
 local origin=make("Attachment","Origin",f)
 origin:SetAttribute("AbilityPresentation",true)
 make("ParticleEmitter","Particles",origin,{Enabled=false,Rate=if id=="Invisible" then 3 else 16,
  Texture="rbxasset://textures/particles/sparkles_main.dds",Color=ColorSequence.new(color),
  Lifetime=NumberRange.new(0.25,0.5),Speed=NumberRange.new(0.5,2),SpreadAngle=Vector2.new(80,80),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,0)}),
  Transparency=NumberSequence.new(if id=="Invisible" then 0.65 else 0.2),LightEmission=0.6})
 local a=make("Attachment","TrailStart",origin,{Position=Vector3.new(-0.7,0,0)})
 local b=make("Attachment","TrailEnd",origin,{Position=Vector3.new(0.7,0,0)})
 make("Trail","Trail",origin,{Enabled=false,Attachment0=a,Attachment1=b,Color=ColorSequence.new(color),
  Lifetime=0.2,Transparency=NumberSequence.new(if id=="Invisible" then 0.85 else 0.4),MinLength=0.2,
  WidthScale=NumberSequence.new(0.35)})
 make("Beam","Beam",origin,{Enabled=false,Attachment0=a,Attachment1=b,Color=ColorSequence.new(color),
  Width0=0.08,Width1=0.08,FaceCamera=true,Transparency=NumberSequence.new(if id=="Invisible" then 0.9 else 0.65)})
 make("Sound","ActivationSound",origin,{SoundId="",Volume=0.35,RollOffMaxDistance=45})
 if id=="StrongSlap" then
  make("Part","LaunchSpectacle",f,{Size=Vector3.new(2,4,1),Anchored=true,CanCollide=false,CanTouch=false,
   CanQuery=false,CastShadow=false,Material=Enum.Material.Neon,Color=color,Transparency=0.35})
 end
end
effects.Parent=RS

local tabs=SG.ShopHUD.MainFrame.Tabs
assert(not tabs:FindFirstChild("AbilitiesTab"),"Abilities tab already exists")
local tab=tabs.DeathEffectsTab:Clone();tab.Name="AbilitiesTab";tab:SetAttribute("Category","Abilities");tab.LayoutOrder=50
for _,v in ipairs(tab:GetDescendants()) do
 if v:IsA("TextLabel") and v.Name~="SoonBadge" then v.Text="ABILITIES" end
 if v.Name=="SoonBadge" and v:IsA("GuiObject") then v.Visible=false end
end
tab.Parent=tabs
return {HUD=hud:GetFullName(),Effects=effects:GetFullName(),Tab=tab:GetFullName(),Backup=backup:GetFullName()}
