-- Isolated Studio harness. Pass fresh service modules; never initializes Bootstrap.
-- All players, rewards, remotes, positioning and resource managers below are fakes.
return function(services)
 local Players = game:GetService("Players")
 local Round, Score = services.RoundService, services.ScoreService
 local passed, resources = {}, {}
 local function check(name, condition)
  assert(condition, name)
  table.insert(passed, name)
 end
 local function player(id, team)
  local event = Instance.new("BindableEvent")
  table.insert(resources, event)
  local attributes = {}
  return {UserId=id, Name="Fake"..id, DisplayName="Fake"..id, Parent=Players,
   IsSimulatedPlayer=true, IsConnected=true, CharacterAdded=event.Event,
   IsA=function(_,class) return class=="Player" end,
   IsDescendantOf=function(_,parent) return parent==Players end,
   SetAttribute=function(_, k, v) attributes[k]=v end,
   GetAttribute=function(_, k) return attributes[k] end}, team
 end
 local function fixture()
  local r = setmetatable({_sessionsById={}, _sessionIdByUserId={}, _participantByPlayer={},
   _closedSessionIds={}, _rewardedMatches={}, _rewardedPlayers={}}, {__index=Round})
  local counts={Coins=0, Wins=0, Losses=0, Returns=0, Destroys=0, Physics=0}
  local mocks={}
  mocks.PlayerService={AddCoins=function(_,_,n) counts.Coins+=n end,
   AddWin=function() counts.Wins+=1 end, AddLoss=function() counts.Losses+=1 end}
  mocks.SpawnService={ReturnPlayersToLobby=function() counts.Returns+=1 return not counts.FailReturn end}
  mocks.SlapService={UnlockPlayer=function() if counts.FailSlap then error("InjectedSlapFailure") end end, RemoveSlaps=function() end}
  mocks.EliminationService={UnbindMatch=function() end}
  mocks.CombatService={ClearMatch=function() end}
  mocks.PointFeedbackService={CleanupMatch=function() end, PlayPoint=function() counts.Physics+=1 end}
  mocks.MatchInstanceService={DestroyInstance=function() counts.Destroys+=1 return true end}
  mocks.ScoreService={StopScoring=function() end, CleanupSession=function() end}
  mocks.MatchmakingService={}
  r._context={GetService=function(_,name) return mocks[name] end}
  r._getRemote=function() return {FireClient=function() end} end
  r.FireSessionRemote=function() return 0 end
  r._setState=function() end
  r._releaseSession=function(_,s) s.Closed=true; r._sessionsById[s.Id]=nil; r._closedSessionIds[s.Id]=true end
  local a=player(-101); local b=player(-102)
  local s={Id="ISOLATED_V12", State="Playing", StateVersion=6, Participants={},
   Score={Red=4,Blue=0}, Mode="1v1", TeamSize=1, CloseSteps={}}
  for i,p in ipairs({a,b}) do
   local part={Player=p,UserId=p.UserId,Team=i==1 and "Red" or "Blue",Slot=1,State="Active"}
   table.insert(s.Participants,part)
   r._participantByPlayer[p]=part; r._sessionIdByUserId[p.UserId]=s.Id
  end
  r._sessionsById[s.Id]=s
  return r,s,a,b,counts,mocks
 end
 local r,s,a,b,c,m=fixture()
 local oldRestart=task.delay(60,function() error("Old restart survived terminal barrier") end)
 s.PointRestartThread=oldRestart
 local scoring=setmetatable({_scores={[s.Id]=s.Score},_pointInProgress={},
  _playersInside={[s.Id]={RedWin={},BlueWin={}}},_matchPointAnnounced={}}, {__index=Score})
 scoring._getRoundService=function() return r end
 scoring._getPlayerService=function() return m.PlayerService end
 scoring._getPointFeedbackService=function() return m.PointFeedbackService end
 scoring._broadcastScore=function() end
 scoring:_handleZoneScoring(s,"RedWin",a,nil)
 if s.ResultsThread then task.cancel(s.ResultsThread); s.ResultsThread=nil end
 check("fifth point freezes Red result",s.Result=="Red" and s.Score.Red==5 and s.GameplayFrozen and s.State=="Ending")
 check("fifth point grants exactly 50 fake Coins",c.Coins==50)
 check("final feedback cannot launch physics",c.Physics==0)
 check("duplicate winner rejected",not r:DeclareSessionWinner(s.Id,"Blue") and s.Result=="Red")
 scoring._pointInProgress[s.Id]=nil
 scoring._playersInside[s.Id].RedWin[a]=nil
 scoring:_handleZoneScoring(s,"RedWin",a,nil)
 check("late scoring cannot grant Coins",s.Score.Red==5 and c.Coins==50)
 check("old callback cannot restore Playing",not r:SetSessionState(s.Id,"Playing",nil,true))
 check("terminal session is not competitive",not r:IsSessionActive(s.Id) and r:GetSessionParticipant(s.Id,a)==nil)
 check("old point restart is cancelled",s.PointRestartThread==nil and coroutine.status(oldRestart)=="dead")
 local slap=setmetatable({_getRoundService=function() return r end},{__index=services.SlapService})
 local target,_,_,reason=slap:_selectOpponent(a,s,nil)
 check("late Slap selection rejected",target==nil and reason=="SessionNotCombatReady")
 local elimination=setmetatable({_roundService=r,_processingEliminations={}}, {__index=services.EliminationService})
 elimination:_processEliminationEvent(a,s,"LateTest",nil)
 check("late elimination has no side effects",elimination._processingEliminations[a]==nil)
 r:_processReward(s,"Red"); r:_processReward(s,"Red")
 check("Win and Loss idempotent",c.Wins==1 and c.Losses==1)
 local result=s.Results
 check("missing token rejected",not r:HandleCinematicAction(a,"Prepared",s.Id,result.Version,"wrong"))
 check("wrong version rejected",not r:HandleCinematicAction(a,"Prepared",s.Id,result.Version-1,result.Token))
 check("wrong session rejected",not r:HandleCinematicAction(a,"Return","other",result.Version,result.Token))
 local outsider=player(-103)
 check("outsider rejected",not r:HandleCinematicAction(outsider,"Return",s.Id,result.Version,result.Token))
 check("Prepared accepted",r:HandleCinematicAction(a,"Prepared",s.Id,result.Version,result.Token))
 check("duplicate Prepared harmless",r:HandleCinematicAction(a,"Prepared",s.Id,result.Version,result.Token) and result.Viewers[a].Prepared)
 check("individual Return authorized",r:HandleCinematicAction(a,"Return",s.Id,result.Version,result.Token))
 check("peer and scene retained",not result.Viewers[b].Returned and c.Destroys==0 and r._sessionsById[s.Id]==s)
 local returns=c.Returns
 check("duplicate Return harmless",r:HandleCinematicAction(a,"Return",s.Id,result.Version,result.Token) and c.Returns==returns)
 check("last participant closes",r:HandleCinematicAction(b,"Return",s.Id,result.Version,result.Token) and r:CloseSession(s.Id) and c.Destroys==1)
 check("CloseSession idempotent",r:CloseSession(s.Id) and c.Destroys==1)
 check("old session action rejected",not r:HandleCinematicAction(a,"Prepared",s.Id,result.Version,result.Token))
 local r2,s2,a2,b2,c2=fixture()
 check("second fixture begins",r2:BeginSessionResults(s2.Id,"Draw"))
 task.cancel(s2.ResultsThread); s2.ResultsThread=nil
 c2.FailReturn=true
 check("failed return retains quarantine",not r2:CloseSession(s2.Id) and c2.Destroys==0 and not s2.Closed)
 c2.FailReturn=false; c2.FailSlap=true
 check("exception releases return lock",not r2:_returnResultsPlayer(s2,a2) and not s2.Results.Viewers[a2].Returning)
 c2.FailSlap=false
 check("quarantine retry recovers",r2:CloseSession(s2.Id) and c2.Destroys==1)
 check("duration includes view margin",r:GetResultsDuration()>require(game.ReplicatedStorage.Shared.EndCinematicConfig).Results.ViewDuration)
 check("XvX remains disabled",not r:IsModePlayable("2v2") and not r:IsModePlayable("3v3") and Round._maxConcurrentSessions==1)
 local r3,s3,a3=fixture()
 local feedback=setmetatable({_processedPoints={},_activeMatchEffects={},_activeMatchHandles={}}, {__index=services.PointFeedbackService})
 feedback._getRoundService=function() return r3 end
 feedback._validateScoringZone=function() return true end
 feedback._resolvePlayerEffectId=function() return "Basic" end
 local zone=Instance.new("Part"); zone.Name="FakeGoal"; table.insert(resources,zone)
 local template=Instance.new("Model"); table.insert(resources,template)
 feedback._getEffectTemplate=function() return template end
 local stopped=0
 feedback._getControllerRegistry=function() return {GetController=function() return {Play=function()
  task.wait()
  s3.GameplayFrozen=true; s3.Closing=true; s3.Result="Red"
  feedback:CleanupMatch(s3.Id)
  return {Destroy=function() stopped+=1 end}
 end} end} end
 local physicalCalls=0
 feedback._getRagdollService=function() return {BlastZone=function() physicalCalls+=1 end} end
 local payload={PointId="delayed",MatchId=s3.Id,ScoringPlayer=a3,ScoringTeam="Red",ScoringZone=zone}
 check("yielding feedback invalidated",not feedback:PlayPoint(s3,payload) and stopped==1 and physicalCalls==0)
 check("no late feedback handles retained",feedback._activeMatchHandles[s3.Id]==nil and #zone:GetChildren()==0)
 check("frozen feedback rejected",not feedback:PlayPoint(s3,{PointId="late"}) and physicalCalls==0)
 for _,resource in ipairs(resources) do resource:Destroy() end
 return {Passed=#passed, Assertions=passed, CloudAccess=false, UsesFakePlayers=true}
end
