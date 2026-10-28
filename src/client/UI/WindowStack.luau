--!nonstrict
-- Desired windows are retained while covered; only the top is physically visible.
local Stack={};Stack.__index=Stack
function Stack.new(apply)return setmetatable({Order={},Apply=apply},Stack)end
function Stack:Remove(id)
 for i=#self.Order,1,-1 do if self.Order[i]==id then table.remove(self.Order,i)end end
 self:Refresh()
end
function Stack:Push(id)
 for i=#self.Order,1,-1 do if self.Order[i]==id then table.remove(self.Order,i)end end
 table.insert(self.Order,id);self:Refresh()
end
function Stack:Refresh()self.Apply(self.Order[#self.Order],self.Order)end
function Stack:Clear()table.clear(self.Order);self:Refresh()end
return Stack
