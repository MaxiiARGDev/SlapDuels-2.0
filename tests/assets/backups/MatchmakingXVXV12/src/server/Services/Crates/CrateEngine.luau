--!nonstrict
-- Pure staging on the EXISTING profile, then stock reservation; presentation never grants items.
local RS=game:GetService("ReplicatedStorage")
local Inventory=require(RS.Shared.SlapCrates.Inventory)
local Odds=require(RS.Shared.SlapCrates.Odds)
local BatchRules=require(RS.Shared.SlapCrates.BatchOpening)
local BatchEngine=require(script.Parent.CrateBatchEngine)
local VisualMetadata=require(script.Parent.RewardVisualMetadata)
local Engine={}
function Engine.Approved(crate)
 if crate and crate.PremiumOnly then return crate.Enabled==true and crate.OddsApproved==true and crate.OpeningApproved==true end
 return crate and crate.Enabled==true and crate.PriceApproved==true and crate.OddsApproved==true
  and type(crate.PriceCoins)=="number" and crate.PriceCoins>0 and crate.PriceCoins<math.huge and crate.PriceCoins%1==0
end
function Engine.Stage(data,crate,kind,id,uid,catalog,stock,unit,available,quantity)
 if crate and crate.PremiumOnly and kind=="Purchase"then return nil,"PremiumPurchaseRequired"end
 quantity=BatchRules.Quantity(quantity);if not quantity then return nil,"InvalidQuantity"end
 if not Engine.Approved(crate)then return nil,"CommercialApprovalPending" end
 local inv=Inventory.Extend(data.Inventory);local old=inv.CrateOperations[id]
 if old then
  if old.Kind~=kind or old.CrateId~=crate.CrateId or(kind=="Open"and (old.Quantity or 1)~=quantity)then return nil,"OperationConflict" end
  -- Return the authoritative journal entry, not the deep copy used for staging.
  return data,nil,data.Inventory.CrateOperations[id],true
 end
 if kind=="Open"and quantity>1 then return BatchEngine.Stage(data,crate,id,uid,catalog,stock,unit,available,quantity)end
 local valid,reason=Inventory.Validate(inv);if not valid then return nil,reason end
 local rows,err=Odds.Resolve(crate,catalog,inv,stock,available);if not rows then return nil,err end
 local nextData=table.clone(data);nextData.Inventory=inv
 local op={OperationId=id,Kind=kind,CrateId=crate.CrateId,State="Committed",OwnerUserId=uid,CreatedAt=os.time()}
 if kind=="Purchase" then
  if type(data.Coins)~="number" or data.Coins~=data.Coins or data.Coins==math.huge or data.Coins<crate.PriceCoins then return nil,"InsufficientFunds" end
  nextData.Coins=data.Coins-crate.PriceCoins;inv.Crates[crate.CrateId]=(inv.Crates[crate.CrateId] or 0)+1
 elseif kind=="Open" then
  if (inv.Crates[crate.CrateId] or 0)<1 then return nil,"NoCrate" end
  local reward=Odds.Roll(rows,if type(unit)=="function"then unit()else unit)
  op.EffectivePercent,op.PreviewRewardIds=VisualMetadata.Read(rows,reward.RewardId)
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
function Engine.Release(op,stock)
 for _,unit in ipairs(BatchRules.Rewards(op))do if unit.UnitId then stock:Release(unit.UnitId)end end
end
function Engine.Reconcile(data,stock)
 local complete=true
 for _,op in pairs(data.Inventory.CrateOperations or {})do
  if op.Kind=="Open" and op.State=="GrantCommitted"then
   local all=true
   for _,unit in ipairs(BatchRules.Rewards(op))do
    local success,ok=pcall(stock.Commit,stock,unit.UnitId);if not success or not ok then all=false end
   end
   if all then op.State="Completed"else complete=false end
  end
 end
 return complete
end
return Engine
