--!nonstrict
-- PREPARED ONLY; not executed by the agent. Run in an isolated developer-owned test context.
-- This suite uses fake players/services and a remote spy; it never credits real profiles.
return function()
 local Shared=game.ReplicatedStorage.Shared
 local Contract=require(Shared.DeathFeedbackContract)
 local Service=require(game.ServerScriptService.Services.DeathEffectService)
 local Catalog=require(Shared.DeathEffectDefinitions)
 local Settings=require(Shared.DeathFeedbackConfig).DeathEffects
 local checks=0
 local function expect(value,message)checks+=1;assert(value,message)end
 local queried
 local victim={UserId=-1,DisplayName="<Victim>",Parent=game.Players}
 local attacker={UserId=-2,DisplayName="Attacker",Parent=game.Players}
 local outsider={UserId=-3,DisplayName="Lobby",Parent=game.Players}
 for _,p in ipairs({victim,attacker})do function p:GetAttribute(key)return key=="MatchId"and"test-session"or nil end end
 function outsider:GetAttribute()return nil end
 local cosmetics={
  GetEquippedItem=function(_,player)queried=player;return player==victim and "VictimEffect"or"AttackerEffect"end,
  HasItem=function()return true end,
  AddCoins=function()error("Presentation must not award Coins")end,
 }
 local future={VictimEffect={RequiredOwnership=true},AttackerEffect={RequiredOwnership=true}}
 expect(Contract.ResolveEffect(cosmetics,victim,true,future,Settings)=="VictimEffect","A1 victim equipment")
 expect(queried==victim,"A2 attacker equipment must not be queried")
 queried=nil
 expect(Contract.ResolveEffect(cosmetics,victim,false,future,Settings)=="DefaultFall"and queried==nil,"A3 fall ignores equipment")
 expect(Contract.ResolveEffect(cosmetics,victim,true,Catalog,Settings)=="BasicKill","Unknown equipment fallback")
 local denied={GetEquippedItem=function()return"VictimEffect"end,HasItem=function()return false end}
 expect(Contract.ResolveEffect(denied,victim,true,future,Settings)=="BasicKill","Ownership enforcement")
 local hit=Contract.ImpactCFrame(CFrame.new(100,-20,50),Vector3.new(40,4,30),Vector3.new(108,-18.5,52))
 expect((hit.Position-Vector3.new(108,-18,52)).Magnitude<.001,"A8 touching limb projected to sensor face")
 expect(not Contract.IsFeedbackState("Ending")and not Contract.IsFeedbackState("Waiting"),"No ending/lobby feedback")
 local vp={Player=victim,Team="Red"};local ap={Player=attacker,Team="Blue"}
 local session={Id="test-session",State="Playing",StateVersion=7,Participants={vp,ap}}
 local members={[victim]=vp,[attacker]=ap}
 local rounds={
  GetSessionById=function(_,id)return id==session.Id and session end,
  IsSessionActive=function(_,id)return id==session.Id and not session.Closed end,
  GetSessionParticipant=function(_,id,p)return id==session.Id and members[p]end,
 }
 local sent={}
 local service=setmetatable({
  _context={GetService=function(_,name)return name=="RoundService"and rounds or cosmetics end},
  _seen={},_remote={FireClient=function(_,p,payload)table.insert(sent,{Player=p,Payload=payload})end},
 },{__index=Service})
 local record={MatchId=session.Id,EliminationId="kill-1",Victim=victim,Killer=attacker,
  Reason="KillPart",ImpactCFrame=hit,RewardCoins=50,StateVersion=7,ConfirmedAt=workspace:GetServerTimeNow()}
 expect(service:HandleConfirmed(record),"Accept final credited decision (synthetic receipt, no credit performed)")
 expect(#sent==2,"A9 private recipients")
 expect(sent[1].Player~=outsider and sent[2].Player~=outsider,"A10 outsider excluded")
 expect(sent[1].Payload.RewardCoins==0 and sent[2].Payload.RewardCoins==50,"A11/A12 exact receipt to attacker only")
 expect(not service:HandleConfirmed(record)and #sent==2,"A5/A6/A7 duplicate final ID rejected")
 local fall=table.clone(record);fall.Killer=nil;fall.EliminationId="fall-1";fall.Reason="KillPart_NormalFall";fall.RewardCoins=0
 expect(service:HandleConfirmed(fall),"Accept final unattributed fall")
 expect(sent[3].Payload.EffectId=="DefaultFall"and sent[3].Payload.RewardCoins==0
  and sent[4].Payload.RewardCoins==0,"A3/A4 fall has no kill reward")
 session.State="Ending"
 local late=table.clone(record);late.EliminationId="late"
 expect(not service:HandleConfirmed(late),"A16 ending rejects late event")
 session.State="Playing"
 late.StateVersion=6
 expect(not service:HandleConfirmed(late),"Old state version rejected")
 late.StateVersion=7;late.ConfirmedAt=workspace:GetServerTimeNow()-60
 expect(not service:HandleConfirmed(late),"Expired receipt rejected")
 print("[DeathFeedbackV1.spec] isolated assertions:",checks)
 return checks
end
