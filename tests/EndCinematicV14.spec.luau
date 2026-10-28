-- Isolated pure ranking + authoritative event tests. No Bootstrap or persistence.
return function(Ranking,Round,Score,Elimination)
 local passed={}
 local function check(name,value) assert(value,name);table.insert(passed,name) end
 local function rows(n)
  local result={}
  for i=1,n do table.insert(result,{UserId=i,DisplayName="Player"..i,Team=i<=n/2 and "Red" or "Blue",
   CompetitiveSlot=(i-1)%(n/2)+1,Goals=i,Kills=0,Deaths=0}) end
  return result
 end
 local id={SessionId="V14",StateVersion=15}
 local four=Ranking.Build(rows(4),"Red","2v2",id)
 check("four participants ranked",#four.Entries==4 and #four.VisibleParticipants==4)
 local six=Ranking.Build(rows(6),"Red","3v3",id)
 check("six ranked but only five visible",#six.Entries==6 and #six.VisibleParticipants==5)
 check("winner priority is separate from global rank",six.Entries[1].Team=="Blue" and six.VisibleParticipants[1].Team=="Red")
 check("global MVP can lose",six.MVPUserId==6 and six.WinningTeam=="Red")
 check("all three winners visible",six.VisibleParticipants[1].Team=="Red" and six.VisibleParticipants[2].Team=="Red" and six.VisibleParticipants[3].Team=="Red")
 check("competitive and cinematic slots differ",six.VisibleParticipants[1].CompetitiveSlot==3 and six.VisibleParticipants[1].CinematicSlot==1)
 local ten=Ranking.Build(rows(10),"Red","XvX",id)
 check("XvX capacity remains five",#ten.Entries==10 and #ten.VisibleParticipants==5)
 local duel=Ranking.Build(rows(2),"Red","1v1",id)
 check("1v1 shows only winner",#duel.VisibleParticipants==1 and duel.VisibleParticipants[1].Team=="Red")
 local tied=rows(4)
 for _,row in tied do row.Goals=0 end
 tied[1].UserId=-1; tied[2].UserId=-2
 local tie=Ranking.Build(tied,"Red","2v2",id)
 check("ties preserve original stable IDs",tie.Entries[1].UserId==-2 and tie.Entries[2].UserId==-1)
 local missing=Ranking.Build({{UserId=1,DisplayName="Unknown",Team="Red",CompetitiveSlot=1}},"Red","1v1",id)
 check("absent stats remain absent",missing.Entries[1].Goals==nil and missing.Entries[1].MatchPoints==nil and missing.MVPUserId==nil)
 check("snapshot validates",Ranking.Validate(six,"V14",15))
 check("other session rejected",not Ranking.Validate(six,"OTHER",15))
 check("old version rejected",not Ranking.Validate(six,"V14",16))
 local changed=pcall(function() six.Entries[1].Goals=999 end)
 check("snapshot immutable",not changed)
 local original=rows(4)
 local frozen=Ranking.Build(original,"Red","2v2",id)
 original[4].Goals=999
 check("snapshot detached from live stats",frozen.Entries[1].Goals==4)

 local Players=game:GetService("Players")
 local function fake(userId)
  return {UserId=userId,Name="Fake"..userId,DisplayName="Fake"..userId,Parent=Players,IsSimulatedPlayer=true,IsConnected=true,
   IsA=function(_,class) return class=="Player" end,IsDescendantOf=function(_,parent) return parent==Players end,
   Character={Parent=workspace,FindFirstChildOfClass=function() return {Health=100} end}}
 end
 local a,b=fake(-101),fake(-102)
 local s={Id="V14_STATS",State="Playing",StateVersion=6,Mode="1v1",Participants={},Score={Red=0,Blue=0}}
 local r=setmetatable({_sessionsById={[s.Id]=s},_sessionIdByUserId={},_participantByPlayer={}}, {__index=Round})
 for i,p in ipairs({a,b}) do
  local part={Player=p,UserId=p.UserId,Team=i==1 and "Red" or "Blue",Slot=1,State="Active",MatchStats={Goals=0,Kills=0,Deaths=0}}
  table.insert(s.Participants,part);r._participantByPlayer[p]=part;r._sessionIdByUserId[p.UserId]=s.Id
 end
 local coins,kills=0,0
 local scoring=setmetatable({_scores={[s.Id]=s.Score},_pointInProgress={},_playersInside={[s.Id]={RedWin={},BlueWin={}}},_matchPointAnnounced={}}, {__index=Score})
 scoring._getRoundService=function() return r end
 scoring._getPlayerService=function() return {AddCoins=function(_,_,amount) coins+=amount end} end
 scoring._getPointFeedbackService=function() return nil end
 scoring._broadcastScore=function() end;r.TriggerPointRestart=function() end
 scoring:_handleZoneScoring(s,"RedWin",a,nil);scoring:_handleZoneScoring(s,"RedWin",a,nil)
 check("accepted goal updates only scorer once",s.Participants[1].MatchStats.Goals==1 and s.Participants[2].MatchStats.Goals==0 and coins==50)
 check("goal dedupe cannot duplicate stats",not r:RecordMatchPerformance(s.Id,"Goal_1_0",a,nil,nil))
 s.PointInProgress=false;s.PointScorer=nil
 local combat={GetLastAttacker=function() return a,s.Id end,ClearCombatTag=function() end}
 local elimination=setmetatable({_roundService=r,_combatService=combat,_playerService={AddKill=function() kills+=1 end},
  _spawnService={ResetCharacterInArena=function() end},_processingEliminations={},_eliminationCounters={},_resolvedEliminations={}}, {__index=Elimination})
 elimination:_processEliminationEvent(b,s,"IsolatedCombat",nil)
 elimination:_processEliminationEvent(b,s,"IsolatedCombat",nil)
 check("accepted combat event updates Kills and Deaths once",kills==1 and s.Participants[1].MatchStats.Kills==1 and s.Participants[2].MatchStats.Deaths==1)
 elimination._processingEliminations={};combat.GetLastAttacker=function() return nil end
 elimination:_processEliminationEvent(b,s,"IsolatedNormalFall",nil)
 check("normal fall is not competitive death",s.Participants[2].MatchStats.Deaths==1)
 s.GameplayFrozen=true;s.Closing=true;s.Result="Red";s.State="Ending";s.StateVersion=7
 check("terminal performance events rejected",not r:RecordMatchPerformance(s.Id,"Late",a,nil,nil))
 local snapshot=r:CaptureCinematicRanking(s)
 check("snapshot contains match-only totals",snapshot.Entries[1].Goals==1 and snapshot.Entries[1].Kills==1 and snapshot.Entries[1].MatchPoints==nil)
 return {Passed=#passed,Assertions=passed,UsesFakePlayers=true,CloudAccess=false}
end
