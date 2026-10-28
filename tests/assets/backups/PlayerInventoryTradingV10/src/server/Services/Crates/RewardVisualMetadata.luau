--!nonstrict
-- Read-only snapshot of the distribution already used by Odds.Roll. Never rolls.
local Metadata={}
function Metadata.Read(rows,rewardId)
 local percent;local eligible={}
 for _,row in ipairs(rows)do
  if row.Probability>0 then table.insert(eligible,row.Reward.RewardId)end
  if row.Reward.RewardId==rewardId then percent=row.Percent end
 end
 return percent,eligible
end
return Metadata
