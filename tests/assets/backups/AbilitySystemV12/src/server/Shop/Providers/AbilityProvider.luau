--!nonstrict
local Definitions=require(game.ReplicatedStorage.Shared.AbilityDefinitions)
local Provider={}
local function players() return require(game.ServerScriptService.Services.PlayerService) end
function Provider:GetCategory() return Definitions.Category end
function Provider:GetProduct(id)
 local d=Definitions.Items[id]
 if not d then return nil end
 local approved=d.PriceApproved==true and type(d.Price)=="number" and d.Price>0
  and d.Price<math.huge and d.Price%1==0
 return {Id=id,Category=Definitions.Category,ProductType="Ability",DisplayName=d.DisplayName,
  Description=d.Description,Price=if id==Definitions.DefaultId then 0 elseif approved then d.Price else 0,
  Currency="Coins",Rarity="Common",Icon=d.Icon,IsAvailable=d.Enabled==true,
  Metadata={PurchaseEnabled=approved and d.PurchaseEnabled==true,PricePending=id~=Definitions.DefaultId and not approved,
   Cooldown=d.Cooldown,Duration=d.Duration}}
end
function Provider:GetProducts()
 local result={} for _,id in ipairs(Definitions.Order) do table.insert(result,self:GetProduct(id)) end return result
end
function Provider:CanPurchase(player,product)
 local actual=self:GetProduct(product.Id)
 if not actual or not actual.IsAvailable then return false,"ProductUnavailable" end
 if players():HasItem(player,Definitions.Category,product.Id) then return false,"AlreadyOwned" end
 if not actual.Metadata.PurchaseEnabled then return false,"PurchasesNotEnabled" end
 return true
end
function Provider:CanEquip(player,product)
 if not players():IsShopDataReady(player) then return false,"DataNotLoaded" end
 if not self:GetProduct(product.Id) or not players():HasItem(player,Definitions.Category,product.Id) then return false,"NotOwned" end
 -- Shop equipment is only the saved preference, never the current round selection.
 return true
end
function Provider:OnEquipped(player,product)
 local ok,reason=self:CanEquip(player,product);if not ok then return false,reason end
 return players():SetEquippedItem(player,Definitions.Category,product.Id)
end
function Provider:OnUnequipped(player,_product) return players():SetEquippedItem(player,Definitions.Category,Definitions.DefaultId) end
function Provider:OnPurchased(player,product)
 local ok,reason=self:CanPurchase(player,product);if not ok then return false,reason end
 return players():CommitShopPurchase(player,self:GetProduct(product.Id))
end
return Provider
