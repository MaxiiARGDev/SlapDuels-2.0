--!nonstrict
-- Explicit ordinary crate provenance only. Legacy entitlements are never tradable units.
local Policy={}
Policy.AllowedSlapIds={Classic=true}
Policy.NonTradableSlapIds={}
Policy.AllowedVariationIds={Common=true,Uncommon=true,Rare=true,Gold=true,Arcoiris=true,Emote=true,Wings=true,Epic=true,Legendary=true,Blood=true,Galaxy=true}
Policy.NonTradableRewardIds={['Classic:Basic']=true}
Policy.NonTradableSourceTypes={Premium=true,Temporary=true,Test=true,Reward=true}
function Policy.Check(unit,inventory,uid,catalog)
 if type(unit)~='table' or type(unit.UnitId)~='string' or unit.OwnerUserId~=uid then return false,'OwnershipMismatch' end
 local reward=catalog.Rewards[unit.RewardId]
 if not reward or reward.SlapId~=unit.SlapId or reward.VariationId~=unit.VariationId then return false,'InvalidVariation' end
 if type(inventory.Owned)~='table' or type(inventory.Owned.Slaps)~='table' or inventory.Owned.Slaps[unit.RewardId]~=true then return false,'NotOwned' end
 local variation=catalog.Variations.ById[unit.VariationId]
 if not Policy.AllowedSlapIds[unit.SlapId]or Policy.NonTradableSlapIds[unit.SlapId]then return false,'RestrictedSlap'end
 if not Policy.AllowedVariationIds[unit.VariationId] or Policy.NonTradableRewardIds[unit.RewardId] then return false,'RestrictedItem' end
 if unit.Locked or unit.TradeLocked or unit.NonTradable or unit.PremiumOnly or unit.Temporary or unit.TestOnly or reward.LimitedStock or variation.LimitedStock then return false,'RestrictedItem' end
 if unit.Origin~='Crate' or Policy.NonTradableSourceTypes[unit.Origin] then return false,'RestrictedSource' end
 local op=type(inventory.CrateOperations)=='table' and inventory.CrateOperations[unit.OperationId]
 if type(op)~='table'then return false,'UnverifiedProvenance'end
 local crate=op and catalog.Crates.ById[op.CrateId]
 if not crate or crate.PremiumOnly or op.OwnerUserId~=uid or op.State~='Completed' then return false,'UnverifiedProvenance' end
 -- The immutable opening journal must really contain this unit, including batch rewards.
 local found=op.UnitId==unit.UnitId and op.RewardId==unit.RewardId
 if op.Rewards~=nil and type(op.Rewards)~='table'then return false,'UnverifiedProvenance'end
 for _,row in ipairs(op.Rewards or {})do if type(row)=='table'and row.UnitId==unit.UnitId and row.RewardId==unit.RewardId then found=true end end
 if not found then return false,'UnverifiedProvenance' end
 return true
end
return Policy
