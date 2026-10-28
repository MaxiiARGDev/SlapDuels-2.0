--!nonstrict
-- The current approved catalogue has unlimited supply. Ownership/units live in profiles.
-- Never use server-local stock for a future globally limited item.
local Ledger=require(script.Parent.StockLedger)
local Stock={};Stock.__index=Stock
function Stock.new(catalog)
 for _,r in pairs(catalog.Rewards)do local v=catalog.Variations.ById[r.VariationId];local cs=Ledger.Constraints(r,v);assert(cs and #cs==0,'Limited stock needs a durable global backend before enabling this catalogue')end
 return setmetatable({Scope='ProductionUnlimited_ProfileUnitsDurable',WritesToCloud=false},Stock)
end
function Stock:View(r,v)
 local cs,why=Ledger.Constraints(r,v);if not cs or #cs~=0 then return nil,why or 'LimitedStockBackendRequired'end
 return Ledger.View({Buckets={},Operations={}},cs,r.RewardId)
end
function Stock:Reserve(_id,_uid,r,v)local view,why=self:View(r,v);return view~=nil,why end
function Stock:Commit(_id)return true end
function Stock:Release(_id)return true end
return Stock
