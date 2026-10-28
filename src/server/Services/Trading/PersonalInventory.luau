--!nonstrict
-- Own-only projection. No balances, trade journals or other players' inventories.
local Public=require(script.Parent.PublicInventory)
local View={Categories={Slaps=true,DeathEffects=true,PointEffects=true,Crates=true}}
function View.Valid(category,page,query)
 return type(category)=='string' and View.Categories[category]==true
  and type(page)=='number' and page==page and page%1==0 and page>=1 and page<=10000
  and type(query)=='string' and #query<=80
end
function View.Build(data,userId,catalog,category,products,crateProducts,page,query,pageSize)
 local rows={}
 if category=='Slaps' then
  local grouped={}
  for _,item in ipairs(Public.Build(data,userId,catalog))do
   local prior=grouped[item.ProductId]
   if prior then prior.Quantity+=1 else
    local row=table.clone(item);row.UnitId=nil;row.EntryId=row.ProductId;row.Quantity=1
    grouped[row.ProductId]=row;table.insert(rows,row)
   end
  end
 elseif category=='Crates' then
  local counts=data.Inventory and data.Inventory.Crates or {}
  for _,product in ipairs(crateProducts or {})do
   local n=counts[product.Id]
   if type(n)=='number' and n==n and n>0 and n<math.huge then
    table.insert(rows,{Category='Crates',ProductId=product.Id,EntryId=product.Id,DisplayName=product.DisplayName,
     Rarity=product.Rarity,Icon=product.Icon,Quantity=math.floor(n),Owned=true,Available=product.IsAvailable,
     Description=product.Description,Product=product})
   end
  end
 else rows=Public.Effects(data,category,products)end
 local total=#rows;local filtered={};query=string.lower(query)
 for _,row in ipairs(rows)do
  if query=='' or string.find(string.lower(row.DisplayName or ''),query,1,true) or string.find(string.lower(row.VariationName or ''),query,1,true)then table.insert(filtered,row)end
 end
 table.sort(filtered,function(a,b)
  if a.Equipped~=b.Equipped then return a.Equipped==true end
  return a.DisplayName==b.DisplayName and a.ProductId<b.ProductId or a.DisplayName<b.DisplayName
 end)
 local pages=math.max(1,math.ceil(#filtered/pageSize));page=math.min(page,pages);local items={}
 for i=(page-1)*pageSize+1,math.min(#filtered,page*pageSize)do table.insert(items,filtered[i])end
 return {UserId=userId,Category=category,Items=items,Total=total,FilteredTotal=#filtered,Page=page,Pages=pages,HasNext=page<pages}
end
return View
