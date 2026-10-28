--!strict
-- Permanent blocks earned, plus only the unfinished consecutive-win block.
local Config=require(game:GetService('ReplicatedStorage').Shared.SocialPlayConfig)
local Streak={}
function Streak.Normalize(value: any): { [string]: any }
 local v=if type(value)=='table' then value else {}
 local function integer(n: any): number
  return if type(n)=='number' and n==n and n>=0 and n<9007199254740991 then math.floor(n) else 0
 end
 return {Total=integer(v.Total),Progress=integer(v.Progress)%Config.WinBlockSize,
  LastMatchId=if type(v.LastMatchId)=='string' and #v.LastMatchId<=128 then v.LastMatchId else nil}
end
function Streak.Apply(data: any,matchId: string,outcome: string): boolean
 if type(matchId)~='string' or #matchId==0 or #matchId>128 then return false end
 if outcome~='Win' and outcome~='Loss' and outcome~='Draw' then return false end
 local stats=Streak.Normalize(data.WinStreak)
 if stats.LastMatchId==matchId then return false end
 stats.LastMatchId=matchId
 if outcome=='Win' then
  stats.Progress+=1
  if stats.Progress==Config.WinBlockSize then stats.Total+=1;stats.Progress=0 end
 else stats.Progress=0 end
 data.WinStreak=stats
 return true
end
return Streak
