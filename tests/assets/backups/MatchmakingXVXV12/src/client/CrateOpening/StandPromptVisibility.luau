--!nonstrict
-- Local prompt lease, scoped to the selected stand and private opening.
local Prompts={}
function Prompts.Release(lease)
 if not lease or lease.Released then return end;lease.Released=true
 if lease.Connection then lease.Connection:Disconnect();lease.Connection=nil end
 for object,row in pairs(lease.Saved)do
  row.Connection:Disconnect()
  pcall(function()if object.Enabled==false then object.Enabled=row.Previous end end)
 end
 table.clear(lease.Saved)
end
function Prompts.Acquire(stand,id)
 local lease={Id=id,Saved={},Released=false}
 local function hide(obj)
  if lease.Released or not obj:IsA("ProximityPrompt")or lease.Saved[obj]then return end
  local row={Previous=obj.Enabled,Writing=false};lease.Saved[obj]=row
  row.Connection=obj:GetPropertyChangedSignal("Enabled"):Connect(function()
   if lease.Released or row.Writing then return end
   if obj.Enabled then row.Previous=true;row.Writing=true;obj.Enabled=false;row.Writing=false end
  end)
  row.Writing=true;obj.Enabled=false;row.Writing=false
 end
 local ok,failure=pcall(function()
  lease.Connection=stand.DescendantAdded:Connect(hide)
  for _,obj in ipairs(stand:GetDescendants())do hide(obj)end
 end)
 if not ok then Prompts.Release(lease);error(failure)end
 return lease
end
return Prompts
