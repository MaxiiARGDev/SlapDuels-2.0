--!nonstrict
local Profiles=require(script.Parent.ProfileReceiptStore)
local Backend={};Backend.__index=Backend
function Backend.Create(context,isStudio)
 local info=context.PersistenceInfo
 if isStudio or not info or info.Environment~="Production"or info.WritesToCloud~=true or info.ProviderName=="InMemory"then return nil,"TestingOrUnapprovedEnvironment"end
 local data=context:GetService("PlayerDataService")
 -- The current GetAsync + last-write SavePlayer lifecycle is NOT a fenced transaction owner.
 -- A verified bridge must serialize ALL saves/mutations, publish the committed runtime snapshot,
 -- and retain a handle across disconnect until its final fenced release.
 local bridge=data and data.GetPremiumProfileBridge and data:GetPremiumProfileBridge()
 if not bridge or bridge.FullyFenced~=true or bridge.SupportsOfflineReceipts~=true or type(bridge.CanPurchase)~="function"or type(bridge.RunReceiptTransaction)~="function"or type(bridge.ReadReceipts)~="function"then return nil,"ProfileLifecycleIntegrationPending"end
 return setmetatable({DurableValidated=true,SupportsOffline=true,Bridge=bridge,Profiles=Profiles.new(data:GetStore(),{ProfileVersion=bridge.ProfileVersion})},Backend)
end
function Backend:ApplyReceiptAtomic(_player,receipt,product)
 return self.Bridge:RunReceiptTransaction(receipt.PlayerId,function(handle)
  local result,why=self.Profiles:ApplyReceipt(handle,receipt,product)
  if not result then error(why,0)end
  -- Bridge must reconcile PlayerService before releasing its mutation/save lock.
  return result
 end)
end
function Backend:ReadReceipts(uid)return self.Bridge:ReadReceipts(uid)end
function Backend:CanPurchase(uid,product)return self.Bridge:CanPurchase(uid,product)end
return Backend
