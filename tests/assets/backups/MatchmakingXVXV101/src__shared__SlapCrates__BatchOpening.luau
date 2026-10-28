--!nonstrict
local Config=require(script.Parent.OpeningConfig)
local Batch={}
function Batch.Quantity(value)
 if value==nil then return 1 end
 if type(value)~="number"then return nil end
 for _,allowed in ipairs(Config.AllowedOpenQuantities)do if value==allowed then return value end end
 return nil
end
function Batch.Count(operation)return operation.Quantity or 1 end
function Batch.Rewards(operation)return operation.Rewards or {operation}end
return Batch
