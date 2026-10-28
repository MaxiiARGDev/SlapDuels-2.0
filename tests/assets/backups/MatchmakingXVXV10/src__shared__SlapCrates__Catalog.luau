--!nonstrict
local Registry=require(script.Parent.Registry)
local Catalog={}
Catalog.Variations=Registry.Build(require(script.Parent.VariationDefinitions),"Id")
Catalog.Slaps=Registry.Build(require(script.Parent.SlapDefinitions),"SlapId",function(d)
 assert(type(d.Model)=="string" and type(d.VariationIds)=="table","InvalidSlap")
 local seen={} for _,id in ipairs(d.VariationIds)do assert(Catalog.Variations.ById[id] and not seen[id],"InvalidVariation");seen[id]=true end
end)
Catalog.Crates=Registry.Build(require(script.Parent.CrateDefinitions),"CrateId",function(d)
 assert(type(d.SortOrder)=="number" and d.SortOrder==d.SortOrder and math.abs(d.SortOrder)<math.huge,"InvalidCrateSortOrder")
 assert(d.AnimationProfile=="Horizontal","UnsupportedAnimationProfile")
 assert(type(d.Model)=="string" and type(d.Icon)=="string" and type(d.Weights)=="table","InvalidCrateDefinition")
 local sum,count=0,0
 for id,weight in pairs(d.Weights)do
  assert(Catalog.Variations.ById[id]and type(weight)=="number"and weight==weight and weight>=0 and weight<math.huge,"InvalidCrateWeight")
  sum+=weight;count+=1
 end
 if d.MatrixVersion=="InitialV13Review"then assert(count==12 and math.abs(sum-100)<1e-9,"InvalidInitialMatrixSum")end
 assert(d.SoldOutPolicy=="ExcludeAndRenormalize","UnknownSoldOutPolicy")
 assert(d.DuplicatePolicy=="UniquePerPlayer" or d.DuplicatePolicy=="AllowDuplicates","UnapprovedDuplicatePolicy")
 assert(type(d.RollDuration)=="number" and d.RollDuration>=1 and d.RollDuration<=30,"InvalidDuration")
end)
Catalog.Rewards={}
for _,sid in ipairs(Catalog.Slaps.Order)do
 for _,vid in ipairs(Catalog.Slaps.ById[sid].VariationIds)do
  local v=Catalog.Variations.ById[vid];local id=sid..":"..vid
  Catalog.Rewards[id]={RewardId=id,SlapId=sid,VariationId=vid,DisplayName=Catalog.Slaps.ById[sid].DisplayName.." ["..v.DisplayName.."]",
   LimitedStock=false,TotalSupply=nil,EditionId=nil}
 end
end
local stock=require(script.Parent.StockDefinitions)
for id,definition in pairs(stock.Rewards)do
 local reward=assert(Catalog.Rewards[id],"UnknownStockReward:"..id)
 reward.LimitedStock=definition.LimitedStock;reward.TotalSupply=definition.TotalSupply;reward.EditionId=definition.EditionId
end
for id,definition in pairs(stock.Variations)do
 local variation=assert(Catalog.Variations.ById[id],"UnknownStockVariation:"..id)
 variation.LimitedStock=definition.LimitedStock;variation.DefaultStock=definition.DefaultStock;variation.EditionId=definition.EditionId
end
-- Production hard gate: requires a reviewed durable profile journal/session owner backend.
Catalog.ProductionCommerceEnabled=false
Catalog.DefaultRewardId="Classic:Basic"
return Catalog
