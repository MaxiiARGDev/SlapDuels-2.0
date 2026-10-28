--!nonstrict
-- Approved tier-relative balance: own 60%, immediate neighbours 20% each.
-- At either boundary the missing neighbour's weight goes to the crate's own tier (80/20).
local Matrix={VariationOrder={"Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy"},Rows={
}}
for index,id in ipairs(Matrix.VariationOrder)do
 local row=table.create(#Matrix.VariationOrder,0)
 row[index]=60
 if index>1 then row[index-1]=20 else row[index]+=20 end
 if index<#Matrix.VariationOrder then row[index+1]=20 else row[index]+=20 end
 Matrix.Rows[id]=row
end
function Matrix.WeightsFor(id)
 local row=assert(Matrix.Rows[id],"UnknownMatrixCrate:"..tostring(id))
 local weights={} for i,vid in ipairs(Matrix.VariationOrder)do weights[vid]=row[i]end
 return weights
end
return Matrix
