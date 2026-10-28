--!nonstrict
-- Bundled by tests/tools/run_ability_unit_tests.py. Pure disposable mocks in the
-- official standalone Luau interpreter; no Studio, live players or cloud calls.
local passed=0
local function check(condition,label)
 assert(condition,label);passed+=1
end
local function load(name,environment)
 local f=assert(loadstring(Sources[name],name))
 setfenv(f,setmetatable(environment or {},{__index=getfenv()}));return f()
end
local Settings=load("Definitions")
local Fixture=load("Fixture",{Sources=Sources})
local fakeGuard={Take=function()return true end,Release=function()end,SafeDistance=function(_,delta)return delta.Magnitude end}
local fixtureEnv={script={Parent={MovementGuard=true}},require=function()return fakeGuard end}
local registry=Fixture.Build(fixtureEnv)
local D={DefaultId=Settings.DefaultId,Category=Settings.Category,Items={}}
for _,id in ipairs(registry.GetPublicCatalog().Order) do D.Items[id]=registry:Get(id).Definition end
for id,expected in pairs({Dash=11,StrongSlap=25,AirJumps=20,DevilSpeed=14,Invisible=35}) do
 check(D.Items[id].Cooldown==expected,"Approved cooldown contract: "..id)
end
local clock=0
local vectorMeta={}
local function vec(x,y,z) return setmetatable({X=x,Y=y,Z=z,__kind="Vector3"},vectorMeta) end
vectorMeta.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vectorMeta.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vectorMeta.__mul=function(a,b)return vec(a.X*b,a.Y*b,a.Z*b)end
vectorMeta.__div=function(a,b)return vec(a.X/b,a.Y/b,a.Z/b)end
vectorMeta.__index=function(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return v/v.Magnitude end
end
local V={new=vec,zero=vec(0,0,0)}
local function cf(position)
 return {LookVector=vec(0,0,-1),PointToObjectSpace=function(_,p)return p-position end,
  VectorToObjectSpace=function(_,p)return p end}
end
local P={}
local world={GetServerTimeNow=function()return 1000+clock end}
local function character()
 local attrs={ArenaPhysicsGeneration=1}
 local hum={Health=100,PlatformStand=false,WalkSpeed=16,Parent=true,FloorMaterial="Air"}
 local root={Anchored=false,Parent=true,Position=vec(0,0,0),CFrame=cf(vec(0,0,0)),AssemblyLinearVelocity=vec(0,0,0)}
 local char={Parent=world,Attributes=attrs,Humanoid=hum,Root=root}
 function char:GetAttribute(k)return attrs[k]end
 function char:IsDescendantOf(parent)return parent==world end
 function char:FindFirstChildOfClass()return hum end
 function char:FindFirstChild()return root end
 function char:GetPivot()return {Position=root.Position}end
 return char
end
local function player(id)
 local p={__kind="Instance",UserId=id,Parent=P,Character=character()}
 function p:IsA(class)return class=="Player"end
 return p
end
local a,b,outsider=player(-1),player(-2),player(10)
local ownership={[a]={Dash=true,StrongSlap=true,AirJumps=true,DevilSpeed=true,Invisible=true},[b]={Dash=true},[outsider]={Dash=true}}
local ps={}
function ps:IsShopDataReady(p)return p.Parent==P end
function ps:HasItem(p,category,id)return category=="Abilities" and ownership[p] and ownership[p][id]==true end
function ps:GetEquippedItem()return "Dash"end
function ps:SetEquippedItem(p,category,id)self.Preference=id;return self:HasItem(p,category,id)end
local session={Id="S",State="StartCountdown",StateVersion=1,Participants={{Player=a},{Player=b}}}
local members={[a]=session.Participants[1],[b]=session.Participants[2]}
local round={}
function round:GetSessionForPlayer(p)return members[p] and session end
function round:GetSessionById(id)return id==session.Id and session or nil end
function round:IsSessionActive(id)return id==session.Id and not session.Closed end
function round:GetSessionParticipant(id,p)return id==session.Id and members[p] or nil end
function round:IsGameplayRoundOpen(s)return s.State=="Playing" and not s.PointInProgress and not s.GameplayRound.Resolved end
local sends={}
local stateRemote={IsA=function(_,c)return c=="RemoteEvent"end,FireClient=function(_,p,data)table.insert(sends,{Player=p,Data=data})end}
local requestRemote={IsA=stateRemote.IsA,OnServerEvent={Connect=function()return {Disconnect=function()end}end}}
local combat={GetChildren=function()return {}end,FindFirstChild=function(_,name)return if name=="AbilityState" then stateRemote else requestRemote end}
local shared={AbilityDefinitions="Definitions",AbilityDiagnostics="Diagnostics"}
local traceEnabled=false
local traceRows={}
local Diagnostics={Build="AbilityMultiplayerFixV1",Enabled=function()return traceEnabled end,
 TraceId=function(v)return v end,Forget=function()end,
 Emit=function(side,phase,row)if traceEnabled then table.insert(traceRows,{Side=side,Phase=phase,Values=row})end end}
local modules={DashAbility="Dash",StrongSlapAbility="Strong",AirJumpsAbility="Air",DevilSpeedAbility="Speed",InvisibilityAbility="Invisible"}
local calls={Starts=0,Cancels=0,Jumps=0}
local failureMode
fixtureEnv.Vector3=V;fixtureEnv.Enum={Material={Air="Air"}};fixtureEnv.os={clock=function()return clock end}
registry=Fixture.Build(fixtureEnv,function(module)
 local start,cancel,action=module.Start,module.Cancel,module.OnAction
 module.Start=function(...)
  calls.Starts+=1
  if failureMode=="throw" then error("activation failure") end
  if failureMode=="yield" then coroutine.yield();error("late callback resumed") end
  return start(...)
 end
 module.Cancel=function(...)calls.Cancels+=1;return cancel(...)end
 if action then module.OnAction=function(...)calls.Jumps+=1;return action(...)end end
end)
local Callbacks=load("Callbacks")
local Input=load("Input",{Vector3=V,typeof=function(v)return type(v)=="table" and v.__kind or type(v)end})
modules.AbilityCallbacks="Callbacks";modules.AbilityInputAdapter="Input"
local services={Players=P,RunService={},ReplicatedStorage={Shared=shared,Remotes={Combat=combat}},
 HttpService={GenerateGUID=function()servicesDummy=(servicesDummy or 0)+1;return tostring(servicesDummy)end}}
local gameMock={GetService=function(_,name)return assert(services[name],name)end}
local onWait
local env={game=gameMock,workspace=world,Vector3=V,warn=function()end,script={Parent={AbilityRegistry="Registry",Parent={Abilities=modules}}},
 os={clock=function()return clock end},typeof=function(v)return type(v)=="table" and v.__kind or type(v)end,
 task={wait=function(t)if onWait then local callback=onWait;onWait=nil;callback()end;clock+=math.max(t,0.000001)end},
 require=function(module)return assert(({Definitions=Settings,Registry=registry,Callbacks=Callbacks,Input=Input,Diagnostics=Diagnostics})[module],tostring(module))end}
local S=load("Service",env)
local context={GetService=function(_,name)
 return ({RoundService=round,PlayerService=ps,SpawnService={IsKillPartRespawnPending=function()return false end},
  RagdollService={IsRagdolled=function(_,char)return char.Humanoid.PlatformStand end}})[name]
end}
S:Init(context)
onWait=function()
 local r=S._sessions.S
 S:HandleRequest(a,{Action="Select",SessionId="S",WindowId=r.WindowId,PreparationId=r.PreparationId,RequestId="owned",AbilityId="StrongSlap"})
 S:HandleRequest(b,{Action="Select",SessionId="S",WindowId=r.WindowId,PreparationId=r.PreparationId,RequestId="locked",AbilityId="Invisible"})
end
check(S:PrepareSelection(session,5),"Selection opens with the real countdown deadline")
onWait();onWait=nil
local record=S._sessions.S
check(clock==0,"Selection adds no extra preparation wait")
check(record.Players[a].AbilityId=="StrongSlap","Owned selection accepted during window")
check(record.Players[b].AbilityId=="Dash","Unowned selection rejected")
check(record.Players[a]~=record.Players[b],"Negative Studio identifiers do not collide")
clock=5;S:FinishSelection(session,record.WindowId)
session.GameplayRound={Id="R1",Index=1};session.State="Playing";S:BeginRound(session)
local function request(p,action,overrides)
 clock+=0.13
 local state=record.Players[p]
 local payload={Action=action,SessionId="S",RoundId=record.RoundId,AbilityId=state and state.AbilityId,
  LifeId=state and state.LifeId,CharacterGeneration=p.Character.Attributes.ArenaPhysicsGeneration,
  ActivationId=state and state.Active and state.Active.ActivationId,Direction=vec(0,0,-1)}
 for k,v in pairs(overrides or {})do payload[k]=v end
 S:HandleRequest(p,payload)
end
request(a,"Activate")
local active=record.Players[a].Active
check(active and active.Runtime.State=="Armed","StrongSlap is armed authoritatively")
check(active.Runtime.SessionId=="S" and active.Runtime.UserId==-1 and active.Character==a.Character,"Activation has session/player/Character identity")
check(active.CharacterGeneration==1 and active.ActivationId~=nil,"Activation identifies its generation and receipt")
check(math.abs(active.CooldownUntil-active.Runtime.ActivatedAt-25)<0.00001,"Cooldown starts at activation")
check(math.abs(active.ActiveUntil-active.Runtime.ActivatedAt-15)<0.00001,"Strong window is 15 seconds")
local starts=calls.Starts;request(a,"Activate")
check(calls.Starts==starts,"Repeated activation does not create a second charge")
local deadline=record.Players[a].CooldownUntil
check(S:PrepareHit(a,session)~=nil,"Charge stays armed until valid hit or expiry")
clock+=15;S:Step(0.01)
check(record.Players[a].Active==nil,"Expired charge clears without a hit")
check(record.Players[a].CooldownUntil==deadline,"Expiry does not restart cooldown")
request(a,"Activate");check(record.Players[a].Active==nil,"Cooldown remains enforced after expiry")
local oldLife=record.Players[a].LifeId
a.Character=character();S:Publish(a,record)
check(record.Players[a].LifeId~=oldLife,"New Character gets a different life token even at same generation")
check(record.Players[a].CooldownUntil==deadline,"Death/new Character preserves round cooldown")
clock=deadline+0.1
request(a,"Activate",{LifeId=oldLife});check(record.Players[a].Active==nil,"Prior-life activation is rejected")
request(a,"Activate",{RoundId="old"});check(record.Players[a].Active==nil,"Stale round rejected")
request(a,"Activate",{SessionId="other"});check(record.Players[a].Active==nil,"Wrong session rejected")
a.Character.Humanoid.PlatformStand=true
request(a,"Activate");check(record.Players[a].Active==nil,"Ragdoll rejects activation")
a.Character.Humanoid.PlatformStand=false;a.Character.Humanoid.WalkSpeed=0
request(a,"Activate");check(record.Players[a].Active==nil,"Movement lock rejects activation")
a.Character.Humanoid.WalkSpeed=16;a.Character.Attributes.ArenaRespawnPending=true
request(a,"Activate");check(record.Players[a].Active==nil,"Pending elimination rejects activation")
a.Character.Attributes.ArenaRespawnPending=nil
request(a,"Activate");check(record.Players[a].Active~=nil,"Valid activation after cooldown is accepted")
local ticket=S:PrepareHit(a,session)
check(S:ConsumeHit(a,session,b,ticket),"Confirmed hit consumes charge")
check(not S:ConsumeHit(a,session,b,ticket),"Second consumption rejected")
check(record.Players[a].CooldownUntil>clock,"Hit consumption retains cooldown")
clock+=0.13;S:HandleRequest(a,{Action="Select",SessionId="S",WindowId=record.WindowId,AbilityId="Dash"})
check(record.Players[a].AbilityId=="StrongSlap","Selection cannot change during Playing")
S:CancelSession("S","Goal")
check(not record.Playing and record.Players[a].Active==nil,"Goal cancels all active effects")
request(a,"Activate");check(record.Players[a].Active==nil,"Activation blocked between rounds")
session.GameplayRound={Id="R2"};S:BeginRound(session)
check(record.Players[a].CooldownUntil==0,"New round resets cooldown after preparation contract")
request(a,"Activate")
check(record.Players[a].Active~=nil,"New round activation accepted")
members[a]=nil -- RoundService disconnect callback may have already unregistered it.
S:CancelPlayer(a,"Disconnect")
check(record.Players[a].Active==nil,"Disconnect cleans effects after registry removal")
members[a]=session.Participants[1]
local lobbyCount=#sends
request(outsider,"Sync")
local lobby=sends[#sends]
check(#sends==lobbyCount+1 and lobby.Player==outsider and not lobby.Data.SessionId and #lobby.Data.Presentations==0,"Lobby gets no foreign match HUD/effects")
request(b,"Activate",{Direction=vec(0/0,0,0)})
check(record.Players[b].Active==nil,"Nonfinite dash direction rejected")
clock+=0.13
S:HandleRequest(b,{Action="Sync"});local afterSync=#sends
S:HandleRequest(b,{Action="Sync"});check(#sends==afterSync,"Remote spam is rate limited")
record.Players[a].AbilityId="AirJumps";record.Players[a].CooldownUntil=0
request(a,"Activate")
check(record.Players[a].Active~=nil,"Generic activation starts AirJumps")
local jumps=calls.Jumps
request(a,"AirJump")
check(calls.Jumps==jumps+1,"Manifest-declared action reaches OnAction")
request(a,"UnapprovedAction")
check(calls.Jumps==jumps+1,"Undeclared secondary action rejected")
local airToken=record.Players[a].Active.ActivationId
a.Character.Attributes.ArenaPhysicsGeneration+=1
request(a,"AirJump",{ActivationId=airToken})
check(record.Players[a].Active==nil and calls.Jumps==jumps+1,"Generation change cancels stale secondary callback")
for _,mode in ipairs({"throw","yield"})do
 failureMode=mode;record.Players[a].AbilityId="Dash";record.Players[a].CooldownUntil=0
 local cancels=calls.Cancels
 request(a,"Activate")
 check(record.Players[a].Active==nil and record.Players[a].CooldownUntil==0,"Failed activation has no charge or cooldown: "..mode)
 check(calls.Cancels==cancels+1,"Partial activation cleanup runs once: "..mode)
 S:CancelPlayer(a,"Repeated")
 check(calls.Cancels==cancels+1,"Duplicate cancellation cannot repeat cleanup: "..mode)
end
failureMode=nil
request(a,"Activate")
check(record.Players[a].Active~=nil,"Other activation still works after contained errors")
local cancels=calls.Cancels
S:CleanupSession("S","Closed");check(S._sessions.S==nil,"Session records released")
S:CleanupSession("S","Closed")
check(calls.Cancels==cancels+1,"Repeated round closure does not repeat module cleanup")
local duplicateService=load("Service",env)
combat.GetChildren=function()return {{Name="AbilityState"},{Name="AbilityState"}}end
check(not pcall(function()duplicateService:Init(context)end),"Duplicate physical ability remote fails closed")
combat.GetChildren=function()return {}end

local Purchase=load("Purchase")
local profile={Coins=500,Inventory={Owned={Abilities={Dash=true}},Equipped={Abilities="Dash"}}}
local product={Id="StrongSlap",Category="Abilities",ProductType="Ability",Currency="Coins",Price=100,IsAvailable=true,Metadata={PurchaseEnabled=false}}
check(Purchase.Stage(profile,product)==nil,"Unapproved ability purchase blocked in atomic staging")
product.Metadata.PurchaseEnabled=true;product.Metadata.PriceApproved=true
local nextProfile=Purchase.Stage(profile,product)
check(nextProfile.Coins==400 and nextProfile.Inventory.Owned.Abilities.StrongSlap,"Approved purchase atomically grants ownership and debits existing Coins")
check(profile.Coins==500 and not profile.Inventory.Owned.Abilities.StrongSlap,"Purchase staging leaves original profile intact")
check(nextProfile.Inventory.Equipped.Abilities=="Dash","Purchase does not change current preference/selection")
check(Purchase.Stage(nextProfile,product)==nil,"Duplicate purchase rejected")
product.Price=501;check(Purchase.Stage(profile,product)==nil,"Insufficient Coins rejected")
product.Price=0/0;check(Purchase.Stage(profile,product)==nil,"Nonfinite price rejected")
local providerGame={ReplicatedStorage={Shared=shared},ServerScriptService={Services={PlayerService="Players",AbilityRegistry="Registry"}}}
local Provider=load("Provider",{game=providerGame,require=function(id)return ({Definitions=Settings,Registry=registry,Players=ps})[id] end})
check(#Provider:GetProducts()==5,"Five abilities share one Shop provider")
check(Provider:GetProduct("Dash").Price==0,"Dash is free")
for _,id in ipairs({"StrongSlap","AirJumps","DevilSpeed","Invisible"}) do
 local p=Provider:GetProduct(id)
 check(not p.Metadata.PricePending and p.Metadata.PurchaseEnabled and p.Metadata.PriceApproved,"Approved commercial purchase enabled: "..id)
end
check(Provider:CanPurchase(b,Provider:GetProduct("StrongSlap")),"Provider accepts unowned registered ability with approved commercial metadata")
check(not pcall(function()registry:Get("StrongSlap").Shop.Price=100 end),"Sealed commercial metadata cannot change during a match")

local Speed=load("Speed")
local speedRecord={Humanoid={WalkSpeed=16,Parent=true},Definition=D.Items.DevilSpeed}
check(Speed.Start(speedRecord),"Speed modifier captures valid base")
Speed.Step(speedRecord,0.1);check(speedRecord.Humanoid.WalkSpeed>16,"Speed accelerates toward configured target")
Speed.Cancel(speedRecord);check(speedRecord.Humanoid.WalkSpeed==16,"Owned speed restored")
Speed.Start(speedRecord);Speed.Step(speedRecord,0.1);speedRecord.Humanoid.WalkSpeed=0
check(not Speed.Step(speedRecord,0.1),"Competing movement lock cancels modifier")
Speed.Cancel(speedRecord);check(speedRecord.Humanoid.WalkSpeed==0,"Cleanup preserves another owner's movement lock")

local released=0
local fakeGuard={Take=function()return true end,Release=function()released+=1 end,SafeDistance=function(_,delta)return delta.Magnitude end}
local motionEnv={require=function()return fakeGuard end,script={Parent={MovementGuard=true}},Vector3=V,
 Enum={Material={Air="Air"}},os={clock=function()return clock end}}
local Air=load("Air",motionEnv)
local c=character()
local ar={Root=c.Root,Character=c,Humanoid=c.Humanoid,Definition=D.Items.AirJumps}
check(Air.Start(ar),"Air window starts without taking permanent network ownership")
clock+=1;check(Air.Jump(ar,clock),"Server accepts moderated extra jump")
check(ar.Root.AssemblyLinearVelocity.Y<=D.Items.AirJumps.MaxVerticalVelocity,"Vertical velocity capped")
check(not Air.Jump(ar,clock+0.1),"Jump interval enforced")
for _=1,3 do clock+=1;check(Air.Jump(ar,clock),"Consecutive jump within limit") end
clock+=1;check(not Air.Jump(ar,clock),"Air jump count caps ascent")
ar.Humanoid.FloorMaterial="Ground";Air.Step(ar,0.1)
check(ar.AirJumps==0,"Grounded state resets server jump count")
ar.Humanoid.FloorMaterial="Air";ar.Root.Position=vec(0,25,0)
check(not Air.Jump(ar,clock+1),"Rise limit enforced")
Air.Cancel(ar);check(released>0,"Jump ownership is released")
local Dash=load("Dash",motionEnv)
for _,dir in ipairs({vec(0,0,-1),vec(0,0,1),vec(-1,0,0),vec(1,0,0),vec(0.7,0,-0.7),vec(0,0,0)}) do
 local dchar=character()
 local dr={Root=dchar.Root,Character=dchar,Humanoid=dchar.Humanoid,Definition=D.Items.Dash}
 check(Dash.Start(dr,dir),"Dash accepts validated cardinal/diagonal/stationary direction")
 check(math.abs(dr.Direction.Magnitude-1)<0.0001 and dr.Direction.Y==0,"Dash normalizes horizontal direction")
 check(Dash.Step(dr,0.016),"Dash step uses bounded time and sweep")
 Dash.Cancel(dr);check(dr.Root.AssemblyLinearVelocity.Magnitude==0,"Dash cancellation removes its horizontal impulse")
end
local physics={GetPartBoundsInBox=function()return {}end,Blockcast=function()return nil end}
local Guard=load("Guard",{Vector3=V,workspace=physics,RaycastParams={new=function()return {}end},OverlapParams={new=function()return {}end},Enum={RaycastFilterType={Exclude=true}}})
check(Guard.SegmentBox(cf(vec(4,0,0)),vec(1,1,1),vec(0,0,0),vec(10,0,0),0)~=nil,"Nonqueryable sensor geometric sweep intersects")
check(Guard.SegmentBox(cf(vec(4,10,0)),vec(1,1,1),vec(0,0,0),vec(10,0,0),0)==nil,"Separated sensor does not intersect")
local g={Root={CFrame=cf(vec(0,0,0)),Position=vec(0,0,0)},Character={},World={VoidBoundaryPart={Position=vec(0,0,0),Size=vec(100,1,100)},KillParts={}}}
check(Guard.SafeDistance(g,vec(10,0,0))==10,"Unobstructed bounded sweep allows distance")
physics.Blockcast=function()return {Distance=3}end
check(Guard.SafeDistance(g,vec(10,0,0))<3,"Wall collision clips distance with margin")
physics.GetPartBoundsInBox=function()return {{}}end
check(Guard.SafeDistance(g,vec(10,0,0))==0,"Initial overlap fails closed")
physics.GetPartBoundsInBox=function()return {}end;physics.Blockcast=function()return nil end
check(Guard.SafeDistance(g,vec(60,0,0))==0,"Arena envelope cannot be crossed")
g.World.KillParts={{CFrame=cf(vec(4,0,0)),Size=vec(1,1,1)}}
check(Guard.SafeDistance(g,vec(10,0,0))<4,"Noncolliding KillPart is not skipped")
local owner,auto="OriginalPlayer",true
local ownedRoot={Parent=true,CanSetNetworkOwnership=function()return true end,
 GetNetworkOwnershipAuto=function()return auto end,GetNetworkOwner=function()return owner end,
 SetNetworkOwner=function(_,value)owner=value;auto=false end,SetNetworkOwnershipAuto=function()auto=true end}
local taken,previous=Guard.Take(ownedRoot)
check(taken and owner==nil and not auto,"Movement takes server ownership")
Guard.Release(ownedRoot,previous);check(auto,"Original automatic ownership restored")
owner="ManualOwner";auto=false
taken,previous=Guard.Take(ownedRoot);Guard.Release(ownedRoot,previous)
check(owner=="ManualOwner" and not auto,"Original explicit owner restored")
taken,previous=Guard.Take(ownedRoot);owner="NewOwner";Guard.Release(ownedRoot,previous)
check(owner=="NewOwner","Cleanup preserves a newer explicit owner")
for _,send in ipairs(sends)do check(send.Data.Kind~="AbilityDiagnostic","Disabled diagnostics send no optional packets")end
traceEnabled=true
session.State="StartCountdown";session.StateVersion+=1;session.GameplayRound=nil
S:PrepareSelection(session,5);record=S._sessions.S
clock+=5;S:FinishSelection(session,record.WindowId)
session.State="Playing";session.GameplayRound={Id="TraceRound",Index=1};S:BeginRound(session)
request(a,"Activate",{TraceId="aaaa"})
check(record.Players[a].Active~=nil,"Free default Dash activation is accepted with diagnostics enabled")
local activationA=record.Players[a].Active.ActivationId
local function phases(phase,who)
 local n=0 for _,r in ipairs(traceRows)do if r.Phase==phase and (who==nil or r.Values.UserId==who)then n+=1 end end return n
end
check(phases("Received",-1)==1 and phases("StartBegin",-1)==1 and phases("Accepted",-1)==1,"Trace identifies received/start/accepted stages for actual UserId")
S:Step(.016);S:Step(.016)
check(phases("FirstStep",-1)==1,"Movement observation occurs once, never every frame")
request(b,"Activate",{TraceId="bbbb"})
check(record.Players[b].Active and record.Players[b].Active.ActivationId~=activationA,"Two Studio users have independent activation identities")
local accepted=sends[#sends]
check(accepted.Player==b and accepted.Data.Kind=="AbilityDiagnostic" and accepted.Data.Result=="Accepted","Diagnostic result is private to requesting participant")
S:CancelPlayer(a,"FixtureCancel");clock+=.6
request(a,"Activate",{TraceId="cccc"})
local rejected=sends[#sends]
check(rejected.Data.Kind=="AbilityDiagnostic" and rejected.Data.Reason=="Cooldown","Rejection reports exact cooldown gate")
clock=record.Players[a].CooldownUntil+.1
request(a,"Activate",{TraceId="dddd"});S:Step(.11)
check(record.Players[a].Active==nil,"Existing long-frame guard still cancels movement")
local longFrame=false
for _,r in ipairs(traceRows)do if r.Phase=="Cancelled" and r.Values.UserId==-1 and r.Values.Reason=="LongFrame" then longFrame=true end end
check(longFrame,"Cancelled trace exposes long-frame cause without changing the guard")
check(D.Items.Dash.Cooldown==11 and D.Items.Dash.Duration==.2 and D.Items.Dash.DistanceStuds==24,"Dash values unchanged")
S:CleanupSession("S","FixtureEnd")
print(string.format("PASS: %d isolated activation/regression assertions; no Studio/gameplay/cloud execution.",passed))
