--!nonstrict
-- Prepared adapter only: injected store, no DataStoreService lookup, never selected in V1.
local Ledger=require(script.Parent.StockLedger)
local Adapter={};Adapter.__index=Adapter
function Adapter.new(store,key)
 assert(store and type(store.UpdateAsync)=="function" and type(key)=="string","StoreRequired")
 return setmetatable({Store=store,Key=key,Scope="ProductionLedgerUnvalidated",WritesToCloud=true},Adapter)
end
function Adapter:View(reward,variation)
 local cs,reason=Ledger.Constraints(reward,variation);if not cs then return nil,reason end
 -- A potentially cached read cannot prove current available stock for a purchase quote.
 return nil,"AuthoritativeSnapshotRequired"
end
function Adapter:_update(transform)
 local accepted,reason
 local ok,err=pcall(function()self.Store:UpdateAsync(self.Key,function(old)
  local state=old or {Buckets={},Operations={}}
  accepted,reason=transform(state)
  return if accepted then state else nil
 end)end)
 if not ok then return false,"StockOutcomeUnknown:"..tostring(err) end
 return accepted,reason
end
function Adapter:Reserve(id,uid,reward,variation)
 local cs,reason=Ledger.Constraints(reward,variation);if not cs then return false,reason end
 return self:_update(function(state)return Ledger.Reserve(state,id,uid,reward,cs)end)
end
function Adapter:Commit(id)return self:_update(function(state)return Ledger.Finish(state,id,true)end)end
function Adapter:Release(id)return self:_update(function(state)return Ledger.Finish(state,id,false)end)end
return Adapter
