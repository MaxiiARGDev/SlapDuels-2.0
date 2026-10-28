--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Inventory=require(RS.Shared.SlapCrates.Inventory)
local Providers={}
function Providers.Create(service)
 local crates={}
 function crates:GetCategory()return "Crates"end
 function crates:GetProducts()
  -- Premium crates belong to PremiumShop's receipt flow, not this Coins provider.
  -- Draft Robux entries without product IDs must never abort Slaps registration.
  local products={}
  for _,product in ipairs(service:GetCatalog())do
   if product.Currency=='Coins'and not(product.Metadata and product.Metadata.PremiumOnly)then table.insert(products,product)end
  end
  return products
 end
 function crates:GetProduct(id)for _,p in ipairs(self:GetProducts())do if p.Id==id then return p end end end
 function crates:CanPurchase()return false,"UseCratePurchaseWithOdds"end
 function crates:CanEquip()return false,"NotEquippable"end
 function crates:OnPurchased()return false,"UseCratePurchaseWithOdds"end
 function crates:OnEquipped()return false,"NotEquippable"end
 function crates:OnUnequipped()return false,"NotEquippable"end
 local slaps={}
 function slaps:GetCategory()return "Slaps"end
 function slaps:GetProduct(id)
  local reward=Catalog.Rewards[id];if not reward then return nil end
  return {Id=id,Category="Slaps",ProductType="Cosmetic",DisplayName=reward.DisplayName,Description="Se obtiene mediante cajas. Selección para el próximo combate.",
   Price=0,Currency="Coins",Rarity=reward.VariationId,Icon=Catalog.Variations.ById[reward.VariationId].Icon,
   IsAvailable=service:_resource(reward),Metadata={CrateExclusive=true,PurchaseEnabled=false}}
 end
 function slaps:GetProducts()local r={}for id in pairs(Catalog.Rewards)do table.insert(r,self:GetProduct(id))end;return r end
 function slaps:CanPurchase()return false,"CrateExclusive"end
 function slaps:OnPurchased()return false,"CrateExclusive"end
 function slaps:CanEquip(player,product)
  local ps=service:_players();if not ps:IsShopDataReady(player)then return false,"DataNotLoaded"end
  if not service:_lobby(player)then return false,"LobbyOnly"end
  local r=Catalog.Rewards[product.Id];local inv=Inventory.Extend(ps:GetInventory(player))
  if not r or not inv.Owned.Slaps[product.Id]then return false,"NotOwned"end
  if not service:_resource(r)then return false,"ProductUnavailable"end
  return true
 end
 function slaps:OnEquipped(player,product)
  local ok,err=self:CanEquip(player,product);if not ok then return false,err end
  return service:_players():SetEquippedItem(player,"Slaps",product.Id)
 end
 function slaps:OnUnequipped(player)return self:OnEquipped(player,self:GetProduct(Catalog.DefaultRewardId))end
 return {crates,slaps}
end
return Providers
