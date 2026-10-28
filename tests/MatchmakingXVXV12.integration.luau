-- Runs after V12 base + prematch. Actual server modules, isolated engine adapters.
local before12=count
world.GetServerTimeNow=function()return now101 end
local function newZone12(mode,attrs,withPads)
 local z=node("Folder",mode)
 for k,v in pairs(attrs or {})do z[k]=v end
 if withPads then local joins=put(z,node("Folder","joins-parts"));put(joins,pad101("Red"));put(joins,pad101("Blue"))end
 return z
end
mm=load("Matchmaking");mm._getFeedbackService=function()end
for n=1,4 do
 local mode=n.."v"..n
 check(round:IsModePlayable(mode)and cfg.Matchmaking.Modes[mode].TeamSize==n and cfg.Matchmaking.Modes[mode].TotalPlayers==n*2,"authorized registry "..mode)
 local z=newZone12(mode,{Mode=mode,TeamSize=n,MaxPlayersPerTeam=n,TotalPlayers=n*2,Secuencia="authored"},true)
 mm:_registerZone(z)
 check(mm._zones[z]and mm._zones[z].Config.TeamSize==n and z.Secuencia=="authored","physical zone registration uses registry without editing decorative attrs")
end
for _,value in ipairs({0,-1,1.5,math.huge,0/0,"4",true,3})do
 local z=newZone12("bad",{Mode="4v4",TeamSize=value},true);mm:_registerZone(z)
 check(mm._zones[z]==nil,"inconsistent team capacity rejected")
end
for _,entry in ipairs({{Mode="5v5"},{Mode="Unknown"},{Mode="4v4",MaxPlayersPerTeam=9},{Mode="3v3",TotalPlayers=8}})do
 local z=newZone12("bad",entry,true);mm:_registerZone(z);check(mm._zones[z]==nil,"unknown or inconsistent zone rejected")
end
local noPads=newZone12("4v4",{},false);mm:_registerZone(noPads);check(mm._zones[noPads]==nil,"mode flag cannot create a missing physical queue")
local a=newZone12("A",{Mode="4v4",ZoneId="same"},true);local b=newZone12("B",{Mode="3v3",ZoneId="same"},true)
mm:_registerZone(a);mm:_registerZone(b);check(mm._zones[a]and not mm._zones[b],"duplicate zone identity rejected")

for _,n in ipairs({1,2,3,4})do
 local f=fresh101(n);local s=assert(round:GetSession())
 local sp=load("Spawn");local ar=load("Arena");local sc=load("Score")
 local moved,gear,locks,unlocks,returned={},{},0,0,{}
 sp._getRoundService=function()return round end;sp._getMatchInstanceService=function()return ar end
 sp._getSlapService=function()return{GiveSlap=function(_,p)gear[p]=true end}end
 sp.TeleportCharacterToSpawn=function(_,p,target)
  moved[p]=target;s.ArenaTransferred=true;s.TransferredPlayers=s.TransferredPlayers or {};s.TransferredPlayers[p]=true;return true
 end
 sp.LockSessionPlayers=function(_,session)locks+=#sp:GetSessionParticipants(session)end
 sp.UnlockSessionPlayers=function(_,session)unlocks+=#sp:GetSessionParticipants(session)end
 sp.ReturnPlayersToLobby=function(_,list)for _,p in ipairs(list)do returned[p]=(returned[p]or 0)+1 end;return true end
 round._getSpawnService=function()return sp end;round._getMatchInstanceService=function()return ar end
 ar.CreateInstance=function(_,session,name)
  local valid=ar:IsMapCompatible(name,n);if not valid then return nil end
  local template=maps:FindFirstChild(name);local win=template:FindFirstChild("ZoneWin")
  local info={MatchId=session.Id,TeamSpawns=resolver.Resolve(template,n),Container=world,ZoneWin=win,RedWin=win:FindFirstChild("RedWin"),BlueWin=win:FindFirstChild("BlueWin")}
  ar._instances[session.Id]=info;return info
 end
 ar.DestroyInstance=function(_,id)ar._instances[id]=nil;return true end
 local equipped=0
 round._getSlapService=function()return{EquipMatchPlayers=function(_,session)equipped+=#session.Participants end,UnlockPlayer=function()end,RemoveSlaps=function()end}end
 round._getEliminationService=function()return nil end;round._getCombatService=function()return nil end
 sc._getRoundService=function()return round end
 sc.StartScoring=function(_,session)
  sc._scores[session.Id]=session.Score;sc._playersInside[session.Id]={RedWin={},BlueWin={}};sc._pointInProgress[session.Id]=false
 end
 sc.StopScoring=function()end
 sc.CleanupSession=function(_,id)sc._scores[id]=nil end
 round._getScoreService=function()return sc end
 advance101(5)
 check(s.State==constants.RoundState.MapSelection and f.Calls.MapSelection==n*2,"all participants receive voting "..n)
 -- All slots can submit a vote; no first-player-only path.
 for _,p in ipairs(s.Participants)do round:SubmitMapVote(p.Player,"Levels",s.Id)end
 check(round:_resolveMap(s.Id,{"Levels"})=="Levels","all-team voting resolves compatible map")
 advance101(5)
 check(s.InstanceInfo~=nil and s.State==constants.RoundState.MapLoading,"map preflight and initial batch succeeded")
 for _,q in ipairs(s.Participants)do
  check(q.Slot>=1 and q.Slot<=n and moved[q.Player]==s.InstanceInfo.TeamSpawns[q.Team][q.Slot]and gear[q.Player],"stable distinct spawn and equipment for every slot")
 end
 advance101(1)
 check(s.State==constants.RoundState.StartCountdown and locks==n*2 and equipped==n*2,"all participants locked and equipped during arena preparation")
 advance101(5.5)
 check(s.State==constants.RoundState.Playing and unlocks==n*2 and s.GameplayRound.Index==1,"real round coroutine begins playing")
 check(s.GameplayRound.Deadline-now101>179.9 and s.GameplayRound.Deadline-now101<=180,"180-second round deadline")
 check(not round:AdmitSession({Mode="1v1",ZoneId="other",TeamSize=1,RedTeam={player(5001)},BlueTeam={player(5002)}}),"single concurrent session enforced")
 for _,q in ipairs(s.Participants)do
  local char=q.Player.Character;q.Player.Character=nil
  check(not round:ValidatePreparationParticipants(s,true),"every missing character is rejected")
  q.Player.Character=char
 end
 -- Scope and ID registry must remain authoritative for the last participant as well.
 check(sp:ResolveParticipantSpawn(s.Id,f.Blue[n])==s.InstanceInfo.TeamSpawns.Blue[n],"individual recovery uses last teammate's own spawn")
 check(not sp:ResolveParticipantSpawn(s.Id,player(9999)),"outsider cannot resolve session spawn")
 moved={};local last=s.InstanceInfo.TeamSpawns.Blue[n];s.InstanceInfo.TeamSpawns.Blue[n]=nil
 check(not sp:SpawnMatchPlayers(s).Success and next(moved)==nil,"last missing spawn prevents any partial transfer")
 s.InstanceInfo.TeamSpawns.Blue[n]=last
 local balances={};sc._getPlayerService=function()return{AddCoins=function(_,p,amount)balances[p]=(balances[p]or 0)+amount end}end
 sc._getPointFeedbackService=function()end;sc._broadcastScore=function()end
 sc._getEliminationService=function()return{TryProtectGoal=function()return true end,ReleaseGoalProtections=function()end}end
 local scorer=f.Blue[n]
 sc:_handleZoneScoring(s,"BlueWin",scorer,nil)
 sc:_handleZoneScoring(s,"BlueWin",scorer,nil)
 sc:_handleZoneScoring(s,"RedWin",f.Red[1],nil)
 check(s.Score.Blue==1 and s.Score.Red==0 and balances[scorer]==150,"one shared goal and one personal 150 reward despite repeated/opposing contacts")
 for _,q in ipairs(s.Participants)do if q.Player~=scorer then check(balances[q.Player]==nil,"teammates and opponents receive no scorer reward")end end
 advance101(5)
 check(s.State==constants.RoundState.Playing and s.GameplayRound.Index==2 and s.Score.Blue==1,"goal restarts clock and keeps cumulative team score")
 for _,q in ipairs(s.Participants)do check(moved[q.Player]==s.InstanceInfo.TeamSpawns[q.Team][q.Slot],"round reset preserves every team/slot")end
 check(s.GameplayRound.Deadline-now101>179.9,"new round gets full 180 seconds")
 local oldNow=now101;now101=s.GameplayRound.Deadline-30
 check(round:UpdateGameplayRound(s)and s.GameplayRound.SuddenDeath,"last thirty seconds enable sudden death")
 now101=oldNow -- keep scheduler monotonic relative to its scheduled tasks; isolated deadline probe only.
 if n>1 then
  round:_handlePlayerLeaving(f.Red[n])
  check(s.Result==nil and round:GetSessionParticipant(s.Id,f.Red[n])==nil,"partial active abandonment continues without rebalance")
  f.Red[n].Parent=nil -- finish the simulated PlayerRemoving lifecycle before later cleanup.
 end
 s.Result="Blue"
 local snap=round:CaptureCinematicRanking(s)
 check(#snap.Entries==n*2 and #snap.VisibleParticipants==n and ranking.Validate(snap,s.Id,s.StateVersion),"all participants ranked and only winners visible")
 for index,q in ipairs(snap.VisibleParticipants)do check(q.Team=="Blue"and q.CinematicSlot==index and index<=4,"winning identity maps uniquely to existing stand 1-4")end
 local draw=ranking.Build(snap.Entries,"Draw",s.Mode,{SessionId=s.Id,StateVersion=s.StateVersion})
 check(#draw.VisibleParticipants==0 and ranking.Validate(draw,s.Id,s.StateVersion),"draw remains valid with no winner rigs")
 local forged=table.clone(snap);forged.VisibleParticipants=table.clone(snap.VisibleParticipants)
 forged.VisibleParticipants[1]=table.clone(snap.VisibleParticipants[1]);forged.VisibleParticipants[1].DisplayName="SomeoneElse"
 check(not ranking.Validate(forged,s.Id,s.StateVersion),"wrong billboard name rejected")
 check(not ranking.Validate(snap,"foreign-session",s.StateVersion),"other session snapshot rejected")
 s.Result=nil
 check(round:CloseSession(s.Id,{Cancelled=true})and round:IsAvailable()and ar._instances[s.Id]==nil,"active cleanup releases map and authoritative session")
 local expected=n*2-(n>1 and 1 or 0);local amount=0;for _,v in pairs(returned)do amount+=v end
 check(amount==expected,"only remaining active players return to lobby via adapter")
 round:CloseSession(s.Id,{Cancelled=true});local second=0;for _,v in pairs(returned)do second+=v end
 check(second==amount,"active return is idempotent")
 check(next(round._participantByPlayer)==nil and next(round._sessionIdByUserId)==nil,"no residual participant records")
end

-- Actual queue HUD controller with presentation-only adapters; no new ScreenGui.
-- Execute both positioning paths with a full-orientation CFrame witness. The witness
-- rejects the former Euler-Y reconstruction (Angles is intentionally unavailable).
local originalCFrame=fixtureCFrame
local cfmeta={}
local function frame12(rotation,offset)return setmetatable({Rotation=rotation,Offset=offset,Position={X=0,Y=100,Z=0}},cfmeta)end
cfmeta.__mul=function(a,b)return frame12(a.Rotation or b.Rotation,a.Offset or b.Offset)end
cfmeta.__index={Inverse=function()return frame12(nil,nil)end}
fixtureCFrame={new=function(x,y,z)return frame12(nil,{X=x,Y=y,Z=z})end}
loaded.CharacterPhysics.Restore=function()end;loaded.CharacterPhysics.Trace=function()end
world.FallenPartsDestroyHeight=-500
local actualSpawn=load("Spawn");local subject=player(8801);local other=player(8802)
local subjectChar=subject.Character;local rootPart=subjectChar:FindFirstChild("HumanoidRootPart")
rootPart.Position={Y=100};rootPart.Size={Y=2};rootPart.CFrame=frame12(nil,nil)
local humanoid=subjectChar:FindFirstChildOfClass("Humanoid");humanoid.HipHeight=2
subjectChar.WaitForChild=subjectChar.FindFirstChild;subjectChar.GetDescendants=subjectChar.GetChildren
subjectChar.GetPivot=function()return frame12(nil,nil)end
subjectChar.PivotTo=function(_,value)subjectChar.LastPivot=value end
local marker=node("Part","Spawn4");marker.Size={Y=0.4};marker.CFrame=frame12("pitch/yaw/roll-authored",nil)
local isolated={Id="positioning",State="Playing"};local part={Player=subject,Team="Blue",Slot=4,State="Active"}
isolated.Participants={part}
local authority={GetSessionForPlayer=function(_,p)return p==subject and isolated or nil end,GetSessionParticipant=function(_,_,p)return p==subject and part or nil end}
actualSpawn._getRoundService=function()return authority end;actualSpawn._getRagdollService=function()end
actualSpawn.ResolveParticipantSpawn=function(_,id,p)return id==isolated.Id and p==subject and marker or nil end
check(actualSpawn:TeleportCharacterToSpawn(subject,marker)and subjectChar.LastPivot.Rotation=="pitch/yaw/roll-authored","initial positioning preserves complete orientation")
check(isolated.ArenaTransferred and isolated.TransferredPlayers[subject]and not isolated.TransferredPlayers[other],"only actual transfer is recorded")
check(actualSpawn:ResetCharacterInArena(subject,isolated.Id)and subjectChar.LastPivot.Rotation=="pitch/yaw/roll-authored","individual recovery preserves complete orientation")
check(subject.Character==subjectChar and other.Character.LastPivot==nil and marker.CFrame.Rotation=="pitch/yaw/roll-authored","recovery keeps same rig and leaves teammate and authored spawn intact")
fixtureCFrame=originalCFrame

local queue=load("QueueClient");local p=players.LocalPlayer
queue._queueFrame={Visible=false,AbsoluteSize={X=1600}}
queue._hud={AbsoluteSize={X=800}};queue._queueScale={Scale=1};queue._authoredQueueScale=1
queue._slotTemplate={};queue._redSlotsContainer={};queue._blueSlotsContainer={}
queue._redTeamHeader={};queue._blueTeamHeader={};queue._statusBadge={};queue._isInQueue=true
queue._createSlotInstance=function(_,person)return{Person=person,Destroy=function()end}end
queue:_handleQueueStatus({ZoneId="hud",Mode="4v4",TeamSize=4,TotalPlayers=8,Red={p,player(7102),player(7103),player(7104)},Blue={player(7105),player(7106),player(7107)},State="WAITING"})
check(queue._redTeamHeader.Text=="RED 4/4"and queue._blueTeamHeader.Text=="BLUE 3/4","dynamic per-team counters")
check(#queue._redSlotClones==4 and #queue._blueSlotClones==4 and queue._statusBadge.Text=="ESPERANDO (7/8)","existing HUD presents all eight slots and missing participant")
check(math.abs(queue._queueScale.Scale-0.46)<0.0001,"queue scales to viewport width")
queue._queueFrame.AbsoluteSize.X=1600*queue._queueScale.Scale;queue:_fitQueue()
check(math.abs(queue._queueScale.Scale-0.46)<0.0001,"layout fitting converges without shrinking feedback loop")
check(cfg.Match.PointReward==150 and cfg.Economy.KillRewardCoins==30 and cfg.Combat.SlapCombo.SwingWindow==0.10 and cfg.Combat.DefaultSlapKnockdownDuration==3,"economy and combat balance preserved")
print("PASS MatchmakingXVXV12 integration: "..(count-before12).." new assertions; TOTAL="..count.."; engine adapters, gameplay NOT RUN")
