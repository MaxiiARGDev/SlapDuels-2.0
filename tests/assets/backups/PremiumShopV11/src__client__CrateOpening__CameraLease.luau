--!nonstrict
-- A lower-priority lobby camera never restores over a match or EndCinematic.
local Lease={}
function Lease.Acquire(camera,id,character)
 if not camera or camera.CameraType==Enum.CameraType.Scriptable or camera:GetAttribute("CrateCameraOwner")then return nil end
 local row={Camera=camera,Id=id,Character=character,Type=camera.CameraType,Subject=camera.CameraSubject,
  FieldOfView=camera.FieldOfView,CFrame=camera.CFrame}
 camera:SetAttribute("CrateCameraOwner",id);return row
end
function Lease.Owns(row)return row and row.Camera:GetAttribute("CrateCameraOwner")==row.Id end
function Lease.Restore(row,character,higherPriority)
 if not Lease.Owns(row)then return false end
 local camera=row.Camera;camera:SetAttribute("CrateCameraOwner",nil)
 if higherPriority then return false end
 if character==row.Character then
  camera.CameraType=row.Type;camera.FieldOfView=row.FieldOfView;camera.CFrame=row.CFrame
  camera.CameraSubject=if row.Subject and row.Subject.Parent then row.Subject else character and character:FindFirstChildOfClass("Humanoid")
 else
  camera.CameraType=Enum.CameraType.Custom
  camera.CameraSubject=character and character:FindFirstChildOfClass("Humanoid")
  -- Do not apply the old life's FOV or position to a new Character.
 end
 return true
end
return Lease
