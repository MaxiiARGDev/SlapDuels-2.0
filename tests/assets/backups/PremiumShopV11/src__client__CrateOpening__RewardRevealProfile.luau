--!nonstrict
local Config=require(script.Parent.RewardRevealConfig)
local Existing=require(script.Parent.VisualProfile)
local Profiles={}
function Profiles.ValidPercent(p)return type(p)=="number"and p==p and p>0 and p<=100 end
function Profiles.For(percent,variation)
 local rank;local thresholds=Config.Thresholds
 if Profiles.ValidPercent(percent)then
  rank=if percent>thresholds.NormalAbove then 1 elseif percent>=thresholds.FeaturedAtLeast then 2
   elseif percent>=thresholds.RareAtLeast then 3 elseif percent>=thresholds.UltraAtLeast then 4 else 5
 else rank=math.clamp(Existing.For(variation).Tier-1,1,#Config.Profiles)end
 local result=table.clone(Config.Profiles[rank]);result.Rank=rank
 result.Percent=if Profiles.ValidPercent(percent)then percent else nil
 result.Color=variation.Color;return result
end
function Profiles.Best(units,catalog)
 local best,index
 for i,unit in ipairs(units)do
  local reward=catalog.Rewards[unit.RewardId];local variation=reward and catalog.Variations.ById[reward.VariationId]
  if variation then
   local p=Profiles.For(unit.EffectivePercent,variation)
   if not best or(p.Percent and(not best.Percent or p.Percent<best.Percent))or(not p.Percent and not best.Percent and p.Rank>best.Rank)then best=p;index=i end
  end
 end
 return best,index
end
return Profiles
