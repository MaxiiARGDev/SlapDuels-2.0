-- Actual queue + round coroutine flow, deterministic scheduler and spatial adapter.
local before101=count
local now101=100;local tasks101={};local cancelled101=0
fixtureOS={clock=function()return now101 end,time=os.time}
fixtureTask={}
function fixtureTask.spawn(fn)
 local co=coroutine.create(fn);tasks101[co]={At=now101};return co
end
fixtureTask.defer=fixtureTask.spawn
function fixtureTask.wait(dt)return coroutine.yield(dt or 0)end
function fixtureTask.cancel(co)tasks101[co]=nil;cancelled101+=1;if coroutine.status(co)=="suspended"then coroutine.close(co)end end
local function advance101(dt)
 local goal=now101+dt;local turns=0
 while true do
  local chosen,at
  for co,t in pairs(tasks101)do if t.At<=goal and(not at or t.At<at)then chosen=co;at=t.At end end
  if not chosen then break end
  turns+=1;assert(turns<1000,"scheduler loop")
  now101=at;local ok,delay=coroutine.resume(chosen);assert(ok,delay)
  if coroutine.status(chosen)=="dead"then tasks101[chosen]=nil
  elseif tasks101[chosen]then tasks101[chosen].At=now101+(delay or 0)end
 end
 now101=goal
end
local uid101=0;services.HttpService.GenerateGUID=function()uid101+=1;return "preparation-"..uid101 end
local positions101={};local chars101={};local live101={}
players.GetPlayers=function()return live101 end
players.GetPlayerFromCharacter=function(_,char)return chars101[char]end
world.GetPartBoundsInBox=function(_,frame)return positions101[frame.Pad]or {}end
local function pad101(team)
 local p=node("Part",team);p.Size=vector(8,1,8);p.CFrame=setmetatable({Pad=p},{__mul=function(a)return a end});return p
end
local function fresh101(n)
 tasks101={};positions101={};chars101={};live101={}
 round=load("Round");mm=load("Matchmaking")
 local zone={ZoneId="queue",ZoneName="queue",Instance=node("Folder","queue"),Config={Mode=n==1 and"1v1"or"2v2",TeamSize=n,MaxPlayersPerTeam=n,TotalPlayers=n*2},RedPads={pad101("Red")},BluePads={pad101("Blue")},PadOccupants={},OccupantLastSeen={},CandidateArrivals={},CandidateLastSeen={},CurrentRed={},CurrentBlue={},State="WAITING"}
 for _,p in ipairs({zone.RedPads[1],zone.BluePads[1]})do zone.PadOccupants[p]={}end
 mm._zones={[zone.Instance]=zone};mm._latestSnapshots={};mm._getRoundService=function()return round end;mm._getFeedbackService=function()end
 local packets={};mm._queueStatusRemote={FireAllClients=function(_,p)table.insert(packets,p)end}
 round._getMatchmakingService=function()return mm end
 round._getMatchInstanceService=function()return nil end
 local calls={Teleports=0,Results=0,Rewards=0,Score=0,MapSelection=0,Countdowns={}}
 local remote={FireClient=function(_,p,...)
  local args={...}
  if args[3]=="LA PARTIDA COMIENZA EN"then table.insert(calls.Countdowns,{Value=args[2],Token=args[4]and args[4].CountdownToken})end
 end}
 -- A remote adapter counts calls while preserving actual recipient and token logic.
 round._getRemote=function(_,_,name)
  if name=="MatchResult"or name=="EndCinematic"then calls.Results+=1 end
  return {FireClient=function(_,p,...)
   local args={...}
   if name=="Countdown"and args[2]=="LA PARTIDA COMIENZA EN"then table.insert(calls.Countdowns,{Value=args[1],Token=args[3].CountdownToken})end
   if name=="MapSelection"then calls.MapSelection+=1 end
  end}
 end
 round._getSpawnService=function()return {ReturnPlayersToLobby=function()calls.Teleports+=1;return true end}end
 round._getScoreService=function()calls.Score+=1;return nil end
 round._processReward=function()calls.Rewards+=1 end
 local red,blue={},{}
 for i=1,n*2 do local p=player(1000+i);chars101[p.Character]=p;table.insert(live101,p);table.insert(i<=n and red or blue,p)end
 local function occupy(r,b)
  positions101[zone.RedPads[1]]={};for _,p in ipairs(r)do table.insert(positions101[zone.RedPads[1]],p.Character:FindFirstChild("HumanoidRootPart"))end
  positions101[zone.BluePads[1]]={};for _,p in ipairs(b)do table.insert(positions101[zone.BluePads[1]],p.Character:FindFirstChild("HumanoidRootPart"))end
 end
 occupy(red,blue);mm:_updateQueue();advance101(.5)
 return {Zone=zone,Red=red,Blue=blue,Occupy=occupy,Calls=calls,Packets=packets}
end
local function departure101(f,r,b)
 f.Occupy(r,b);advance101(.81);mm:_updateQueue()
end
for _,n in ipairs({1,2})do
 local f=fresh101(n);local old=assert(round:GetSession());local oldThread=old.SessionThread
 check(old.State==constants.RoundState.MatchCountdown,"both complete teams start countdown")
 check(f.Calls.Countdowns[1].Value==5 and f.Calls.Countdowns[1].Token==old.Id,"new preparation starts at five with unique token")
 local remaining={};for i=1,n-1 do table.insert(remaining,f.Blue[i])end
 departure101(f,f.Red,remaining)
 check(round:GetSessionById(old.Id)==nil and old.Closed and old.Cancelled,"departure cancels only preparation")
 check(f.Calls.Teleports==0 and f.Calls.Results==0 and f.Calls.Rewards==0 and f.Calls.Score==0,"prematch no teleport result reward or competitive cleanup")
 check(#f.Zone.CurrentRed==n and #f.Zone.CurrentBlue==n-1,"remaining players retain team and count")
 check(mm:GetQueueSnapshot("queue").TotalPlayers==n*2 and #mm:GetQueueSnapshot("queue").Blue==n-1,"queue HUD snapshot updated")
 check(next(tasks101)==nil and tasks101[oldThread]==nil,"old coroutine cancelled")
 check(not f.Zone.ActiveReservation and round:IsAvailable(),"reservation and session capacity released")
 local replacement=player(2000+n);chars101[replacement.Character]=replacement;table.insert(live101,replacement);table.insert(remaining,replacement)
 f.Occupy(f.Red,remaining);mm:_updateQueue();advance101(.5)
 local newer=assert(round:GetSession());check(newer.Id~=old.Id,"replacement creates distinct preparation")
 check(f.Calls.Countdowns[#f.Calls.Countdowns].Value==5,"replacement restarts five seconds")
 round:_runSession(old.Id);round:_cancelMatchPreparation("LateCallback",old.Id)
 check(round:GetSession()==newer and newer.State==constants.RoundState.MatchCountdown,"stale start and cancellation cannot affect successor")
 check(newer.RedTeam[1]==f.Red[1]and newer.BlueTeam[n]==replacement,"successor preserves teams and replaces only missing slot")
 -- Repeated cancellation/re-entry, also covers leaving and immediately rejoining after confirmed exit.
 for i=1,3 do
  departure101(f,{},{});check(round:IsAvailable()and f.Calls.Teleports==0,"repeated two-sided departures preserve positions")
  f.Occupy(f.Red,remaining);mm:_updateQueue();advance101(.5);check(round:GetSession()~=nil,"queue can restart after cancellation")
 end
 -- A brief unconfirmed sensor absence retains the existing grace policy.
 local current=round:GetSession();f.Occupy(f.Red,{});advance101(.2);mm:_updateQueue();f.Occupy(f.Red,remaining);mm:_updateQueue()
 check(round:GetSession()==current,"brief jitter does not rewrite existing grace policy")
 -- Confirmed exit on the final countdown second cannot reach voting/transfer.
 advance101(3.1);departure101(f,f.Red,{})
 check(round:GetSession()==nil and f.Calls.Teleports==0 and f.Calls.MapSelection==0,"final second exit prevents stale start")
end
for _,n in ipairs({1,2})do
 local ready=fresh101(n);local id=round:GetSession().Id
 advance101(5)
 check(round:GetSessionState(id)==constants.RoundState.MapSelection and ready.Calls.MapSelection==n*2,"complete fresh five-second countdown reaches voting for all participants")
 departure101(ready,ready.Red,{})
 check(round:IsAvailable()and ready.Calls.Teleports==0,"loss before arena transfer cancels voting without teleport")
 round:_runSession(id);check(round:IsAvailable(),"old voting continuation cannot restart closed preparation")
end
-- Final physical gate ignores retained occupancy when actual overlap is absent.
local f=fresh101(1)
f.Occupy(f.Red,{})
check(mm:ArePlayersInZone("queue",f.Red,f.Blue)and not mm:ArePlayersInZone("queue",f.Red,f.Blue,true),"fresh physical gate refuses grace-only occupancy")
local current=round:GetSession();round:_closePrematch(current,"ManualValidationFailure")
check(f.Zone.CurrentRed[1]==f.Red[1]and f.Calls.Teleports==0,"closing preparation never clears physical FIFO occupancy")
local t={Token="newer-reservation"};f.Zone.ActiveReservation=t;mm:ReleasePreparation("queue","old-token")
check(f.Zone.ActiveReservation==t,"old cleanup cannot invalidate newer reservation")
-- A partial initial transfer uses the existing close path, but returns only moved players.
local partial=fresh101(2);local partialSession=round:GetSession();partialSession.State=constants.RoundState.MapLoading
partialSession.ArenaTransferred=true;partialSession.TransferredPlayers={[partial.Red[1]]=true}
local partialReturned={}
round._getSpawnService=function()return {GetSessionParticipants=function()return {partial.Red[1],partial.Red[2],partial.Blue[1],partial.Blue[2]}end,ReturnPlayersToLobby=function(_,list)partialReturned=list;return true end}end
check(round:CloseSession(partialSession.Id,{Cancelled=true,Reason="SpawnPlayersFailed"})and #partialReturned==1 and partialReturned[1]==partial.Red[1],"partial rollback returns only transferred player")
check(round:GetSession()==nil,"partial failure releases session after recovery")
-- Real client cancellation handler and tombstone checks, without UI construction.
services.TweenService={};players.LocalPlayer=f.Red[1]
local client=load("Client");client._currentMatchId="old-ui";client._currentRole="Red";client._lastStateVersion=1
players.LocalPlayer.MatchId="old-ui";client._countdownFrame={Visible=true};client._resultFrame={Visible=true}
client:_handleStateChanged(constants.RoundState.Waiting,{SessionId="old-ui",StateVersion=2,PrematchCancelled=true})
check(not client._countdownFrame.Visible and not client._resultFrame.Visible and client._currentMatchId==nil,"client hides countdown without end-match presentation")
check(not client:_acceptSessionPayload({SessionId="old-ui",StateVersion=1,ParticipantUserIds={players.LocalPlayer.UserId}},true,true),"retired preparation cannot rebind even with stale replicated attribute")
players.LocalPlayer.MatchId="new-ui"
check(client:_acceptSessionPayload({SessionId="new-ui",StateVersion=1,ParticipantUserIds={players.LocalPlayer.UserId},ParticipantTeams={[players.LocalPlayer.UserId]="Red"}},true,true),"client binds new countdown")
client._countdownFrame.Visible=true;client:_handleStateChanged(constants.RoundState.Waiting,{SessionId="old-ui",StateVersion=2,PrematchCancelled=true})
check(client._currentMatchId=="new-ui"and client._countdownFrame.Visible,"late cancelled HUD event cannot hide successor")
check(cfg.Round.PlayableModes["1v1"]and cfg.Round.PlayableModes["2v2"]and not cfg.Round.PlayableModes["3v3"]and not cfg.Round.PlayableModes["4v4"],"mode flags unchanged")
print("PASS MatchmakingXVXV101: "..(count-before101).." new assertions; total including V1.0="..count.."; no Play/cloud")
