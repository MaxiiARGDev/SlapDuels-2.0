-- Appended to the existing real Round/Matchmaking coroutine fixture.
local beforeSocial=count
shared.SocialPlayConfig='SocialPlayConfig';shared.SocialConfig='SocialConfig'
parent.Gameplay.SocialPlayEngine='SocialPlayEngine'
loaded.SocialConfig={InspectDistance=10}
load('SocialPlayConfig');local SocialEngine=load('SocialPlayEngine')
local f=fresh101(1);local prior=round:GetSession();round:CloseSession(prior.Id,{Cancelled=true,Reason='fixture-reset'})
f.Occupy({},{});advance101(.81);mm:_updateQueue()
local a,b=f.Red[1],f.Blue[1]
players.GetPlayerByUserId=function(_,id)for _,p in ipairs(live101)do if p.UserId==id then return p end end end
local play=load('SocialPlayService');play.Rounds=round;play.Matchmaking=mm;play.Profiles={IsShopDataReady=function()return true end};play.LastRequest={}
local context={GetService=function(_,name)if name=='SocialPlayService'then return play elseif name=='RoundService'then return round elseif name=='MatchmakingService'then return mm end end}
play.Context=context;round._context=context;mm._context=context
play.Engine=SocialEngine.new(loaded.SocialPlayConfig,{
 Clock=function()return now101 end,Id=function()return services.HttpService:GenerateGUID(false)end,
 Eligible=function(id)return play:Eligible(id)end,Near=function()return true end,Name=function(id)return players:GetPlayerByUserId(id).Name end,
 Emit=function()end,GroupChanged=function(id,group)players:GetPlayerByUserId(id):SetAttribute('SocialGroupId',group)end,
 StartDuel=function(grant)return play:StartDuel(grant)end})
check(play:Eligible(a.UserId)and play:Eligible(b.UserId),'real service accepts available lobby peers')
local ok,key=play.Engine:Invite(a.UserId,b.UserId,'Duel');check(ok,'real service duel requested')
check(play.Engine:Respond(b.UserId,key,true),'accepted challenge traverses real StartTeamMatch/admission')
local session=assert(round:GetSession());local grant=assert(play.Engine.Grants[session.ZoneId])
check(session.Mode=='1v1'and session.TeamSize==1 and #session.Participants==2,'exactly two challenge participants')
check(grant.Consumed,'admission consumes server-only challenge token')
check(mm:ArePlayersInZone(session.ZoneId,session.RedTeam,session.BlueTeam,true),'challenge checks explicit consent roster instead of physical pad')
check(not mm:ValidateReservation(grant.Token,{ZoneId=grant.ZoneId,Mode='1v1',TeamSize=1,RedTeam={a},BlueTeam={b}}),'consumed token cannot replay')
check(not play:FindGrant(session.ZoneId,{b},{a}),'swapped roster rejected')
advance101(5.5)
check(session.State==constants.RoundState.MapSelection,'real challenge coroutine reaches voting without pad')
round:CloseSession(session.Id,{Cancelled=true,Reason='fixture-close'})
check(play.Engine.Grants[session.ZoneId]==nil and round:IsAvailable(),'cancelled challenge releases grant and session capacity')

-- Real reward hook reaches exactly one streak result for each completed player.
local raw=load('Round');local outcomes={};local wins,losses=0,0
raw._getPlayerService=function()return {RecordStreakResult=function(_,p,id,result)table.insert(outcomes,{p,id,result})end,AddWin=function()wins+=1 end,AddLoss=function()losses+=1 end}end
local resultSession={Id='streak-match',Participants={{Player=a,Team='Red',State='Active'},{Player=b,Team='Blue',State='Active'}},RedTeam={a},BlueTeam={b}}
raw:_processReward(resultSession,'Red');raw:_processReward(resultSession,'Red')
check(#outcomes==2 and wins==1 and losses==1,'actual result hook records each win/loss once')
check(outcomes[1][3]=='Win'and outcomes[2][3]=='Loss','correct authoritative outcomes')
resultSession.Id='streak-draw';raw:_processReward(resultSession,'Draw')
check(#outcomes==4 and outcomes[3][3]=='Draw'and wins==1 and losses==1,'draw resets block without awarding win/loss')
resultSession.Id='streak-cancelled';raw:_processReward(resultSession,'Cancelled')
check(#outcomes==4,'cancelled matches never enter streak progression')
f=fresh101(2);prior=round:GetSession();round:CloseSession(prior.Id,{Cancelled=true,Reason='fixture-reset'})
play.Rounds=round;play.Matchmaking=mm;round._context=context;mm._context=context
play.Engine.Groups={party={Id='party',Leader=f.Red[1].UserId,Revision=1,Members={f.Red[1].UserId,f.Blue[1].UserId}}}
play.Engine.Membership={[f.Red[1].UserId]='party',[f.Blue[1].UserId]='party'}
mm:_updateQueue()
check(not round:GetSession()and f.Zone.ActiveReservation==nil,'real physical queue refuses group members on opposing sides')
play.Engine.Groups.party.Members={f.Red[1].UserId,f.Red[2].UserId}
play.Engine.Membership={[f.Red[1].UserId]='party',[f.Red[2].UserId]='party'}
mm:_updateQueue()
check(round:GetSession()and round:GetSession().TeamSize==2,'real physical queue admits complete same-side party')
print('PASS ProfileSocialV12 integration: '..(count-beforeSocial)..' additional assertions; real modules, isolated scheduler, no Play')
