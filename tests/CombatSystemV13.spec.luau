--!nonstrict
-- Actual runtime modules, disposable network/clock/geometry fixtures, standalone Luau.
-- No Roblox process, match, persistence or external IO is used.
local passed=0
local function check(value,label) assert(value,label);passed+=1 end
local function near(a,b) return math.abs(a-b)<0.000001 end
local function signal()
 local s={Listeners={}}
 function s:Connect(fn)
  local c={Connected=true,Fn=fn}
  function c:Disconnect()self.Connected=false end
  table.insert(self.Listeners,c);return c
 end
 function s:Fire(...)for _,c in ipairs(table.clone(self.Listeners))do if c.Connected then c.Fn(...)end end end
 return s
end
local clock=10
local waits
local world={GetServerTimeNow=function()return 1000+clock end}
local vm={}
local function v(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__add=function(a,b)return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)return v(a.X*b,a.Y*b,a.Z*b)end
vm.__div=function(a,b)return v(a.X/b,a.Y/b,a.Z/b)end
vm.__index=function(a,k)
 if k=="Magnitude" then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end
 if k=="Unit" then return a/a.Magnitude end
 if k=="Dot" then return function(_,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
local vector={new=v}
local function node(name,class,children)
 local n={Name=name,ClassName=class or "Folder",Children=children or {},Attrs={}}
 function n:IsA(c)return c==self.ClassName end
 function n:FindFirstChild(k)return self.Children[k]end
 function n:WaitForChild(k)return self.Children[k]end
 function n:GetAttribute(k)return self.Attrs[k]end
 function n:GetChildren()local r={};for _,c in pairs(self.Children)do table.insert(r,c)end;return r end
 n.ChangedSignals={}
 function n:GetAttributeChangedSignal(k)
  if not self.ChangedSignals[k]then self.ChangedSignals[k]=signal()end
  return self.ChangedSignals[k]
 end
 function n:SetAttribute(k,x)self.Attrs[k]=x;self:GetAttributeChangedSignal(k):Fire()end
 return n
end
local plays,stops=0,0
local animator={LoadAnimation=function()
 return {Play=function()plays+=1 end,Stop=function()stops+=1 end}
end}
local function character(name)
 local c=node(name,"Model");c.Parent=world;c.Attrs.ArenaPhysicsGeneration=1
 c.ChildAdded=signal();c.ChildRemoved=signal()
 local hum=node("Humanoid","Humanoid");hum.Health=100;hum.PlatformStand=false
 function hum:FindFirstChildOfClass(k)return k=="Animator" and animator or nil end
 local root=node("HumanoidRootPart","Part");root.Position=v(0,0,0)
 root.CFrame={LookVector=v(0,0,-1)};root.Parent=c
 c.Children.HumanoidRootPart=root
 function c:FindFirstChildOfClass(k)return k=="Humanoid" and hum or nil end
 function c:IsDescendantOf(w)return self.Parent==w end
 return c,hum,root
end
local P=node("Players","Players");P.PlayerRemoving=signal()
local function player(id)
 local p=node("P"..id,"Player");p.UserId=id;p.Parent=P
 p.Character=character("C"..id);p.CharacterAdded=signal();p.Attrs.MatchId="S"
 return p
end
local a,b=player(-1),player(-2);P.LocalPlayer=a
local function tool(p)
 local power=node("Power","NumberValue");power.Value=20
 local cooldown=node("SlapCooldown","NumberValue");cooldown.Value=.6
 local t=node("Classic","Tool",{Configuration=node("Configuration",nil,{Power=power,SlapCooldown=cooldown}),Swing=node("Swing","Animation")})
 t.Parent=p.Character;t.Attrs.IsSlapWeapon=true;t.Activated=signal();p.Character.Children.Classic=t
 return t
end
local ta,tb=tool(a),tool(b)
local messages,requests={},{}
local perform=node("PerformSlap","RemoteEvent");perform.OnServerEvent=signal()
function perform:FireServer(t,r)table.insert(requests,{Tool=t,Request=r})end
local feedback=node("SlapFeedback","RemoteEvent");feedback.OnClientEvent=signal()
function feedback:FireClient(p,d)table.insert(messages,{Player=p,Data=table.clone(d)})end
local state=node("StateChanged","RemoteEvent");state.OnClientEvent=signal()
local countdown=node("Countdown","RemoteEvent");countdown.OnClientEvent=signal()
local shared={Constants="Constants",Config="Config",Types="Types"}
local rs=node("ReplicatedStorage",nil,{Remotes=node("Remotes",nil,{
 Combat=node("Combat",nil,{PerformSlap=perform,SlapFeedback=feedback}),
 Match=node("Match",nil,{StateChanged=state,Countdown=countdown})})})
rs.Shared=shared
local run={IsStudio=function()return false end}
local services={Players=P,ReplicatedStorage=rs,ServerStorage=node("ServerStorage"),
 ServerScriptService=node("ServerScriptService"),RunService=run,HttpService={}}
local guid=0
function services.HttpService:GenerateGUID()guid+=1;return "guid"..guid end
local gameMock={GetService=function(_,k)return assert(services[k],k)end}
local modules={}
local env={game=gameMock,workspace=world,Vector3=vector,Color3={fromRGB=function()return {}end},
 os={clock=function()return clock end},typeof=function(o)return type(o)=="table" and o.ClassName and "Instance" or type(o)end,
 Enum={AnimationPriority={Action="Action"}},print=function()end,warn=function()end,
 task={wait=function(dt)clock+=dt;if waits then waits(dt)end end},
 require=function(k)return assert(modules[k],"Unknown require "..tostring(k))end}
local function load(key)
 local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable(env,{__index=getfenv()}));return f()
end
modules.Config=load("Config");modules.Constants={RoundState={Playing="Playing"}};modules.Types={}
local C=modules.Config
check(C.Combat.SlapCombo.MissRecovery==.45 and C.Combat.SlapCombo.SuccessfulHitRecovery==.15,"Balance preserved")
check(C.Combat.SlapCombo.SwingWindow==.10 and C.Combat.DefaultSlapKnockdownDuration==3,"Window/ragdoll preserved")
local session={Id="S",State="Playing",GameplayRound={Id="R1"},Participants={}}
local members={}
for i,p in ipairs({a,b})do local row={Player=p,Team=if i==1 then "Red" else "Blue",Slot=1,UserId=p.UserId};members[p]=row;table.insert(session.Participants,row)end
local rounds={}
function rounds:GetSessionForPlayer(p)return members[p] and session end
function rounds:GetSessionById(id)return id==session.Id and session end
function rounds:IsSessionActive(id)return id==session.Id and not session.Closed end
function rounds:GetSessionState()return session.State end
function rounds:GetSessionParticipant(id,p)return id==session.Id and members[p]end
function rounds:IsGameplayRoundOpen(s)return s.State=="Playing" and not s.PointInProgress and not s.Closed end
local Combat=load("Combat")
local combat=setmetatable({_tags={},_lifeHits={},_history={},_roundService=rounds},{__index=Combat})
local hitCalls=0
local originalRegister=combat.RegisterHit
function combat:RegisterHit(...)hitCalls+=1;return originalRegister(self,...)end
local ragdolls,thirds,strongKills=0,0,0
local faultRagdoll=false
local ragdoll={ApplyRagdoll=function(_,_,duration)
 check(duration==3,"Slap ragdoll argument remains 3 seconds")
 if faultRagdoll then error("fixture late physics error")end
 ragdolls+=1
end}
local Strong=load("Strong")
local armed=nil
local abilities={
 PrepareHit=function()
  if armed and Strong.Hooks.BeforeHit(armed)then return {SkipComboCount=true}end
 end,
 ConsumeHit=function()
  if armed and Strong.Hooks.Consume(armed)then return true,{},"StrongSlap"end
  return false
 end,
 PresentCue=function()end,
}
local elimination={
 HandleSlapThreshold=function()thirds+=1;return true end,
 HandleAbilityHit=function()strongKills+=1;return true end,
}
local ctx={GetService=function(_,k)
 return ({RoundService=rounds,CombatService=combat,RagdollService=ragdoll,
 AbilityService=abilities,EliminationService=elimination})[k]
end}
local Slap=load("Slap")
local server=setmetatable({},{__index=Slap})
server:Init(ctx);server:Start(ctx)
local ids={}
local function request(p,t,overrides)
 ids[p]=(ids[p]or 0)+1
 local r={RequestId=ids[p],Character=p.Character,Generation=p.Character:GetAttribute("ArenaPhysicsGeneration"),
 SessionId="S",RoundId=session.GameplayRound.Id}
 for k,x in pairs(overrides or {})do r[k]=x end
 perform.OnServerEvent:Fire(p,t,r)
 return r
end
local function last(p)
 for i=#messages,1,-1 do if messages[i].Player==p then return messages[i].Data end end
end
local function away()b.Character.Children.HumanoidRootPart.Position=v(0,0,-30)end
local function close()b.Character.Children.HumanoidRootPart.Position=v(0,0,-3)end
away()
local start=clock
request(a,ta)
local miss=server._attacks[a]
check(miss.Outcome=="Miss" and near(clock,start+.1),"Miss closes actual 0.10 window")
check(near(miss.RecoveryUntil,clock+.45),"Miss deadline starts at close")
check(last(a).Phase=="Result" and last(a).Accepted and not last(a).Hit,"Accepted Miss distinct from rejection")
local deadline=miss.RecoveryUntil
for _=1,100 do request(a,ta)end
check(server._attacks[a]==miss and miss.RecoveryUntil==deadline and hitCalls==0,"100 miss-recovery requests create no windows/hits")
clock=deadline-.00001;request(a,ta)
check(last(a).Reason=="OnCooldown","Miss boundary before deadline rejected")
clock=deadline;close();request(a,ta)
local hit=server._attacks[a]
check(hit~=miss and hit.Outcome=="Hit" and hit.AttackId~=miss.AttackId,"Hit has unique server ID")
check(near(hit.RecoveryUntil,clock+.15) and last(a).Hit,"Hit recovery starts at accepted contact")
local oldCalls=hitCalls
for _=1,100 do request(a,ta)end
check(hitCalls==oldCalls and server._attacks[a]==hit,"100 hit-recovery requests don't extend or bypass")
clock=hit.RecoveryUntil;request(a,ta)
check(hitCalls==oldCalls+1,"Next valid hit at exact .15 boundary")
-- Hit count belongs to actual CombatService; third accepted hit uses threshold branch.
clock=server._attacks[a].RecoveryUntil;request(a,ta)
check(thirds==1 and combat._lifeHits[b].Count==3,"Three real RegisterHit calls trigger one threshold")
-- Replay, forged scope, invalid Tool and closed round have no new accepted attack.
local before=server._attackSerial
request(a,ta,{RequestId=ids[a]})
check(last(a).Reason=="RequestReplayed" and server._attackSerial==before,"Request replay rejected")
request(a,ta,{Generation=999})
check(last(a).Reason=="RequestScopeMismatch","Forged life rejected")
clock=server._attacks[a].RecoveryUntil
request(a,{})
check(not last(a).Accepted and server._attackSerial==before,"Invalid tool rejected without attack")
session.State="Ending";request(a,ta)
check(last(a).Reason=="MatchNotPlaying" and server._attackSerial==before,"Ending denies attack")
session.State="Playing"
-- In-flight concurrent requests and a second independent real player.
away()
local flooded=false
waits=function()
 if flooded then return end
 flooded=true
 local record=server._attacks[a]
 for _=1,30 do request(a,ta)end
 check(server._attacks[a]==record and last(a).WindowPending,"In-flight spam cannot close/replace window")
 check(last(a).RecoveryUntil==nil,"No invented .05 release for in-flight rejection")
 request(b,tb)
 check(server._attacks[b]~=record and server._attacks[b].AttackId~=record.AttackId,"Two negative users have independent attack IDs")
end
request(a,ta);waits=nil
check(server._attacks[a].Outcome=="Miss" and server._attacks[b].Outcome=="Miss","Both independent miss outcomes finalized")
local beforePair=hitCalls
for cycle=1,3 do
 clock=math.max(server._attacks[a].RecoveryUntil,server._attacks[b].RecoveryUntil)
 request(a,ta);request(b,tb)
 local first,second=server._attacks[a],server._attacks[b]
 for _=1,40 do request(a,ta);request(b,tb)end
 check(server._attacks[a]==first and server._attacks[b]==second,"Repeated pair spam preserves both records "..cycle)
 check(first.AttackId~=second.AttackId and first.Outcome=="Miss" and second.Outcome=="Miss","Independent pair Miss outcomes "..cycle)
end
check(hitCalls==beforePair,"Two-player repeated misses create no extra combat hits")
-- New generation should not inherit the previous life cooldown.
close();combat:ClearCombatTag(b)
a.Character:SetAttribute("ArenaPhysicsGeneration",2)
request(a,ta)
check(last(a).Hit and server._attacks[a].Generation==2,"New life can attack immediately")
-- Error after hit confirmation preserves hit recovery, no extra free hit.
clock=server._attacks[a].RecoveryUntil;faultRagdoll=true
request(a,ta);faultRagdoll=false
local late=server._attacks[a]
check(late.Outcome=="Hit" and near(late.RecoveryUntil,clock+.15) and last(a).Reason=="InternalError","Post-hit exception preserves accepted hit recovery")
local count=hitCalls;request(a,ta)
check(hitCalls==count and last(a).Reason=="OnCooldown","Post-hit error grants no free hit")
-- Error before hit uses finite safe Miss recovery, not a permanent in-flight gate.
clock=late.RecoveryUntil
local originalSelect=server._selectOpponent
server._selectOpponent=function()error("fixture probe error")end
request(a,ta);server._selectOpponent=originalSelect
local failed=server._attacks[a]
check(failed.Stage=="Recovery" and failed.Outcome=="Miss" and near(failed.RecoveryUntil,clock+.45),"Probe exception finalizes finite Miss recovery")
clock=failed.RecoveryUntil;request(a,ta)
check(server._attacks[a]~=failed,"Recoverable error does not permanently lock player")
-- Suspended old invocation throws after replacement: it must not finish or erase replacement.
clock=server._attacks[a].RecoveryUntil
local replacement
server._selectOpponent=function(self,...)
 self._selectOpponent=originalSelect
 a.Character:SetAttribute("ArenaPhysicsGeneration",3)
 request(a,ta);replacement=self._attacks[a]
 error("fixture OLD attempt fails after new life")
end
request(a,ta)
check(server._attacks[a]==replacement and replacement.Stage=="Recovery","Old exception cannot mutate current attack")
check(last(a).Phase=="Cancelled" and last(a).Generation==2,"Obsolete error retains old generation in feedback")
-- Round resolution during window and ragdoll transition after yield cancel without a hit.
clock=replacement.RecoveryUntil;away();local wasHits=hitCalls
waits=function()waits=nil;session.PointInProgress=true end
request(a,ta);waits=nil
check(last(a).Reason=="SwingInvalidated" and hitCalls==wasHits,"Point resolution invalidates pending window")
session.PointInProgress=false;session.GameplayRound.Id="R2"
close();request(a,ta)
check(last(a).Hit and server._attacks[a].RoundId=="R2","New round does not inherit old recovery")
clock=server._attacks[a].RecoveryUntil;away()
waits=function()waits=nil;a.Character:FindFirstChildOfClass("Humanoid").PlatformStand=true;close()end
request(a,ta);waits=nil
check(last(a).Reason=="SwingInvalidated","Ragdoll after yield prevents contact")
a.Character:FindFirstChildOfClass("Humanoid").PlatformStand=false
-- StrongSlap uses real module hooks + real Combat count, keeps arm on Miss.
clock=server._attacks[a].RecoveryUntil;away();armed={}
Strong.Start(armed);request(a,ta)
check(armed.State=="Armed" and strongKills==0,"Miss does not consume StrongSlap")
clock=server._attacks[a].RecoveryUntil;close()
local comboBefore=combat._lifeHits[b].Count
request(a,ta)
check(armed.State=="Consumed" and strongKills==1,"Accepted hit consumes StrongSlap once")
check(combat._lifeHits[b].Count==comboBefore,"StrongSlap skips normal three-hit counter")
check(near(server._attacks[a].RecoveryUntil,clock+.15),"StrongSlap uses same hit recovery")
request(a,ta)
check(strongKills==1,"Cooldown spam cannot duplicate StrongSlap elimination")
armed=nil
-- A hook's yield/state transition must not commit a stale hit.
clock=server._attacks[a].RecoveryUntil
local realPrepare=abilities.PrepareHit
local hitsBeforeHook=hitCalls
abilities.PrepareHit=function()
 a.Character:SetAttribute("ArenaPhysicsGeneration",4)
 return nil
end
request(a,ta);abilities.PrepareHit=realPrepare
check(hitCalls==hitsBeforeHook and last(a).Reason=="SwingInvalidated","Generation change inside hook cannot commit hit")
request(a,ta)
check(last(a).Hit and server._attacks[a].Generation==4,"Replacement life remains usable after stale hook")
-- Actual client lifecycle and input/feedback, with reliable fixtures and deliberate reorder.
local Client=load("SlapController")
local client=setmetatable({},{__index=Client})
client:Init({});client:Start({})
local function snapshot(index,resolved)
 return {SessionId="S",StateVersion=index,RoundId="R"..index,RoundIndex=index,Resolved=resolved}
end
countdown.OnClientEvent:Fire(180,"PLAYING",snapshot(2))
local function activate()ta.Activated:Fire()end
local function feedbackFor(req,sequence,phase,extra)
 local d={Protocol=2,RequestId=req.RequestId,Sequence=sequence,Phase=phase,Accepted=phase~="Rejected",
 Character=req.Character,Generation=req.Generation,SessionId=req.SessionId,RoundId=req.RoundId,AttackId="client-fixture-"..req.RequestId}
 for k,x in pairs(extra or {})do d[k]=x end
 feedback.OnClientEvent:Fire(d);return d
end
activate();local r=requests[#requests].Request
check(#requests==1 and plays==0,"Input sends once with no speculative animation")
for _=1,30 do activate()end
check(#requests==1 and plays==0,"Pending spam has no extra requests or animation")
feedbackFor(r,1,"Rejected",{Reason="OnCooldown",RecoveryUntil=world:GetServerTimeNow()+.45})
check(plays==0 and client._pending==nil,"Rejected request never animates")
local untilTime=client._localNextSlapTime
-- Re-equip same tool via actual character events.
ta.Parent=nil;a.Character.ChildRemoved:Fire(ta)
ta.Parent=a.Character;a.Character.ChildAdded:Fire(ta)
activate()
check(#requests==1 and client._localNextSlapTime==untilTime,"Reequip cannot reset local recovery")
local replacedTool=ta
ta.Parent=nil;a.Character.ChildRemoved:Fire(ta);ta=tool(a);a.Character.ChildAdded:Fire(ta)
activate();replacedTool.Activated:Fire()
check(#requests==1 and client._localNextSlapTime==untilTime,"Replacement Tool cannot reset cooldown or keep old input connected")
clock=untilTime-1000+.000001;activate();local r2=requests[#requests].Request
check(#requests==2,"First input after recovery emits exactly one request")
feedbackFor(r2,3,"Started")
check(plays==1,"Only server-accepted attack animates")
feedbackFor(r2,4,"Started")
check(plays==1,"Duplicate Started cannot replay animation")
local ready=world:GetServerTimeNow()+.15
feedbackFor(r2,5,"Result",{Outcome="Hit",Hit=true,RecoveryUntil=ready})
check(near(client._localNextSlapTime,ready),"Authoritative fast hit recovery reflected")
feedbackFor(r,2,"Rejected",{RecoveryUntil=0})
check(near(client._localNextSlapTime,ready),"Old rejected ack cannot overwrite newer recovery")
for _=1,40 do activate()end
check(#requests==2 and plays==1,"Hit-recovery spam has no effects")
clock=ready-1000+.000001;activate();local r3=requests[#requests].Request
-- Deliberately deliver result before Started.
feedbackFor(r3,7,"Result",{Outcome="Miss",RecoveryUntil=world:GetServerTimeNow()+.45})
feedbackFor(r3,6,"Started")
check(plays==1 and client._pending==nil,"Out-of-order late Started cannot replay a closed attack")
-- New life discards old recovery immediately and rejects late old-generation replies.
a.Character:SetAttribute("ArenaPhysicsGeneration",5);activate()
local fresh=requests[#requests].Request
check(#requests==4 and fresh.Generation==5,"New life first valid attack not blocked")
feedbackFor(r3,1000,"Result",{RecoveryUntil=99999})
check(client._pending.RequestId==fresh.RequestId and client._lastSequence==7,"Old scope ack cannot poison sequence or block new life")
feedbackFor(fresh,8,"Started")
check(plays==2,"Fresh life accepted attack animates normally")
feedbackFor(fresh,9,"Result",{Outcome="Hit",RecoveryUntil=world:GetServerTimeNow()+.15})
-- State transitions clear pending; same-version closed-round data cannot reopen.
clock+=.15;activate();local pendingEnd=requests[#requests].Request
state.OnClientEvent:Fire("PointRestartCountdown",{SessionId="S",StateVersion=3})
feedbackFor(pendingEnd,10,"Started")
local sent=#requests;activate()
check(plays==2 and #requests==sent and client._pending==nil,"End round cancels pending attack and suppresses late visual")
countdown.OnClientEvent:Fire(179,"PLAYING",snapshot(2))
check(not client._playing,"Stale round cannot reopen competition")
countdown.OnClientEvent:Fire(180,"PLAYING",snapshot(3,"Goal"))
countdown.OnClientEvent:Fire(179,"PLAYING",snapshot(3))
check(not client._playing,"Resolved round is sticky even if unresolved snapshot arrives late")
countdown.OnClientEvent:Fire(180,"PLAYING",snapshot(4));activate()
check(#requests==sent+1,"Next round first valid attack is available")
-- No animation for a server rejection despite higher sequence, no delay fabricated.
local nextRequest=requests[#requests].Request
feedbackFor(nextRequest,11,"Rejected",{Reason="MatchNotPlaying"})
check(plays==2,"Competitive server rejection produces no attack animation")
-- Character replacement disconnects old callbacks and doesn't inherit cooldown.
local oldChar=a.Character
a.Character=character("NewCharacter");ta=tool(a);a.CharacterAdded:Fire(a.Character)
activate();local replaced=requests[#requests].Request
check(replaced.Character==a.Character,"Character replacement binds new tool")
oldChar.ChildAdded:Fire(tb)
check(client._equippedTool==ta,"Old character callbacks are disconnected")
-- Transport timeout permits a retry, never visual authorization or accepting old acks.
clock+=2;activate();local retried=requests[#requests].Request
local oldPlays=plays
feedbackFor(replaced,12,"Started")
check(plays==oldPlays and client._pending.RequestId==retried.RequestId,"Timed-out request cannot animate on late acceptance")
feedbackFor(retried,13,"Rejected",{WindowPending=true})
activate()
check(client._pending.RequestId==retried.RequestId and plays==oldPlays,"In-flight rejection cannot release client early")
-- Optional diagnostics stay off by default, Studio-only and at most 12 rows/user/second.
local traceRows={}
services.HttpService.JSONEncode=function(_,row)table.insert(traceRows,row);return "fixture-json"end
rs:SetAttribute("SlapDiagnosticsEnabled",true)
server:_trace(a,"Fixture",server._attacks[a])
check(#traceRows==0,"Diagnostics cannot run outside Studio")
run.IsStudio=function()return true end
rs:SetAttribute("SlapDiagnosticsEnabled",nil)
server:_trace(a,"Fixture",server._attacks[a])
check(#traceRows==0,"Diagnostics default off")
rs:SetAttribute("SlapDiagnosticsEnabled",true)
for _=1,100 do server:_trace(a,"Fixture",server._attacks[a])end
check(#traceRows==12 and traceRows[1].UserId==-1,"Diagnostics bounded and preserve negative UserId")
rs:SetAttribute("SlapDiagnosticsEnabled",nil)
-- Cleanup detaches server record before any suspended call can finish it.
local record=server._attacks[a]
server:_cancelAttack(a,"FixtureSessionEnd")
check(server._attacks[a]==nil and not server:_finishAttack(a,record,"Miss"),"Cancelled record cannot finalize")
P.PlayerRemoving:Fire(a)
check(server._requestIds[a]==nil and server._swingSequence[a]==nil,"Disconnect clears authoritative player state")
print("PASS CombatSystemV13: "..passed.." assertions (isolated; gameplay NOT RUN)")
