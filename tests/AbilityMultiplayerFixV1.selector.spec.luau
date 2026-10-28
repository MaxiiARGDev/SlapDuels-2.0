--!nonstrict
-- Pure selection/GUI-state mocks outside Studio; not a gameplay validation.
local passed=0
local function check(value,label) assert(value,label);passed+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local D=load("Definitions")
local Fixture=load("Fixture",{Sources=Sources})
local registry=Fixture.Build({script={Parent={MovementGuard=true}},require=function()return {}end})
local Catalog=load("Catalog");assert(Catalog.Apply(registry.GetPublicCatalog()))
local clock,sequence=0,0
local function guid()sequence+=1;return "request-"..sequence end
local Players={}
local function player(id)
 local p={UserId=id,Parent=Players,__kind="Instance"}
 function p:IsA(class)return class=="Player"end
 return p
end
local a,b=player(-1),player(-2)
local owned={[a]={Dash=true,StrongSlap=true,AirJumps=true},[b]={Dash=true}}
local session={Id="S",State="StartCountdown",StateVersion=1,Participants={{Player=a},{Player=b}},RedScore=0,BlueScore=0}
local members={[a]=true,[b]=true}
local rounds={}
function rounds:GetSessionForPlayer(p)return members[p] and session end
function rounds:GetSessionById(id)return id=="S" and session end
function rounds:IsSessionActive(id)return id=="S" and not session.Closed end
function rounds:GetSessionParticipant(id,p)return id=="S" and members[p] end
local ps={}
function ps:IsShopDataReady(p)return p.Parent==Players end
function ps:HasItem(p,category,id)return category=="Abilities" and owned[p] and owned[p][id]==true end
function ps:GetEquippedItem()return "Dash"end
local messages={}
local stateRemote={IsA=function(_,c)return c=="RemoteEvent"end,FireClient=function(_,p,payload)table.insert(messages,{Player=p,Payload=payload})end}
local requestRemote={IsA=stateRemote.IsA,OnServerEvent={Connect=function()return {Disconnect=function()end}end}}
local combat={GetChildren=function()return {}end,FindFirstChild=function(_,name)return if name=="AbilityState" then stateRemote else requestRemote end}
local modules={DashAbility=true,StrongSlapAbility=true,AirJumpsAbility=true,DevilSpeedAbility=true,InvisibilityAbility=true}
local shared={AbilityDefinitions="Definitions",AbilityDiagnostics="Diagnostics"}
local diagnostics={Enabled=function()return false end,Emit=function()end,TraceId=function()end,Forget=function()end}
local services={Players=Players,RunService={},HttpService={GenerateGUID=guid},ReplicatedStorage={Shared=shared,Remotes={Combat=combat}}}
local gameMock={GetService=function(_,name)return services[name]end}
local world={GetServerTimeNow=function()return 1000+clock end}
local service=load("Service",{game=gameMock,workspace=world,script={Parent={AbilityRegistry="Registry",Parent={Abilities=modules}}},
 os={clock=function()return clock end},typeof=function(v)return type(v)=="table" and v.__kind or type(v)end,
 require=function(id)return ({Definitions=D,Registry=registry,Diagnostics=diagnostics})[id]end,
 task={wait=function()error("Selection must not add waits")end}})
service.SyncLife=function()end -- Life/activation behavior is outside this selector-only fixture.
service:Init({GetService=function(_,name)return if name=="RoundService" then rounds else ps end})
local initialConnections=#service._connections
local start=clock
local window=service:PrepareSelection(session,5)
local record=service._sessions.S
check(type(window)=="string","Initial window has a token")
check(clock==start,"Opening selection adds no waiting")
check(record.SelectionUntil-start==5,"Initial selection shares the five-second countdown")
check(record.PreparationIndex==1,"First round identified from authoritative lifecycle")
check(record.Players[a].AbilityId=="Dash","Default selection is retained without opening a menu")
local function choose(p,id,changes,advance)
 if advance~=false then clock+=0.13 end
 local payload={Action="Select",SessionId="S",WindowId=record.WindowId,PreparationId=record.PreparationId,AbilityId=id,RequestId=guid()}
 for k,v in pairs(changes or {})do payload[k]=v end
 service:HandleRequest(p,payload)
end
choose(a,"StrongSlap")
check(record.Players[a].AbilityId=="StrongSlap","Owned selection confirmed by server")
check(record.Players[a].SelectionReceipt.Accepted,"Confirmation receipt emitted")
check(record.Players[b].AbilityId=="Dash","Selection is individual per participant")
choose(b,"StrongSlap")
check(not record.Players[b].SelectionReceipt.Accepted and record.Players[b].AbilityId=="Dash","Unowned skill rejected without replacing selection")
choose(a,"AirJumps",{SessionId="other"})
check(record.Players[a].AbilityId=="StrongSlap","Foreign session request rejected")
choose(a,"AirJumps",{PreparationId="old"})
check(not record.Players[a].SelectionReceipt.Accepted,"Wrong preparation rejected")
choose(a,"AirJumps",{WindowId="old"})
check(record.Players[a].AbilityId=="StrongSlap","Old window rejected")
local deadline=record.SelectionUntil
check(service:PrepareSelection(session,5)==window,"Duplicate opener reuses current window")
check(record.SelectionUntil==deadline,"Duplicate opener cannot extend deadline")
check(record.Players[a].AbilityId=="StrongSlap","Duplicate opener cannot reset confirmed choice")
clock=deadline
choose(a,"AirJumps",nil,false)
check(record.Players[a].AbilityId=="StrongSlap" and not record.Players[a].SelectionReceipt.Accepted,"Exact deadline rejects late selection")
check(not service:IsSelectionOpen(record,a),"Server closes eligibility even before Heartbeat")
service:Step(0)
check(not record.Selecting,"Heartbeat expires selection without another timer thread")
session.State="Playing";session.StateVersion+=1;session.GameplayRound={Id="R1",Index=1}
service:BeginRound(session)
choose(a,"AirJumps")
check(record.Players[a].AbilityId=="StrongSlap","Playing rejects selection")
session.State="PointRestartCountdown";session.StateVersion+=1
local previousWindow,previousPreparation=record.WindowId,record.PreparationId
local restartStart=clock
local restart=service:PrepareSelection(session,3);record=service._sessions.S
check(math.abs(record.SelectionUntil-restartStart-3)<0.000001,"Restart window shares the three-second countdown")
check(clock==restartStart,"Restart adds no delay")
check(record.PreparationIndex==2 and session.RedScore==0 and session.BlueScore==0,"Round identity does not depend on 0-0 score")
check(record.WindowId~=previousWindow and record.PreparationId~=previousPreparation,"Next preparation has a new identity")
check(record.Players[a].AbilityId=="StrongSlap","Previous round choice is retained instead of reverting to preference")
choose(a,"AirJumps",{WindowId=previousWindow,PreparationId=previousPreparation})
check(record.Players[a].AbilityId=="StrongSlap","Prior round replay rejected")
choose(a,"AirJumps")
check(record.Players[a].AbilityId=="AirJumps","New window allows a new owned selection")
members[a]=nil;choose(a,"Dash")
check(record.Players[a].AbilityId=="AirJumps","Unregistered participant cannot change selection")
members[a]=true;a.Parent=nil;choose(a,"Dash")
check(record.Players[a].AbilityId=="AirJumps","Disconnected player cannot change selection")
a.Parent=Players
session.Closing=true;choose(a,"Dash")
check(record.Players[a].AbilityId=="AirJumps","Closing session rejects selection")
session.Closing=false;session.Result="Red";choose(a,"Dash")
check(record.Players[a].AbilityId=="AirJumps","Results reject selection")
session.Result=nil
session.StateVersion+=1;choose(a,"Dash")
check(record.Players[a].AbilityId=="AirJumps","Changed preparation generation rejects selection")
service:Step(0)
check(not record.Selecting,"State-version change closes old window")
check(#service._connections==initialConnections,"Windows add no event connections")
service:CleanupSession("S","Lobby")
check(service._sessions.S==nil,"Lobby cleanup releases window state")

-- Client selector: render/tick never open it; only explicit Open does.
local function card()
 local c={AbilityName={},Description={},Cooldown={},Icon={},Status={}}
 c.Activated={Connect=function(_,callback)c.Click=callback;return {Disconnect=function()c.Disconnected=true end}end}
 function c:Destroy()self.Destroyed=true end
 return c
end
local frame={Visible=true,Title={},Cards={AbilityCardTemplate={Clone=function()return card()end}}}
local clientGame={ReplicatedStorage={Shared=shared},GetService=function()return services.HttpService end}
local Selection=load("Selection",{game=clientGame,workspace=world,require=function()return Catalog end})
local sent={}
local selector=Selection.new(frame,function(id,p,requestId)table.insert(sent,{Id=id,RequestId=requestId,Window=p.WindowId,Preparation=p.PreparationId})end,
 function(p)return p.SessionId=="S"end)
local p={SessionId="S",WindowId="W1",PreparationId="P1",PreparationState="StartCountdown",Selecting=true,
 Playing=false,Preparing=true,SelectionUntil=1000+clock+5,AbilityId="Dash",Owned={Dash=true,StrongSlap=true}}
selector:Render(p)
check(not frame.Visible,"Initial server snapshot does not auto-open menu")
selector:Tick();check(not frame.Visible,"Clock ticks do not open menu")
check(selector:CanOpen(),"Change button is eligible during preparation")
check(selector:Open() and frame.Visible,"Explicit button action opens menu")
selector.Cards.AirJumps.Click();check(#sent==0,"Locked card cannot send selection")
selector.Cards.StrongSlap.Click()
check(#sent==1 and selector.Pending~=nil,"Owned card sends request and waits for server receipt")
check(frame.Visible and p.AbilityId=="Dash","No optimistic menu close or local selection replacement")
selector.Cards.Dash.Click();check(#sent==1,"Pending confirmation prevents request overlap")
p.SelectionReceipt={RequestId="unrelated",WindowId="W1",PreparationId="P1",Accepted=true,AbilityId="Dash"}
selector:Render(p);check(frame.Visible,"Unrelated receipt cannot close pending selection")
p.AbilityId="StrongSlap"
p.SelectionReceipt={RequestId=sent[1].RequestId,WindowId="W1",PreparationId="P1",Accepted=true,AbilityId="StrongSlap"}
selector:Render(p)
check(not frame.Visible and selector.Pending==nil,"Matching authoritative confirmation closes menu")
check(selector.Payload.AbilityId=="StrongSlap","Confirmed state remains available to current-ability HUD")
selector:Open();selector.Cards.Dash.Click()
p.SelectionReceipt={RequestId=sent[2].RequestId,WindowId="W1",PreparationId="P1",Accepted=false,AbilityId="StrongSlap"}
selector:Render(p)
check(frame.Visible and selector.Pending==nil and p.AbilityId=="StrongSlap","Rejection preserves previous selection and allows retry inside window")
clock=p.SelectionUntil-1000
selector:Tick()
check(not frame.Visible and not selector:CanOpen(),"Local deadline closes menu and hides change button without waiting for network")
check(not selector:Open(),"Menu cannot reopen after deadline")
p.WindowId="W2";p.PreparationId="P2";p.PreparationState="PointRestartCountdown";p.SelectionUntil=1000+clock+3
selector:Render(p)
check(not frame.Visible and selector:CanOpen(),"Next window shows eligibility without auto-opening")
selector:Open();p.WindowId="W3";p.PreparationId="P3";selector:Render(p)
check(not frame.Visible and selector.Pending==nil,"New preparation clears old menu/pending state")
p.Playing=true;selector:Render(p)
check(not selector:Open(),"Playing blocks local menu opening")
p.Playing=false;p.SessionId="other";selector:Render(p)
check(not selector:CanOpen(),"Foreign session cannot open menu")
p.SessionId="S";p.Selecting=false;selector:Render(p)
check(not selector:Open(),"Server cancellation closes and locks selector")
selector:Destroy()
check(not frame.Visible and selector.Cards.Dash.Disconnected and selector.Cards.Dash.Destroyed,"Controller destruction disconnects and removes cloned cards")
print(string.format("PASS: %d isolated selection assertions; no Studio/gameplay/cloud execution.",passed))
