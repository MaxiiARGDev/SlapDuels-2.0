--!nonstrict
-- Only session participants receive these records. Local visual changes never
-- touch collision, hitboxes, health, equipped tools or persistent preferences.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Presentation={}
Presentation.__index=Presentation
local function marked(object)
 while object do
  if object:GetAttribute("AbilityPresentation") then return true end
  object=object.Parent
 end
 return false
end
function Presentation.new() return setmetatable({Active={},Impacts={},Transient={}},Presentation) end
function Presentation:_remove(key)
 local record=self.Active[key]
 if not record then return end
 self.Active[key]=nil
 if record.Connection then record.Connection:Disconnect() end
 for object,properties in pairs(record.Saved) do
  if object.Parent then
   for property,values in pairs(properties) do
    -- A later local visual owner wins; restore only values still owned here.
    pcall(function() if object[property]==values.Applied then object[property]=values.Original end end)
   end
  end
 end
 for _,v in ipairs(record.Assets) do v:Destroy() end
end
local function hide(record,object)
 if marked(object) or record.Saved[object] then return end
 local property,value
 if object:IsA("BasePart") then property,value="LocalTransparencyModifier",1
 elseif object:IsA("Decal") then property,value="Transparency",1
 elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then property,value="Enabled",false
 elseif object:IsA("BillboardGui") then property,value="Enabled",false
 elseif object:IsA("Humanoid") then property,value="DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None end
 if property then
  record.Saved[object]={[property]={Original=object[property],Applied=value}}
  object[property]=value
 end
end
function Presentation:Reconcile(payload)
 local desired={}
 if payload.Playing and payload.SessionId==Players.LocalPlayer:GetAttribute("MatchId") then
  for _,effect in ipairs(payload.Presentations or {}) do
   local player=Players:GetPlayerByUserId(effect.UserId)
   local char=player and player.Character
   local root=char and char:FindFirstChild("HumanoidRootPart")
   if char and root and (char:GetAttribute("ArenaPhysicsGeneration") or 0)==effect.CharacterGeneration
    and not char:GetAttribute("ArenaRespawnPending") and effect.ActiveUntil>workspace:GetServerTimeNow() then
    desired[effect.ActivationId]=true
    local record=self.Active[effect.ActivationId]
    if record and record.Character~=char then self:_remove(effect.ActivationId);record=nil end
    if not record then
     record={Saved={},Assets={},Character=char,Until=effect.ActiveUntil,Generation=effect.CharacterGeneration}
     self.Active[effect.ActivationId]=record
     if effect.AbilityId=="Invisible" then
      for _,v in ipairs(char:GetDescendants()) do hide(record,v) end
      record.Connection=char.DescendantAdded:Connect(function(v) hide(record,v) end)
     end
     local templates=RS:FindFirstChild("AbilityEffects")
     local template=templates and templates:FindFirstChild(effect.AbilityId)
     local origin=template and template:FindFirstChild("Origin")
     if origin then
      local asset=origin:Clone();asset:SetAttribute("AbilityPresentation",true);asset.Parent=root
      table.insert(record.Assets,asset)
      for _,v in ipairs(asset:GetDescendants()) do
       if v:IsA("ParticleEmitter") then v.Enabled=true
       elseif v:IsA("Trail") or v:IsA("Beam") then v.Enabled=true
       elseif v:IsA("Sound") and v.SoundId~="" then v:Play() end
      end
     end
    end
   end
  end
 end
 local remove={}
 for key in pairs(self.Active) do if not desired[key] then table.insert(remove,key) end end
 for _,key in ipairs(remove) do self:_remove(key) end
end
function Presentation:Tick()
 local remove={}
 for key,r in pairs(self.Active) do
  if not r.Character.Parent or r.Character:GetAttribute("ArenaRespawnPending")
   or (r.Character:GetAttribute("ArenaPhysicsGeneration") or 0)~=r.Generation or workspace:GetServerTimeNow()>=r.Until then table.insert(remove,key) end
 end
 for _,key in ipairs(remove) do self:_remove(key) end
end
function Presentation:Impact(payload)
 if payload.SessionId~=Players.LocalPlayer:GetAttribute("MatchId") or self.Impacts[payload.ActivationId] then return end
 self.Impacts[payload.ActivationId]=true
 local template=RS.AbilityEffects.StrongSlap:FindFirstChild("LaunchSpectacle")
 if not template then return end
 -- Authored silhouette prop is detached from the competitive rig. Zero-Death
 -- retires the real Character immediately through the normal elimination path.
 local prop=template:Clone();prop:SetAttribute("AbilityPresentation",true)
 prop.CFrame=CFrame.new(payload.Position);prop.Parent=workspace
 self.Transient[prop]=true
 local tween=TweenService:Create(prop,TweenInfo.new(0.65,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
  {CFrame=prop.CFrame+Vector3.new(0,payload.Lift,0),Transparency=1})
 tween:Play();Debris:AddItem(prop,0.8)
 task.delay(0.9,function() self.Transient[prop]=nil end)
end
function Presentation:Clear()
 local keys={} for key in pairs(self.Active) do table.insert(keys,key) end
 for _,key in ipairs(keys) do self:_remove(key) end
 for prop in pairs(self.Transient) do prop:Destroy() end
 self.Transient={};self.Impacts={}
end
return Presentation
