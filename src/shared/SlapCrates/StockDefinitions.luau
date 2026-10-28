--!nonstrict
-- No approved limited editions yet. Never change an existing edition supply to restock it.
-- Rewards[RewardId] = {LimitedStock=true, TotalSupply=<approved>, EditionId=<immutable id>}
-- Variations[VariationId] = {LimitedStock=true, DefaultStock=<approved>, EditionId=<immutable id>}
return {Rewards={},Variations={}}
