--!nonstrict
-- PREPARED / NOT RUN by the agent. Developer isolated harness, no matchmaking or profiles.
return function()
 local Players=game:GetService("Players")
 local Physics=require(game.ServerScriptService.Services.Respawn.CharacterPhysics)
 local Effects=require(game.ServerScriptService.Services.DeathEffectService)
 local Config=require(game.ReplicatedStorage.Shared.Config)
 local count=0
 local function expect(value,message)count+=1;assert(value,message)end
 expect(Config.Respawn.KillPartDelayMs==500,"500ms unchanged")
 expect(Config.Economy.KillRewardCoins==50 and Config.Match.PointReward==50,"Economy unchanged")
 expect(not Config.Respawn.Debug,"Debug disabled by default")
 local service=setmetatable({_seen={},_connections={}},{__index=Effects})
 local session={Id="V122_fixture",State="Playing",StateVersion=3,Participants={}}
 local function player(id)
  return {UserId=id,DisplayName="Fixture"..id,Parent=Players,
   GetAttribute=function(_,key)if key=="MatchId" then return session.Id end end}
 end
 local victim,killer=player(-1),player(-2)
 local red={Player=victim,Team="Red"};local blue={Player=killer,Team="Blue"}
 session.Participants={red,blue}
 local rounds={
  GetSessionById=function(_,id)if id==session.Id then return session end end,
  IsSessionActive=function(_,id)return id==session.Id end,
  GetSessionParticipant=function(_,id,p)if id~=session.Id then return nil end;return if p==victim then red elseif p==killer then blue else nil end,
 }
 service._context={GetService=function(_,name)if name=="RoundService" then return rounds end;error("Snapshot must not query live Character/cosmetic")end}
 local receipts={}
 service._remote={FireClient=function(_,p,payload)table.insert(receipts,{Player=p,Payload=payload})end}
 -- Alternate all three detection paths. Character deliberately absent on both fake players.
 for n=1,10 do
  local reason=({"KillPart","VoidBoundary","VoidBoundaryPolling"})[(n-1)%3+1]
  local id="V122_"..n
  local snapshot=table.freeze({SessionId=session.Id,EliminationId=id,VictimUserId=-1,KillerUserId=-2,
   VictimName="Victim",KillerName="Attacker",Kind="CreditedKill",EffectId="BasicKill",ImpactCFrame=CFrame.new(0,-25,n),Generation=n})
  local record={MatchId=session.Id,EliminationId=id,Reason=reason,Victim=victim,Killer=killer,
   FeedbackSnapshot=snapshot,ImpactCFrame=snapshot.ImpactCFrame,RewardCoins=50,StateVersion=3,ConfirmedAt=workspace:GetServerTimeNow()}
  expect(service:HandleConfirmed(record),"All paths deliver elimination "..n)
  expect(not service:HandleConfirmed(record),"Same elimination rejected twice "..n)
  local private=receipts[#receipts].Payload
  expect(private.RewardOnly~=true and private.EffectId=="BasicKill","Actual visual for void and KillPart "..n)
  expect(private.RewardCoins==50,"Attacker confirmed receipt "..n)
  expect(receipts[#receipts-1].Payload.RewardCoins==0,"Victim gets no reward receipt "..n)
 end
 expect(#receipts==20,"Exactly two authorized deliveries per elimination; no replay")
 local fall={MatchId=session.Id,EliminationId="V122_fall",Reason="VoidBoundaryPolling_NormalFall",Victim=victim,
  RewardCoins=0,StateVersion=3,ConfirmedAt=workspace:GetServerTimeNow(),ImpactCFrame=CFrame.new(),
  FeedbackSnapshot=table.freeze({SessionId=session.Id,EliminationId="V122_fall",VictimUserId=-1,
   Kind="UnattributedFall",EffectId="DefaultFall",ImpactCFrame=CFrame.new()})}
 expect(service:HandleConfirmed(fall),"Unattributed void fallback also delivers DefaultFall")
 expect(receipts[#receipts].Payload.EffectId=="DefaultFall" and receipts[#receipts].Payload.RewardCoins==0,"Fall has effect, no Kill reward")
 session.Closing=true
 fall.EliminationId="closed"
 expect(not service:HandleConfirmed(fall),"Closed session cannot leak feedback")
 session.Closing=nil
 -- Physical contract roundtrip uses an unparented fixture, not a live Character.
 local character=Instance.new("Model")
 local torso=Instance.new("Part");torso.Name="Torso";torso.CanCollide=true;torso.Parent=character
 local root=Instance.new("Part");root.Name="HumanoidRootPart";root.CanCollide=false;root.Parent=character
 local ok,failure=xpcall(function()
  Physics.Track(character)
  torso.CanCollide=false;root.CanCollide=true;torso.CanTouch=false
  expect(Physics.Restore(character),"Captured normal physical contract restored")
  expect(torso.CanCollide and not root.CanCollide,"Restore per part, never all parts collidable")
  expect(torso.CollisionGroup==Physics.Group and root.CollisionGroup==Physics.Group,"Characters keep dedicated group")
  local p=game:GetService("PhysicsService")
  expect(p:CollisionGroupsAreCollidable(Physics.Group,"Default"),"World contact enabled")
  expect(not p:CollisionGroupsAreCollidable(Physics.Group,Physics.Group),"Player exclusion preserved")
 end,debug.traceback)
 Physics.Forget(character);character:Destroy()
 assert(ok,failure)
 return count
end
