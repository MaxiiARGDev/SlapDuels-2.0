--!nonstrict
-- Studio does not even acquire MemoryStoreService.
local Model=require(script.Parent.PartyQueueModel)
local Store={};Store.__index=Store
function Store.new(global,namespace)
 local map
 if global then map=game:GetService('MemoryStoreService'):GetSortedMap(namespace)end
 return setmetatable({Map=map,Local={}},Store)
end
function Store:Update(mode,transform)
 if self.Map then
  return self.Map:UpdateAsync(mode,function(old)
   local s=Model.Copy(old or Model.Empty());transform(s);return s
  end,600)
 end
 local s=Model.Copy(self.Local[mode]or Model.Empty());transform(s);self.Local[mode]=s;return Model.Copy(s)
end
function Store:Read(mode)
 return self.Map and self.Map:GetAsync(mode)or Model.Copy(self.Local[mode]or Model.Empty())
end
return Store
