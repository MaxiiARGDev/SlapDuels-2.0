--!nonstrict
local count=0
local function check(v,m)count+=1;assert(v,m)end
local function node(class,name)
 local n={ClassName=class,Name=name,Children={},Parent=true}
 function n:IsA(c)return self.ClassName==c or c=="BasePart"and self.ClassName=="Part"end
 function n:FindFirstChild(k)for _,c in ipairs(self.Children)do if c.Name==k then return c end end end
 function n:GetChildren()return self.Children end
 function n:IsDescendantOf()return self.Parent~=nil end
 function n:GetAttribute(k)return self[k]end
 function n:SetAttribute(k,v)self[k]=v end
 function n:FindFirstChildOfClass(k)for _,c in ipairs(self.Children)do if c.ClassName==k then return c end end end
 return n
end
local function put(p,c)table.insert(p.Children,c);c.Parent=p;return c end
local function map(n)
 local m=node("Model","FutureMap");put(m,node("Folder","Geometry"));local wins=put(m,node("Folder","ZoneWin"));put(wins,node("Part","RedWin"));put(wins,node("Part","BlueWin"))
 for _,team in ipairs({"Red","Blue"})do local f=put(m,node("Folder",team.."Team"));for i=n,1,-1 do local p=put(f,node("Part","Spawn"..i));p.Anchored=true;p.CanCollide=false;p.CFrame={Position=team..i,Rotation=team.."Rotation"}end end
 return m
end
local loaded={Types={},ArenaRespawn={},CharacterPhysics={}}
local parent=setmetatable({TeamSpawnResolver="Resolver",Gameplay={RoundClock="Clock"},Respawn={ArenaRespawn="ArenaRespawn",CharacterPhysics="CharacterPhysics",MovementSpeed="MovementSpeed"}},{__index=function(_,k)return k end})
local world=node("Workspace","Workspace");local players=node("Players","Players");local ss=node("ServerStorage","ServerStorage");local maps=put(ss,node("Folder","Maps"))
local shared={Config="Config",Constants="Constants",Types="Types",EndCinematicConfig="CinematicConfig",EndCinematicRanking="Ranking",ArenaRespawnPolicy="Policy"}
local services={Players=players,Workspace=world,ServerStorage=ss,ReplicatedStorage={Shared=shared},RunService={IsStudio=function()return true end},HttpService={GenerateGUID=function()return "session-fixture"end},ServerScriptService=node("Folder","SSS")}
local enums=setmetatable({},{__index=function(_,k)return k end})
local fixtureTask={cancel=function()end,defer=function()return nil end}
local fixtureOS=os
local function vector(x,y,z)return {X=x,Y=y,Z=z}end
local fixtureCFrame={new=function()return {}end}
local v2meta={}
local function v2(x,y)return setmetatable({X=x,Y=y},v2meta)end
v2meta.__index=function(a,k)if k=="Unit"then local m=math.sqrt(a.X*a.X+a.Y*a.Y);return v2(a.X/m,a.Y/m)end end
v2meta.__add=function(a,b)return v2(a.X+b.X,a.Y+b.Y)end
v2meta.__sub=function(a,b)return v2(a.X-b.X,a.Y-b.Y)end
v2meta.__mul=function(a,b)if type(a)=="number"then return v2(a*b.X,a*b.Y)end;return v2(a.X*b,a.Y*b)end
local function load(name)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable({script={Parent=parent},game={ReplicatedStorage=services.ReplicatedStorage,GetService=function(_,k)return assert(services[k],k)end},workspace=world,
  require=function(k)return assert(loaded[k],"Missing "..tostring(k))end,typeof=function(v)return type(v)=="table"and v.ClassName and "Instance"or type(v)end,
  Vector3={new=vector},Vector2={new=v2},UDim2={new=function(...)return {...}end,fromScale=function(...)return {...}end,fromOffset=function(...)return {...}end},CFrame=fixtureCFrame,Color3={fromRGB=function(...)return {...}end},Enum=setmetatable({},{__index=function()return enums end}),
  OverlapParams={new=function()return {}end},os=fixtureOS,
  Instance={new=function()return {Event={},Fire=function()end}end},task=fixtureTask,print=function()end,warn=function()end},{__index=getfenv()}));loaded[name]=f();return loaded[name]
end
local cfg=load("Config");local constants=load("Constants");loaded.EndCinematicConfig=load("CinematicConfig");local ranking=load("Ranking");load("Clock");load("Policy")
load("MovementSpeed")
local resolver=load("Resolver");local round=load("Round");local spawn=load("Spawn");local arena=load("Arena");local score=load("Score");local mm=load("Matchmaking")
local m=put(maps,map(4));m.Name="Levels"
for n=1,4 do local rows,capacity=resolver.Resolve(m,n);check(rows and capacity==4,"generic capacity for "..n);for i=1,n do check(rows.Red[i].Name=="Spawn"..i and rows.Blue[i].Name=="Spawn"..i,"stable numeric order")end end
check(resolver.Resolve(m,1).Red[1].CFrame.Position=="Red1","authored transform preserved")
local bad=map(1);check(not resolver.Resolve(bad,2),"missing second spawn rejected")
bad=map(2);table.remove(bad.Children,#bad.Children);check(not resolver.Resolve(bad,2),"missing team folder rejected")
bad=map(2);bad:FindFirstChild("RedTeam"):FindFirstChild("Spawn2").ClassName="Folder";check(not resolver.Resolve(bad,2),"invalid marker rejected")
bad=map(2);put(bad:FindFirstChild("BlueTeam"),node("Part","Spawn1"));check(not resolver.Resolve(bad,2),"duplicate index rejected")
check(arena:IsMapCompatible("Levels",2),"map compatible 2v2")
check(not arena:IsMapCompatible("Levels",5),"capacity insufficient rejected")
local future=put(maps,map(4));check(arena:IsMapCompatible("FutureMap",4),"future map relative resolution")
check(cfg.Round.PlayableModes["1v1"]and cfg.Round.PlayableModes["2v2"]and round:IsModePlayable("3v3")and round:IsModePlayable("4v4"),"only authorized modes")
check(round._maxConcurrentSessions==1,"one session remains")
local function player(i)
 local p=node("Player","P"..i);p.Parent=players;p.UserId=i;p.DisplayName=p.Name
 local c=node("Model","Character");c.Parent=world;local h=put(c,node("Humanoid","Humanoid"));h.Health=100;put(c,node("Part","HumanoidRootPart"));p.Character=c;return p
end
local p1,p2,p3,p4=player(1),player(2),player(3),player(4)
local session=assert(round:AdmitSession({ZoneId="z",Mode="2v2",TeamSize=2,RedTeam={p1,p2},BlueTeam={p3,p4}}))
check(#session.Participants==4 and session.Participants[2].Team=="Red"and session.Participants[4].Team=="Blue","admit two teams of two")
check(round:ValidatePreparationParticipants(session,true),"all four prepared")
p4.Parent=nil;check(not round:ValidatePreparationParticipants(session,true),"fourth disconnected fails preparation");p4.Parent=players
local oldChar=p2.Character;p2.Character=nil;check(not round:ValidatePreparationParticipants(session,true),"second character missing fails");p2.Character=oldChar
session.Participants[2].Team="Blue";check(not round:ValidatePreparationParticipants(session,true),"wrong team rejected");session.Participants[2].Team="Red"
local info={MatchId=session.Id,TeamSpawns=resolver.Resolve(m,2),Container=world};session.InstanceInfo=info;arena._instances[session.Id]=info
round._getSpawnService=function()return spawn end
spawn._getRoundService=function()return round end;spawn._getMatchInstanceService=function()return arena end
check(spawn:ResolveParticipantSpawn(session.Id,p2)==info.TeamSpawns.Red[2],"individual respawn resolves slot2")
local placed={};spawn.TeleportCharacterToSpawn=function(_,p,t)placed[p]=t;return true end
local given={};spawn._getSlapService=function()return {GiveSlap=function(_,p)given[p]=true end}end
check(spawn:SpawnMatchPlayers(session).Placed==4 and placed[p2]~=placed[p1],"four distinct per-team placements")
check(given[p1]and given[p2]and given[p3]and given[p4],"equipment all participants")
placed={};check(spawn:SpawnMatchPlayers(session).Success and placed[p2]==info.TeamSpawns.Red[2],"goal reset stable")
local target=info.TeamSpawns.Blue[2];info.TeamSpawns.Blue[2]=nil;placed={};check(not spawn:SpawnMatchPlayers(session).Success and next(placed)==nil,"preflight rejects whole batch before teleport");info.TeamSpawns.Blue[2]=target
session.State=constants.RoundState.Playing;round._getEliminationService=function()end;round._getCombatService=function()end
round._getPlayerService=function()return {AddWin=function()end,AddLoss=function()end}end
round:_handlePlayerLeaving(p2);check(session.Result==nil and session.Participants[2].State=="Left","partial abandonment continues")
check(spawn:ResolveParticipantSpawn(session.Id,p2)==nil and spawn:ResolveParticipantSpawn(session.Id,p1)==info.TeamSpawns.Red[1],"remaining slot never reassigned")
local rows={};for _,q in ipairs(session.Participants)do table.insert(rows,{UserId=q.UserId,DisplayName=q.Player.Name,Team=q.Team,Goals=0,Kills=0,Deaths=0,CompetitiveSlot=q.Slot})end
local rank=ranking.Build(rows,"Red","2v2",{SessionId=session.Id,StateVersion=1});check(#rank.Entries==4 and #rank.VisibleParticipants==2,"four ranked and only two winners represented")
check(#ranking.Build(rows,"Draw","2v2",{SessionId=session.Id,StateVersion=1}).VisibleParticipants==0,"draw has no winner rigs")
local stats={};round._getPlayerService=function()return {AddWin=function(_,p)stats[p]=(stats[p]or 0)+1 end,AddLoss=function(_,p)stats[p]=(stats[p]or 0)+10 end}end
round:_processReward(session,constants.MatchResult.Blue);round:_processReward(session,constants.MatchResult.Blue)
check(stats[p3]==1 and stats[p4]==1 and stats[p1]==10 and stats[p2]==nil,"team result rewards once; departed participant excluded")
-- Exercise existing shared score/reward commit without any live profile.
session.Closing=false;session.Closed=false;session.Result=nil;session.GameplayFrozen=false
score._scores[session.Id]={Red=0,Blue=0};score._playersInside[session.Id]={RedWin={},BlueWin={}};score._pointInProgress[session.Id]=false
local balances={};local awards={};score._getPlayerService=function()return {AddCoins=function(_,p,n,_,id)if not awards[id]then balances[p]=(balances[p]or 0)+n;awards[id]=true end end}end
score._getPointFeedbackService=function()end;score._broadcastScore=function()end
local restarted=0;local terminal=0
score._getRoundService=function()return {RecordMatchPerformance=function()end,TriggerPointRestart=function()restarted+=1 end,DeclareSessionWinner=function()terminal+=1 end}end
score:_commitPoint(session,"Blue",p4,"one");check(session.Score.Blue==1 and session.Score.Red==0 and balances[p4]==150 and balances[p3]==nil,"shared team score personal goal coins")
check(restarted==1,"goal uses existing round restart")
score._scores[session.Id].Blue=4;score:_commitPoint(session,"Blue",p3,"fifth");check(terminal==1 and session.Score.Blue==5,"fifth goal existing winner flow")
check(cfg.Economy.KillRewardCoins==30 and cfg.Round.RoundDuration==180 and cfg.Round.SuddenDeath.StartAtRemainingSeconds==30,"economy and timing unchanged")
-- Existing session close coordinator with deterministic cleanup adapters.
local returned=0;spawn.GetSessionParticipants=function(_,s)local list={};for _,q in ipairs(s.Participants)do if q.State~="Left"and q.State~="Released"then table.insert(list,q.Player)end end;return list end;spawn.ReturnPlayersToLobby=function(_,list)returned+=#list;return true end
round._getRemote=function()return nil end
round._getScoreService=function()return {StopScoring=function()end,CleanupSession=function()end}end
round._getSlapService=function()return {UnlockPlayer=function()end,RemoveSlaps=function()end}end
round._getMatchInstanceService=function()return {DestroyInstance=function()arena._instances[session.Id]=nil;return true end}end
round.SetSessionState=function(_,id,state)round._sessionsById[id].State=state;return true end
check(round:CloseSession(session.Id,{Cancelled=true})and returned==3 and round:GetSessionForPlayer(p1)==nil and arena._instances[session.Id]==nil,"close returns all remaining and releases session")
check(round:CloseSession(session.Id,{Cancelled=true})and returned==3,"close idempotent")
local one=assert(round:AdmitSession({ZoneId="z",Mode="1v1",TeamSize=1,RedTeam={p1},BlueTeam={p3}}));check(one.Participants[1].Slot==1 and one.Participants[2].Slot==1,"1v1 slot1 remains")
local zone={Instance=node("Folder","Zone"),CurrentRed={p1,p2},CurrentBlue={p3,p4},ZoneId="z"};mm._zones={[zone.Instance]=zone}
check(mm:ArePlayersInZone("z",{p1,p2},{p3,p4}),"all four presence accepted")
zone.CurrentRed={p1};check(not mm:ArePlayersInZone("z",{p1,p2},{p3,p4}),"second walks off rejects whole roster")
one.State=constants.RoundState.MatchCountdown;round:_cancelMatchPreparation("PlayerLeftQueuePad",one.Id)
check(round:GetSessionById(one.Id)==nil and returned==3,"prematch cancellation releases registration without teleport")
print("PASS MatchmakingXVXV12 base: "..count.." isolated assertions; gameplay NOT RUN")
