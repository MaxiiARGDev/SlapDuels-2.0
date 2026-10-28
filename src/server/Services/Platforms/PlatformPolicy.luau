--!nonstrict
-- Pure configuration and support geometry policy; no remotes or per-part scripts.
local Policy = {}
local function number(value, minimum, maximum, exclusiveMinimum)
 return type(value)=="number" and value==value and value<math.huge
  and value>=minimum and value<=maximum and (not exclusiveMinimum or value>minimum)
end
function Policy.Validate(raw)
 if type(raw)~="table" then return nil,"Expected configuration table" end
 if type(raw.Enabled)~="boolean" then return nil,"Enabled must be boolean" end
 for _,key in {"TargetPartName","GeometryFolderName"} do
  if type(raw[key])~="string" or raw[key]=="" then return nil,key.." must be a nonempty name" end
 end
 local ranges={FadeDelay={0,60},FadeDuration={0,60,true},DetectionInterval={0.02,5},
  SupportTolerance={0.01,0.5},SurfaceTolerance={0.001,0.2},TopNormalDot={0.9,1},MaxSupportNormalSpeed={0,10}}
 for key,range in pairs(ranges) do
  if not number(raw[key],range[1],range[2],range[3]) then return nil,"Invalid "..key end
 end
 if raw.ResetDuringMatch~=false then return nil,"V1 requires ResetDuringMatch=false" end
 if raw.DisableCollisionOnFadeComplete~=true then return nil,"V1 requires DisableCollisionOnFadeComplete=true" end
 return table.freeze(table.clone(raw))
end
function Policy.ExpectedHeight(character,humanoid,root)
 local height=root.Size.Y*0.5+humanoid.HipHeight
 if humanoid.RigType==Enum.HumanoidRigType.R6 then
  local leg=character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
  if not leg or not leg:IsA("BasePart") then return nil end
  height+=leg.Size.Y
 end
 return if height>0 then height else nil
end
function Policy.CanStand(character,humanoid,root,config)
 if humanoid.Health<=0 or humanoid.PlatformStand or humanoid.Sit
  or character:GetAttribute("ArenaRespawnPending") or character:GetAttribute("Ragdolled") then return false end
 local state=humanoid:GetState()
 if state~=Enum.HumanoidStateType.Running and state~=Enum.HumanoidStateType.RunningNoPhysics
  and state~=Enum.HumanoidStateType.Landed then return false end
 return true
end
function Policy.IsTopSupport(part,root,hit,expectedHeight,config)
 if not part.CanCollide or hit.Instance~=part then return false end
 local up=part.CFrame.UpVector
 if up.Y<=0 or hit.Normal:Dot(up)<config.TopNormalDot then return false end
 local point=part.CFrame:PointToObjectSpace(hit.Position)
 local half=part.Size*0.5
 if math.abs(point.X)>half.X+config.SurfaceTolerance or math.abs(point.Z)>half.Z+config.SurfaceTolerance
  or math.abs(point.Y-half.Y)>config.SurfaceTolerance then return false end
 local rootLocal=part.CFrame:PointToObjectSpace(root.Position)
 if rootLocal.Y<=half.Y then return false end
 -- Normal avatar clearance, not a long ray that can reach through an airborne jump.
 if math.abs(root.Position.Y-hit.Position.Y-expectedHeight)>config.SupportTolerance then return false end
 -- Tangential walking on a slope is support, even when world Y velocity is nonzero.
 local normalSpeed=(root.AssemblyLinearVelocity-part.AssemblyLinearVelocity):Dot(up)
 return math.abs(normalSpeed)<=config.MaxSupportNormalSpeed
end
return table.freeze(Policy)
