--!nonstrict
-- Weight of a variation is divided equally among its currently eligible base Slaps.
local Odds={}
function Odds.Resolve(crate,catalog,inventory,stock,resourcesAvailable)
 local results={};local excluded={};local total=0;local hasWeights=false
 for vid,weight in pairs(crate.Weights)do
  hasWeights=true
  if not catalog.Variations.ById[vid] or type(weight)~="number" or weight~=weight or weight<0 or weight==math.huge then return nil,"InvalidWeights" end
  if weight==0 then continue end
  local candidates={}
  for id,reward in pairs(catalog.Rewards)do
   if reward.VariationId~=vid then continue end
   if crate.DuplicatePolicy=="UniquePerPlayer" and inventory.Owned.Slaps[id] then table.insert(excluded,{Reward=reward,Reason="AlreadyOwned"});continue end
   if resourcesAvailable and not resourcesAvailable(reward)then table.insert(excluded,{Reward=reward,Reason="ResourceUnavailable"});continue end
   local view,reason=stock:View(reward,catalog.Variations.ById[vid])
   if not view then return nil,reason or "StockUnknown" end
   if not view.SoldOut then table.insert(candidates,{Reward=reward,Stock=view})else table.insert(excluded,{Reward=reward,Stock=view,Reason="SoldOut"})end
  end
  for _,row in ipairs(candidates)do row.Weight=weight/#candidates;total+=row.Weight;table.insert(results,row)end
 end
 if not hasWeights or total<=0 or total==math.huge then return nil,"NoEligibleResults",excluded end
 table.sort(results,function(a,b)return a.Reward.RewardId<b.Reward.RewardId end)
 for _,row in ipairs(results)do row.Probability=row.Weight/total;row.Percent=row.Probability*100 end
 return results,nil,excluded
end
function Odds.Roll(results,unit)
 assert(type(unit)=="number" and unit>=0 and unit<1,"InvalidRandom")
 local sum=0 for _,row in ipairs(results)do sum+=row.Probability;if unit<sum then return row.Reward end end
 return results[#results].Reward
end
return Odds
