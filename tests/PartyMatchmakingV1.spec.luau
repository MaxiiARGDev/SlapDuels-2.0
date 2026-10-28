local count=0
local function check(v,m)assert(v,m);count+=1 end
local function load(key,env)
 local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local C=load('Config');local M=load('Model')
local function ticket(id,members,region,ping,time)
 return {Id=id,Members=members,Leader=members[1],Job='job',Region=region or 'AR',Ping=ping or 50,CreatedAt=time or 0,ExpiresAt=100}
end
local s=M.Empty()
check(M.Add(s,ticket('a',{1,2}),C,0),'Add party')
check(not M.Add(s,ticket('duplicate',{2,3}),C,0),'Reject overlapping players')
check(not M.Add(s,ticket('selfduplicate',{5,5}),C,0),'Reject duplicate members')
check(M.Select(s,1,1,C)==nil,'Never split large party for 1v1')
M.Add(s,ticket('b',{3}),C,0);M.Add(s,ticket('c',{4}),C,0)
local teams=M.Select(s,2,1,C)
check(teams~=nil,'2v2 fills team with two solos')
check(#teams.Red==1 and teams.Red[1]=='a' or #teams.Blue==1 and teams.Blue[1]=='a','Party remains on one side')
local m=M.Assign(s,'match','2v2',2,'job',1,C)
check(#m.Red==2 and #m.Blue==2,'Exact teams')
check(not M.Cancel(s,'a','job'),'Cancellation cannot undo committed assignment')
check(M.Assign(s,'again','2v2',2,'other',1,C)==nil,'Another coordinator cannot reuse tickets')
local clone=M.Copy(s);clone.Matches.match.Red[1]=999;check(s.Matches.match.Red[1]~=999,'Transaction snapshots isolated')
M.Fail(s,'match','TeleportFailed');check(s.Matches.match.State=='Failed','Failure shared by origins')
M.Prune(s,1000);check(next(s.Tickets)==nil and next(s.Matches)==nil,'Expired leases cleaned')
s=M.Empty();M.Add(s,ticket('a',{1},'AR'),C,0);M.Add(s,ticket('b',{2},'US'),C,0)
check(not M.Select(s,1,2,C),'Different player regions initially separated')
for _,t in pairs(s.Tickets)do t.ExpiresAt=200 end
check(M.Select(s,1,100,C)~=nil,'Relax region after wait')
s=M.Empty();M.Add(s,ticket('a',{1},'AR',20),C,0);M.Add(s,ticket('b',{2},'AR',200),C,0)
check(not M.Select(s,1,1,C),'Source ping preference applied')
check(not M.Cancel(s,'a','other'),'Other server cannot cancel ticket')
check(M.Cancel(s,'a','job'),'Owner cancellation succeeds')
check(not M.Select(s,1,1,C),'Cancelled ticket never matched')
m={State='Ready',ExpiresAt=100,PrivateId='private',Red={1},Blue={2}}
check(M.ValidArrival(m,1,'private',1),'Valid destination member')
check(not M.ValidArrival(m,3,'private',1),'Reject foreign arrival')
check(not M.ValidArrival(m,1,'other',1),'Reject wrong reserved destination')
check(not M.ValidArrival(m,1,'private',100),'Reject expired arrival')
m.State='Failed';check(not M.ValidArrival(m,1,'private',1),'Reject cancelled manifest')
s=M.Empty();for i=1,C.MaxTickets do check(M.Add(s,ticket(tostring(i),{i}),C,0),'Bounded insertion '..i)end
check(not M.Add(s,ticket('full',{999}),C,0),'Queue capacity enforced')

-- Actual service, real local adapter and fake Players. No Roblox/cloud/gameplay execution.
local time=10;local serial=0;local all={};local players={}
function players:GetPlayerByUserId(id)return all[id]end
function players:GetPlayers()local out={};for _,p in pairs(all)do table.insert(out,p)end;return out end
local function p(id)
 local x={UserId=id,Parent=players,Attributes={},Character={FindFirstChildOfClass=function()return {Health=100}end}}
 function x:GetAttribute(k)return self.Attributes[k]end
 function x:SetAttribute(k,v)self.Attributes[k]=v end
 function x:GetNetworkPing()return .05 end
 all[id]=x;return x
end
local cloudCalls=0
local storage=load('Store',{script={Parent={PartyQueueModel='Model'}},require=function()return M end,game={GetService=function()cloudCalls+=1;error('Cloud forbidden')end}})
local store=storage.new(false,'isolated')
check(cloudCalls==0,'Local store never acquires cloud service')
local configNode={PartyMatchConfig='Config'};local parent={Gameplay={PartyQueueModel='Model',PartyQueueStore='Store'}}
local teleports={};local failTeleport=false
local teleport={ReserveServerAsync=function()return 'secret','private'end,TeleportAsync=function(_,place,list,opts)if failTeleport then error('offline')end;table.insert(teleports,{Place=place,Players=list,Options=opts})end}
local svc=load('Service',{game={PlaceId=123,PrivateServerId='private',PlaceVersion=7,GetService=function(_,key)
 return ({Players=players,ReplicatedStorage={Shared=configNode},RunService={IsStudio=function()return true end},HttpService={GenerateGUID=function()serial+=1;return 'id'..serial end},TeleportService=teleport})[key]
 end},workspace={GetServerTimeNow=function()return time end},script={Parent=parent},warn=function()end,
 Instance={new=function()local o={};function o:SetTeleportData(d)self.Data=d end;return o end},
 require=function(key)return ({Config=C,Model=M,Store=storage})[key]end})
local social={Engine={Busy={},Group=function()return nil end}}
local sessions={};local started=0;local physical={}
svc.Context={GetService=function()return nil end};svc.Social=social;svc.Profiles={IsShopDataReady=function()return true end}
svc.MM={IsPlayerOnPhysicalQueue=function(_,x)return physical[x]end};svc.Rounds={
 GetSessionForPlayer=function(_,x)return sessions[x]end,IsModePlayable=function(_,mode)return mode=='1v1'or mode=='2v2'end,IsAvailable=function()return started==0 end,
 StartTeamMatch=function(_,req)
  check(svc:ValidateReservation(req.ReservationToken,req),'Real reservation validation')
  check(svc:ConsumeReservation(req.ReservationToken),'Consume exactly once')
  check(not svc:ConsumeReservation(req.ReservationToken),'Duplicate consume rejected')
  started+=1;for _,team in ipairs({req.RedTeam,req.BlueTeam})do for _,x in ipairs(team)do sessions[x]={ZoneId=req.ZoneId}end end;return true
 end}
svc.Enabled=true;svc.Global=false;svc.Job='job';svc.Store=store;svc.Tickets={};svc.Regions={};svc.Grants={};svc.PendingArrivals={};svc.Returning={};svc.Updated={FireClient=function()end}
local a,b=p(1),p(2)
physical[a]=true;check(not svc:Join(a,'1v1').Ok,'Physical queue excludes menu queue');physical[a]=nil
a:SetAttribute('TrainingSessionId','training');check(not svc:Join(a,'1v1').Ok,'Training excluded');a:SetAttribute('TrainingSessionId',nil)
check(svc:Join(a,'1v1').Ok,'Local solo joins')
local group={Leader=2,Members={1,2}}
social.Engine.Group=function()return group end
check(not svc:Join(a,'2v2').Ok,'Only leader queues party')
social.Engine.Group=function()return nil end
check(not svc:Join(a,'2v2').Ok,'No second mode while queued')
check(not svc:Join(b,'5v5').Ok,'Unknown mode rejected')
check(svc:Cancel(a).Ok and a:GetAttribute('PartyQueueTicket')==nil,'Local cancellation unlocks')
check(svc:Join(a,'1v1').Ok and svc:Join(b,'1v1').Ok,'Both solos search')
svc:PollMode('1v1');check(started==1,'Local queue starts one match')
check(a:GetAttribute('PartyQueueTicket')==nil and b:GetAttribute('PartyQueueTicket')==nil,'Admission releases queue locks')
svc:PollMode('1v1');check(started==1,'Repeat poll cannot duplicate match')
check(cloudCalls==0,'Whole local path had zero cloud calls')

-- Cross-server adapter is replaced by local transactions, transport by spy.
sessions={};started=0;svc.Global=true;svc.Store=storage.new(false,'fakeGlobal');svc.Tickets={}
check(svc:Join(a,'1v1').Ok and svc:Join(b,'1v1').Ok,'Global tickets admitted')
svc:PollMode('1v1');check(started==0 and #teleports==2,'Global match teleports parties instead of starting at origin')
check(teleports[1].Options.ReservedServerAccessCode=='secret','Transport uses reserved code server-side')
check(teleports[1].Options.Data.PartyMatchV1.Id~=nil,'TeleportData contains manifest ID')
check(teleports[1].Options.Data.PartyMatchV1.Members==nil,'Client transport data has no authoritative roster')
svc:PollMode('1v1');check(#teleports==2,'No repeated teleports while pending')
local t=svc.Tickets[a:GetAttribute('PartyQueueTicket')];svc:Abort(t,'TeleportFailed')
svc:PollMode('1v1');check(b:GetAttribute('PartyQueueTicket')==nil,'One failed origin aborts other ticket')
check(next(svc.Tickets)==nil,'Failed transfer unlocks origin tickets')
check(svc:Join(a,'1v1').Ok and svc:Join(b,'1v1').Ok,'Failure allows new search without TTL wait')
failTeleport=true;svc:PollMode('1v1');svc:PollMode('1v1')
check(next(svc.Tickets)==nil,'Thrown teleport failure recovers')

-- Destination admits only a complete, validated roster, once.
sessions={};started=0;failTeleport=false;svc.IsReserved=true;svc.Arrivals={[a]=true};svc.PendingArrivals={[1]=time,[2]=time}
local dest={Id='dest',Mode='1v1',Size=1,State='Ready',PrivateId='private',ExpiresAt=200,Red={1},Blue={2},Parties={ticket('a',{1}),ticket('b',{2})}}
svc.Store:Update('1v1',function(state)state.Matches.dest=M.Copy(dest)end);svc.Destination=dest
a:SetAttribute('PartyQueueTicket','Arrival:dest');b:SetAttribute('PartyQueueTicket','Arrival:dest')
svc:DestinationTick();check(started==0,'Partial arrival cannot start match')
svc.Arrivals[b]=true;svc:DestinationTick();check(started==1,'Complete arrival starts one match')
check(svc.Destination==nil and next(svc.PendingArrivals)==nil,'Destination pending resources released')
check(svc.Store:Read('1v1').Matches.dest.State=='Running','Manifest marks confirmed start')
svc:DestinationTick();check(started==1,'Destination polling cannot double-start')
sessions={};started=0;dest.Id='otherJob';svc.Destination=dest
svc.Store:Update('1v1',function(state)local d=M.Copy(dest);d.State='Starting';d.ConsumerJob='differentInstance';state.Matches.otherJob=d end)
a:SetAttribute('PartyQueueTicket','Arrival:otherJob');b:SetAttribute('PartyQueueTicket','Arrival:otherJob')
svc:DestinationTick();check(started==0 and svc.Destination==nil,'Another instance cannot consume same reserved manifest')
dest.Id='timeout';svc.Destination=dest;svc.PendingArrivals={[2]=time};all[2]=nil
svc.Store:Update('1v1',function(state)state.Matches.timeout=M.Copy(dest)end)
time=201;svc:DestinationTick();check(started==0 and a:GetAttribute('PartyQueueTicket')==nil,'Partial arrival timeout unlocks without match')
check(svc:State(a).CanReturn,'Failed destination offers lobby return')
svc.ArrivalLoading={};svc.Arrivals={};svc.PendingArrivals={[1]=time}
function a:GetJoinData()return {SourcePlaceId=123,TeleportData={PartyMatchV1={Id='invented',Mode='1v1'}}}end
a:SetAttribute('PartyQueueTicket','ArrivalPending');svc:LoadArrival(a)
check(a:GetAttribute('PartyQueueTicket')==nil and not svc.PendingArrivals[1],'Forged manifest cannot strand arrival lock')
all[2]=b;time=20;dest.Id='lag';svc.Destination=dest;svc.PendingArrivals={};svc.Arrivals={[a]=true,[b]=true}
svc.Store:Update('1v1',function(state)state.Matches.lag=M.Copy(dest)end)
a:SetAttribute('PartyQueueTicket','Arrival:lag');b:SetAttribute('PartyQueueTicket','Arrival:lag')
function b:GetNetworkPing()return 1 end
svc:DestinationTick();check(started==0 and svc.Store:Read('1v1').Matches.lag.State=='Failed','Excessive destination ping aborts before combat')

-- Existing SocialPlayEngine remains authoritative; only Group lifts proximity rule.
local Engine=load('SocialEngine');local socialConfig=load('SocialConfig');local socialTime=0;local id=0
local e=Engine.new(socialConfig,{Clock=function()return socialTime end,Id=function()id+=1;return 'req'..id end,Eligible=function()return true end,Near=function()return false end,Name=tostring,GroupChanged=function()end,Emit=function()end})
check(not e:Invite(1,2,'Duel'),'Duel still requires proximity')
local invited,key=e:Invite(1,2,'Group');check(invited,'Server-wide Group invitation works')
check(e:Respond(2,key,true),'Group acceptance uses real engine')
check(#e:Group(1).Members==2 and e:Group(1).Leader==1,'Leader and members retained')
check(not e:Invite(2,3,'Group'),'Member cannot invite as leader')
socialTime=20;local yes,key3=e:Invite(1,3,'Group');check(yes and e:Respond(3,key3,true),'Third member joins')
socialTime=40;local yes4,key4=e:Invite(1,4,'Group');check(yes4 and e:Respond(4,key4,true),'Fourth member joins')
socialTime=60;check(not e:Invite(1,5,'Group'),'Fifth member rejected')
check(not e:CanQueueTeam({a,b},4),'Partial party rejected by existing admission guard')
e:Disconnect(1);check(e:Group(2).Leader==2 and #e:Group(2).Members==3,'Leader departure elects next member')
print('PartyMatchmakingV1 PASS '..count..' isolated assertions; live gameplay/teleports NOT RUN')
