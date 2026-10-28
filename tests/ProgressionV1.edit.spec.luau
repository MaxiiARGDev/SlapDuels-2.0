assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local modelModule=game.ReplicatedStorage.Shared.Progression.Model:Clone();modelModule.Name='__ProgressionModelUnit';modelModule.Parent=game.ReplicatedStorage.Shared.Progression
local M=require(modelModule)
local catalogModule=game.ReplicatedStorage.Shared.Progression.PassCatalog:Clone();catalogModule.Name='__ProgressionCatalogUnit';catalogModule.Parent=game.ReplicatedStorage.Shared.Progression
local Catalog=require(catalogModule)
local stateModule=game.ServerScriptService.Services.Gameplay.SeasonState:Clone();stateModule.Name='__ProgressionSeasonUnit';stateModule.Parent=game.ServerScriptService.Services.Gameplay
local State=require(stateModule)
local checks=0
local function check(v,m)assert(v,m);checks+=1 end
local function season(id)return {Id=id or 'S1',StartsAt=1000,EndsAt=10000,Stages=30,StageXP=800,Rewards=M.Copy(Catalog.ById.TestSeason.Rewards)}end
local function match(id)return {Id=id or 'M1',StartedAt=1100,EditionId='S1',Playing=60,Goals=1,Kills=1,Connected=true,Won=true}end
local p=M.Normalize(nil);check(p.TotalXP==0,'New player starts at zero')
local threshold=0
for level=0,200 do
 local cost=math.min(100+25*level,1000)
 local actual,xp,nextCost=M.Level(threshold)
 check(actual==level and xp==0 and nextCost==cost,'Exact level threshold')
 local upper,remainder=M.Level(threshold+cost-1);check(upper==level and remainder==cost-1,'No premature level')
 threshold+=cost
end
local s=season()
check(not State.Valid({Revision=0,Active={Id='Broken'}}),'Corrupt season fails closed')
local awarded,r,changed=M.Award(p,match(),s,1200)
check(changed and r.XP==105 and r.PassXP==105,'40+40+15+10 authoritative award')
check(awarded.TotalXP==105 and awarded.Edition.XP==105,'Both tracks accumulate')
local duplicate,_,again=M.Award(awarded,match(),s,1201);check(not again and duplicate.TotalXP==105,'Repeated match idempotent')
local crossing=match('Expired');crossing.StartedAt=9800
local expired,receipt=M.Award(p,crossing,s,10000);check(expired.TotalXP==105 and receipt.PassXP==0,'Closing at deadline lifetime only')
local replaced,rec=M.Award(p,match('Changed'),season('S2'),1200);check(replaced.TotalXP==105 and rec.PassXP==0,'Edition change lifetime only')
for _,mutation in ipairs({function(m)m.Playing=59.99 end,function(m)m.Left=true end,function(m)m.Connected=false end,function(m)m.Cancelled=true end,function(m)m.Goals=0;m.Kills=0 end})do
 local m=match();mutation(m);local q,_,ok=M.Award(p,m,s,1200);check(not ok and q.TotalXP==0,'Eligibility excludes invalid match')
end
local a=match('Attacks');a.Goals=0;a.Kills=0;a.Won=false;a.FirstAttack=1;a.LastAttack=11
local q,rr,ok=M.Award(p,a,s,1200);check(ok and rr.XP==40,'Two accepted attacks separated by ten seconds')
a.Id='TooClose';a.LastAttack=10.99;local _,_,bad=M.Award(p,a,s,1200);check(not bad,'Attack spacing enforced')
local short=match('Short');short.Playing=59;local _,notice=M.Award(p,short,s,1200);check(notice.XP==0 and notice.Reason=='MinimumPlaying','Clear zero-XP explanation')
local large=match('Big');large.Goals=100;large.Kills=10;local high=M.Award(p,large,s,1200);check(M.Level(high.TotalXP)>1,'Multiple levels in one award')
local current={Revision=0}
local def=Catalog.ById.TestSeason
local started=assert(State.Apply(current,0,'Start',def,60,'S1','Op1',1000,1522376993))
check(started.Active.EndsAt==1000+60*86400,'Global exact end timestamp')
local denied,why=State.Apply(started,1,'Start',def,60,'S2','Op2',1001,1);check(not denied and why=='SeasonAlreadyActive','Cannot replace active season via Start')
local reset=assert(State.Apply(started,1,'Restart',def,30,'S2','Op2',1002,1));check(reset.Active.Id=='S2'and reset.Revision==2,'Reset creates distinct edition')
local replay=State.Apply(reset,1,'Restart',def,30,'S2','Op2',1003,1);check(replay==reset,'Repeated admin operation does not restart twice')
local stale,code=State.Apply(reset,1,'End',nil,nil,nil,'Op3',1004,1);check(not stale and code=='SeasonChanged','Stale revision rejected')
local ended=assert(State.Apply(reset,2,'End',nil,nil,nil,'Op3',1004,1));check(not M.Active(ended.Active,1004),'Explicit early end expires rewards')
check(def.Rewards[1].Amount==150 and started.Active.Rewards[1].Amount==150,'Catalog frozen by copy')
started.Active.Rewards[1].Amount=1;check(def.Rewards[1].Amount==150,'Edition cannot mutate next catalog')
local data={Coins=0,Inventory={Owned={Slaps={},PointEffects={},DeathEffects={}},Equipped={},SlapUnits={}},Progression={TotalXP=24000,Edition={Id='S1',XP=24000,Claimed={}}}}
local slapCatalog={Rewards={}}
for _,rwd in ipairs(s.Rewards)do if rwd.Kind=='Slap'then local slap,var=rwd.Id:match('([^:]+):(.+)');slapCatalog.Rewards[rwd.Id]={SlapId=slap,VariationId=var}end end
local staged=data
for i=1,30 do
 local nextData,delivery=M.Claim(staged,s,1200,i,77,slapCatalog);check(nextData~=nil,'Each stage deliverable');staged=nextData
 local repeatData,reason=M.Claim(staged,s,1200,i,77,slapCatalog);check(not repeatData and reason=='AlreadyClaimed','Every reward claims once')
end
check(staged.Coins==10350,'Approved Coins total')
local units=0;for _,unit in pairs(staged.Inventory.SlapUnits)do units+=1;check(unit.OwnerUserId==77 and unit.Origin=='BattlePass','Individual slap ownership/provenance')end
check(units==6,'Six individual Slaps')
check(staged.Inventory.Owned.PointEffects.Void and staged.Inventory.Owned.DeathEffects.Void,'Effect categories separate')
check(data.Coins==0 and next(data.Inventory.Owned.Slaps)==nil,'Claim staging never mutates original profile')
local restarted=M.Copy(staged);M.Edition(restarted.Progression,season('S2'));check(restarted.Progression.Edition.XP==0 and restarted.Progression.TotalXP==24000 and restarted.Coins==10350,'Reset preserves level and delivered rewards')
local low=M.Copy(data);low.Progression.Edition.XP=799
local locked,reason=M.Claim(low,s,1200,1,77,slapCatalog);check(not locked and reason=='StageLocked','No early claim')
local after,why2=M.Claim(data,s,10000,1,77,slapCatalog);check(not after and why2=='SeasonExpired','No claim at/after deadline')
for stage,amount in pairs({[5]=500,[10]=750,[15]=750,[20]=1500,[25]=3000,[28]=3000})do
 local d=M.Copy(data);local reward=s.Rewards[stage];d.Inventory.Owned[reward.Category][reward.Id]=true
 local got,delivery=M.Claim(d,s,1200,stage,77,slapCatalog);check(got.Coins==amount and delivery.Compensation,'Approved effect compensation')
end
local receipts=M.Normalize(nil)
for i=1,140 do local m=match('Ledger'..i);m.StartedAt=1100+i;receipts=M.Award(receipts,m,nil,1500)end
check(#receipts.ReceiptOrder==128,'Bounded match ledger')
local old=match('Ledger1');old.StartedAt=1101;local final,_,applied=M.Award(receipts,old,nil,1501);check(not applied and final.TotalXP==receipts.TotalXP,'Pruned match cannot replay')
local clean=M.Normalize({TotalXP=0/0,Edition={Id='S1',XP=-1}});check(clean.TotalXP==0 and clean.Edition==nil,'Invalid progression sanitized')
catalogModule:Destroy();stateModule:Destroy();modelModule:Destroy()
return {Assertions=checks,Scope='Pure progression/claims/season transforms; Edit only; no DataStore or players'}
