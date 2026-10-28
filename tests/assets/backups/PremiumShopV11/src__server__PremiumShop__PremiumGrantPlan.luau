--!nonstrict
-- PREPARATION ONLY: copy-on-write on the existing profile schema. No live grant or persistence.
local RS=game:GetService("ReplicatedStorage")
local Inventory=require(RS.Shared.SlapCrates.Inventory)
local Plan={}
function Plan.Stage(data,product,receipt)
 if type(receipt)~="table"or type(receipt.PurchaseId)~="string"or receipt.PurchaseId==""or product.DeveloperProductId~=receipt.ProductId then return nil,"InvalidReceipt"end
 if type(data)~="table"or type(data.Coins)~="number"or data.Coins~=data.Coins or data.Coins<0 or data.Coins==math.huge then return nil,"InvalidProfile"end
 local inv=Inventory.Extend(data.Inventory);inv.PremiumReceipts=inv.PremiumReceipts or {};inv.PremiumPurchases=inv.PremiumPurchases or {}
 local prior=inv.PremiumReceipts[receipt.PurchaseId]
 if prior then
  if prior.ProductId~=receipt.ProductId or prior.PlayerId~=receipt.PlayerId then return nil,"ReceiptConflict"end
  return data,nil,true
 end
 if product.BlockedReason then return nil,product.BlockedReason end
 if product.DuplicatePolicy=="OncePerPlayer"and inv.PremiumPurchases[product.Id]then return nil,"AlreadyPurchased"end
 local rewards=product.Rewards;local quantity=0
 for _,item in ipairs(rewards.Slaps)do
  local id=item.SlapId..":"..item.VariationId
  if product.DuplicatePolicy~="RepeatableNoCompensation"and inv.Owned.Slaps[id]then return nil,"AlreadyOwned"end
  quantity+=1;local unitId="Premium:"..receipt.PurchaseId..":"..quantity
  inv.Owned.Slaps[id]=true;inv.SlapUnits[unitId]={UnitId=unitId,RewardId=id,SlapId=item.SlapId,VariationId=item.VariationId,OwnerUserId=receipt.PlayerId,Origin="PremiumGuaranteed",PurchaseId=receipt.PurchaseId}
 end
 inv.Owned.DeathEffects=inv.Owned.DeathEffects or {}
 for _,id in ipairs(rewards.KillEffects)do
  if product.DuplicatePolicy~="RepeatableNoCompensation"and inv.Owned.DeathEffects[id]then return nil,"AlreadyOwned"end
  inv.Owned.DeathEffects[id]=true
 end
 for _,item in ipairs(rewards.Crates)do inv.Crates[item.CrateId]=(inv.Crates[item.CrateId]or 0)+item.Quantity end
 inv.PremiumReceipts[receipt.PurchaseId]={ProductId=receipt.ProductId,PlayerId=receipt.PlayerId,ContractVersion=product.ContractVersion}
 inv.PremiumPurchases[product.Id]=true
 local nextData=table.clone(data);nextData.Inventory=inv;nextData.Coins=data.Coins+rewards.Coins
 if nextData.Coins==math.huge or nextData.Coins%1~=0 then return nil,"InvalidCoinTotal"end
 return nextData,nil,false
end
return Plan
