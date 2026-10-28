--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Config=require(RS.Shared.PartyMatchConfig)
local Model=require(script.Parent.Gameplay.PartyQueueModel)
local Store=require(script.Parent.Gameplay.PartyQueueStore)
local Service={Name='PartyMatchService'}
local function now()return workspace:GetServerTimeNow()end
local function guid()return Http:GenerateGUID(false)end
local function connected(id)return Players:GetPlayerByUserId(id)end
local function ensure(parent,name,class)
 local o=parent:FindFirstChild(name);if o then assert(o:IsA(class));return o end
 o=Instance.new(class);o.Name=name;o.Parent=parent;return o
end
function Service:Init(context)
 self.Context=context;self.Social=context:GetService('SocialPlayService');self.Rounds=context:GetService('RoundService')
 self.MM=context:GetService('MatchmakingService');self.Profiles=context:GetService('PlayerService')
 local info=context.PersistenceInfo
 self.Global=not Run:IsStudio()and Config.GlobalEnabled and game.GameId==Config.ApprovedUniverseId
  and info and info.Environment=='Production'and info.WritesToCloud==true or false
 self.Enabled=Run:IsStudio()and info and info.ProviderName=='InMemory'and info.WritesToCloud==false or self.Global
 self.Job=game.JobId~=''and game.JobId or guid();self.Store=Store.new(self.Global,'PartyMatchV1_'..game.PlaceId)
 self.Tickets={};self.Regions={};self.Last={};self.Busy={};self.Grants={};self.PendingArrivals={};self.Arrivals={};self.ArrivalLoading={};self.Returning={};self.ReturnGroups={}
 self.IsReserved=self.Global and game.PrivateServerId~=''and game.PrivateServerOwnerId==0
 local folder=ensure(RS.Remotes,'PartyMatch','Folder');self.Remote=ensure(folder,'Request','RemoteFunction');self.Updated=ensure(folder,'Updated','RemoteEvent')
end
function Service:Available(p,ownTicket)
 if not p or p.Parent~=Players or not self.Profiles:IsShopDataReady(p)then return false end
 if self.Rounds:GetSessionForPlayer(p)or p:GetAttribute('ResultsSessionId')or p:GetAttribute('TrainingSessionId')then return false end
 local lock=p:GetAttribute('PartyQueueTicket');if lock and lock~=ownTicket then return false end
 if self.MM:IsPlayerOnPhysicalQueue(p)then return false end
 local trade=self.Context:GetService('SocialService');if trade and trade.Engine and trade.Engine.Busy[p.UserId]then return false end
 local crates=self.Context:GetService('CrateService');if crates and crates._stands and crates._stands.Active[p.UserId]then return false end
 local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');return h~=nil and h.Health>0
end
function Service:State(p)
 local id=p:GetAttribute('PartyQueueTicket');local t=id and self.Tickets[id]
 local modes={};for _,mode in ipairs(Config.Modes)do modes[mode]=self.Rounds:IsModePlayable(mode)end
 return {Ok=true,Enabled=self.Enabled==true,Global=self.Global,Modes=modes,State=t and t.State or self.IsReserved and 'Destination'or 'Idle',Mode=t and t.Mode,
  Since=t and t.Since or 0,Leader=t and t.Leader,CanCancel=t and t.State=='Searching'and t.Leader==p.UserId or false,
  CanReturn=self.IsReserved and not self.Rounds:GetSessionForPlayer(p)and not self.PendingArrivals[p.UserId]and not self.Destination,
  Server=Run:IsStudio()and 'Studio' or self.Job:sub(1,8),Version=game.PlaceVersion,Region='Región del servidor no disponible'}
end
function Service:Push(t,reason)
 for _,id in ipairs(t.Members)do local p=connected(id);if p then local s=self:State(p);s.Reason=reason;self.Updated:FireClient(p,s)end end
end
function Service:Unlock(t,reason)
 if self.Tickets[t.Id]~=t then return end
 local removed=pcall(function()self.Store:Update(t.Mode,function(s)
  local row=s.Tickets[t.Id];if row and row.Job==self.Job then s.Tickets[t.Id]=nil end
 end)end)
 if not removed and now()-t.Since<=Config.MaxSearchSeconds+Config.MatchTTL then return end
 self.Tickets[t.Id]=nil
 for _,id in ipairs(t.Members)do local p=connected(id);if p and p:GetAttribute('PartyQueueTicket')==t.Id then p:SetAttribute('PartyQueueTicket',nil)end end
 self:Push(t,reason)
end
function Service:Join(p,mode)
 if not self.Enabled or self.IsReserved then return {Ok=false,Reason='Unavailable'}end
 if not table.find(Config.Modes,mode)or not self.Rounds:IsModePlayable(mode)then return {Ok=false,Reason='ModeUnavailable'}end
 local size=tonumber(mode:sub(1,1));local group=self.Social.Engine:Group(p.UserId)
 if group and group.Leader~=p.UserId then return {Ok=false,Reason='NotLeader'}end
 local members=group and table.clone(group.Members)or {p.UserId}
 if #members>size then return {Ok=false,Reason='GroupTooLarge'}end
 local ping=0;local region
 for _,id in ipairs(members)do local member=connected(id)
  if not self:Available(member)or self.Social.Engine.Busy[id]then return {Ok=false,Reason='PlayerUnavailable'}end
  local ok,value=pcall(member.GetNetworkPing,member);ping=math.max(ping,ok and value*1000 or 0)
  local r=self.Regions[id]or 'Unknown';region=region and(region==r and r or 'Mixed')or r
 end
 local id=guid();local t={Id=id,Mode=mode,Leader=p.UserId,Members=members,Job=self.Job,CreatedAt=now(),Since=now(),Region=region,Ping=ping,State='Searching'}
 self.Tickets[id]=t;for _,uid in ipairs(members)do connected(uid):SetAttribute('PartyQueueTicket',id)end
 local ok,state=pcall(function()return self.Store:Update(mode,function(s)Model.Prune(s,now());Model.Add(s,t,Config,now())end)end)
 if not ok or not state.Tickets[id]then self:Unlock(t,'QueueUnavailable');return {Ok=false,Reason='QueueUnavailable'}end
 self:Push(t);return self:State(p)
end
function Service:Cancel(p)
 local t=self.Tickets[p:GetAttribute('PartyQueueTicket')];if not t then return self:State(p)end
 if t.Leader~=p.UserId then return {Ok=false,Reason='NotLeader'}end
 local ok,s=pcall(function()return self.Store:Update(t.Mode,function(state)Model.Cancel(state,t.Id,self.Job)end)end)
 if not ok then return {Ok=false,Reason='QueueUnavailable'}end
 if s.Tickets[t.Id]then return {Ok=false,Reason='MatchFound'}end
 self:Unlock(t,'Cancelled');return self:State(p)
end
function Service:Abort(t,reason)
 local ok=pcall(function()self.Store:Update(t.Mode,function(s)
  local row=s.Tickets[t.Id];if row and row.Match then Model.Fail(s,row.Match,reason)end
  s.Tickets[t.Id]=nil
 end)end)
 if ok or now()-t.Since>Config.MaxSearchSeconds+Config.TicketTTL then self:Unlock(t,reason)end
end
function Service:ValidateReservation(token,request)
 local g=self.Grants[token];if not g or g.Consumed or now()>=g.ExpiresAt or g.ZoneId~=request.ZoneId or g.Mode~=request.Mode or g.Size~=request.TeamSize then return false,'InvalidMenuReservation'end
 for _,side in ipairs({'RedTeam','BlueTeam'})do
  if #g[side]~=#request[side]then return false,'InvalidRoster'end
  for i,p in ipairs(g[side])do if p~=request[side][i]or p.Parent~=Players then return false,'InvalidRoster'end end
 end
 return true
end
function Service:ConsumeReservation(token)local g=self.Grants[token];if not g or g.Consumed then return false end;g.Consumed=true;return true end
function Service:Prepared(zone,red,blue)
 for _,g in pairs(self.Grants)do if g.ZoneId==zone and g.Consumed then
  for _,side in ipairs({{g.RedTeam,red},{g.BlueTeam,blue}})do if #side[1]~=#side[2]then return false end
   for i,p in ipairs(side[1])do local s=self.Rounds:GetSessionForPlayer(p);local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid');if p.Parent~=Players or not h or h.Health<=0 or side[2][i]~=p or not s or s.ZoneId~=zone or s.Closing then return false end end
  end;return true
 end end;return false
end
function Service:Release(zone,token)local g=self.Grants[token];if g and g.ZoneId==zone then self.Grants[token]=nil end end
function Service:StartMatch(m)
 local g={ZoneId='Menu:'..m.Id,Mode=m.Mode,Size=m.Size,ExpiresAt=now()+120,RedTeam={},BlueTeam={}}
 for _,side in ipairs({'Red','Blue'})do for _,id in ipairs(m[side])do
  local p=connected(id);if not self:Available(p,p and p:GetAttribute('PartyQueueTicket'))then return false,'PlayerUnavailable'end
  table.insert(g[side..'Team'],p)
 end end
 local token=guid();self.Grants[token]=g
 local ok,started,why=pcall(self.Rounds.StartTeamMatch,self.Rounds,{ZoneId=g.ZoneId,Mode=g.Mode,TeamSize=g.Size,RedTeam=g.RedTeam,BlueTeam=g.BlueTeam,ReservationToken=token})
 if not ok or not started then self.Grants[token]=nil;return false,ok and why or 'StartFailed'end
 return true
end
function Service:RestoreParties(m)
 local e=self.Social.Engine
 for _,t in ipairs(m.Parties)do
  if #t.Members>1 then
   for _,id in ipairs(t.Members)do if e:Group(id)then return false end end
  end
 end
 for _,t in ipairs(m.Parties)do if #t.Members>1 then
  local g={Id=guid(),Leader=t.Leader,Members=table.clone(t.Members),Revision=0};e.Groups[g.Id]=g;e:_publish(g)
 end end;return true
end
function Service:Teleport(t,m)
 if t.State=='Teleporting'then return end
 t.State='Teleporting';t.Match=m.Id;self:Push(t)
 local list={};for _,id in ipairs(t.Members)do local p=connected(id);if not self:Available(p,t.Id)then self:Abort(t,'PlayerUnavailable');return end;table.insert(list,p)end
 local options=Instance.new('TeleportOptions');options.ReservedServerAccessCode=m.AccessCode
 options:SetTeleportData({PartyMatchV1={Id=m.Id,Mode=m.Mode}})
 local ok=pcall(function()game:GetService('TeleportService'):TeleportAsync(game.PlaceId,list,options)end)
 if not ok then self:Abort(t,'TeleportFailed')end
end
function Service:PollMode(mode)
 local timestamp=now();local candidateId=guid();local size=tonumber(mode:sub(1,1))
 local state=self.Store:Update(mode,function(s)
  Model.Prune(s,timestamp)
  for _,t in pairs(self.Tickets)do if t.Mode==mode then Model.Heartbeat(s,t.Id,self.Job,timestamp,Config)end end
  for _,m in pairs(s.Matches)do if m.State=='Allocating'and timestamp>=m.AllocateUntil then Model.Fail(s,m.Id,'ReservationTimeout')end end
  if self.Global or self.Rounds:IsAvailable()then Model.Assign(s,candidateId,mode,size,self.Job,timestamp,Config)end
 end)
 for _,m in pairs(state.Matches)do if m.Owner==self.Job and m.State=='Allocating'then
  if self.Global then
   local ok,access,privateId=pcall(function()return game:GetService('TeleportService'):ReserveServerAsync(game.PlaceId)end)
   state=self.Store:Update(mode,function(s)
    local current=s.Matches[m.Id]
    if current and current.State=='Allocating'and now()<current.AllocateUntil then
     if ok then current.State='Ready';current.AccessCode=access;current.PrivateId=privateId else Model.Fail(s,m.Id,'ReservationFailed')end
    end
   end)
  else
   local ok,why=self:StartMatch(m)
   state=self.Store:Update(mode,function(s)local row=s.Matches[m.Id];if row then row.State=ok and 'Running'or 'Failed';row.Reason=why end end)
  end
 end end
 for _,t in pairs(table.clone(self.Tickets))do if t.Mode==mode then
  local row=state.Tickets[t.Id];local m=row and row.Match and state.Matches[row.Match]
  if not row then self:Unlock(t,'QueueExpired')
  elseif m and m.State=='Failed'then self:Unlock(t,m.Reason)
  elseif m and m.State=='Running'then self:Unlock(t)
  elseif m then
   t.Match=m.Id
   if m.State=='Ready'and self.Global then self:Teleport(t,m)
   elseif t.State~='Teleporting'then t.State='Matched';self:Push(t)end
  else self:Push(t)end
 end end
end
function Service:LoadArrival(p)
 if self.ArrivalLoading[p]or self.Arrivals[p]then return end;self.ArrivalLoading[p]=true
 local ok,join=pcall(p.GetJoinData,p);local payload=ok and join.TeleportData and join.TeleportData.PartyMatchV1
 if not payload or type(payload.Id)~='string'or #payload.Id>64 or not table.find(Config.Modes,payload.Mode)or join.SourcePlaceId~=game.PlaceId then
  self.PendingArrivals[p.UserId]=nil;p:SetAttribute('PartyQueueTicket',nil);self.Arrivals[p]=true;self.ArrivalLoading[p]=nil;return
 end
 local loaded,s=pcall(function()return self.Store:Read(payload.Mode)end)
 local m=loaded and s and s.Matches[payload.Id]
 if not loaded then self.ArrivalLoading[p]=nil;return end
 if not Model.ValidArrival(m,p.UserId,game.PrivateServerId,now())then
  self.PendingArrivals[p.UserId]=nil;p:SetAttribute('PartyQueueTicket',nil);self.Arrivals[p]=true;self.ArrivalLoading[p]=nil;return
 end
 if self.Destination and self.Destination.Id~=m.Id then self.PendingArrivals[p.UserId]=nil;p:SetAttribute('PartyQueueTicket',nil);self.Arrivals[p]=true;self.ArrivalLoading[p]=nil;return end
 self.Destination=self.Destination or m
 self.Arrivals[p]=true;self.ArrivalLoading[p]=nil
 p:SetAttribute('PartyQueueTicket','Arrival:'..m.Id)
end
function Service:DestinationTick()
 if not self.Destination then return end
 local m=self.Destination;local state=self.Store:Read(m.Mode);local current=state and state.Matches[m.Id]
 if not current or current.State=='Failed'or now()>=m.ExpiresAt then self:FinishDestination('ArrivalFailed');return end
 local all=true
 for _,side in ipairs({'Red','Blue'})do for _,id in ipairs(m[side])do
  local p=connected(id)
  if not p or not self.Arrivals[p]or not self:Available(p,'Arrival:'..m.Id)then all=false end
 end end
 if not all then return end
 -- Verify actual latency at the destination rather than treating source ping as a guarantee.
 for _,side in ipairs({'Red','Blue'})do for _,id in ipairs(m[side])do
  if connected(id):GetNetworkPing()*1000>Config.ArrivalMaxPingMs then
   self.Store:Update(m.Mode,function(s)Model.Fail(s,m.Id,'DestinationLatency')end);self:FinishDestination('DestinationLatency');return
  end
 end end
 local committed=self.Store:Update(m.Mode,function(s)
  local row=s.Matches[m.Id]
  if row and row.State=='Ready'and not row.ConsumerJob then row.ConsumerJob=self.Job;row.State='Starting'end
 end)
 local row=committed.Matches[m.Id]
 if not row or row.ConsumerJob~=self.Job or row.State~='Starting'then self:FinishDestination('DestinationUnavailable');return end
 local ok,why=false,'PartyRestoreFailed'
 if self:RestoreParties(row)then ok,why=self:StartMatch(row)end
 self.Store:Update(m.Mode,function(s)local r=s.Matches[m.Id];if r and r.ConsumerJob==self.Job then r.State=ok and 'Running'or 'Failed';r.Reason=why end end)
 self:FinishDestination(ok and nil or why)
end
function Service:FinishDestination(reason)
 self.Destination=nil
 for _,p in ipairs(Players:GetPlayers())do self.PendingArrivals[p.UserId]=nil;p:SetAttribute('PartyQueueTicket',nil)
  local s=self:State(p);s.Reason=reason;self.Updated:FireClient(p,s)
 end
end
function Service:Return(p)
 if not self:State(p).CanReturn or self.Returning[p]then return {Ok=false,Reason='PlayerUnavailable'}end
 local g=self.Social.Engine:Group(p.UserId);if g and g.Leader~=p.UserId then return {Ok=false,Reason='NotLeader'}end
 local members=g and g.Members or {p.UserId};local list={}
 for _,id in ipairs(members)do local q=connected(id);if not q or not self:Available(q)or not self:State(q).CanReturn then return {Ok=false,Reason='PlayerUnavailable'}end;table.insert(list,q)end
 for _,q in ipairs(list)do self.Returning[q]=true end
 local ok=pcall(function()
  local key='Return_'..guid();local data={Members=table.clone(members),Leader=p.UserId,ExpiresAt=now()+Config.MatchTTL}
  self.Store:Update(key,function(s)s.Return=data end)
  local options=Instance.new('TeleportOptions');options:SetTeleportData({PartyReturnV1=key})
  game:GetService('TeleportService'):TeleportAsync(game.PlaceId,list,options)
 end)
 if not ok then for _,q in ipairs(list)do self.Returning[q]=nil end end
 return {Ok=ok,Reason=not ok and 'TeleportFailed'or nil}
end
function Service:LoadReturn(p)
 local join=p:GetJoinData();local key=join.TeleportData and join.TeleportData.PartyReturnV1
 if join.SourcePlaceId~=game.PlaceId or type(key)~='string'or #key>64 or key:sub(1,7)~='Return_'then return end
 p:SetAttribute('PartyQueueTicket',key)
 local ok,s=pcall(function()return self.Store:Update(key,function(state)
  local r=state.Return;if r and r.ExpiresAt>now()and table.find(r.Members,p.UserId)and(not r.Job or r.Job==self.Job)then r.Job=self.Job end
 end)end)
 local r=ok and s.Return
 if r and r.ExpiresAt>now()and r.Job==self.Job and table.find(r.Members,p.UserId)then self.ReturnGroups[key]=r
 else p:SetAttribute('PartyQueueTicket',nil)end
end
function Service:ReturnTick()
 for key,r in pairs(self.ReturnGroups)do
  local ready=true;for _,id in ipairs(r.Members)do local p=connected(id);if not p or not self:Available(p,key)then ready=false end end
  if ready or now()>=r.ExpiresAt then
   if ready then self:RestoreParties({Parties={r}})end
   for _,id in ipairs(r.Members)do local p=connected(id);if p and p:GetAttribute('PartyQueueTicket')==key then p:SetAttribute('PartyQueueTicket',nil)end end
   self.ReturnGroups[key]=nil
   self.Store:Update(key,function(s)s.Return=nil end)
  end
 end
end
function Service:Request(p,action,arg)
 if self.Busy[p]or now()-(self.Last[p]or 0)<.4 then return {Ok=false,Reason='RateLimited'}end
 self.Last[p]=now();self.Busy[p]=true
 local ok,r=pcall(function()
  if action=='State'then return self:State(p)
  elseif action=='Join'and type(arg)=='string'then return self:Join(p,arg)
  elseif action=='Cancel'then return self:Cancel(p)
  elseif action=='Return'then return self:Return(p)end
  return {Ok=false,Reason='InvalidRequest'}
 end)
 self.Busy[p]=nil;if not ok then warn('[PartyMatch] Request failed: '..tostring(r));return {Ok=false,Reason='QueueUnavailable'}end;return r
end
function Service:Start()
 self.Remote.OnServerInvoke=function(...)return self:Request(...)end
 if not self.Enabled then return end
 local function added(p)
  if self.IsReserved then self.PendingArrivals[p.UserId]=now();p:SetAttribute('PartyQueueTicket','ArrivalPending');task.spawn(function()self:LoadArrival(p)end)
  elseif self.Global then task.spawn(function()
   local returned,err=pcall(self.LoadReturn,self,p);if not returned then p:SetAttribute('PartyQueueTicket',nil);warn('[PartyMatch] Return validation failed: '..tostring(err))end
   local ok,r=pcall(function()return game:GetService('LocalizationService'):GetCountryRegionForPlayerAsync(p)end)
   if ok and p.Parent==Players then self.Regions[p.UserId]=r end
  end)end
 end
 Players.PlayerAdded:Connect(added);for _,p in ipairs(Players:GetPlayers())do added(p)end
 Players.PlayerRemoving:Connect(function(p)
  local t=self.Tickets[p:GetAttribute('PartyQueueTicket')];if t and t.State~='Teleporting'then task.spawn(function()self:Abort(t,'Disconnected')end)end
  self.Last[p]=nil;self.Busy[p]=nil;self.Arrivals[p]=nil;self.ArrivalLoading[p]=nil;self.Regions[p.UserId]=nil;self.Returning[p]=nil
 end)
 if self.Global then game:GetService('TeleportService').TeleportInitFailed:Connect(function(p,_,_,_,options)
  self.Returning[p]=nil
  local data=options and options:GetTeleportData();local id=data and data.PartyMatchV1 and data.PartyMatchV1.Id
  local t=self.Tickets[p:GetAttribute('PartyQueueTicket')]
  if t and type(id)=='string'and t.Match==id then task.spawn(function()self:Abort(t,'TeleportFailed')end)end
 end)end
 task.spawn(function()while true do
  task.wait(Config.PollSeconds)
  local ok,err=pcall(function()
   if self.IsReserved then
    for id,since in pairs(self.PendingArrivals)do local p=connected(id)
     if p and now()-since<Config.MatchTTL then self:LoadArrival(p)
     elseif now()-since>=Config.MatchTTL then self.PendingArrivals[id]=nil;if p then p:SetAttribute('PartyQueueTicket',nil)end end
    end
    self:DestinationTick();for _,p in ipairs(Players:GetPlayers())do self.Updated:FireClient(p,self:State(p))end
   else
    self:ReturnTick()
    local modes={}
    for _,t in pairs(table.clone(self.Tickets))do
     local present=false;for _,id in ipairs(t.Members)do if connected(id)then present=true;break end end
     if t.State=='Teleporting'and not present then self:Unlock(t);continue end
     local valid=now()-t.Since<Config.MaxSearchSeconds
     if t.State~='Teleporting'then for _,id in ipairs(t.Members)do if not self:Available(connected(id),t.Id)then valid=false end end end
     if not valid then self:Abort(t,'PlayerUnavailable')else modes[t.Mode]=true end
    end
    for mode in pairs(modes)do self:PollMode(mode)end
   end
   for token,g in pairs(self.Grants)do if not self.Rounds:GetSessionForPlayer(g.RedTeam[1])and now()>g.ExpiresAt then self.Grants[token]=nil end end
  end)
  if not ok then warn('[PartyMatch] Poll failed; leases expire safely: '..tostring(err))end
 end end)
end
return Service
