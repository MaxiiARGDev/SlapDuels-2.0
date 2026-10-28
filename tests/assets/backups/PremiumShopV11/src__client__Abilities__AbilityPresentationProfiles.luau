--!nonstrict
-- Reviewed visual adapters. Profiles describe capabilities, never ability IDs.
local RS=game:GetService("ReplicatedStorage")
local Profiles={}
local function marked(object)
 while object do
  if object:GetAttribute("AbilityPresentation") then return true end
  object=object.Parent
 end
 return false
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
function Profiles.Start(assets,record,char,root)
 if assets.Profile=="None" then return end
 if assets.Profile=="InvisibleAvatar" then
  for _,v in ipairs(char:GetDescendants()) do hide(record,v) end
  record.Connection=char.DescendantAdded:Connect(function(v) hide(record,v) end)
 elseif assets.Profile~="AttachmentEffect" then return end
 local templates=RS:FindFirstChild("AbilityEffects")
 local template=templates and templates:FindFirstChild(assets.Key)
 local origin=template and template:FindFirstChild("Origin")
 if not origin then return end
 local asset=origin:Clone();asset:SetAttribute("AbilityPresentation",true);asset.Parent=root
 table.insert(record.Assets,asset)
 for _,v in ipairs(asset:GetDescendants()) do
  if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled=true
  elseif v:IsA("Sound") and v.SoundId~="" then v:Play() end
 end
end
return table.freeze(Profiles)
