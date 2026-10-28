-- Actual authority/presentation methods over disposable profiles, no Studio or cloud.
local n=0
local function check(v,msg)n+=1;assert(v,msg)end
local function load(key,env)local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local F=load("ShopFixture",{Sources=Sources});local s=F.New()
local ps,a,b=s.PS,s.A,s.B
local constants={RoundState={Playing="Playing",PointRestartCountdown="PointRestartCountdown"}}
local id="economy"
function a:GetAttribute(key)return key=="MatchId"and id end
function b:GetAttribute(key)return key=="MatchId"and id end
a.Character={}
local session={Id=id,State="Playing",Score={Red=0,Blue=0},Participants={}}
local receipts={}
ps._coinTransactions={};ps._data[a].Coins=0
ps._sendDataUpdate=function(_,p,receipt)if receipt then table.insert(receipts,{Player=p,Receipt=receipt})end end
local members={[a]={Team="Red"},[b]={Team="Blue"}}
local rounds={GetSessionById=function()return session end,IsSessionActive=function()return true end,
 GetSessionState=function()return "Playing"end,GetSessionParticipant=function(_,_,p)return members[p]end,
 RecordMatchPerformance=function()end,TriggerPointRestart=function()end,
 TryResolveGameplayRound=function()return true end}
ps._context={GetService=function()return rounds end}
local psEnv=table.clone(s.Env);local oldRequire=s.Env.require
psEnv.require=function(k)return if k=="Constants"then constants else oldRequire(k)end
setmetatable(ps,{__index=load("PlayerService",psEnv)})
check(s.Config.Match.PointReward==150 and s.Config.Economy.KillRewardCoins==30,"Official single configuration")
local shared={Config="Config",Constants="Constants",Types="Types",ArenaRespawnPolicy="Arena"}
local scoreClass=load("ScoreService",{game={GetService=function(_,name)return name=="ReplicatedStorage"and {Shared=shared}or {}end},
 require=function(k)return ({Config=s.Config,Constants=constants,Types={},Arena={}})[k]end,print=function()end,warn=function()end})
local score=setmetatable({_scores={[id]=session.Score},_pointInProgress={},_playersInside={[id]={RedWin={},BlueWin={}}},_matchPointAnnounced={[id]={}}},{__index=scoreClass})
score._getRoundService=function()return rounds end;score._getPlayerService=function()return ps end
score._getPointFeedbackService=function()return nil end;score._broadcastScore=function()end;score._broadcastLastPoint=function()end
score._validateScorer=function()return true,"Red"end
score._getEliminationService=function()return {TryProtectGoal=function()return true end}end
score:_handleZoneScoring(session,"RedWin",a)
check(ps:GetCoins(a)==150 and session.Score.Red==1,"Valid goal credits 150")
check(#receipts==1 and receipts[1].Receipt.RewardCoins==150 and receipts[1].Receipt.Kind=="CreditedGoal","Goal receipt uses committed amount")
score:_handleZoneScoring(session,"RedWin",a)
check(ps:GetCoins(a)==150 and #receipts==1 and session.Score.Red==1,"Duplicate goal no credit or feedback")
local tx=receipts[1].Receipt.EventId
local _,credited=ps:AddCoins(a,s.Config.Match.PointReward,"MatchPoint",tx)
check(credited==0 and #receipts==1,"Replay transaction never emits goal receipt")
for i,reason in ipairs({"SlapThreshold","StrongSlap","KillPart"})do
 local key=id.."_"..b.UserId.."_"..i
 local before=ps:GetCoins(a)
 local amount=ps:AwardConfirmedKill(a,b,id,key)
 check(amount==30 and ps:GetCoins(a)==before+30,"Confirmed "..reason.." reward contract 30")
 check(ps:AwardConfirmedKill(a,b,id,key)==0 and ps:GetCoins(a)==before+30,"Duplicate "..reason.." idempotent")
end
check(ps:AwardConfirmedKill(nil,b,id,id.."_-2_fall")==0,"Unattributed fall has zero reward")
session.GameplayRound={Id="sd",Resolved="SuddenDeathFall"};score._pointInProgress[id]=false
local before=ps:GetCoins(a);local count=#receipts
score:AwardSuddenDeathGoal(session,b,"sd")
check(ps:GetCoins(a)==before and #receipts==count and session.PointScorer==nil,"Sudden death collective goal has no fabricated recipient")
-- Actual shared animation controller: both kinds display the server-confirmed number.
local labels={};local function find(t)return {FindFirstChild=function(_,k)return t[k]end}end
local target=find({})
local hud=find({CoinTarget=target,CoinTemplate={},EffectsContainer={},RewardAmountTemplate={Clone=function()local x={};table.insert(labels,x);return x end}})
a.PlayerGui=find({KillRewardHUD=hud});s.Players.LocalPlayer=a
local scope={new=function()return {Add=function(_,v)return v end,Delay=function()end,Destroy=function()end}end}
local controller=load("KillRewardController",{game={Players=s.Players,ReplicatedStorage={Shared={DeathFeedbackConfig="Settings"}},GetService=function()return {RenderStepped={Connect=function()return {Disconnect=function()end}end}}end},
 script={Parent={Parent={DeathFeedback={Scope="Scope"}}}},require=function(k)return if k=="Scope"then scope else s.Death end})
controller:Init();controller:PlayGoalReceipt(receipts[1].Receipt)
check(#labels==1 and labels[1].Text=="+150 Coins","Actual goal HUD text 150")
controller:PlayGoalReceipt(receipts[1].Receipt)
check(#labels==1,"Duplicate goal receipt no extra animation")
controller:PlayReceipt({Kind="CreditedKill",KillerUserId=a.UserId,RewardCoins=30,SessionId=id,EliminationId="kill-ui"})
check(#labels==2 and labels[2].Text=="+30 Coins","Actual kill HUD text 30")
controller:PlayReceipt({Kind="CreditedKill",KillerUserId=b.UserId,RewardCoins=30,SessionId=id,EliminationId="foreign"})
check(#labels==2,"Foreign reward no animation")
local bad=table.clone(receipts[1].Receipt);bad.RecipientUserId=b.UserId;controller:PlayGoalReceipt(bad)
check(#labels==2,"Foreign goal no animation")
-- Actual elimination entry points -> real processing -> real PlayerService award.
local transit=load("CompetitiveTransit")
shared.DeathFeedbackContract="Contract";shared.DeathEffectDefinitions="Effects";shared.DeathFeedbackConfig="Settings"
local eEnv=table.clone(psEnv)
eEnv.game={GetService=function(_,name)return if name=="ReplicatedStorage"then {Shared=shared}else s.Players end}
eEnv.script={Parent={Respawn={CompetitiveTransit="Transit"}}}
eEnv.require=function(k)return ({Config=s.Config,Constants=constants,Types={},Transit=transit,
 Contract={ResolveEffect=function()return "BasicKill"end},Effects={},Settings=s.Death,Arena={}})[k]end
eEnv.workspace={GetServerTimeNow=function()return 100 end}
eEnv.Instance={new=function()return {Fire=function()end}end}
local elimClass=load("EliminationService",eEnv)
local generation=1
b.Character={Parent=true,GetAttribute=function()return generation end,GetPivot=function()return {}end,
 FindFirstChildOfClass=function()return {Health=100}end}
function b:IsDescendantOf(x)return x==s.Players end
session.PointInProgress=false;session.GameplayRound=nil
rounds.IsGameplayRoundOpen=function()return true end
local attacker=a
local combat={GetLastAttacker=function()return attacker,id end,ClearCombatTag=function()end}
local records={}
local elim=setmetatable({_transits=transit.new(),_processingEliminations={},_eliminationCounters={[b]=20},_resolvedEliminations={}},{__index=elimClass})
elim._getRoundService=function()return rounds end;elim._getActiveSession=function()return session end
elim._getParticipant=function(_,_,p)return members[p]end
elim._getSpawnService=function()return nil end;elim._getCombatService=function()return combat end
elim._getPlayerService=function()return ps end;elim._isOpposingParticipant=function()return true end
elim._publishReceipt=function(_,record)table.insert(records,record)end
for _,reason in ipairs({"SlapThreshold","StrongSlap","KillPart"})do
 generation+=1;elim._processingEliminations[b]=nil
 local before=ps:GetCoins(a);local priorKills=ps._data[a].Kills
 if reason=="SlapThreshold"then check(elim:HandleSlapThreshold(b,session,a),"Actual threshold entry")
 elseif reason=="StrongSlap"then check(elim:HandleAbilityHit(b,session,a,reason),"Actual strong entry")
 else check(elim:_processEliminationEvent(b,session,reason),"Actual attributed boundary processing")end
 check(ps:GetCoins(a)==before+30 and ps._data[a].Kills==priorKills+1 and records[#records].RewardCoins==30,"Actual "..reason.." records one kill and 30")
 elim:_processEliminationEvent(b,session,reason)
 check(ps:GetCoins(a)==before+30 and ps._data[a].Kills==priorKills+1,"Actual duplicate "..reason.." suppressed")
end
generation+=1;elim._processingEliminations[b]=nil;attacker=nil
before=ps:GetCoins(a);local kills=ps._data[a].Kills
elim:_processEliminationEvent(b,session,"KillPart")
check(ps:GetCoins(a)==before and ps._data[a].Kills==kills and records[#records].RewardCoins==0,"Actual unattributed fall no coins or kill")
generation+=1;elim._processingEliminations[b]=nil;attacker=a
check(elim._transits:Claim(session,b,b.Character,generation,"Goal","protected"),"Claim scored life")
local recordCount=#records
elim:_processEliminationEvent(b,session,"KillPart")
check(ps:GetCoins(a)==before and #records==recordCount,"Post-goal boundary does not create reward or elimination")
print("PASS EconomyBalanceV1: "..n.." isolated assertions; gameplay NOT RUN")
