--!nonstrict
-- Single-key ledger: reward and optional aggregate variation supply change atomically.
local Ledger={}
local function valid(n)return type(n)=="number" and n>=0 and n<math.huge and n%1==0 end
function Ledger.Constraints(reward,variation)
 local constraints={}
 for _,d in ipairs({{Definition=reward,Key="Reward:"..reward.RewardId},{Definition=variation,Key="Variation:"..variation.Id}})do
  local x=d.Definition
  if x.LimitedStock then
   if not valid(x.TotalSupply or x.DefaultStock) or type(x.EditionId)~="string" or x.EditionId=="" then return nil,"StockUnconfigured" end
   table.insert(constraints,{Key=d.Key..":"..x.EditionId,Supply=x.TotalSupply or x.DefaultStock,EditionId=x.EditionId})
  end
 end
 return constraints
end
function Ledger.View(state,constraints,rewardId)
 local remaining=nil;local issued=0;local totalSupply=nil
 for _,op in pairs(state.Operations)do if op.RewardId==rewardId and op.State=="Issued"then issued+=1 end end
 for _,c in ipairs(constraints)do
  local bucket=state.Buckets[c.Key]
  if bucket and bucket.Supply~=c.Supply then return nil,"SupplyChanged" end
  local n=bucket and bucket.Reserved or 0;local i=bucket and bucket.Issued or 0
  if not valid(n)or not valid(i)or n+i>c.Supply then return nil,"StockCorrupt" end
  remaining=math.min(remaining or math.huge,c.Supply-n-i)
  if c.Key:sub(1,7)=="Reward:"then totalSupply=c.Supply end
 end
 return {UnlimitedStock=#constraints==0,LimitedStock=#constraints>0,TotalSupply=totalSupply,RemainingStock=remaining,IssuedCount=issued,
  CurrentlyOwnedUnits=nil,UniqueOwnerCount=nil,SoldOut=remaining~=nil and remaining<=0,Scope="Ledger",Constraints=constraints}
end
function Ledger.Reserve(state,operationId,userId,reward,constraints)
 local existing=state.Operations[operationId]
 if existing then
  if existing.UserId~=userId or existing.RewardId~=reward.RewardId then return false,"OperationConflict" end
  return existing.State~="Released",existing.State=="Released" and "ReservationReleased" or nil
 end
 local size=0 for _ in pairs(state.Operations)do size+=1 end
 if size>=1024 then return false,"StockJournalCapacity" end
 local view,reason=Ledger.View(state,constraints,reward.RewardId);if not view then return false,reason end
 if view.SoldOut then return false,"SoldOut" end
 for _,c in ipairs(constraints)do
  local b=state.Buckets[c.Key] or {Supply=c.Supply,Reserved=0,Issued=0};state.Buckets[c.Key]=b;b.Reserved+=1
 end
 state.Operations[operationId]={UserId=userId,RewardId=reward.RewardId,State="Reserved",Constraints=constraints}
 return true
end
function Ledger.Finish(state,id,commit)
 local op=state.Operations[id];if not op then return false,"ReservationMissing" end
 local target=if commit then "Issued" else "Released"
 if op.State==target then return true end
 if op.State~="Reserved" then return false,"InvalidStockTransition" end
 for _,c in ipairs(op.Constraints)do local b=state.Buckets[c.Key];b.Reserved-=1;if commit then b.Issued+=1 end end
 op.State=target;return true
end
return Ledger
