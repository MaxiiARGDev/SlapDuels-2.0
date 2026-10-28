--!nonstrict
-- Formats the authoritative Quote only; never estimates, samples or grants rewards.
local Presentation={}
local reasons={SoldOut="AGOTADO",AlreadyOwned="YA ADQUIRIDO",ResourceUnavailable="RECURSO NO DISPONIBLE"}
function Presentation.Rows(quote)
 local entries={}
 for _,row in ipairs(quote.Outcomes or {})do table.insert(entries,{Row=row,Excluded=false})end
 for _,row in ipairs(quote.ExcludedOutcomes or {})do table.insert(entries,{Row=row,Excluded=true})end
 table.sort(entries,function(a,b)
  local x,y=a.Row.SortOrder or math.huge,b.Row.SortOrder or math.huge
  return if x==y then tostring(a.Row.RewardId)<tostring(b.Row.RewardId)else x<y
 end)
 local result={}
 for _,entry in ipairs(entries)do
  local row=entry.Row;local stock=row.Stock
  local status=if entry.Excluded then reasons[row.Reason]or tostring(row.Reason)
   elseif stock and stock.UnlimitedStock then "Ilimitado"else tostring(stock and stock.RemainingStock or "?").." disponibles"
  local amount=if entry.Excluded then "0"else string.format("%.10g",row.Percent)
  table.insert(result,{Text=(row.SlapName or row.SlapId or row.DisplayName).." · "..(row.VariationName or row.VariationId or "").." — "..amount.." %\n"..status,
   Color=row.Color,RewardId=row.RewardId,Excluded=entry.Excluded})
 end
 return result
end
return Presentation
