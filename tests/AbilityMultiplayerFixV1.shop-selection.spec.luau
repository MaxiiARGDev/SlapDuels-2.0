--!nonstrict
-- Purchase/preference/selection integration over the actual production methods.
local count=0
local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local F=load("ShopFixture",{Sources=Sources});local s=F.New()
local clock,seq=1,0
local function guid()seq+=1;return "window-"..seq end
local a,b=s.A,s.B
local session={Id="S",State="StartCountdown",StateVersion=1,Participants={{Player=a},{Player=b}}}
local rounds={GetSessionForPlayer=function(_,p)return if p==a or p==b then session else nil end,
 GetSessionById=function(_,id)return if id=="S" then session else nil end,
 IsSessionActive=function()return true end,GetSessionParticipant=function(_,id,p)return id=="S" and (p==a or p==b)end}
local messages={}
local stateRemote={Name="AbilityState",IsA=function()return true end,FireClient=function(_,p,msg)messages[p]=msg end}
local requestRemote={Name="AbilityRequest",IsA=function()return true end,OnServerEvent={Connect=function()return {}end}}
local combat={GetChildren=function()return {stateRemote,requestRemote}end,
 FindFirstChild=function(_,name)return if name=="AbilityState" then stateRemote else requestRemote end}
local world={GetServerTimeNow=function()return 1000+clock end}
local services={Players=s.Players,RunService={},HttpService={GenerateGUID=guid},ReplicatedStorage={Shared={AbilityDefinitions="Definitions",AbilityDiagnostics="Diagnostics"},Remotes={Combat=combat}}}
local diagnostics={Enabled=function()return false end,Emit=function()end,TraceId=function()end,Forget=function()end}
local modules={AbilityCallbacks="Callbacks",AbilityInputAdapter="Input"}
local abilities=load("Service",{game={GetService=function(_,name)return services[name]end},workspace=world,
 script={Parent={AbilityRegistry="Registry",Parent={Abilities=modules}}},os={clock=function()return clock end},
 require=function(name)return ({Definitions=s.Settings,Registry=s.AbilityRegistry,Callbacks={},Input={},Diagnostics=diagnostics})[name]end,
 typeof=s.Env.typeof})
abilities.SyncLife=function()end -- Activation/life mechanics covered by separate regression.
abilities:Init({GetService=function(_,name)return if name=="RoundService" then rounds else s.PS end})
local opened=clock
abilities:PrepareSelection(session,5)
local record=abilities._sessions.S
check(record.SelectionUntil==opened+5 and record.Players[a].AbilityId=="Dash","Initial selection remains five seconds with free default")
local function select(p,id)
 clock+=.13
 abilities:HandleRequest(p,{Action="Select",SessionId="S",PreparationId=record.PreparationId,WindowId=record.WindowId,RequestId=guid(),AbilityId=id})
end
select(a,"AirJumps")
check(not record.Players[a].SelectionReceipt.Accepted,"Unowned skill cannot be selected")
check(s.Shop:PurchaseProduct(a,"AirJumps","Abilities"),"Skill purchased through actual Shop pipeline")
abilities:PublishSession(record)
check(messages[a].Owned.AirJumps and not messages[b].Owned.AirJumps,"New property published only for actual owner")
select(a,"AirJumps")
check(record.Players[a].AbilityId=="AirJumps" and record.Players[a].SelectionReceipt.Accepted,"Bought skill selectable inside original five-second window")
check(s.PS:GetEquippedItem(a,"Abilities")=="Dash","Round selection does not change Shop preference")
clock=record.SelectionUntil;abilities:FinishSelection(session,record.WindowId)
session.State="Playing";session.StateVersion+=1;session.GameplayRound={Id="R1",Index=1}
abilities:BeginRound(session)
record.Players[a].CooldownUntil=clock+100
local cooldown=record.Players[a].CooldownUntil
check(s.Shop:PurchaseProduct(a,"DevilSpeed","Abilities") and s.Shop:EquipProduct(a,"DevilSpeed","Abilities"),"Purchase/equip supported while competitive round is Playing")
check(record.Players[a].AbilityId=="AirJumps" and record.Players[a].CooldownUntil==cooldown,"Purchase/preference does not change current skill or cooldown")
select(a,"DevilSpeed")
check(not record.Players[a].SelectionReceipt.Accepted and record.Players[a].AbilityId=="AirJumps","Playing rejects even newly acquired selection")
session.State="PointRestartCountdown";session.StateVersion+=1
local restartStart=clock
abilities:PrepareSelection(session,3);record=abilities._sessions.S
check(record.SelectionUntil==restartStart+3 and record.Players[a].AbilityId=="AirJumps","Three-second restart retains last competitive choice")
select(a,"DevilSpeed")
check(record.Players[a].AbilityId=="DevilSpeed" and record.Players[a].SelectionReceipt.Accepted,"New preference can become selected only after valid request")
check(record.Players[b].AbilityId=="Dash","Other participant unaffected")
clock=record.SelectionUntil;select(a,"Dash")
check(not record.Players[a].SelectionReceipt.Accepted and record.Players[a].AbilityId=="DevilSpeed","Late request cannot replace selection")
abilities:CleanupSession("S","Closed")
session.State="StartCountdown";session.StateVersion+=1;session.GameplayRound=nil
abilities:PrepareSelection(session,5);record=abilities._sessions.S
check(record.Players[a].AbilityId=="DevilSpeed","Next session starts from owned saved preference")
check(s.Config.Round.RoundDuration==180 and s.Config.Round.SuddenDeath.StartAtRemainingSeconds==30,"Round timing/sudden death configuration untouched")
print(string.format("PASS: %d isolated purchase/selection assertions; no Studio/gameplay/cloud execution.",count))
