--!nonstrict
-- PREPARED, NOT RUN by the agent. Isolated fake profiles; no real players or DataStores.
return function()
 local Shared=game.ReplicatedStorage.Shared
 local Config=require(Shared.Config)
 local PlayerService=require(game.ServerScriptService.Services.PlayerService)
 local DeathEffectService=require(game.ServerScriptService.Services.DeathEffectService)
 local checks=0
 local function expect(value,message)checks+=1;assert(value,message)end
 local attacker={Name="Attacker",DisplayName="Attacker",UserId=-1,Parent=game.Players}
 local victim={Name="Victim",DisplayName="Victim",UserId=-2,Parent=game.Players}
 local lobby={Name="Lobby",DisplayName="Lobby",UserId=-3,Parent=game.Players}
 local id="reward-test"
 function attacker:GetAttribute(key)return key=="MatchId" and id end
 function victim:GetAttribute(key)return key=="MatchId" and id end
 local a={Player=attacker,Team="Red"};local v={Player=victim,Team="Blue"}
 local session={Id=id,State="Playing",StateVersion=1,Participants={a,v}}
 local members={[attacker]=a,[victim]=v}
 local rounds={
  GetSessionById=function(_,key)return key==id and session end,
  IsSessionActive=function(_,key)return key==id and not session.Closed end,
  GetSessionParticipant=function(_,key,player)return key==id and members[player]end,
 }
 local updates=0
 local profiles=setmetatable({
  _data={[attacker]={Coins=100,Kills=0}},_coins={},_kills={},_coinTransactions={},
  _context={GetService=function()return rounds end},
  _sendDataUpdate=function()updates+=1 end,
  _register=function()error("A transaction must not recreate a profile")end,
 },{__index=PlayerService})
 expect(Config.Economy.KillRewardCoins==50,"Authorized Kill economy")
 expect(Config.Match.PointReward==50,"Point economy preserved")
 local key=id.."_-2_1"
 local credited,balance=profiles:AwardConfirmedKill(attacker,victim,id,key)
 expect(credited==50 and balance==150,"One valid Kill reward")
 expect(updates==1,"Confirmed credit updates the existing data channel")
 local duplicate,unchanged=profiles:AwardConfirmedKill(attacker,victim,id,key)
 expect(duplicate==0 and unchanged==150 and updates==1,"Repeated transaction has no second receipt or credit")
 local kills,noMoney=profiles:AddKill(attacker,1,"StatsOnly")
 expect(kills==1 and noMoney==0 and profiles:GetCoins(attacker)==150,"Stats-only AddKill does not award twice")
 local newCredit,newBalance=profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_2")
 expect(newCredit==50 and newBalance==200,"A distinct elimination gets its own reward")
 expect(profiles:AwardConfirmedKill(nil,victim,id,id.."_-2_3")==0,"Unattributed fall has no recipient")
 expect(profiles:AwardConfirmedKill(victim,victim,id,id.."_-2_3")==0,"No self reward")
 expect(profiles:AwardConfirmedKill(attacker,victim,id,"wrong-key")==0,"Reject mismatched elimination identity")
 local prior=profiles:GetCoins(attacker)
 attacker.Parent=nil
 expect(profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")==0,"Disconnected attacker rejected")
 attacker.Parent=game.Players
 session.State="Ending"
 expect(profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")==0,"No ending reward")
 session.State="Playing";session.GameplayFrozen=true
 expect(profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")==0,"No frozen gameplay reward")
 session.GameplayFrozen=false
 v.Team="Red"
 expect(profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")==0,"No teammate reward")
 v.Team="Blue"
 expect(profiles:GetCoins(attacker)==prior,"Rejected attempts do not alter balance")
 local data=profiles._data[attacker]
 profiles._data[attacker]=nil
 expect(profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")==0,"Missing profile is not loaded by transaction")
 profiles._data[attacker]=data
 local pointBalance=profiles:AddCoins(attacker,Config.Match.PointReward,"MatchPoint")
 expect(pointBalance==prior+50,"Point and Kill awards are independent")
 profiles._sendDataUpdate=function()error("Intentional notification failure")end
 local committed,committedBalance=profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")
 expect(committed==50 and committedBalance==pointBalance+50,"Notification failure cannot undo committed money")
 local replay,replayBalance=profiles:AwardConfirmedKill(attacker,victim,id,id.."_-2_3")
 expect(replay==0 and replayBalance==committedBalance,"No double credit after notification error")
 local sent={}
 local cosmetics={GetEquippedItem=function()return nil end,HasItem=function()return false end}
 local visual=setmetatable({
  _context={GetService=function(_,name)return name=="RoundService" and rounds or cosmetics end},
  _seen={},_remote={FireClient=function(_,player,payload)table.insert(sent,{Player=player,Payload=payload})end},
 },{__index=DeathEffectService})
 local record={MatchId=id,EliminationId=id.."_-2_3",Victim=victim,Killer=attacker,Reason="KillPart",
  ImpactCFrame=CFrame.new(),RewardCoins=committed,StateVersion=1,ConfirmedAt=workspace:GetServerTimeNow()}
 expect(visual:HandleConfirmed(record),"Visual receipt accepted after commit")
 expect(#sent==2 and sent[1].Player==attacker and sent[1].Payload.RewardCoins==50
  and sent[2].Payload.RewardCoins==0,"Positive receipt only to actual attacker, lobby excluded")
 expect(not visual:HandleConfirmed(record) and #sent==2,"Retransmission does not send another receipt")
 record=table.clone(record);record.EliminationId=id.."_-2_4";record.Reason="VoidBoundary";record.ImpactCFrame=nil
 expect(visual:HandleConfirmed(record) and #sent==3 and sent[3].Player==attacker
  and sent[3].Payload.RewardOnly==true,"Confirmed void Kill can display money without inventing impact effects")
 print("[DeathFeedbackV11.spec] isolated assertions:",checks)
 return checks
end
