--!nonstrict
local Ledger=require(script.Parent.StockLedger)
local Stock={};Stock.__index=Stock
function Stock.new(sharedState)return setmetatable({State=sharedState or {Buckets={},Operations={}},Scope="StudioServerInMemory",WritesToCloud=false},Stock)end
function Stock:View(reward,variation)
 local cs,reason=Ledger.Constraints(reward,variation);if not cs then return nil,reason end
 local view,err=Ledger.View(self.State,cs,reward.RewardId);if view then view.Scope=self.Scope end;return view,err
end
function Stock:Reserve(id,userId,reward,variation)
 local cs,reason=Ledger.Constraints(reward,variation);if not cs then return false,reason end
 return Ledger.Reserve(self.State,id,userId,reward,cs)
end
function Stock:Commit(id)return Ledger.Finish(self.State,id,true)end
function Stock:Release(id)return Ledger.Finish(self.State,id,false)end
return Stock
