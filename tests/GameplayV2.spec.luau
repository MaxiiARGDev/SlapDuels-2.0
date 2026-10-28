--!nonstrict
-- PREPARED ONLY; agent did not execute. Isolated harness, disposable tables only.
-- No bootstrap/Init/live profiles, Play, real purchases, timers sped up or cloud access.
return function()
 local root=game.ServerScriptService.Services
 local Clock=require(root.Gameplay.RoundClock)
 local Combat=require(root.CombatService)
 local Score=require(root.ScoreService)
 local Round=require(root.RoundService)
 local Config=require(game.ReplicatedStorage.Shared.Config)
 local n=0
 local function expect(v,label)n+=1;assert(v,label)end
 expect(Config.Round.RoundDuration==180,"T1 180 seconds")
 expect(Config.Round.SuddenDeath.StartAtRemainingSeconds==30,"S1 30-second threshold")
 local a=Clock.Start("s",1,180,100,1000)
 expect(Clock.Remaining(a,100)==180 and a.NetworkDeadline==1180,"T2 start 3:00/network deadline")
 expect(Clock.Remaining(a,249.9)==31 and Clock.Remaining(a,250)==30,"S2 exact threshold")
 expect(Clock.IsOpen(a,279.999) and not Clock.IsOpen(a,280),"T3 timeout boundary")
 expect(not Clock.Resolve(a,"Goal",280),"T4 no goal at/after deadline")
 expect(Clock.Resolve(a,"Timeout",280) and not Clock.Resolve(a,"Goal",280),"T5 timeout terminal once")
 local b=Clock.Start("s",2,180,500,1500)
 expect(b.Id~=a.Id and Clock.Remaining(b,500)==180,"T6 new round full duration/identity")
 expect(not Clock.Resolve(a,"Timeout",1000) and Clock.IsOpen(b,501),"T7 old timer cannot resolve new object")
 expect(Clock.Resolve(b,"Goal",501) and not Clock.Resolve(b,"SuddenDeathFall",501),"T8 goal wins one terminal outcome")
 local c=Clock.Start("s",3,180,700,1700)
 expect(Clock.Resolve(c,"SuddenDeathFall",850) and not Clock.Resolve(c,"Goal",850),"S3 fall wins once")
 -- Exercise real round owner deadline/timeout with an injected expired record and fake result sink.
 local timeoutSession={Id="timeout",State="Playing",StateVersion=1,Participants={},Score={Red=2,Blue=1},
  GameplayRound={Id="old",Index=1,Deadline=-1,NetworkDeadline=0}}
 local ended
 local owner=setmetatable({_sessionsById={timeout=timeoutSession}},{__index=Round})
 owner.CancelGameplayRecoveries=function()end;owner.PublishGameplayRound=function()end
 owner._getScoreService=function()return {GetWinner=function()return "Red" end}end
 owner.BeginSessionResults=function(_,id,result)ended={id,result};return true end
 expect(not owner:UpdateGameplayRound(timeoutSession) and ended[2]=="Red","T9 timeout enters existing results by score")
 expect(timeoutSession.GameplayRound.Resolved=="Timeout","T10 no synthetic goal")
 local roster={}
 local round={Id="combat",State="Playing",StateVersion=1,GameplayRound={Id="round1"}}
 local generation=1
 local character={GetAttribute=function(_,key)return if key=="ArenaPhysicsGeneration" then generation else nil end}
 local attacker={Name="FixtureA",UserId=-1,Parent={},Character=character,IsA=function()return true end}
 local victim={Name="FixtureB",UserId=-2,Parent={},Character=character,IsA=function()return true end}
 roster[attacker]={Player=attacker,Team="Red"};roster[victim]={Player=victim,Team="Blue"}
 local authority={
  GetSessionForPlayer=function()return round end,GetSessionById=function()return round end,
  IsSessionActive=function()return true end,GetSessionState=function()return "Playing" end,
  GetSessionParticipant=function(_,_,p)return roster[p]end,
  IsGameplayRoundOpen=function()return round.GameplayRound.Resolved==nil end,
 }
 local combat=setmetatable({_tags={},_history={},_lifeHits={},_roundService=authority},{__index=Combat})
 for hit=1,3 do local ok,_,count=combat:RegisterHit(attacker,victim,round.Id);expect(ok and count==hit,"C1 valid received hit "..hit)end
 generation=2
 local ok,_,count=combat:RegisterHit(attacker,victim,round.Id)
 expect(ok and count==1,"C2 new life resets hits")
 round.GameplayRound.Id="round2"
 ok,_,count=combat:RegisterHit(attacker,victim,round.Id)
 expect(ok and count==1,"C3 new round resets hits")
 roster[victim].Team="Red"
 expect(not combat:RegisterHit(attacker,victim,round.Id),"C4 friendly fire denied")
 roster[victim].Team="Blue";round.GameplayRound.Resolved="Goal"
 expect(not combat:RegisterHit(attacker,victim,round.Id),"C5 closed round denies hit")
 combat:ClearCombatTag(victim)
 expect(combat._lifeHits[victim]==nil,"C6 elimination/disconnect clears hits")
 -- Collective goal fixture: real Score method, no personal scorer and absolutely no Coins grant.
 local session={Id="collective",State="Playing",StateVersion=1,Score={Red=0,Blue=0},
  GameplayRound={Id="collective:Round:1",Resolved="SuddenDeathFall"}}
 local restarts=0;local finals=0;local payload
 local rounds={
  GetSessionParticipant=function()return {Team="Red"}end,
  RecordMatchPerformance=function()error("Collective goal must not invent individual scorer")end,
  TriggerPointRestart=function()restarts+=1 end,DeclareSessionWinner=function()finals+=1 end,
 }
 local score=setmetatable({_scores={[session.Id]=session.Score},_pointInProgress={},_matchPointAnnounced={[session.Id]={}}},{__index=Score})
 score._getRoundService=function()return rounds end
 score._getPlayerService=function()return {AddCoins=function()error("No personal +50 for collective goal")end}end
 score._broadcastScore=function()end;score._broadcastLastPoint=function()end
 score._getPointFeedbackService=function()return {PlayPoint=function(_,_,data)payload=data end}end
 expect(score:AwardSuddenDeathGoal(session,victim,session.GameplayRound.Id),"S4 collective fall goal")
 expect(session.Score.Blue==1 and session.Score.Red==0 and restarts==1,"S5 opposing team/restart")
 expect(session.PointScorer==nil and payload.ScoringPlayer==nil,"S6 no fabricated personal scorer")
 expect(not score:AwardSuddenDeathGoal(session,victim,session.GameplayRound.Id) and session.Score.Blue==1,"S7 no duplicate goal")
 session.GameplayRound={Id="collective:Round:2",Resolved="SuddenDeathFall"}
 session.Score.Blue=4;score._pointInProgress[session.Id]=false
 expect(score:AwardSuddenDeathGoal(session,victim,session.GameplayRound.Id) and session.Score.Blue==5 and finals==1,"S8 special fifth goal uses terminal owner")
 expect(Config.Combat.DefaultSlapKnockdownDuration==3 and Config.Combat.SlapElimination.HitsToEliminate==3,"C7 defaults")
 expect(Config.Combat.SlapCombo.SuccessfulHitRecovery==.15 and Config.Combat.SlapCombo.MissRecovery==.45,"C8 cadence config")
 expect(Config.Economy.KillRewardCoins==50 and Config.Match.PointReward==50,"R1 economy unchanged")
 expect(Config.Round.PlayableModes["2v2"]==false and Config.Round.PlayableModes["3v3"]==false,"R2 modes disabled")
 -- Remaining integration/gameplay cases require the developer: actual swing window,
 -- third-hit receipt + late sensor, ragdoll duration, private environment/music,
 -- preferences, cinematic, lobby and a second match. No PASS inferred from these fixtures.
 return n
end
