--!nonstrict
-- PREPARED ONLY. NOT executed by agent. Disposable fixtures; no Init/bootstrap/live player/cloud.
return function()
 local root=game.ServerScriptService.Services
 local Transit=require(root.Respawn.CompetitiveTransit)
 local Score=require(root.ScoreService)
 local Elimination=require(root.EliminationService)
 local n=0
 local function expect(value,message)n+=1;assert(value,message)end
 local registry=Transit.new()
 local a={Id="a"};local b={Id="b"}
 local p={UserId=-1};local q={UserId=-2};local char={};local nextChar={}
 expect(registry:Claim(a,p,char,1,"Goal","point1"),"Goal first accepted")
 expect(not registry:Claim(a,p,char,1,"Elimination","killpart"),"A1-A4 goal blocks elimination")
 expect(not registry:Claim(a,p,char,1,"Goal","point1"),"A10 no duplicate outcome")
 expect(registry:Claim(a,q,char,1,"Elimination","other"),"A6 other participant unaffected")
 expect(registry:Claim(b,p,char,1,"Elimination","other-session"),"A7 other session unaffected")
 a.PointInProgress=true
 expect(registry:Get(a,p,char,2).Kind=="Goal","Keep same Character protected during reposition/countdown generation handoff")
 registry:ReleaseGoals("a")
 a.PointInProgress=false
 expect(registry:Claim(a,p,char,1,"Elimination","next-play"),"A8 goal release")
 expect(not registry:Claim(a,p,char,1,"Goal","late-score"),"Kill first forbids retroactive score")
 expect(registry:Claim(a,p,nextChar,1,"Goal","new-character"),"A9 new Character independent")
 expect(registry:Claim(a,p,nextChar,2,"Elimination","new-generation"),"A9 new generation independent")
 registry:ForgetPlayer("a",p)
 expect(registry:Get(a,p,nextChar,2)==nil,"Disconnect/Character cleanup")
 registry:ClearSession("b")
 expect(registry._sessions.b==nil,"Close/cancel clears session")
 local replacement={Id="a"}
 expect(registry:Claim(replacement,p,char,1,"Goal","new-session-identity"),"Exact session object required")
 -- Service fixture uses an unparented sandbox folder, never Workspace/Players.
 local box=Instance.new("Folder");box.Name="DisposableScoreKillPartFixture"
 local character=Instance.new("Model");character.Parent=box
 local humanoid=Instance.new("Humanoid");humanoid.Parent=character
 character:SetAttribute("ArenaPhysicsGeneration",7)
 local player={UserId=-1,Name="Fixture",DisplayName="Fixture",Character=character,
  IsA=function(_,kind)return kind=="Player" end,IsDescendantOf=function()return true end}
 local session={Id="fixture",State="Playing",StateVersion=1,Score={Red=0,Blue=0},Participants={}}
 local el=setmetatable({_transits=Transit.new(),_processingEliminations={},_eliminationCounters={},_resolvedEliminations={}},{__index=Elimination})
 el._getActiveSession=function(_,id)return if id==session.Id then session else nil end
 el._getParticipant=function()return {} end
 el._getSpawnService=function()return {IsKillPartRespawnPending=function()return false end}end
 el._getCombatService=function()error("A1-A4 protected goal must never reach attribution")end
 el._getPlayerService=function()error("A4 protected goal must never reach Kill rewards")end
 local starts=0;local finals=0;local coins=0;local awards={}
 local rounds={GetSessionState=function()return session.State end,
  RecordMatchPerformance=function()end,
  TriggerPointRestart=function()starts+=1 end,
  DeclareSessionWinner=function()finals+=1;session.State="Ending";session.GameplayFrozen=true end}
 el._getRoundService=function()return rounds end
 local score=setmetatable({_scores={[session.Id]=session.Score},_pointInProgress={},_playersInside={[session.Id]={RedWin={},BlueWin={}}},_matchPointAnnounced={[session.Id]={}}},{__index=Score})
 score._validateScorer=function()return true,"Red" end
 score._getEliminationService=function()return el end
 score._getRoundService=function()return rounds end
 score._getPlayerService=function()return {AddCoins=function(_,_,amount,reason,id)
  expect(reason=="MatchPoint" and id~=nil,"A5/A17 stable point transaction identity")
  expect(not awards[id],"A17 one award per point");awards[id]=true;coins+=amount
 end}end
 score._getPointFeedbackService=function()return nil end
 score._broadcastScore=function()end;score._broadcastLastPoint=function()end
 score:_handleZoneScoring(session,"RedWin",player,nil)
 expect(session.Score.Red==1 and coins==50 and starts==1,"A5 normal goal +50 and restart")
 -- These calls exercise the actual suppression path, not a UI filter.
 el:_processEliminationEvent(player,session,"KillPart",nil,nil)
 el:_processEliminationEvent(player,session,"VoidBoundaryPolling",nil,nil)
 expect(next(el._processingEliminations)==nil and next(el._eliminationCounters)==nil,"A1-A4 no elimination side effects/debounce")
 score:_handleZoneScoring(session,"RedWin",player,nil)
 expect(coins==50 and session.Score.Red==1,"A10 duplicate touch no goal or reward")
 score:ResumeScoring(session.Id);score:ResetZonePresences(session.Id)
 expect(el._transits:Get(session,player,character,7)==nil,"A8 ResumeScoring clears protection")
 expect(el._transits:Claim(session,player,character,7,"Elimination","first-kill"),"Kill first fixture")
 score:_handleZoneScoring(session,"RedWin",player,nil)
 expect(coins==50 and session.Score.Red==1,"No retroactive goal after elimination")
 -- Simulate successful authoritative reposition by changing existing physics generation.
 character:SetAttribute("ArenaPhysicsGeneration",8)
 for point=2,5 do
  score:ResumeScoring(session.Id);score:ResetZonePresences(session.Id)
  score:_handleZoneScoring(session,"RedWin",player,nil)
 end
 expect(session.Score.Red==5 and coins==250 and starts==4 and finals==1,"A11/A12 fifth goal terminal route once")
 -- Visual/cinematic/Zero-Death/lobby require manual gameplay: A11-A16 remain NOT RUN.
 box:Destroy()
 return n
end
