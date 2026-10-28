--!nonstrict
local Inventory={}
function Inventory.Copy(value)
 if type(value)~="table" then return value end
 local result={} for k,v in pairs(value)do result[k]=Inventory.Copy(v)end return result
end
function Inventory.Extend(raw)
 local inv=Inventory.Copy(raw or {Owned={},Equipped={}})
 inv.Owned=inv.Owned or {};inv.Equipped=inv.Equipped or {}
 inv.Owned.Slaps=inv.Owned.Slaps or {};inv.Owned.Slaps["Classic:Basic"]=true
 -- Legacy base ownership preserved and represented only as its Basic cosmetic.
 for id,owned in pairs(inv.Owned.Slaps)do if owned==true and not id:find(":",1,true)then inv.Owned.Slaps[id..":Basic"]=true end end
 inv.Equipped.Slaps=inv.Equipped.Slaps or "Classic:Basic"
 inv.Crates=inv.Crates or {};inv.SlapUnits=inv.SlapUnits or {};inv.CrateOperations=inv.CrateOperations or {}
 return inv
end
-- Preserve rich fields, including unknown future units, without a destructive migration.
function Inventory.Preserve(raw, sanitized)
 for _,key in ipairs({"Crates","SlapUnits","CrateOperations","PremiumReceipts","PremiumPurchases"})do
  if raw and raw[key]~=nil then sanitized[key]=Inventory.Copy(raw[key]) end
 end
 return Inventory.Extend(sanitized)
end
function Inventory.Validate(inv)
 for _,key in ipairs({"Crates","SlapUnits","CrateOperations"})do if type(inv[key])~="table" then return false,"InvalidCrateInventory" end end
 for id,n in pairs(inv.Crates)do if type(id)~="string" or type(n)~="number" or n<0 or n%1~=0 or n==math.huge then return false,"InvalidCrateInventory" end end
 local count=0 for _,op in pairs(inv.CrateOperations)do
  if type(op)~="table" then return false,"InvalidCrateInventory" end;count+=1
 end
 if count>=256 then return false,"JournalCapacityReached" end
 return true
end
return Inventory
