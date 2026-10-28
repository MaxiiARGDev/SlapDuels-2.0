--!nonstrict
-- Server-owned movement, conservative body sweep and explicit arena envelope.
local Guard = {}
local function segmentBox(cf,size,origin,delta,padding)
 local p=cf:PointToObjectSpace(origin)
 local d=cf:VectorToObjectSpace(delta)
 local half=size/2+Vector3.new(padding,padding,padding)
 local lo,hi=0,1
 for _,axis in {"X","Y","Z"} do
  if math.abs(d[axis])<1e-6 then
   if math.abs(p[axis])>half[axis] then return nil end
  else
   local a,b=(-half[axis]-p[axis])/d[axis],(half[axis]-p[axis])/d[axis]
   if a>b then a,b=b,a end
   lo=math.max(lo,a);hi=math.min(hi,b)
   if lo>hi then return nil end
  end
 end
 return lo
end
Guard.SegmentBox=segmentBox
function Guard.CanOwn(root)
 local ok,allowed=pcall(function() return root:CanSetNetworkOwnership() end)
 return ok and allowed
end
function Guard.Take(root)
 if not Guard.CanOwn(root) then return false end
 local captured,ownership=pcall(function() return {Auto=root:GetNetworkOwnershipAuto(),Owner=root:GetNetworkOwner()} end)
 if not captured then return false end
 local ok=pcall(function() root:SetNetworkOwner(nil) end)
 return ok,if ok then ownership else nil
end
function Guard.Release(root,ownership)
 if root and root.Parent and ownership then pcall(function()
  if root:GetNetworkOwner()~=nil then return end -- A newer explicit owner wins.
  if ownership.Auto then root:SetNetworkOwnershipAuto() else root:SetNetworkOwner(ownership.Owner) end
 end) end
end
function Guard.SafeDistance(record,delta)
 if delta.Magnitude<1e-5 then return 0 end
 local root=record.Root
 local size=Vector3.new(3,3,3)
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={record.Character}
 params.RespectCanCollide=true
 local overlap=OverlapParams.new()
 overlap.FilterType=Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances={record.Character}
 overlap.RespectCanCollide=true
 -- Blockcast does not detect an initial overlap. Fail closed on such overlaps.
 if #workspace:GetPartBoundsInBox(root.CFrame,size,overlap)>0 then return 0 end
 local hit=workspace:Blockcast(root.CFrame,size,delta,params)
 local distance=if hit then math.max(0,hit.Distance-0.3) else delta.Magnitude
 local info=record.World
 if not info or not info.VoidBoundaryPart then return 0 end
 local bounds=info.VoidBoundaryPart
 local relative=root.Position-bounds.Position
 local endRelative=relative+delta
 if math.abs(endRelative.X)>bounds.Size.X/2-3 or math.abs(endRelative.Z)>bounds.Size.Z/2-3 then return 0 end
 -- Noncolliding KillPart/void sensors may have CanQuery=false. Never skip them
 -- merely because they are absent from a physics query.
 for _,part in info.KillParts or {} do
  local t=segmentBox(part.CFrame,part.Size,root.Position,delta,1.5)
  if t then distance=math.min(distance,math.max(0,t*delta.Magnitude-0.3)) end
 end
 return distance
end
return Guard
