--!nonstrict
-- One callback, one durable backend contract. No in-memory success is ever acknowledged.
local Coordinator={};Coordinator.__index=Coordinator
local function positive(n)return type(n)=="number"and n==n and n>0 and n<math.huge and n%1==0 end
function Coordinator.new(registry,backend,players,options)
 options=options or {}
 return setmetatable({Registry=registry,Backend=backend,Players=players,InFlight={},Reserved=options.Reserved or {},Delivered=options.Delivered},Coordinator)
end
function Coordinator:Process(receipt)
 local pending=Enum.ProductPurchaseDecision.NotProcessedYet
 if type(receipt)~="table"or not positive(receipt.PlayerId)or not positive(receipt.ProductId)
  or type(receipt.PurchaseId)~="string"or #receipt.PurchaseId==0 or #receipt.PurchaseId>200 then return pending end
 local product=self.Registry.ByProductId[receipt.ProductId]
 if not product or product.IsPlaceholder~=false or self.Reserved[receipt.ProductId]or not product.PurchaseApproved or not product.ContentsApproved then return pending end
 local backend=self.Backend
 if not backend or backend.DurableValidated~=true or type(backend.ApplyReceiptAtomic)~="function"then return pending end
 local player=self.Players:GetPlayerByUserId(receipt.PlayerId)
 if (not player or player.Parent~=self.Players)and backend.SupportsOffline~=true then return pending end
 if self.InFlight[receipt.PurchaseId]then return pending end
 self.InFlight[receipt.PurchaseId]=true
 -- Backend must atomically persist rewards AND PurchaseId in the same owned profile transaction,
 -- serialize with gameplay/profile saves, handle reconnects/cross-server ownership and return only after durability.
 local ok,confirmation=pcall(backend.ApplyReceiptAtomic,backend,player,receipt,product)
 self.InFlight[receipt.PurchaseId]=nil
 if ok and type(confirmation)=="table"and confirmation.Durable==true and confirmation.PurchaseId==receipt.PurchaseId
  and confirmation.PlayerId==receipt.PlayerId and confirmation.ProductId==receipt.ProductId then
  if self.Delivered then pcall(self.Delivered,receipt.PlayerId,confirmation,product)end
  return Enum.ProductPurchaseDecision.PurchaseGranted
 end
 return pending
end
return Coordinator
