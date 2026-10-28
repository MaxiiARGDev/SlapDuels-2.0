--!nonstrict
-- Pure leases; never grants inventory or Coins. Time is injected and authoritative.
local Ledger={};Ledger.__index=Ledger
function Ledger.new(config,plan,clock)
 return setmetatable({Config=config,Plan=plan,Clock=clock,Players={},Stands={},Cooldowns={}},Ledger)
end
function Ledger:Release(userId,committed)
 local row=self.Players[userId];if not row then return end
 self.Players[userId]=nil
 if self.Stands[row.StandId]==row then self.Stands[row.StandId]=nil end
 if committed or row.Committed then
  local key=tostring(userId)..":"..row.StandId
  self.Cooldowns[key]=math.max(self.Cooldowns[key]or 0,self.Clock()+self.Config.Stand.ReopenCooldown)
 end
 return row
end
function Ledger:Acquire(userId,standId,operationId)
 self:Step()
 local existing=self.Players[userId]
 if existing then
  if existing.StandId==standId and existing.OperationId==operationId then return existing,nil,true end
  return nil,"OpeningInProgress"
 end
 if self.Clock()<(self.Cooldowns[tostring(userId)..":"..standId]or 0)then return nil,"StandCooldown"end
 if self.Config.Stand.ExclusiveOpening and self.Stands[standId]then return nil,"StandBusy"end
 local row={UserId=userId,StandId=standId,OperationId=operationId,State="Reserved",Until=self.Clock()+self.Config.Stand.MaxSequenceDuration}
 self.Players[userId]=row
 if self.Config.Stand.ExclusiveOpening then self.Stands[standId]=row end
 return row
end
function Ledger:Commit(row,openingId)
 if self.Players[row.UserId]~=row or row.Committed then return false end
 row.Committed=true;row.OpeningId=openingId;row.Started=self.Clock();row.State="Opening"
 row.Until=row.Started+self.Plan.Duration
 return true
end
function Ledger:Step()
 local expired={};local now=self.Clock()
 for id,row in pairs(self.Players)do
  if now>=row.Until then table.insert(expired,id)
  elseif row.Committed then
   local elapsed=now-row.Started
   local reward=self.Plan.Stages[8].Start;local outro=self.Plan.Stages[9].Start
   row.State=if elapsed>=outro then "Finishing"elseif elapsed>=reward then "Revealing"else "Opening"
  end
 end
 local released={};for _,id in ipairs(expired)do table.insert(released,self:Release(id))end
 for key,deadline in pairs(self.Cooldowns)do if now>=deadline then self.Cooldowns[key]=nil end end
 return released
end
return Ledger
