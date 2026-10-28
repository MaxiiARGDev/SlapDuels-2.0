--!strict
-- Pure deadline contract; callers supply monotonic/server network time for isolated tests.
local Clock={}
function Clock.Start(sessionId: string,index: number,duration: number,now: number,networkNow: number): any
 return {Id=sessionId..":Round:"..index,Index=index,Deadline=now+duration,NetworkDeadline=networkNow+duration,Resolved=nil,SuddenDeath=false}
end
function Clock.IsOpen(round: any,now: number): boolean
 return round~=nil and round.Resolved==nil and now<round.Deadline
end
function Clock.Remaining(round: any,now: number): number
 return math.max(0,math.ceil(round.Deadline-now))
end
function Clock.Resolve(round: any,kind: string,now: number): boolean
 if not round or round.Resolved~=nil then return false end
 if kind=="Timeout" then if now<round.Deadline then return false end
 elseif now>=round.Deadline then return false end
 round.Resolved=kind;round.ResolvedAt=now
 return true
end
return Clock
