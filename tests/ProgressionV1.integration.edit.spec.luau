assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local source=game.ServerScriptService.Services.ProgressionService
local scope=Instance.new('Folder');scope.Name='__ProgressionIntegrationScope';scope.Parent=game.ServerScriptService
local gameplay=Instance.new('Folder');gameplay.Name='Gameplay';gameplay.Parent=scope
game.ReplicatedStorage.Shared.Progression.Config:Clone().Parent=scope
game.ReplicatedStorage.Shared.Progression.Model:Clone().Parent=scope
source.Parent.Gameplay.SeasonState:Clone().Parent=gameplay
local temp=source:Clone();temp.Name='ProgressionService';temp.Source=temp.Source:gsub('local M=require%(RS.Shared.Progression.Model%)','local M=require(script.Parent.Model)',1);temp.Parent=scope
local checks=0
local function check(v,m)assert(v,m);checks+=1 end
local ok,result=xpcall(function()
 local service=require(temp)
 local M=require(game.ReplicatedStorage.Shared.Progression.Model)
 local Store=require(game.ServerScriptService.Services.Persistence.InMemoryDataStore)
 local store=Store.new()
 local actor={UserId=1522376993};local stranger={UserId=8}
 local fake={UserId=-1,Parent=game.Players,GetAttribute=function()return nil end}
 local ps={_data={},IsShopDataReady=function(_,p)return p==fake end}
 ps._data[fake]={Coins=0,Wins=0,Inventory={Owned={Slaps={},PointEffects={},DeathEffects={}},Equipped={},SlapUnits={}},Progression=M.Normalize(nil)}
 function ps:GetPlayerData(p)return self._data[p]end
 function ps:CommitProgression(p,old,nextData)if self._data[p]~=old then return false end;self._data[p]=nextData;return true end
 local commits=0
 local shop={_withShopLock=function(_,p,fn)commits+=1;return fn()end}
 local admin={IsAdmin=function(_,p)return p==actor end}
 local crates={GetRewardTemplate=function(_,reward)if not reward then return nil end;return game.ServerStorage.SlapVariations[reward.SlapId][reward.VariationId]end}
 local context={PersistenceProvider=store,PersistenceInfo={Environment='Studio',ProviderName='InMemory',WritesToCloud=false},GetService=function(_,name)return ({PlayerService=ps,ShopService=shop,AdminService=admin,CrateService=crates})[name]end}
 local lastReceipt
 service:Init(context);service.Push=function(_,_,r)lastReceipt=r end
 check(service.Enabled and service.Store==store,'Strict isolated provider enabled')
 check(service:ReadSeason()and service.Season.Revision==0,'No season starts automatically')
 local forbidden=service:Admin(stranger,'Prepare',{Command='Start',PresetId='TestSeason',Days=60});check(not forbidden.Ok and forbidden.Reason=='Forbidden','Server authorization enforced')
 local request=service:Admin(actor,'Prepare',{Command='Start',PresetId='TestSeason',Days=60});check(request.Ok and request.Token,'Prepare produces confirmation token')
 check(store:GetDiagnostics().CommittedWrites==0,'Prepare cannot mutate season')
 local wrong=service:Admin(actor,'Apply',{Token='wrong'});check(not wrong.Ok,'Wrong confirmation rejected')
 local applied=service:Admin(actor,'Apply',{Token=request.Token});check(applied.Ok and applied.Revision==1,'Confirmed start')
 local id=service.Season.Active.Id
 local repeated=service:Admin(actor,'Apply',{Token=request.Token});check(repeated.Ok and service.Season.Active.Id==id and service.Season.Revision==1,'Retry start cannot create second edition')
 local blocked=service:Admin(actor,'Prepare',{Command='Start',PresetId='TestSeason',Days=60});check(not blocked.Ok and blocked.Reason=='SeasonAlreadyActive','Active season cannot be replaced accidentally')
 local profile=ps._data[fake];profile.Progression.TotalXP=800;profile.Progression.Edition={Id=id,XP=800,Claimed={}}
 local first=service:Claim(fake,1,false);check(first.Ok and ps._data[fake].Coins==150,'Real service claims first reward')
 local repeatClaim=service:Claim(fake,1,false);check(not repeatClaim.Ok and repeatClaim.Reason=='AlreadyClaimed'and ps._data[fake].Coins==150,'Service duplicate does not grant twice')
 profile=ps._data[fake];profile.Progression.TotalXP=24000;profile.Progression.Edition.XP=24000
 local all=service:Claim(fake,nil,true);check(all.Ok and #all.Granted==29 and ps._data[fake].Coins==10350,'Claim all stages remaining atomically')
 local noMore=service:Claim(fake,nil,true);check(not noMore.Ok and noMore.Reason=='NothingToClaim','Repeated claim all grants nothing')
 local snapshot=service:Snapshot(fake);check(snapshot.Stage==30 and snapshot.Level>0 and snapshot.PremiumEnabled==false,'Progression snapshot')
 local restart=service:Admin(actor,'Prepare',{Command='Restart',PresetId='TestSeason',Days=30});check(restart.Ok,'Restart confirmation')
 local reset=service:Admin(actor,'Apply',{Token=restart.Token});check(reset.Ok and service.Season.Active.Id~=id,'New edition ID')
 local after=service:Snapshot(fake);check(after.PassXP==0 and after.Stage==0 and after.TotalXP==24000 and ps._data[fake].Coins==10350,'Reset expires old pass and preserves permanent progress/delivered items')
 local session={Id='IntegrationMatch',State='Playing',Participants={{Player=fake,UserId=-1,Team='Red',State='Active',MatchStats={Goals=1,Kills=1}}}}
 service:StateChanged(session,'StartCountdown','Playing');service:AcceptedAttack(session,fake)
 local track=service.Sessions[session.Id];check(track.Attacks[-1].First~=nil,'Only server accepted attack hook recorded')
 track.Playing=60;track.Since=nil;session.State='Ending'
 service:Settle(session,'Red');check(ps._data[fake].Progression.TotalXP==24105,'Actual settlement path grants correct EXP')
 service:Settle(session,'Red');check(ps._data[fake].Progression.TotalXP==24105,'Close retry idempotent')
 session.Id='Disconnected';service:StateChanged(session,'StartCountdown','Playing');service.Sessions[session.Id].Playing=60;service.Sessions[session.Id].Since=nil;session.Participants[1].State='Left'
 service:Settle(session,'Red');check(ps._data[fake].Progression.TotalXP==24105,'Left participant receives no EXP')
 session.Id='Short';session.Participants[1].State='Active';service:StateChanged(session,'StartCountdown','Playing');service.Sessions[session.Id].Playing=59;service.Sessions[session.Id].Since=nil
 service:Settle(session,'Red');check(lastReceipt and lastReceipt.Reason=='MinimumPlaying'and lastReceipt.XP==0,'Short match notifies zero-XP reason')
 local ending=service:Admin(actor,'Prepare',{Command='End',PresetId='TestSeason',Days=30});check(ending.Ok,'Early-end confirmation')
 check(service:Admin(actor,'Apply',{Token=ending.Token}).Ok,'Confirmed early-end')
 check(not service:Snapshot(fake).Active,'Ending expires pass immediately')
 local closed=service:Claim(fake,1,false);check(not closed.Ok and closed.Reason=='SeasonExpired','Cannot claim after early-end')
 context.PersistenceInfo.WritesToCloud=true;service:Init(context)
 check(not service.Enabled and not service.Store,'Cloud-writing provider blocked even in Studio')
 local gated=service:Request(actor,'AdminInfo',{});check(not gated.Ok and gated.Reason=='StudioOnlyPendingProductionValidation','Disabled environment rejects all actions')
 context.PersistenceInfo={Environment='Production',ProviderName='RobloxDataStore',WritesToCloud=true};service:Init(context);check(not service.Enabled,'Production feature remains disabled')
 return {Assertions=checks,Persistence=store:GetDiagnostics(),Scope='Actual ProgressionService methods with fake players and independent InMemory provider; no Start/Play/cloud'}
end,debug.traceback)
scope:Destroy();if not ok then error(result)end;return result
