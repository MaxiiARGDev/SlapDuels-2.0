-- Actual production modules, fake Players/characters and deterministic delayed callbacks.
local count=0
local function check(v,m) assert(v,m);count+=1 end
local function load(k,env)
 local f=assert(loadstring(Sources[k],k));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local config=load('Config',{Color3={fromRGB=function(...)return {...}end},Vector3={new=function(...)return {...}end}});local constants=load('Constants')
local rs={Shared={Config='Config',Constants='Constants',Types='Types',EndCinematicConfig='EndCinematicConfig',EndCinematicRanking='EndCinematicRanking'}}
local players={};local workspace={}
local function signal()
 local s={Listeners={}}
 function s:Connect(fn)
  local c={Connected=true};function c:Disconnect()self.Connected=false end
  table.insert(self.Listeners,{Connection=c,Call=fn});return c
 end
 function s:Fire(...)for _,v in ipairs(self.Listeners)do if v.Connection.Connected then v.Call(...)end end end
 function s:Count()local n=0;for _,v in ipairs(self.Listeners)do if v.Connection.Connected then n+=1 end end;return n end
 return s
end
local loaded={Config=config,Constants=constants,Types={},Arena={},Physics={Configure=function()end,Track=function()end,Forget=function()end}}
local suspended={}
local scheduler={spawn=function(fn)local co=coroutine.create(fn);local ok,err=coroutine.resume(co);assert(ok,err);if coroutine.status(co)~='dead' then table.insert(suspended,co)end end}
local game={ReplicatedStorage=rs,GetService=function(_,k)return ({Players=players,Workspace=workspace,ReplicatedStorage=rs,ServerScriptService={},ServerStorage={},HttpService={},RunService={}})[k]end}
local function env(parent)
 return {game=game,workspace=workspace,script={Parent=parent},require=function(k)return assert(loaded[k],tostring(k))end,
  task=scheduler,print=function()end,warn=function()end,typeof=function(v)return type(v)=='table' and v.ClassName and 'Instance' or type(v)end,
  Vector3={zero={}},Enum={HumanoidStateType={Jumping='Jumping'}},Instance={new=function()return{Event=signal(),Fire=function()end}end}}
end
loaded.Movement=load('Movement',env({}))
local M=loaded.Movement
local speed=load('Speed',env({Parent={Services={Respawn={MovementSpeed='Movement'}}}}))
local spawn=load('Spawn',env({Respawn={ArenaRespawn='Arena',CharacterPhysics='Physics',MovementSpeed='Movement'}}))
local parent=setmetatable({Gameplay={RoundClock='Clock'}},{__index=function(_,k)return k end})
-- Round source has presentation/clock dependencies; stub only those dependencies.
loaded.EndCinematicConfig={};loaded.EndCinematicRanking={};loaded.Clock={}
local round=load('Round',env(parent))
local current
local fakeRounds={GetSessionForPlayer=function()return current end}
spawn._context={GetService=function(_,k)return k=='RoundService' and fakeRounds or nil end}
spawn._movementCharacterConnections={}
local function character(hasHum)
 local c={Parent=workspace,Attrs={},Pending=signal(),Root={}}
 function c:GetAttribute(k)return self.Attrs[k]end
 function c:SetAttribute(k,v)self.Attrs[k]=v end
 function c:GetAttributeChangedSignal()return self.Pending end
 function c:IsDescendantOf()return true end
 function c:FindFirstChild(k)if k=='HumanoidRootPart'then return self.Root elseif k=='Humanoid'then return self.Humanoid end end
 function c:FindFirstChildOfClass()return self.Humanoid end
 function c:GetDescendants()return{}end
 function c:WaitForChild()coroutine.yield();return self.Humanoid end
 local h={Parent=c,Health=100,WalkSpeed=32,PlatformStand=false,Attrs={},Changed=signal(),JumpPower=50,JumpHeight=7.2}
 function h:GetAttribute(k)return self.Attrs[k]end
 function h:SetAttribute(k,v)self.Attrs[k]=v end
 function h:GetPropertyChangedSignal()return self.Changed end
 function h:IsA(k)return k=='Humanoid'end
 c.SavedHumanoid=h
 if hasHum~=false then c.Humanoid=h end
 return c,h
end
local p={Name='Fixture',UserId=-1,Parent=players,ClassName='Player',Attrs={}}
function p:GetAttribute(k)return self.Attrs[k]end
function p:SetAttribute(k,v)self.Attrs[k]=v end
function p:IsA(k)return k=='Player'end
local c,h=character();p.Character=c
local function refresh(state)
 current=state and {Id='session',State=state} or nil;p.Attrs.MatchId=state and 'session' or nil
 spawn:RefreshMovementSpeed(p)
end
refresh(nil);check(h.WalkSpeed==32,'Lobby 32')
refresh('Waiting');check(h.WalkSpeed==32,'Waiting/platform 32')
refresh('MatchReady');check(h.WalkSpeed==32,'MatchReady 32')
refresh('MatchCountdown');check(h.WalkSpeed==32,'Prematch countdown 32')
p.Attrs.MatchId=nil;spawn:RefreshMovementSpeed(p);check(h.WalkSpeed==32,'Cancelled preparation 32')
for _,state in ipairs({'MapSelection','MapLoading','Playing','PointRestartCountdown'})do
 refresh(state);check(h.WalkSpeed==16,'Session base 16: '..state)
end
for n=1,4 do current.TeamSize=n;spawn:RefreshMovementSpeed(p);check(h.WalkSpeed==16,'Team size '..n..' base 16')end
refresh('Playing');local nc,nh=character();p.Character=nc;spawn:TrackMovementCharacter(p,nc)
check(nh.WalkSpeed==16,'CharacterAdded during match resolves current session')
spawn:TrackMovementCharacter(p,nc);check(nh.Changed:Count()==1 and nc.Pending:Count()==1,'Repeated tracking replaces connections')
refresh(nil);check(nh.WalkSpeed==32,'Return lobby 32')
local lc,lh=character();p.Character=lc;spawn:TrackMovementCharacter(p,lc)
check(lh.WalkSpeed==32 and nh.Changed:Count()==0,'Lobby CharacterAdded and old connections removed')
local old,oh=character(false);p.Character=old;spawn:TrackMovementCharacter(p,old)
local newer,newh=character();p.Character=newer;spawn:TrackMovementCharacter(p,newer)
old.Humanoid=oh;assert(coroutine.resume(table.remove(suspended,1)))
check(oh:GetAttribute('BaseWalkSpeed')==nil and newh.WalkSpeed==32,'Stale wait cannot write replaced character')
local delayed,dh=character(false);p.Character=delayed;refresh('Playing');spawn:TrackMovementCharacter(p,delayed)
current=nil;p.Attrs.MatchId=nil;delayed.Humanoid=dh;assert(coroutine.resume(table.remove(suspended,1)))
check(dh.WalkSpeed==32,'Session ended while waiting: resolves lobby on resume')
c,h=character();p.Character=c;refresh('StartCountdown');spawn:LockCharacterMovement(p)
check(h.WalkSpeed==0,'Countdown lock zero')
spawn:RefreshMovementSpeed(p);check(h.WalkSpeed==0,'Base refresh preserves lock')
spawn:UnlockCharacterMovement(p);check(h.WalkSpeed==16,'Explicit unlock restores match base')
spawn:LockCharacterMovement(p);h.PlatformStand=true;spawn:UnlockCharacterMovement(p)
check(h.WalkSpeed==0,'Unlock does not interrupt ragdoll')
spawn:TrackMovementCharacter(p,c);h.PlatformStand=false;h.Changed:Fire()
check(h.WalkSpeed==0,'Tracking countdown reasserts lock')
current.State='Playing';spawn:UnlockCharacterMovement(p);check(h.WalkSpeed==16,'Resume after ragdoll')
h.PlatformStand=true;spawn:LockCharacterMovement(p);spawn:UnlockCharacterMovement(p)
check(h.WalkSpeed==0,'Deferred unlock while PlatformStand')
h.PlatformStand=false;h.Changed:Fire();check(h.WalkSpeed==16,'Ragdoll release completes pending explicit unlock')
current.State='Ending';spawn:LockCharacterMovement(p);spawn:RefreshMovementSpeed(p)
check(h.WalkSpeed==0,'Cinematic retains zero')
h:SetAttribute('MovementLocked',nil);h:SetAttribute('MovementSpeedUnlockPending',nil);h.WalkSpeed=0;M.SetBase(h,32)
check(h.WalkSpeed==0,'Unknown zero owner preserved')
h.WalkSpeed=16;M.SetBase(h,16)
local record={Humanoid=h,Definition={SpeedMultiplier=speed.Config.SpeedMultiplier,MaxSpeed=speed.Config.MaxSpeed,Acceleration=speed.Config.Acceleration}}
check(speed.Descriptor.Duration==5 and speed.Descriptor.Cooldown==14 and speed.Config.SpeedMultiplier==2.4 and speed.Config.MaxSpeed==48 and speed.Config.Acceleration==100,'DevilSpeed approved balance unchanged')
check(speed.Start(record),'DevilSpeed start')
check(speed.Step(record,.1) and h.WalkSpeed==26,'Acceleration exactly 100 per second')
speed.Step(record,1);check(math.abs(h.WalkSpeed-38.4)<.001,'Match multiplier 2.4 preserved')
speed.Cancel(record);check(h.WalkSpeed==16,'Expiry returns current match base')
speed.Start(record);speed.Step(record,1);M.SetBase(h,32);speed.Cancel(record)
check(h.WalkSpeed==32,'Modifier cleanup restores new lobby base, never captured 16')
speed.Start(record);speed.Step(record,1);check(h.WalkSpeed==48,'Existing absolute max speed 48 preserved')
local newerOwner={};speed.Cancel(record);M.SetModifier(h,newerOwner,3);speed.Cancel(record)
check(h.WalkSpeed==35,'Stale cleanup does not erase newer modifier')
M.RemoveModifier(h,newerOwner);M.SetBase(h,16);speed.Start(record);speed.Step(record,1)
h:SetAttribute('MovementLocked',true);h.WalkSpeed=0
check(not speed.Step(record,.1),'Competing lock cancels DevilSpeed')
speed.Cancel(record);check(h.WalkSpeed==0,'Modifier cleanup cannot release lock')
h:SetAttribute('MovementLocked',nil);M.Apply(h,true);check(h.WalkSpeed==16,'Lock release does not retain cancelled bonus')
spawn:ForgetMovementCharacter(p);check(h.Changed:Count()==0 and c.Pending:Count()==0,'Character cleanup disconnects listeners')
-- Execute actual RoundService transition hook with isolated dependencies.
local touched=0;local s={Id='round-test',State='MatchCountdown',StateVersion=0,Participants={}}
local fake=setmetatable({_sessionsById={[s.Id]=s},_getSpawnService=function()return{RefreshSessionMovement=function(_,arg)check(arg==s and arg.State=='MapSelection','State stored before movement refresh');touched+=1 end}end,
 _applySessionIdentity=function(_,_,x)return x end,FireSessionRemote=function()end},{__index=round})
check(fake:SetSessionState(s.Id,'MapSelection') and touched==1,'Actual RoundService invokes movement hook')
-- Actual zero-death Restore lifecycle, without physics simulation or real players.
rs.Shared.ArenaRespawnPolicy='Policy';loaded.Policy={}
loaded.Physics.Restore=function()end
local arena=load('ArenaRespawn',env({CharacterPhysics='Physics'}))
local lifecycle=arena.new(spawn)
c,h=character();p.Character=c;refresh('Playing');spawn:TrackMovementCharacter(p,c)
function h:SetStateEnabled()end
local recordRestore={Character=c,Humanoid=h,Root=c.Root,Properties={},AutoRotate=true,PlatformStand=false,JumpingEnabled=true,OwnerAuto=false,Anchored=false}
c.Root.Anchored=true;h.PlatformStand=true;c:SetAttribute('ArenaRespawnPending',true)
lifecycle:Restore(recordRestore);h.Changed:Fire();c.Pending:Fire()
check(h.WalkSpeed==16 and not h.PlatformStand and c:GetAttribute('ArenaRespawnPending')==nil,'Actual arena Restore keeps match base and restores pending lifecycle')
spawn:LockCharacterMovement(p);lifecycle:Restore(recordRestore);h.Changed:Fire();c.Pending:Fire()
check(h.WalkSpeed==0 and h:GetAttribute('MovementLocked'),'Actual arena Restore preserves countdown/cinematic lock')
spawn:ForgetMovementCharacter(p)
-- Start is idempotent and reuses the existing player lifecycle, without duplicate subscriptions.
players.PlayerAdded=signal();players.PlayerRemoving=signal();function players:GetPlayers()return{}end
spawn._respawnConnections={};spawn._respawnPlayerConnections={}
spawn:Start(spawn._context);spawn:Start(spawn._context)
check(players.PlayerAdded:Count()==1 and players.PlayerRemoving:Count()==1,'Duplicate Start cannot duplicate player listeners')
local beforeConfig=load('ConfigBefore',{Color3={fromRGB=function(...)return {...}end},Vector3={new=function(...)return {...}end}})
for k,value in pairs(beforeConfig.Economy)do check(config.Economy[k]==value,'Economy configuration preserved: '..k)end
check(config.Match.PointReward==beforeConfig.Match.PointReward,'Point reward unchanged')
rs.Shared.Progression={Model='Model'};rs.Shared.PointEffectDefinitions='Points';rs.Shared.DeathFeedbackConfig='DeathSettings'
loaded.Model={};loaded.Points={};loaded.DeathSettings={DeathEffects={}};loaded.Purchase={};loaded.WinStreak={}
local psClass=load('PlayerService',env({Gameplay={WinStreak='WinStreak'},Parent={Shop={ProfilePurchase='Purchase'}}}))
local ps=setmetatable({_data={[p]={Coins=0}},_coinTransactions={},_coins={},_sendDataUpdate=function()end},{__index=psClass})
local balance,credited=ps:AddCoins(p,config.Match.PointReward,'MatchPoint','Goal:movement-test')
check(credited==config.Match.PointReward and balance==credited,'Actual economy authority credits unchanged goal amount')
local repeated,extra=ps:AddCoins(p,config.Match.PointReward,'MatchPoint','Goal:movement-test')
check(repeated==balance and extra==0,'Coin reward remains idempotent')
print('MovementSpeedV10 PASS '..count..' assertions; no Studio, real players or cloud')
