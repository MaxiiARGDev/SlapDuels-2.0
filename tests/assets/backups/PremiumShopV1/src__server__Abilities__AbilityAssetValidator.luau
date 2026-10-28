--!nonstrict
-- Physical, authored templates only. Never imports assets or executes code.
local Validator={}
function Validator.Validate(assets,root)
 if assets.Profile=="None" then return true end
 local template=root and root:FindFirstChild(assets.Key)
 local origin=template and template:FindFirstChild("Origin")
 if not template or not origin or not origin:IsA("Attachment") then return false,"MissingEffectOrigin" end
 local descendants=template:GetDescendants()
 if #descendants>500 then return false,"EffectTooLarge" end
 local visual=false
 for _,v in ipairs(descendants) do
  if v:IsA("LuaSourceContainer") or v:IsA("Explosion") then return false,"ExecutableOrUnsafeEffect" end
  if v:IsA("BasePart") and (not v.Anchored or v.CanCollide or v.CanTouch or v.CanQuery) then return false,"UnsafeEffectPart" end
  if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then visual=true end
  if v:IsA("Trail") or v:IsA("Beam") then
   if not v.Attachment0 or not v.Attachment1 or not v.Attachment0:IsDescendantOf(origin)
    or not v.Attachment1:IsDescendantOf(origin) then return false,"InvalidEffectAttachments" end
  end
 end
 if not visual then return false,"MissingVisualTrace" end
 for _,cue in pairs(assets.Cues or {}) do
  local resource=template:FindFirstChild(cue.Resource)
  if not resource or not resource:IsA("BasePart") then return false,"MissingCueResource" end
 end
 return true
end
return table.freeze(Validator)
