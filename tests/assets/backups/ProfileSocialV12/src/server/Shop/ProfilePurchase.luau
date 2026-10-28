--!strict
-- Pure staging only: no profile, provider, notifications, yields or persistence.
local Purchase = {}
function Purchase.Stage(data: any, product: any): (any?, string?)
 if type(product) ~= "table" or product.Currency ~= "Coins" or (product.ProductType ~= "Cosmetic" and product.ProductType ~= "Ability") then return nil,"UnsupportedProduct" end
 if product.ProductType == "Ability" and (product.Category ~= "Abilities" or type(product.Metadata) ~= "table"
  or product.Metadata.PurchaseEnabled ~= true or product.Metadata.PriceApproved ~= true) then return nil,"PurchasesNotEnabled" end
 if type(product.Id) ~= "string" or product.Id == "" or type(product.Category) ~= "string" or product.Category == "" then return nil,"InvalidProductId" end
 local price = product.Price
 if type(price) ~= "number" or price ~= price or price < 0 or price == math.huge or price % 1 ~= 0 then return nil,"InvalidPrice" end
 if not product.IsAvailable then return nil,"ProductUnavailable" end
 if type(data) ~= "table" or type(data.Coins) ~= "number" or data.Coins ~= data.Coins or data.Coins < 0 or data.Coins == math.huge then return nil,"InvalidProfile" end
 local inventory = data.Inventory
 if type(inventory) ~= "table" or type(inventory.Owned) ~= "table" or type(inventory.Equipped) ~= "table" then return nil,"InvalidInventory" end
 local owned = inventory.Owned[product.Category]
 if owned and owned[product.Id] == true then return nil,"AlreadyOwned" end
 if data.Coins < price then return nil,"InsufficientFunds" end
 -- Copy-on-write: an exception while staging cannot leave half a purchase.
 local nextData = table.clone(data)
 local nextInventory = table.clone(inventory)
 nextInventory.Owned = table.clone(inventory.Owned)
 local nextOwned = table.clone(owned or {})
 nextOwned[product.Id] = true
 nextInventory.Owned[product.Category] = nextOwned
 nextData.Inventory = nextInventory
 nextData.Coins = data.Coins - price
 return nextData,nil
end
return Purchase
