--!nonstrict
-- Cosmetic-only: no Parts, joints, scripts, Configuration, animation or combat state.
local Appearance={}
local allowed={Attachment=true,ParticleEmitter=true,PointLight=true,BillboardGui=true,Frame=true,TextLabel=true,UICorner=true,UIStroke=true}
local function material(name)
 if type(name)~="string"then return nil end
 local ok,result=pcall(function()return Enum.Material[name]end)
 return if ok then result else nil
end
local function finite(n)return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function safe(root)
 if not allowed[root.ClassName]then return false end
 for _,desc in ipairs(root:GetDescendants())do if not allowed[desc.ClassName]then return false end end
 return true
end
function Appearance.Apply(hand,profile)
 if not hand or not hand:IsA("BasePart")or not profile then return false end
 local original=hand:GetAttribute("SlapVariationOriginalColor")
 if typeof(original)~="Color3"then original=hand.Color;hand:SetAttribute("SlapVariationOriginalColor",original)end
 local originalMaterial=hand:GetAttribute("SlapVariationOriginalMaterial")
 if not material(originalMaterial)then originalMaterial=hand.Material.Name;hand:SetAttribute("SlapVariationOriginalMaterial",originalMaterial)end
 hand.Color=original;hand.Material=material(originalMaterial)
 for _,child in ipairs(hand:GetChildren())do
  if child:GetAttribute("SlapVariationManaged")==true then child:Destroy()end
 end
 local tint=profile:GetAttribute("Tint")
 if profile:GetAttribute("ApplyTint")~=false and typeof(tint)=="Color3"then hand.Color=tint end
 if profile:GetAttribute("ApplyMaterial")==true then
  local m=material(profile:GetAttribute("Material"));if m then hand.Material=m end
 end
 local intensity=profile:GetAttribute("Intensity")
 intensity=if finite(intensity)then math.clamp(intensity,0,2)else 1
 for _,resource in ipairs(profile:GetChildren())do
  if not safe(resource)then continue end
  local copy=resource:Clone();copy:SetAttribute("SlapVariationManaged",true)
  local all=copy:GetDescendants();table.insert(all,copy)
  for _,desc in ipairs(all)do
   if desc:IsA("Attachment")and desc:GetAttribute("ScaleToHand")==true then
    local position=desc:GetAttribute("NormalizedPosition")
    if typeof(position)=="Vector3"then desc.Position=hand.Size*position end
   elseif desc:IsA("ParticleEmitter")then
    desc:SetAttribute("SlapVariationEmitter",true)
    desc.Rate=math.clamp(desc.Rate*intensity,0,24)
    if intensity==0 then desc.Enabled=false end
   elseif desc:IsA("PointLight")then
    desc.Brightness=math.clamp(desc.Brightness*intensity,0,1)
    if intensity==0 then desc.Enabled=false end
   end
  end
  copy.Parent=hand
 end
 return true
end
return Appearance
