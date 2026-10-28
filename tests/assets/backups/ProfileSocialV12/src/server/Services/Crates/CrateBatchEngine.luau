--!nonstrict
-- No-yield staging/reservations in one Studio server. Never a durable cross-server transaction.
local RS=game:GetService("ReplicatedStorage")
local Inventory=require(RS.Shared.SlapCrates.Inventory)
local Odds=require(RS.Shared.SlapCrates.Odds)
local VisualMetadata=require(script.Parent.RewardVisualMetadata)
local Batch={}
function Batch.Stage(data,crate,id,uid,catalog,stock,random,available,quantity)
 local inv=Inventory.Extend(data.Inventory)
 local valid,reason=Inventory.Validate(inv);if not valid then return nil,reason end
 if (inv.Crates[crate.CrateId]or 0)<quantity then return nil,"InsufficientCrates"end
 if type(random)~="function"then return nil,"InvalidRandomSource"end
 local nextData=table.clone(data);nextData.Inventory=inv
 local op={OperationId=id,BatchId=tostring(uid)..":"..id,UnitId=tostring(uid)..":"..id,
  Kind="Open",CrateId=crate.CrateId,Quantity=quantity,OwnerUserId=uid,CreatedAt=os.time(),
  State="GrantCommitted",PresentationSent=false,Rewards={}}
 local reserved={}
 local ok,failure=pcall(function()
  for index=1,quantity do
   -- Newly owned prizes and previous reservations alter eligibility for the next draw.
   local rows,why=Odds.Resolve(crate,catalog,inv,stock,available)
   if not rows then error(why or "NoEligibleResults",0)end
   local reward=Odds.Roll(rows,random());local variation=catalog.Variations.ById[reward.VariationId]
   local percent,eligible=VisualMetadata.Read(rows,reward.RewardId)
   if index==1 then op.PreviewRewardIds=eligible end
   local unitId=op.BatchId..":"..index
   table.insert(reserved,unitId) -- Also release if Reserve throws after allocating.
   local held,code=stock:Reserve(unitId,uid,reward,variation)
   if not held then error(code or "StockUnavailable",0)end
   local unit={UnitId=unitId,RewardId=reward.RewardId,SlapId=reward.SlapId,VariationId=reward.VariationId,
    OperationId=id,OwnerUserId=uid,EditionId=reward.EditionId,VariationEditionId=variation.EditionId,Origin="Crate",EffectivePercent=percent}
   table.insert(op.Rewards,unit);inv.SlapUnits[unitId]=unit;inv.Owned.Slaps[reward.RewardId]=true
  end
 end)
 if not ok then
  for _,unitId in ipairs(reserved)do stock:Release(unitId)end
  return nil,tostring(failure)
 end
 inv.Crates[crate.CrateId]-=quantity
 op.RewardId=op.Rewards[1].RewardId;op.SlapId=op.Rewards[1].SlapId;op.VariationId=op.Rewards[1].VariationId
 op.EffectivePercent=op.Rewards[1].EffectivePercent
 inv.CrateOperations[id]=op
 return nextData,nil,op,false
end
return Batch
