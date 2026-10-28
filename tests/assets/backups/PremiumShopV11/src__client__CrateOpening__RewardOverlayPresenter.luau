--!nonstrict
local TweenService=game:GetService("TweenService")
local Presenter={};Presenter.__index=Presenter
function Presenter.new(root)
 if not root then return nil end
 local self=setmetatable({Root=root,Position=root.Position,Entries={}},Presenter)
 for _,obj in ipairs(root:GetDescendants())do
  local props={}
  if obj:IsA("GuiObject")then props.BackgroundTransparency=obj.BackgroundTransparency end
  if obj:IsA("TextLabel")then props.TextTransparency=obj.TextTransparency end
  if obj:IsA("UIStroke")then props.Transparency=obj.Transparency end
  if next(props)then table.insert(self.Entries,{Object=obj,Properties=props})end
 end
 table.insert(self.Entries,{Object=root,Properties={BackgroundTransparency=root.BackgroundTransparency}})
 self.Scale=root:FindFirstChild("RevealScale");root.Visible=false
 return self
end
function Presenter:_tween(run,obj,duration,props)
 local t=TweenService:Create(obj,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),props)
 table.insert(run.Tweens,t);t:Play()
end
function Presenter:Show(run,slap,variation)
 if not run.Private or self.Owner==run.Id then return end
 self.Owner=run.Id;local root=self.Root
 root.Title.Text="¡RECOMPENSA OBTENIDA!";root.SlapName.Text=slap.DisplayName
 root.VariationName.Text=variation.DisplayName;root.VariationName.TextColor3=variation.Color
 local stroke=root:FindFirstChild("AccentStroke");if stroke then stroke.Color=variation.Color end
 root.Position=self.Position+UDim2.fromScale(0,.025);root.Visible=true
 if self.Scale then self.Scale.Scale=.94;self:_tween(run,self.Scale,.35,{Scale=1})end
 for _,entry in ipairs(self.Entries)do
  for key in pairs(entry.Properties)do entry.Object[key]=1 end
  self:_tween(run,entry.Object,.35,entry.Properties)
 end
 self:_tween(run,root,.35,{Position=self.Position})
end
function Presenter:Exit(run)
 if self.Owner~=run.Id then return end
 for _,entry in ipairs(self.Entries)do local p={};for key in pairs(entry.Properties)do p[key]=1 end;self:_tween(run,entry.Object,.25,p)end
 self:_tween(run,self.Root,.25,{Position=self.Position+UDim2.fromScale(0,.015)})
end
function Presenter:Reset(id)
 if self.Owner and self.Owner~=id then return end
 self.Owner=nil;self.Root.Visible=false;self.Root.Position=self.Position
 if self.Scale then self.Scale.Scale=1 end
 for _,entry in ipairs(self.Entries)do for key,value in pairs(entry.Properties)do entry.Object[key]=value end end
end
return Presenter
