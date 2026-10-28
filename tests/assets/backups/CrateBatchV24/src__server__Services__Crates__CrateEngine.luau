--!nonstrict
-- Pure staging on the EXISTING profile, then stock reservation; presentation never grants items.
local RS=game:GetService("ReplicatedStorage")
local Inventory=require(RS.Shared.SlapCrates.Inventory)
local Odds=require(RS.Shared.SlapCrates.Odds)
local Engine={}
function Engine.Approved(crate)
 return crate and crate.Enabled==true and crate.PriceApproved==true and crate.OddsApproved==true
  and type(crate.PriceCoins)=="number" and crate.PriceCoins>0 and crate.PriceCoins<math.huge and crate.PriceCoins%1==0
end
function Engine.Stage(data,crate,kind,id,uid,catalog,stock,unit,available)
 if not Engine.Approved(crate)then return nil,"CommercialApprovalPending" end
 local inv=Inventory.Extend(data.Inventory);local old=inv.CrateOperations[id]
 if old then
  if old.Kind~=kind or old.CrateId~=crate.CrateId then return nil,"OperationConflict" end
  return data,nil,old,true
 end
 local valid,reason=Inventory.Validate(inv);if not valid then return nil,reason end
 local rows,err=Odds.Resolve(crate,catalog,inv,stock,available);if not rows then return nil,err end
 local nextData=table.clone(data);nextData.Inventory=inv
 local op={OperationId=id,Kind=kind,CrateId=crate.CrateId,State="Committed",OwnerUserId=uid,CreatedAt=os.time()}
 if kind=="Purchase" then
  if type(data.Coins)~="number" or data.Coins~=data.Coins or data.Coins==math.huge or data.Coins<crate.PriceCoins then return nil,"InsufficientFunds" end
  nextData.Coins=data.Coins-crate.PriceCoins;inv.Crates[crate.CrateId]=(inv.Crates[crate.CrateId] or 0)+1
 elseif kind=="Open" then
  if (inv.Crates[crate.CrateId] or 0)<1 then return nil,"NoCrate" end
  local reward=Odds.Roll(rows,unit)
  local v=catalog.Variations.ById[reward.VariationId]
  op.RewardId=reward.RewardId;op.SlapId=reward.SlapId;op.VariationId=reward.VariationId
  op.EditionId=reward.EditionId;op.VariationEditionId=v.EditionId
  -- Unit identity stays original, scoped by owner and unique operation, including negative Studio IDs.
  op.UnitId=tostring(uid)..":"..id;op.State="GrantCommitted"
  inv.Crates[crate.CrateId]-=1;inv.Owned.Slaps[reward.RewardId]=true
  inv.SlapUnits[op.UnitId]={UnitId=op.UnitId,RewardId=reward.RewardId,SlapId=reward.SlapId,VariationId=reward.VariationId,
   OperationId=id,OwnerUserId=uid,EditionId=reward.EditionId,VariationEditionId=v.EditionId,Origin="Crate"}
  -- All allocations staged before the reservation. The caller still owns the only profile commit.
  local ok,why=stock:Reserve(op.UnitId,uid,reward,v);if not ok then return nil,why end
 else return nil,"InvalidOperation" end
 inv.CrateOperations[id]=op
 return nextData,nil,op,false
end
function Engine.Reconcile(data,stock)
 for _,op in pairs(data.Inventory.CrateOperations or {})do
  if op.Kind=="Open" and op.State=="GrantCommitted"then
   local ok=stock:Commit(op.UnitId);if ok then op.State="Completed" end
  end
 end
end
return Engine
