--!nonstrict
-- Pure transaction model. No yielding, remotes, clocks, random calls or cloud access.
local M={}
function M.Copy(v)
 if type(v)~='table'then return v end
 local out={};for k,x in pairs(v)do out[k]=M.Copy(x)end;return out
end
function M.Empty()return {Tickets={},Matches={}}end
function M.Prune(s,now)
 for id,m in pairs(s.Matches)do if now>=m.ExpiresAt then s.Matches[id]=nil end end
 for id,t in pairs(s.Tickets)do
  if now>=t.ExpiresAt or t.Match and not s.Matches[t.Match]then s.Tickets[id]=nil end
 end
end
function M.Add(s,t,c,now)
 if s.Tickets[t.Id]then return false,'AlreadyQueued'end
 local n=0;local ids={};for _,v in ipairs(t.Members)do if ids[v]then return false,'DuplicatePlayer'end;ids[v]=true end
 for _,existing in pairs(s.Tickets)do n+=1;for _,id in ipairs(existing.Members)do if ids[id]then return false,'AlreadyQueued'end end end
 if n>=c.MaxTickets then return false,'QueueFull'end
 s.Tickets[t.Id]=M.Copy(t);s.Tickets[t.Id].ExpiresAt=now+c.TicketTTL;return true
end
function M.Cancel(s,id,job)
 local t=s.Tickets[id];if not t then return true end
 if t.Job~=job then return false,'Forbidden'end
 if t.Match then return false,'MatchFound'end
 s.Tickets[id]=nil;return true
end
function M.Heartbeat(s,id,job,now,c)
 local t=s.Tickets[id];if not t or t.Job~=job then return false end
 t.ExpiresAt=now+(t.Match and c.MatchTTL or c.TicketTTL);return true
end
local function compatible(a,b,now,c)
 if now-math.min(a.CreatedAt,b.CreatedAt)>=c.RegionRelaxSeconds then return true end
 return a.Region==b.Region and math.abs(a.Ping-b.Ping)<=c.PingSpread
end
-- Bounded dynamic programming (at most 25 states for 4v4), never split a ticket.
function M.Select(s,size,now,c)
 local list={};for _,t in pairs(s.Tickets)do if not t.Match and t.ExpiresAt>now and #t.Members<=size then table.insert(list,t)end end
 table.sort(list,function(a,b)return a.CreatedAt==b.CreatedAt and a.Id<b.Id or a.CreatedAt<b.CreatedAt end)
 for _,anchor in ipairs(list)do
  local dp={['0:0']={Red={},Blue={}}}
  for _,t in ipairs(list)do if compatible(anchor,t,now,c)then
   local nextDP=table.clone(dp)
   for key,teams in pairs(dp)do
    local r,b=key:match('(%d+):(%d+)');r=tonumber(r);b=tonumber(b)
    for _,side in ipairs({'Red','Blue'})do
     local nr=r+(side=='Red'and #t.Members or 0);local nb=b+(side=='Blue'and #t.Members or 0)
     local k=nr..':'..nb
     if nr<=size and nb<=size and not nextDP[k]then
      local selected={Red=table.clone(teams.Red),Blue=table.clone(teams.Blue)}
      table.insert(selected[side],t.Id);nextDP[k]=selected
     end
    end
   end
   dp=nextDP
  end end
  if dp[size..':'..size]then return dp[size..':'..size]end
 end
end
function M.Assign(s,id,mode,size,job,now,c)
 local count=0;for _ in pairs(s.Matches)do count+=1 end;if count>=c.MaxMatches then return end
 local teams=M.Select(s,size,now,c);if not teams then return end
 local m={Id=id,Mode=mode,Size=size,Owner=job,State='Allocating',CreatedAt=now,ExpiresAt=now+c.MatchTTL,AllocateUntil=now+c.AllocationSeconds,Red={},Blue={},Parties={}}
 for _,side in ipairs({'Red','Blue'})do for _,key in ipairs(teams[side])do
  local t=s.Tickets[key];t.Match=id;t.ExpiresAt=m.ExpiresAt
  table.insert(m.Parties,M.Copy(t));for _,uid in ipairs(t.Members)do table.insert(m[side],uid)end
 end end
 s.Matches[id]=m;return m
end
function M.Fail(s,id,reason)
 local m=s.Matches[id];if m and m.State~='Running'then m.State='Failed';m.Reason=reason end
end
function M.IsMember(m,id)
 return table.find(m.Red,id)~=nil or table.find(m.Blue,id)~=nil
end
function M.ValidArrival(m,id,privateId,now)
 return m~=nil and m.State=='Ready'and m.ExpiresAt>now and m.PrivateId==privateId and M.IsMember(m,id)
end
return M
